import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/state/roll_session.dart';
import '../data/session_record.dart';
import '../data/session_store.dart';
import 'history_providers.dart';

/// What became of slot [i] of [session], right now.
///
/// Exhaustive on [SessionPhase] on purpose, in the same style as
/// [RollSession.statusOf]: a phase added without an outcome is a compile error
/// rather than a silently mis-recorded workout.
SlotOutcome outcomeOf(RollSession session, int i) {
  // The user's own call outranks where the session got to — they bailed on it
  // and moved on, so it is neither in progress nor unreached.
  if (session.bailed.contains(i)) return SlotOutcome.skipped;

  return switch (session.phase) {
    SessionPhase.done => SlotOutcome.completed,
    // The one being worked on. Reached, and the outcome genuinely unknown until
    // the session moves past it or stops.
    SessionPhase.exercising when i == session.index => SlotOutcome.inProgress,
    // While resting, `index` is the exercise the rest leads *into*, so it has
    // not been started yet.
    SessionPhase.exercising || SessionPhase.resting =>
      i < session.index ? SlotOutcome.completed : SlotOutcome.notReached,
    SessionPhase.clear ||
    SessionPhase.rolling ||
    SessionPhase.rolled => SlotOutcome.notReached,
  };
}

/// Turns the roll session's phase transitions into records on disk.
///
/// **It listens; it is not injected.** [RollSessionNotifier] knows nothing about
/// persistence — no repository reaches into `advance()`, and the state machine
/// stays a state machine. The practical payoff is that
/// `test/home/roll_session_test.dart` needs no store at all, and this class is
/// testable by driving the session provider exactly as that file already does.
class SessionRecorder {
  SessionRecorder(this._store, {required this.onCommitted});

  final SessionStore _store;

  /// Called the moment a finished session joins the log, so History updates
  /// without re-reading the file. Fired synchronously — the store's in-memory
  /// list is updated before its write is even queued.
  final VoidCallback onCommitted;

  DateTime? _startedAt;

  void onSessionChanged(RollSession? previous, RollSession next) {
    // Countdown ticks and reel steps change the state without changing the
    // phase. Nothing has happened, so nothing is written — this guard is what
    // keeps a rest interval from being sixty writes.
    if (previous?.phase == next.phase) return;

    switch (next.phase) {
      // The whole day is decided the instant ROLL is pressed — that is the
      // documented invariant that makes SKIP safe. If it is decided, it is
      // data, so a kill mid-spin still leaves a record.
      case SessionPhase.rolling:
        _startedAt = DateTime.now();
        _store.saveInFlight(_snapshot(next));

      // Only `reset()` reaches clear, and RESET means throw this away. Note
      // that a day merely *walked away from* is still recorded: that path ends
      // in an app kill or a re-roll, never in an explicit discard.
      case SessionPhase.clear:
        _startedAt = null;
        unawaited(_store.discardInFlight());

      case SessionPhase.done:
        final record = _snapshot(
          next,
          outcome: SessionOutcome.finished,
          finishedAt: DateTime.now(),
        );
        unawaited(_store.commit(record));
        onCommitted();

      case SessionPhase.rolled ||
          SessionPhase.exercising ||
          SessionPhase.resting:
        _store.saveInFlight(_snapshot(next));
    }
  }

  SessionRecord _snapshot(
    RollSession session, {
    SessionOutcome outcome = SessionOutcome.running,
    DateTime? finishedAt,
  }) {
    final startedAt = _startedAt ??= DateTime.now();

    return SessionRecord(
      startedAt: startedAt,
      day: dayOf(startedAt),
      finishedAt: finishedAt,
      outcome: outcome,
      slotCount: slots,
      // Only what the roll filled. A slot the day didn't fill gets no entry at
      // all rather than an entry with a failure outcome — see
      // [SlotOutcome.notRolled].
      slots: [
        for (var i = 0; i < session.exercises.length; i++)
          SlotRecord(
            id: session.exercises[i].id,
            name: session.exercises[i].name,
            intensity: session.exercises[i].intensity,
            outcome: outcomeOf(session, i),
            // TEMPORARY alongside [kRestSeconds]. The field is written now so
            // history has no gap on the day the real random interval lands.
            restBefore: i == 0 ? null : kRestSeconds,
          ),
      ],
    );
  }
}

/// Subscribes the recorder to the roll session for the life of the app.
///
/// Eager: `SweatRouletteApp` watches it, because a lazy provider nobody watches
/// never subscribes and the whole session would go unrecorded. Its value never
/// changes, so watching it costs no rebuilds.
final sessionRecorderProvider = Provider<SessionRecorder>((ref) {
  final recorder = SessionRecorder(
    ref.watch(sessionStoreProvider),
    onCommitted: () => ref.read(sessionHistoryProvider.notifier).refresh(),
  );

  // Deliberately not `fireImmediately`: the session starts at
  // [SessionPhase.clear], and firing on it would run the discard branch and
  // delete a live file that `main()` has not finished recovering.
  ref.listen<RollSession>(rollSessionProvider, recorder.onSessionChanged);

  return recorder;
});

/// Forces the live session out to disk when the app is backgrounded — the last
/// reliable moment on Android before it can be killed without warning.
///
/// Separate from [sessionRecorderProvider] so a plain `test()` can build the
/// recorder without a `WidgetsBinding`.
final sessionFlushProvider = Provider<AppLifecycleListener>((ref) {
  final store = ref.watch(sessionStoreProvider);
  final listener = AppLifecycleListener(
    onPause: () => unawaited(store.flush()),
  );
  ref.onDispose(listener.dispose);
  return listener;
});
