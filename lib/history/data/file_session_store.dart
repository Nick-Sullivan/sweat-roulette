import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'session_record.dart';
import 'session_store.dart';

/// The only file in `lib/` that touches the disk.
///
/// `path_provider` is deliberately *not* imported here — the directory arrives
/// through the constructor, and `main()` is the one place that resolves it.
/// That is what lets the whole storage layer be tested against
/// `Directory.systemTemp` with no platform channel and no mocking package.
class FileSessionStore implements SessionStore {
  FileSessionStore(this.directory);

  final Directory directory;

  /// Append-only. Never rewritten — that single rule is most of the durability
  /// argument, and it is also why a line from a newer build survives a
  /// downgrade: nothing this build writes can erase what it couldn't parse.
  File get _log => File('${directory.path}/sessions.jsonl');

  /// The one session under way, rewritten whole on every transition.
  File get _live => File('${directory.path}/session.live.json');

  final List<SessionRecord> _records = [];
  SessionRecord? _inFlight;

  /// The newest live snapshot not yet on disk. Coalesced: eight transitions in
  /// one debounce window write once, not eight times.
  SessionRecord? _pending;
  Timer? _debounce;

  /// One write at a time, in order. Serialising through a single future chain
  /// is what stops two renames racing for the same target path.
  Future<void> _queue = Future.value();

  Object? _lastError;

  @override
  List<SessionRecord> get records => List.unmodifiable(_records);

  @override
  SessionRecord? get inFlight => _inFlight;

  @override
  Object? get lastError => _lastError;

  /// Long enough that ROLL-then-RESET inside it writes nothing at all, short
  /// enough that a transition is on disk well before the next one.
  static const _debounceFor = Duration(milliseconds: 300);

  @override
  Future<void> load() async {
    _records
      ..clear()
      ..addAll(foldLog(await _readLog()));

    _inFlight = await _readLive();
  }

  Future<List<SessionRecord>> _readLog() async {
    if (!await _log.exists()) return const [];

    final parsed = <SessionRecord>[];
    // A torn final line is exactly what a kill mid-append leaves. Each line is
    // parsed on its own so one bad one costs one session, not the file.
    for (final line in await _log.readAsLines()) {
      final record = _decode(line);
      if (record != null) parsed.add(record);
    }
    return parsed;
  }

  Future<SessionRecord?> _readLive() async {
    if (!await _live.exists()) return null;
    return _decode(await _live.readAsString());
  }

  /// Null for a blank line, a torn one, or a shape a newer build wrote.
  SessionRecord? _decode(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final json = jsonDecode(line);
      return json is Map<String, Object?> ? SessionRecord.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  void saveInFlight(SessionRecord record) {
    // In-memory truth updates now; the disk catches up.
    _inFlight = record;
    _pending = record;

    _debounce?.cancel();
    _debounce = Timer(_debounceFor, _drain);
  }

  void _drain() {
    _debounce?.cancel();
    _debounce = null;

    final pending = _pending;
    if (pending == null) return;
    _pending = null;

    _enqueue(() => _writeAtomic(_live, jsonEncode(pending.toJson())));
  }

  @override
  Future<void> commit(SessionRecord record) {
    // The live snapshot is superseded. Letting a queued write land after the
    // commit would resurrect the session as a ghost in-flight record.
    _debounce?.cancel();
    _debounce = null;
    _pending = null;

    _inFlight = null;
    _records
      ..add(record)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    return _enqueue(() async {
      await directory.create(recursive: true);

      // Append first, delete second — see [SessionStore.commit].
      final sink = _log.openWrite(mode: FileMode.writeOnlyAppend);
      sink.writeln(jsonEncode(record.toJson()));
      await sink.flush();
      await sink.close();

      if (await _live.exists()) await _live.delete();
    });
  }

  @override
  Future<void> discardInFlight() {
    _debounce?.cancel();
    _debounce = null;
    _pending = null;
    _inFlight = null;

    return _enqueue(() async {
      if (await _live.exists()) await _live.delete();
    });
  }

  @override
  Future<void> flush() {
    _drain();
    return _queue;
  }

  Future<void> _writeAtomic(File target, String contents) async {
    await directory.create(recursive: true);

    final temp = File('${target.path}.tmp');
    // `flush: true` pushes the bytes out of Dart's buffers. Dart exposes no
    // fsync, so this survives process death — the failure this is guarding —
    // but not a power cut mid-rename. That is the right place to stop: an app
    // kill happens weekly, and the difference costs one workout.
    await temp.writeAsString(contents, flush: true);
    // Atomic within a filesystem, and both paths are in the same directory, so
    // a reader sees the whole old file or the whole new one, never a half.
    await temp.rename(target.path);
  }

  /// Errors are captured, not thrown. A workout must not stop because the disk
  /// is full — the in-memory state is authoritative and the file is a copy of
  /// it. There is deliberately no retry loop.
  Future<void> _enqueue(Future<void> Function() op) {
    return _queue = _queue.then((_) async {
      try {
        await op();
      } on Object catch (error) {
        _lastError = error;
      }
    });
  }
}
