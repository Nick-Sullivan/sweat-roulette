import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/exercises/state/exercise_providers.dart';
import 'package:sweat_roulette/history/data/session_record.dart';
import 'package:sweat_roulette/history/data/session_store.dart';
import 'package:sweat_roulette/history/state/history_providers.dart';
import 'package:sweat_roulette/history/state/session_recorder.dart';
import 'package:sweat_roulette/home/state/roll_session.dart';

import '../exercises/catalogue_fixture.dart';

/// What actually reaches storage as a session is walked.
///
/// Driven through [rollSessionProvider] rather than by calling the recorder,
/// because the recorder *listens* — the state machine knows nothing about it,
/// and this is the test that proves the wiring rather than the method.
void main() {
  late MemorySessionStore store;
  late ProviderContainer container;

  setUp(() {
    store = MemorySessionStore();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        // The fixture, never the shipped catalogue — see
        // `test/exercises/catalogue_fixture.dart`.
        exerciseCatalogueProvider.overrideWithValue(kTestCatalogue),
      ],
    );
    // Disposing cancels any rest timer through `ref.onDispose`, so a test that
    // ends mid-rest doesn't leak one into the next.
    addTearDown(container.dispose);

    // The recorder is lazy; nothing watches it here, so bring it into being.
    container.read(sessionRecorderProvider);
  });

  RollSession read() => container.read(rollSessionProvider);
  RollSessionNotifier notifier() =>
      container.read(rollSessionProvider.notifier);

  /// ROLL, then SKIP the reels. The day is decided by the first of those.
  void rollAndLand() {
    notifier()
      ..advance()
      ..advance();
  }

  /// Rolls until a day of exactly [count] pools comes up.
  void rollDayOf(int count) {
    for (var i = 0; i < 200; i++) {
      rollAndLand();
      if (read().exercises.length == count) return;
      notifier().reset();
    }
    fail('200 rolls never produced a $count-pool day');
  }

  /// Walks a landed day all the way to FINISH.
  void walkToEnd() {
    // START, then NEXT through every exercise and the rests between them.
    // Bounded, so a state machine that stops advancing fails rather than hangs.
    for (var i = 0; i < 3 * slots + 2; i++) {
      if (read().phase == SessionPhase.done) return;
      notifier().advance();
    }
    fail('the session never reached done');
  }

  group('a finished day', () {
    test('is committed once, with every slot completed', () {
      rollDayOf(3);
      walkToEnd();

      expect(store.records, hasLength(1));
      final record = store.records.single;

      expect(record.outcome, SessionOutcome.finished);
      expect(record.finishedAt, isNotNull);
      expect(record.slots.map((s) => s.outcome), [
        SlotOutcome.completed,
        SlotOutcome.completed,
        SlotOutcome.completed,
      ]);
      expect(record.isComplete, true);

      // Nothing left half-written.
      expect(store.inFlight, isNull);
    });

    test('carries the identity and the display name of each movement', () {
      rollDayOf(3);
      walkToEnd();

      // The id is the identity and the name is a snapshot — two fields, so
      // renaming a movement is not a migration. Deliberately *not* asserting
      // that the id is a slug of the name: pinning one to the other is the
      // exact coupling `SlotRecord`'s doc comment exists to prevent. What has
      // to hold is that the id resolves, and that what was written down is
      // what was rolled.
      for (final slot in store.records.single.slots) {
        final entry = kTestCatalogue.firstWhere((e) => e.id == slot.id);
        expect(slot.name, entry.name);
        expect(intensities, contains(slot.intensity));
      }
    });

    test('reaches the History list without re-reading the file', () {
      rollDayOf(2);
      walkToEnd();

      expect(container.read(sessionHistoryProvider), hasLength(1));
      expect(
        container.read(sessionCalendarProvider).keys.single,
        store.records.single.day,
      );
    });
  });

  group('a two-pool day', () {
    test('records only what the roll filled, and falls short of nothing', () {
      rollDayOf(2);
      walkToEnd();

      final record = store.records.single;

      // The layout had three slots; the roll filled two. VISION.md asks for
      // exactly that, so it is not a shortfall and must never count as one.
      expect(record.slots, hasLength(2));
      expect(record.slotCount, 3);
      expect(record.shortfalls, 0);
      expect(record.isComplete, true);
      expect(record.outcomeAt(2), SlotOutcome.notRolled);
    });
  });

  group('a day that was left', () {
    test('is on disk as it stood, with the tail unreached', () {
      rollDayOf(3);
      notifier()
        ..advance() // START — exercise 0
        ..advance() // NEXT — rest into exercise 1
        ..advance(); // begin exercise 1

      // The app is killed here. Nothing more is called.
      final live = store.inFlight!;
      expect(live.outcome, SessionOutcome.running);
      expect(live.slots.map((s) => s.outcome), [
        SlotOutcome.completed,
        SlotOutcome.inProgress,
        SlotOutcome.notReached,
      ]);

      // Recovered at the next launch, exactly as `main()` does it.
      final recovered = live.abandoned();
      expect(recovered.shortfalls, 1);
      expect(recovered.isComplete, false);
    });

    test('exists from the moment ROLL is pressed', () {
      // The whole day is decided the instant ROLL is pressed, so it is already
      // data — a kill mid-spin still leaves a record.
      notifier().advance();

      expect(store.inFlight, isNotNull);
      expect(store.inFlight!.slots, isNotEmpty);
      expect(
        store.inFlight!.slots.every((s) => s.outcome == SlotOutcome.notReached),
        true,
      );
    });
  });

  group('bailing on one exercise', () {
    test('records it as skipped and moves the session on', () {
      rollDayOf(3);
      notifier()
        ..advance() // START — exercise 0
        ..skipCurrent();

      // One tap, not two: the session has moved past it.
      expect(read().phase, SessionPhase.resting);
      expect(read().index, 1);
      expect(read().statusOf(0), SlotStatus.bailed);

      walkToEnd();

      final record = store.records.single;
      expect(record.slots.first.outcome, SlotOutcome.skipped);
      expect(record.slots[1].outcome, SlotOutcome.completed);
      expect(record.shortfalls, 1);
      expect(record.isComplete, false);
    });

    test('bailing on the last exercise still finishes the day', () {
      rollDayOf(2);
      notifier().advance(); // START
      while (!read().isLast || read().phase != SessionPhase.exercising) {
        notifier().advance();
      }
      notifier().skipCurrent();

      expect(read().phase, SessionPhase.done);
      expect(store.records.single.slots.last.outcome, SlotOutcome.skipped);
    });

    test(
      'is ignored while a rest is running — there is nothing to bail on',
      () {
        rollDayOf(3);
        notifier()
          ..advance() // START
          ..advance(); // NEXT — into a rest

        expect(read().phase, SessionPhase.resting);
        notifier().skipCurrent();

        expect(read().bailed, isEmpty);
        expect(read().phase, SessionPhase.resting);
      },
    );
  });

  group('what never reaches storage', () {
    test('RESET throws the session away from any phase', () {
      for (final steps in [0, 1, 2, 3]) {
        rollAndLand();
        for (var i = 0; i < steps; i++) {
          notifier().advance();
        }
        notifier().reset();

        expect(store.records, isEmpty, reason: '$steps steps in');
        expect(store.inFlight, isNull, reason: '$steps steps in');
      }
    });

    test('a rest counting down does not touch the store', () {
      final recorder = container.read(sessionRecorderProvider);

      const resting = RollSession(
        phase: SessionPhase.resting,
        exercises: [
          RolledExercise('One', 'Heavy', id: 'one'),
          RolledExercise('Two', 'Light', id: 'two'),
        ],
        index: 1,
        secondsLeft: kRestSeconds,
      );

      final before = store.saves;

      // A tick changes `secondsLeft` and nothing else. Sixty of them must not
      // be sixty writes — the phase guard is the only thing standing between a
      // rest interval and a minute of disk traffic.
      for (var i = 1; i <= 5; i++) {
        recorder.onSessionChanged(
          resting.copyWith(secondsLeft: kRestSeconds - i + 1),
          resting.copyWith(secondsLeft: kRestSeconds - i),
        );
      }

      expect(store.saves, before);
    });

    test('a reel landing mid-roll does not touch the store', () {
      final recorder = container.read(sessionRecorderProvider);

      const rolling = RollSession(
        phase: SessionPhase.rolling,
        exercises: [RolledExercise('One', 'Heavy', id: 'one')],
      );

      final before = store.saves;
      recorder.onSessionChanged(rolling, rolling.copyWith(revealed: 1));
      expect(store.saves, before);
    });
  });
}
