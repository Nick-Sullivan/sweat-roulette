import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_record.dart';

/// The one and only source (VISION.md rule 1): every session ever recorded
/// lives here, on the phone.
///
/// Two files rather than one, and the asymmetry is the whole durability story:
/// the *log* of finished sessions is append-only and never rewritten, while the
/// one session under way is a separate small file rewritten atomically on every
/// transition. The mutable thing is 300 bytes; the immutable thing is years of
/// data. Rewriting the log eight times a session would mean writing most of a
/// megabyte per workout by year one, with the entire history sitting in a temp
/// file each time.
abstract class SessionStore {
  /// Every committed record, oldest first. Filled once by [load]; [commit]
  /// keeps it in step, so nothing ever re-reads the file.
  List<SessionRecord> get records;

  /// The session that was under way when the app last stopped, if any.
  /// Non-null after [load] means the app was killed mid-session.
  SessionRecord? get inFlight;

  /// Reads both files. Called once, from `main()`.
  Future<void> load();

  /// Records the live session. Cheap, coalesced and last-write-wins, so it is
  /// safe to call on every phase transition.
  void saveInFlight(SessionRecord record);

  /// Ends a session: appends it to the log, *then* clears the live file.
  ///
  /// That order is deliberate. A crash between the two leaves a duplicate,
  /// which [load] folds away; the other order would lose the session outright.
  /// Trade a recoverable duplicate for an unrecoverable loss.
  Future<void> commit(SessionRecord record);

  /// Throws the live session away without recording it. RESET, and nothing
  /// else.
  Future<void> discardInFlight();

  /// Settles every pending write. Called when the app is backgrounded, and by
  /// tests.
  Future<void> flush();

  /// The last write error, or null.
  ///
  /// Storage failure never interrupts a workout: the in-memory state is
  /// authoritative and the file is a copy of it, so a full disk costs you the
  /// record, not the session. Surfacing this is a later UI decision.
  Object? get lastError;
}

/// Resolved in `main()` and injected via `ProviderScope.overrides`, exactly as
/// `prefsProvider` is.
///
/// It throws rather than defaulting to an in-memory store on purpose: a
/// persistence layer that silently records nothing is the worst failure this
/// app has, so a missing override is a crash on the first frame instead of a
/// quiet year of lost history. Tests supply a [MemorySessionStore]; no platform
/// channel is involved either way.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('sessionStoreProvider must be overridden'),
);

/// An in-memory store for tests and for the temporary seed tile.
///
/// Synchronous throughout, and — importantly — it holds **no timer**. The real
/// store debounces its writes, and a pending `Timer` fails a `testWidgets`
/// teardown with "A Timer is still pending". Keeping the debounce out of this
/// class is what lets every existing widget test stay clean.
class MemorySessionStore implements SessionStore {
  MemorySessionStore({List<SessionRecord> seed = const []})
    : _records = [...seed];

  final List<SessionRecord> _records;

  SessionRecord? _inFlight;

  /// How many times [saveInFlight] has been called — the phase-guard tests
  /// assert on this to prove the rest countdown never reaches disk.
  int saves = 0;

  @override
  List<SessionRecord> get records => List.unmodifiable(_records);

  @override
  SessionRecord? get inFlight => _inFlight;

  @override
  Object? get lastError => null;

  @override
  Future<void> load() async {}

  @override
  void saveInFlight(SessionRecord record) {
    saves++;
    _inFlight = record;
  }

  @override
  Future<void> commit(SessionRecord record) async {
    _records
      ..add(record)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    _inFlight = null;
  }

  @override
  Future<void> discardInFlight() async => _inFlight = null;

  @override
  Future<void> flush() async {}
}

/// Folds a freshly-read log into the list History sees.
///
/// Sorted oldest-first, and de-duplicated on [SessionRecord.startedAt] with the
/// last line winning. The duplicate is not hypothetical: it is exactly what a
/// crash between [SessionStore.commit]'s append and its delete leaves behind,
/// and the later line is the more complete one.
List<SessionRecord> foldLog(Iterable<SessionRecord> parsed) {
  final byStart = <int, SessionRecord>{};
  for (final record in parsed) {
    byStart[record.startedAt.millisecondsSinceEpoch] = record;
  }

  return byStart.values.toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}
