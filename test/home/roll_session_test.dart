import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/exercises/data/exercise.dart';
import 'package:sweat_roulette/exercises/state/exercise_providers.dart';
import 'package:sweat_roulette/home/state/roll_session.dart';

import '../exercises/catalogue_fixture.dart';

/// The state machine on its own, without a widget tree. The screen's tests
/// prove what you see; these prove what the day *is* — cheap enough to run the
/// randomness hundreds of times rather than twenty.
void main() {
  late ProviderContainer container;

  setUp(() {
    // The fixture, never the shipped catalogue — see `catalogue_fixture.dart`.
    container = ProviderContainer(
      overrides: [exerciseCatalogueProvider.overrideWithValue(kTestCatalogue)],
    );
    // Disposing cancels any rest timer through `ref.onDispose`, so a test that
    // ends mid-rest doesn't leak one into the next.
    addTearDown(container.dispose);
  });

  RollSession read() => container.read(rollSessionProvider);
  RollSessionNotifier notifier() =>
      container.read(rollSessionProvider.notifier);

  /// ROLL, then SKIP the reels. The day is decided by the first of those; the
  /// second only stops watching it land.
  void rollAndLand() {
    notifier()
      ..advance()
      ..advance();
  }

  test('starts clear, with no day and nothing to show', () {
    expect(read().phase, SessionPhase.clear);
    expect(read().exercises, isEmpty);
  });

  test('rolls two or three exercises, and both come up', () {
    final counts = <int>{};

    for (var i = 0; i < 200; i++) {
      rollAndLand();
      final day = read();

      // VISION.md: each day randomly selects whether to do 2 or 3 pools.
      expect(day.exercises.length, anyOf(2, 3));
      counts.add(day.exercises.length);

      // Every exercise carries an intensity from the axis, and resolves in the
      // catalogue to the name it was rolled under — the id-is-identity,
      // name-is-a-snapshot contract `SlotRecord` documents, tested at the
      // source of both.
      for (final e in day.exercises) {
        expect(intensities, contains(e.intensity));

        final entry = kTestCatalogue.firstWhere((x) => x.id == e.id);
        expect(e.name, entry.name);
      }

      // No name repeats. This used to hold because the roll shuffled one flat
      // list; it now holds because pools are drawn without replacement and an
      // exercise belongs to exactly one pool — see the sibling assertion below,
      // which is the one carrying the weight.
      expect(
        day.exercises.map((e) => e.name).toSet(),
        hasLength(day.exercises.length),
      );

      notifier().reset();
    }

    expect(counts, containsAll(<int>{2, 3}), reason: '200 rolls saw both');
  });

  test('a day never fills more slots than the layout shows', () {
    for (var i = 0; i < 50; i++) {
      rollAndLand();
      expect(read().exercises.length, lessThanOrEqualTo(slots));
      notifier().reset();
    }
  });

  group('choosing by pool', () {
    /// The pool each rolled exercise came from, resolved through the catalogue
    /// — the roll deliberately doesn't carry it, so the screen can't leak it.
    List<MovementPool> poolsOf(RollSession day) => [
      for (final e in day.exercises)
        kTestCatalogue.firstWhere((x) => x.id == e.id).pool,
    ];

    test('a day never takes two exercises from the same pool', () {
      // VISION.md: "those many pools are selected in random order, and for each
      // pool an exercise from each pool is randomly selected."
      for (var i = 0; i < 200; i++) {
        rollAndLand();
        final pools = poolsOf(read());
        expect(pools.toSet(), hasLength(pools.length));
        notifier().reset();
      }
    });

    test('the pools are ordered randomly, not by declaration', () {
      // Taking the first N of `MovementPool.values` would pass every other
      // assertion here and still be wrong — push would open every single day.
      final opening = <MovementPool>{};

      for (var i = 0; i < 200; i++) {
        rollAndLand();
        opening.add(poolsOf(read()).first);
        notifier().reset();
      }

      expect(opening, hasLength(greaterThan(1)));
    });

    test('every pool the catalogue fills is reachable', () {
      final seen = <MovementPool>{};

      for (var i = 0; i < 200; i++) {
        rollAndLand();
        seen.addAll(poolsOf(read()));
        notifier().reset();
      }

      expect(seen, MovementPool.values.toSet());
    });

    test('a pool with nothing in it is skipped, not rolled empty', () {
      // A catalogue that only fills two pools is a two-pool day every time —
      // and never a slot with nothing in it. VISION.md's short day is the roll
      // choosing two, which is a different thing from the catalogue running
      // out, and the second must not be able to produce a hole.
      final sparse = ProviderContainer(
        overrides: [
          exerciseCatalogueProvider.overrideWithValue(const [
            Exercise(id: 't-anvil', name: 'Anvil', pool: MovementPool.push),
            Exercise(id: 't-drum', name: 'Drum', pool: MovementPool.legPull),
          ]),
        ],
      );
      addTearDown(sparse.dispose);

      final rolls = sparse.read(rollSessionProvider.notifier);
      for (var i = 0; i < 50; i++) {
        rolls
          ..advance()
          ..advance();

        final day = sparse.read(rollSessionProvider);
        expect(day.exercises, hasLength(2));
        expect(day.exercises.every((e) => e.name.isNotEmpty), true);

        rolls.reset();
      }
    });
  });

  group('the reveal', () {
    test('ROLL decides the day before any of it is shown', () {
      notifier().advance();

      // Everything random has already happened. The reels that follow animate
      // towards values that are fixed — which is what makes SKIP safe.
      expect(read().phase, SessionPhase.rolling);
      expect(read().exercises, isNotEmpty);
      expect(read().revealed, 0);
      expect(read().actionLabel, 'SKIP');
    });

    test('lands one reel at a time, exercise then rest then exercise', () {
      // Pure state, built by hand: which reel is spinning is a function of how
      // far the reveal has got, so it can be checked without a clock.
      RollSession at(int revealed) => RollSession(
        phase: SessionPhase.rolling,
        exercises: const [
          RolledExercise('A', 'Heavy'),
          RolledExercise('B', 'Light'),
          RolledExercise('C', 'Normal'),
        ],
        revealed: revealed,
      );

      // Three cards, then the two gaps between them.
      expect(at(0).revealSteps, 5);

      /// Everything still turning, in the order it will stop. The first entry
      /// is always the one settling — the only one marked on screen.
      List<String> stillSpinning(RollSession s) => [
        for (var i = 0; i < slots; i++)
          if (s.statusOf(i) case SlotStatus.spinning || SlotStatus.settling)
            'card-$i',
        for (var i = 1; i < slots; i++)
          if (s.restStatusAt(i) case RestStatus.spinning || RestStatus.settling)
            'rest-$i',
      ];

      /// Exactly one thing is ever about to stop.
      List<String> settling(RollSession s) => [
        for (var i = 0; i < slots; i++)
          if (s.statusOf(i) == SlotStatus.settling) 'card-$i',
        for (var i = 1; i < slots; i++)
          if (s.restStatusAt(i) == RestStatus.settling) 'rest-$i',
      ];

      for (var step = 0; step <= 4; step++) {
        expect(settling(at(step)), hasLength(1), reason: 'at step $step');
      }

      // Nothing has landed: the whole machine is running.
      expect(stillSpinning(at(0)), [
        'card-0',
        'card-1',
        'card-2',
        'rest-1',
        'rest-2',
      ]);

      // Every movement lands before any gap does — a rest revealed above a
      // slot that then comes up skipped was never a rest at all.
      expect(stillSpinning(at(1)), ['card-1', 'card-2', 'rest-1', 'rest-2']);
      expect(stillSpinning(at(2)), ['card-2', 'rest-1', 'rest-2']);
      expect(stillSpinning(at(3)), ['rest-1', 'rest-2']);
      expect(stillSpinning(at(4)), ['rest-2']);

      // What has stopped stays stopped.
      for (var step = 0; step <= 4; step++) {
        final s = at(step);
        for (var i = 0; i < slots; i++) {
          if (RollSession.cardStep(i) < step) {
            expect(
              s.statusOf(i),
              SlotStatus.pending,
              reason: 'card $i at step $step',
            );
          }
        }
      }
    });

    test('a short day keeps its length hidden until everything lands', () {
      for (var attempt = 0; attempt < 100; attempt++) {
        notifier().advance();
        if (read().exercises.length == 2) break;
        notifier().reset();
      }
      expect(read().exercises, hasLength(2), reason: 'needed a two-pool day');

      // The third slot spins like every other one, and so does the gap above
      // it. Either sitting still would announce, in the first frame, that this
      // is a short day.
      expect(read().statusOf(2), SlotStatus.spinning);
      expect(read().restStatusAt(2), RestStatus.spinning);

      // But that gap is not in the run: three slots and one gap, where a
      // three-pool day would have five stops.
      expect(read().revealSteps, 4);

      notifier().advance(); // SKIP
      expect(read().statusOf(2), SlotStatus.unrolled);
      // The gap above it comes up empty rather than as an interval — there is
      // nothing after it to rest before.
      expect(read().restStatusAt(2), RestStatus.ghost);
    });

    test('a skipped slot stops its gap the moment the skip lands', () {
      const day = [RolledExercise('A', 'Heavy'), RolledExercise('B', 'Light')];
      RollSession at(int revealed) => RollSession(
        phase: SessionPhase.rolling,
        exercises: day,
        revealed: revealed,
      );

      // Slot 2 lands at step 2. Until then its gap turns like everything else.
      for (var step = 0; step <= 2; step++) {
        expect(
          at(step).restStatusAt(2),
          RestStatus.spinning,
          reason: 'at step $step',
        );
      }

      // The skip lands, and the gap goes with it rather than waiting for a
      // turn of its own.
      expect(at(3).statusOf(2), SlotStatus.unrolled);
      expect(at(3).restStatusAt(2), RestStatus.ghost);

      // The real gap is still to come — it is the last thing in the run.
      expect(at(3).restStatusAt(1), RestStatus.settling);
      expect(at(3).revealSteps, 4);
    });

    test('SKIP lands the day it was already going to land', () {
      notifier()
        ..seed(11)
        ..advance();
      final decided = read().exercises.map((e) => '${e.name}/${e.intensity}');

      notifier().advance(); // SKIP
      expect(read().phase, SessionPhase.rolled);
      expect(read().revealed, read().revealSteps);
      expect(read().exercises.map((e) => '${e.name}/${e.intensity}'), decided);
    });
  });

  group('the walk through a day', () {
    /// Rolls until a day of exactly [length] comes up, so a test can assert on
    /// a shape rather than on whatever the last roll happened to be.
    void rollDayOf(int length) {
      for (var i = 0; i < 100; i++) {
        rollAndLand();
        if (read().exercises.length == length) return;
        notifier().reset();
      }
      fail('never rolled a day of $length');
    }

    test('START opens the first exercise', () {
      rollDayOf(3);
      expect(read().phase, SessionPhase.rolled);

      notifier().advance();
      expect(read().phase, SessionPhase.exercising);
      expect(read().index, 0);
    });

    test('NEXT alternates exercise and rest, then finishes', () {
      rollDayOf(3);
      notifier().advance(); // START

      for (var i = 0; i < 2; i++) {
        expect(read().phase, SessionPhase.exercising);
        expect(read().index, i);

        notifier().advance(); // into the rest
        expect(read().phase, SessionPhase.resting);
        expect(read().secondsLeft, kRestSeconds);

        // Rest leads *into* the next exercise, so the index has already moved
        // and the active bar is the one above it.
        expect(read().index, i + 1);

        notifier().advance(); // skip the rest
      }

      expect(read().phase, SessionPhase.exercising);
      expect(read().index, 2);
      expect(read().isLast, isTrue);

      notifier().advance();
      expect(read().phase, SessionPhase.done);
    });

    test('a two-pool day finishes one exercise sooner', () {
      rollDayOf(2);
      notifier().advance(); // START

      notifier().advance(); // rest
      notifier().advance(); // exercise 2
      expect(read().index, 1);
      expect(read().isLast, isTrue);

      notifier().advance();
      expect(read().phase, SessionPhase.done);
    });

    test('the finished day stays on screen, and rolls the next one', () {
      rollDayOf(2);
      notifier().advance(); // START
      notifier().advance(); // rest
      notifier().advance(); // exercise 2
      notifier().advance(); // FINISH

      // Nothing is thrown away: the day is still there, every slot complete.
      expect(read().phase, SessionPhase.done);
      expect(read().exercises, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(read().statusOf(i), SlotStatus.complete);
      }
      expect(read().restStatusAt(1), RestStatus.complete);

      // And the action starts the next day rather than emptying the screen and
      // asking for a second tap.
      expect(read().actionLabel, 'ROLL');
      notifier().advance();
      expect(read().phase, SessionPhase.rolling);
      expect(read().exercises, isNotEmpty);
    });

    test('the last exercise says FINISH, every other one says NEXT', () {
      rollDayOf(3);
      notifier().advance(); // START

      expect(read().actionLabel, 'NEXT');
      notifier().advance(); // rest
      expect(read().actionLabel, 'NEXT');
      notifier().advance(); // exercise 2
      expect(read().actionLabel, 'NEXT');
      notifier().advance(); // rest
      notifier().advance(); // exercise 3

      // Nothing comes after this one, so the button must not say "next".
      expect(read().isLast, isTrue);
      expect(read().actionLabel, 'FINISH');
    });

    test('slots complete behind the one being worked on', () {
      rollDayOf(3);
      notifier().advance(); // START

      expect(read().statusOf(0), SlotStatus.active);
      expect(read().statusOf(1), SlotStatus.pending);
      expect(read().restStatusAt(1), RestStatus.pending);

      notifier().advance(); // the rest before exercise 2
      expect(read().statusOf(0), SlotStatus.complete);
      expect(read().restStatusAt(1), RestStatus.active);
      // The rest leads *into* slot 1, which hasn't started.
      expect(read().statusOf(1), SlotStatus.pending);

      notifier().advance(); // exercise 2
      expect(read().statusOf(1), SlotStatus.active);
      expect(read().restStatusAt(1), RestStatus.complete);
      expect(read().restStatusAt(2), RestStatus.pending);
    });

    test('a skipped slot gets a ghost rest, not a live one', () {
      rollDayOf(2);

      expect(read().statusOf(2), SlotStatus.unrolled);
      // The gap above a slot that never happens holds its height and says
      // nothing — it is never a rest, in any phase.
      expect(read().restStatusAt(2), RestStatus.ghost);

      notifier().advance(); // START
      expect(read().restStatusAt(2), RestStatus.ghost);
      notifier().advance(); // rest
      expect(read().restStatusAt(2), RestStatus.ghost);
      notifier().advance(); // exercise 2
      notifier().advance(); // FINISH
      expect(read().restStatusAt(2), RestStatus.ghost);
      expect(read().statusOf(2), SlotStatus.unrolled);
    });

    test('reset returns to clear from every phase', () {
      // Including mid-roll, which has a reveal timer of its own to cancel.
      for (var taps = 1; taps <= 6; taps++) {
        for (var i = 0; i < taps; i++) {
          notifier().advance();
        }

        notifier().reset();
        expect(read().phase, SessionPhase.clear, reason: '$taps taps in');
        expect(read().exercises, isEmpty);
        expect(read().index, 0);
      }
    });
  });

  test('a seeded notifier rolls the same day twice', () {
    notifier()
      ..seed(7)
      ..advance();
    final first = read().exercises.map((e) => '${e.name}/${e.intensity}');

    notifier()
      ..reset()
      ..seed(7)
      ..advance();

    expect(read().exercises.map((e) => '${e.name}/${e.intensity}'), first);
  });
}
