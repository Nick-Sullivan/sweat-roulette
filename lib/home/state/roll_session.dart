import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exercises/data/exercise.dart';
import '../../exercises/state/exercise_providers.dart';

/// How many slots a day has. VISION.md rolls 2 or 3 pools, so the third slot is
/// sometimes skipped — but the layout always shows all three.
const slots = 3;

/// The intensity axis. VISION.md rolls heavy/low-rep against light/high-rep;
/// this is that with a middle setting.
const intensities = ['Heavy', 'Normal', 'Light'];

/// TEMPORARY: VISION.md calls for a *random* rest interval, but its range is
/// undecided. A fixed short one so a whole session can be walked in seconds.
/// Delete this together with the RESET button when the real interval lands.
const kRestSeconds = 10;

/// How long everything spins before the first reel stops.
///
/// VISION.md rule 2: the randomness should be fun, and rolling should be a big
/// deal. Every reel is turning during this — long enough to read as a machine
/// running, before anything starts committing.
const kSpinDuration = Duration(milliseconds: 1700);

/// The gap between one reel stopping and the next.
///
/// Comfortably longer than [kReelTail], so a result has settled and been read
/// before the reel below it starts slowing down. Landing them closer together
/// turns five reveals into one blur of movement with nowhere to look.
const kRevealStep = Duration(milliseconds: 800);

/// How long a reel takes to come off full speed and settle.
///
/// Fixed rather than a fraction of the spin, so the last reel — which has been
/// turning three times as long as the first — stops with exactly the same
/// weight.
const kReelTail = Duration(milliseconds: 450);

/// Where a session is. The primary action moves it forward one step at a time;
/// see [RollSessionNotifier.advance].
enum SessionPhase {
  /// Nothing rolled. Three empty slots, so the shape of a day is visible
  /// before it exists.
  clear,

  /// The day is decided but still landing, one reel at a time.
  ///
  /// The whole day is generated the moment ROLL is pressed — this phase only
  /// controls how much of it has been *shown*. Nothing is being decided while
  /// the reels spin, which is what lets a reel animate towards a value it
  /// already knows and lets SKIP be a pure display shortcut.
  rolling,

  /// Rolled but not begun. Two or three filled cards, nothing under way.
  rolled,

  /// Working through [RollSession.index]. That card is expanded.
  exercising,

  /// Between [RollSession.index] - 1 and [RollSession.index], counting down.
  resting,

  /// Past the last exercise. Everything reads as complete.
  done,
}

/// How an exercise slot draws.
enum SlotStatus {
  /// Nothing rolled yet, or rolled but not yet landed.
  ghost,

  /// Turning, with others still to stop before it.
  spinning,

  /// Turning, and the next to stop. The only slot marked while a roll runs —
  /// one thing at a time is about to become an answer.
  settling,

  /// Rolled, not reached.
  pending,

  /// Being worked on — the expanded one.
  active,

  /// Already done. Recedes down the graphite ramp.
  complete,

  /// Done with, because the user said they couldn't do it. Recedes like
  /// [complete] and carries a mark saying so.
  bailed,

  /// A slot this day didn't fill.
  ///
  /// Named for the roll, not for the user: VISION.md rolls 2 *or* 3 pools, so
  /// an empty third slot is the app working correctly and must never read as
  /// something the day fell short of. [bailed] is the one the user chose.
  unrolled,
}

/// How the rest gap *above* an exercise draws.
enum RestStatus {
  /// Nothing rolled, not yet landed, or the exercise it leads into was
  /// skipped. Holds its height and says nothing.
  ghost,

  /// Turning, with others still to stop before it.
  spinning,

  /// Turning, and the next to stop.
  settling,

  /// Rolled, not reached.
  pending,

  /// Counting down. The focus of the screen while it runs.
  active,

  /// Already served.
  complete,
}

/// One exercise as a day rolled it: which movement, and how hard.
///
/// Carries the catalogue's [id] and a snapshot of its [name], not the
/// [Exercise] itself — so the roll screen is never handed a
/// [MovementPool] and therefore cannot leak one, and so a day already rolled
/// keeps reading correctly if the catalogue changes underneath it.
@immutable
class RolledExercise {
  const RolledExercise(this.name, this.intensity, {this.id = ''});

  /// The catalogue's [Exercise.id]. Identity, so a recorded session survives
  /// the movement being renamed.
  final String id;

  /// The catalogue's [Exercise.name], as it read on the day.
  final String name;

  /// One of [intensities].
  final String intensity;
}

@immutable
class RollSession {
  const RollSession({
    this.phase = SessionPhase.clear,
    this.exercises = const [],
    this.index = 0,
    this.secondsLeft = 0,
    this.revealed = 0,
    this.bailed = const {},
  });

  final SessionPhase phase;

  /// Empty while [SessionPhase.clear], otherwise 2 or 3 entries.
  final List<RolledExercise> exercises;

  /// The exercise being worked on. While [SessionPhase.resting] this is the
  /// one the rest leads *into*, so the active rest bar is the one before it.
  final int index;

  /// Only meaningful while [SessionPhase.resting].
  final int secondsLeft;

  /// How many reels have landed, while [SessionPhase.rolling].
  ///
  /// The day is revealed as one interleaved run of cards and the rests between
  /// them — card 0, the rest above card 1, card 1, and so on. This counts how
  /// far down that run the reveal has got; the element at exactly this
  /// position is the one currently spinning.
  final int revealed;

  /// Slots the user said they couldn't do.
  ///
  /// Kept apart from the slots the *roll* didn't fill, which are simply the
  /// ones past the end of [exercises]. Only one of the two is a shortfall, and
  /// conflating them would count a two-pool day as a failed three-pool one.
  final Set<int> bailed;

  /// Positions in the reveal run: every slot, and a rest between each pair.
  ///
  /// Every slot, plus a gap for each pair of exercises that actually happen.
  ///
  /// All three slots are in it however short the day is: a slot the day didn't
  /// fill spins exactly like the others and stops on `Skipped today`, because
  /// leaving it still would announce the length of the day in the first frame.
  ///
  /// The gaps are counted differently. By the time they are being filled in
  /// every exercise has landed, so a gap above a skipped slot has nothing left
  /// to hide and nothing to reveal — it is dropped from the run rather than
  /// given a turn to stop on nothing.
  int get revealSteps => exercises.isEmpty ? 0 : slots + exercises.length - 1;

  /// The reveal position of the card in slot [i], and of the rest above it.
  ///
  /// Every exercise lands before any rest does. Interleaving them would put a
  /// rest interval on screen before the slot it leads into was known — and a
  /// rest revealed above a slot that then comes up skipped was never a rest at
  /// all. Doing the movements first means a gap is only ever filled in once
  /// there is something on both sides of it.
  static int cardStep(int i) => i;
  static int restStep(int i) => slots + i - 1;

  bool get isRolling => phase == SessionPhase.rolling;

  /// Whether [index] is the last exercise of the day.
  bool get isLast => index >= exercises.length - 1;

  /// Whether a session is under way — rolled, and past the starting line.
  bool get isRunning =>
      phase == SessionPhase.exercising || phase == SessionPhase.resting;

  /// What the one primary action says.
  ///
  /// Exhaustive on purpose: adding a phase without giving it a label is a
  /// compile error rather than a blank button. The last exercise reads FINISH
  /// rather than NEXT — there is nothing after it, so offering "next" would be
  /// asking for a tap that does something else than it says.
  String get actionLabel => switch (phase) {
    SessionPhase.clear => 'ROLL',
    // Nothing is being decided while the reels spin, so the action can only
    // shorten the watching. Tired hands shouldn't have to sit through it.
    SessionPhase.rolling => 'SKIP',
    SessionPhase.rolled => 'START',
    SessionPhase.exercising => isLast ? 'FINISH' : 'NEXT',
    SessionPhase.resting => 'NEXT',
    SessionPhase.done => 'ROLL',
  };

  /// How the exercise in slot [i] draws.
  SlotStatus statusOf(int i) {
    if (phase == SessionPhase.clear) return SlotStatus.ghost;

    // Everything not yet landed is still turning — but only one of them is
    // about to stop.
    if (isRolling) {
      final step = cardStep(i);
      if (step == revealed) return SlotStatus.settling;
      if (step > revealed) return SlotStatus.spinning;
      return i >= exercises.length ? SlotStatus.unrolled : SlotStatus.pending;
    }

    if (i >= exercises.length) return SlotStatus.unrolled;

    return switch (phase) {
      // Unreachable — both are handled above. Listed so the switch stays total
      // and a new phase is a compile error rather than a blank slot.
      SessionPhase.clear || SessionPhase.rolling => SlotStatus.ghost,
      SessionPhase.rolled => SlotStatus.pending,
      SessionPhase.done => _finished(i),
      SessionPhase.exercising when i == index => SlotStatus.active,
      // While resting, [index] is the exercise the rest leads *into* — not
      // started, so pending rather than active.
      SessionPhase.exercising ||
      SessionPhase.resting => i < index ? _finished(i) : SlotStatus.pending,
    };
  }

  /// How a slot the session has moved past draws — done, or bailed on.
  SlotStatus _finished(int i) =>
      bailed.contains(i) ? SlotStatus.bailed : SlotStatus.complete;

  /// How the rest gap above the exercise in slot [i] draws. Slot 0 has none.
  RestStatus restStatusAt(int i) {
    if (phase == SessionPhase.clear) return RestStatus.ghost;

    if (isRolling) {
      // A gap above a slot the day didn't fill turns with everything else
      // while that slot is still a mystery — stopping early would give the
      // short day away. The moment the skip lands it stops too, without
      // waiting for a turn it has nothing to say on.
      if (i >= exercises.length) {
        return cardStep(i) < revealed ? RestStatus.ghost : RestStatus.spinning;
      }

      final step = restStep(i);
      if (step == revealed) return RestStatus.settling;
      if (step > revealed) return RestStatus.spinning;
      return RestStatus.pending;
    }

    // A rest that leads into a slot this day didn't fill isn't a rest — but it
    // still holds its height, or the cards above it would move.
    if (i >= exercises.length) return RestStatus.ghost;

    return switch (phase) {
      // Unreachable — both are handled above.
      SessionPhase.clear || SessionPhase.rolling => RestStatus.ghost,
      SessionPhase.rolled => RestStatus.pending,
      SessionPhase.done => RestStatus.complete,
      SessionPhase.resting when i == index => RestStatus.active,
      // Reaching exercise `index` means every gap up to and including it has
      // been served.
      SessionPhase.exercising =>
        i <= index ? RestStatus.complete : RestStatus.pending,
      SessionPhase.resting =>
        i < index ? RestStatus.complete : RestStatus.pending,
    };
  }

  RollSession copyWith({
    SessionPhase? phase,
    List<RolledExercise>? exercises,
    int? index,
    int? secondsLeft,
    int? revealed,
    Set<int>? bailed,
  }) {
    return RollSession(
      phase: phase ?? this.phase,
      exercises: exercises ?? this.exercises,
      index: index ?? this.index,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      revealed: revealed ?? this.revealed,
      bailed: bailed ?? this.bailed,
    );
  }
}

/// The whole session state machine.
///
/// It lives here rather than in the screen's [State] for two reasons: leaving
/// for History and coming back must not silently discard a half-finished
/// session, and the rest countdown needs a disposal owner that isn't a widget
/// being rebuilt.
class RollSessionNotifier extends Notifier<RollSession> {
  Random _random = Random();
  Timer? _timer;

  @override
  RollSession build() {
    ref.onDispose(_stopTimer);
    return const RollSession();
  }

  /// Fixes the sequence, so a test can assert on a known day.
  @visibleForTesting
  void seed(int seed) => _random = Random(seed);

  /// The one primary action. What it means depends on where the session is —
  /// ROLL, START, NEXT or FINISH — but there is only ever one of it on screen.
  void advance() {
    switch (state.phase) {
      case SessionPhase.clear:
        _roll();
      // The day is already decided; this only stops watching it land.
      case SessionPhase.rolling:
        _land();
      case SessionPhase.rolled:
        _beginAt(0);
      case SessionPhase.exercising:
        if (state.isLast) {
          _stopTimer();
          state = state.copyWith(phase: SessionPhase.done);
        } else {
          _rest();
        }
      // Pressing NEXT mid-rest skips the remainder of it.
      case SessionPhase.resting:
        _beginAt(state.index);
      // The finished day is on screen; the action starts the next one rather
      // than emptying the screen and asking for a second tap.
      case SessionPhase.done:
        _roll();
    }
  }

  /// The user couldn't do the exercise they're on. Marks it and moves on.
  ///
  /// One tap, not two: it advances exactly as NEXT does, because a control that
  /// only records and then wants a second press to continue is a control you
  /// stop using mid-set. Ignored outside [SessionPhase.exercising] — there is
  /// no current exercise to bail on while a rest is running.
  void skipCurrent() {
    if (state.phase != SessionPhase.exercising) return;
    state = state.copyWith(bailed: {...state.bailed, state.index});
    advance();
  }

  /// Back to three empty slots, from wherever the session had got to.
  void reset() {
    _stopTimer();
    state = const RollSession();
  }

  /// Decides the whole day, then starts showing it.
  ///
  /// Everything random happens here, in one go. The reels that follow are
  /// display only — they animate towards values that are already fixed, which
  /// is why SKIP can jump to the end without changing what you get.
  void _roll() {
    _stopTimer();

    final catalogue = ref.read(exerciseCatalogueProvider);

    // Only the pools the catalogue can actually fill. An empty pool is not a
    // short day — VISION.md's short day is the roll choosing two, not the
    // catalogue running out — so it is dropped before the count is drawn,
    // rather than producing a slot with nothing in it.
    final pools = [
      for (final pool in MovementPool.values)
        if (catalogue.any((e) => e.pool == pool)) pool,
    ]..shuffle(_random);

    assert(pools.length >= 2, 'the catalogue must fill at least two pools');

    // VISION.md: a day rolls 2 or 3 pools, selected in random order.
    final count = min(slots - _random.nextInt(2), pools.length);

    state = RollSession(
      phase: SessionPhase.rolling,
      exercises: [for (final pool in pools.take(count)) _pick(catalogue, pool)],
    );

    _scheduleLanding();
  }

  /// One exercise from [pool], at a random intensity.
  ///
  /// No repeat check, and none is needed: the pools above are drawn without
  /// replacement and an [Exercise] belongs to exactly one pool, so a day cannot
  /// roll the same movement twice. That is a property of [Exercise.pool] being
  /// single-valued — read the note on it before making it a set.
  RolledExercise _pick(List<Exercise> catalogue, MovementPool pool) {
    final choices = [
      for (final exercise in catalogue)
        if (exercise.pool == pool) exercise,
    ];
    final chosen = choices[_random.nextInt(choices.length)];

    return RolledExercise(
      chosen.name,
      intensities[_random.nextInt(intensities.length)],
      id: chosen.id,
    );
  }

  /// Stops the reels from the top down — the first exercise, then the rest
  /// after it, then the next exercise, all the way to the bottom.
  ///
  /// Not a periodic timer: the first stop comes after the longer
  /// [kSpinDuration] lead-in, while everything is still turning, and only then
  /// do they fall one [kRevealStep] apart.
  void _scheduleLanding() {
    final delay = state.revealed == 0 ? kSpinDuration : kRevealStep;

    _timer = Timer(delay, () {
      final next = state.revealed + 1;
      if (next >= state.revealSteps) {
        _land();
      } else {
        state = state.copyWith(revealed: next);
        _scheduleLanding();
      }
    });
  }

  /// Everything landed — either because the reels finished or because SKIP was
  /// pressed. The day is identical either way.
  void _land() {
    _stopTimer();
    state = state.copyWith(
      phase: SessionPhase.rolled,
      revealed: state.revealSteps,
    );
  }

  void _beginAt(int index) {
    _stopTimer();
    state = state.copyWith(
      phase: SessionPhase.exercising,
      index: index,
      secondsLeft: 0,
    );
  }

  /// Rest leads into the *next* exercise, so [RollSession.index] moves now and
  /// the active rest bar is the one sitting above it.
  void _rest() {
    _stopTimer();
    state = state.copyWith(
      phase: SessionPhase.resting,
      index: state.index + 1,
      secondsLeft: kRestSeconds,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        // Cancel before the transition, not after: a timer that keeps
        // rescheduling makes `pumpAndSettle()` run to its timeout, and one
        // outliving the tree fails a test with "A Timer is still pending".
        _beginAt(state.index);
      } else {
        state = state.copyWith(secondsLeft: left);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final rollSessionProvider = NotifierProvider<RollSessionNotifier, RollSession>(
  RollSessionNotifier.new,
);
