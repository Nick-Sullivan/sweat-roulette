import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/history/data/file_session_store.dart';
import 'package:sweat_roulette/history/data/session_record.dart';

/// The disk layer, against a real temp directory.
///
/// `dart:io` works in `flutter test` because the suite runs on the host VM, and
/// `path_provider` never appears in `lib/` outside `main()` — the store takes
/// its directory in the constructor. So this needs no channel mock and no
/// mocking package.
///
/// Each case here corresponds to a row of the failure table in [FileSessionStore].
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sweat_history');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  File log() => File('${dir.path}/sessions.jsonl');
  File live() => File('${dir.path}/session.live.json');

  SessionRecord record(
    int day, {
    SessionOutcome outcome = SessionOutcome.finished,
    List<SlotOutcome> outcomes = const [SlotOutcome.completed],
  }) => SessionRecord(
    startedAt: DateTime(2026, 8, day, 18, 30),
    day: DateTime(2026, 8, day),
    finishedAt: outcome == SessionOutcome.finished
        ? DateTime(2026, 8, day, 19)
        : null,
    outcome: outcome,
    slots: [
      for (final (i, o) in outcomes.indexed)
        SlotRecord(
          id: 'movement-$i',
          name: 'Movement $i',
          intensity: 'Heavy',
          outcome: o,
          restBefore: i == 0 ? null : 90,
        ),
    ],
  );

  /// A fresh store over the same directory — what the next app launch sees.
  Future<FileSessionStore> reopen() async {
    final store = FileSessionStore(dir);
    await store.load();
    return store;
  }

  group('the log', () {
    test(
      'appends one line per session, and reads them back in order',
      () async {
        final store = FileSessionStore(dir);
        await store.load();
        await store.commit(record(3));
        await store.commit(record(1));
        await store.flush();

        expect(log().readAsLinesSync(), hasLength(2));

        final next = await reopen();
        expect(next.records.map((r) => r.day.day), [1, 3]);
        expect(next.inFlight, isNull);
      },
    );

    test('a torn final line costs one session, not the file', () async {
      final store = FileSessionStore(dir);
      await store.load();
      await store.commit(record(1));
      await store.commit(record(2));
      await store.flush();

      // Exactly what a kill mid-append leaves behind.
      log().writeAsStringSync(
        '{"v":1,"d":"2026-08-03","s":17673',
        mode: FileMode.append,
      );

      final next = await reopen();
      expect(next.records.map((r) => r.day.day), [1, 2]);
    });

    test('a duplicate start folds away, last line winning', () async {
      final store = FileSessionStore(dir);
      await store.load();
      // A crash between commit's append and its delete re-commits the session
      // at the next launch. The later line is the more complete one.
      await store.commit(record(1, outcome: SessionOutcome.abandoned));
      await store.commit(record(1));
      await store.flush();

      final next = await reopen();
      expect(next.records, hasLength(1));
      expect(next.records.single.outcome, SessionOutcome.finished);
    });

    test('a line from a newer build is left in place, not deleted', () async {
      final store = FileSessionStore(dir);
      await store.load();
      await store.commit(record(1));
      await store.flush();

      log().writeAsStringSync(
        '${jsonEncode({'v': 99, 'd': '2026-08-09', 's': 1, 'x': []})}\n',
        mode: FileMode.append,
      );

      final next = await reopen();
      // Not shown...
      expect(next.records, hasLength(1));
      await next.commit(record(2));
      await next.flush();
      // ...and not destroyed. The log is append-only, so a downgrade cannot
      // erase what it couldn't parse.
      expect(log().readAsStringSync(), contains('"v":99'));
    });
  });

  group('the live session', () {
    test('survives a kill and comes back as in-flight', () async {
      final store = FileSessionStore(dir);
      await store.load();
      store.saveInFlight(
        record(
          5,
          outcome: SessionOutcome.running,
          outcomes: const [
            SlotOutcome.completed,
            SlotOutcome.inProgress,
            SlotOutcome.notReached,
          ],
        ),
      );
      await store.flush();

      // The process dies here; nothing else is called.
      final next = await reopen();
      expect(next.records, isEmpty);
      expect(next.inFlight, isNotNull);
      expect(next.inFlight!.slots.map((s) => s.outcome), [
        SlotOutcome.completed,
        SlotOutcome.inProgress,
        SlotOutcome.notReached,
      ]);

      // Recovered as abandoned before the first frame — the shape `main()` runs.
      await next.commit(next.inFlight!.abandoned());
      await next.flush();

      final third = await reopen();
      expect(third.inFlight, isNull);
      expect(third.records.single.outcome, SessionOutcome.abandoned);
      expect(third.records.single.finishedAt, isNull);
      expect(live().existsSync(), false);
    });

    test('coalesces a burst of transitions into one write', () async {
      final store = FileSessionStore(dir);
      await store.load();

      store
        ..saveInFlight(record(6, outcome: SessionOutcome.running))
        ..saveInFlight(
          record(
            7,
            outcome: SessionOutcome.running,
            outcomes: const [SlotOutcome.completed, SlotOutcome.inProgress],
          ),
        );
      await store.flush();

      // The newest snapshot, and only it.
      final written =
          jsonDecode(live().readAsStringSync()) as Map<String, Object?>;
      expect(written['d'], '2026-08-07');
      expect((written['x']! as List), hasLength(2));
    });

    test('committing cancels a queued live write', () async {
      final store = FileSessionStore(dir);
      await store.load();

      store.saveInFlight(record(8, outcome: SessionOutcome.running));
      // Inside the debounce window: the commit supersedes it. Letting the
      // queued write land afterwards would resurrect a ghost in-flight session.
      await store.commit(record(8));
      await store.flush();

      expect(live().existsSync(), false);
      expect((await reopen()).inFlight, isNull);
    });

    test('RESET throws it away without recording it', () async {
      final store = FileSessionStore(dir);
      await store.load();

      store.saveInFlight(record(9, outcome: SessionOutcome.running));
      await store.flush();
      await store.discardInFlight();
      await store.flush();

      final next = await reopen();
      expect(next.records, isEmpty);
      expect(next.inFlight, isNull);
    });
  });

  test('no temp file is left behind by any of it', () async {
    final store = FileSessionStore(dir);
    await store.load();
    store.saveInFlight(record(10, outcome: SessionOutcome.running));
    await store.flush();
    await store.commit(record(10));
    await store.flush();

    final leftovers = dir
        .listSync()
        .map((e) => e.path)
        .where((p) => p.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('a write failure is captured, never thrown at the session', () async {
    // A directory where a file has to go: creating the log fails every time.
    final store = FileSessionStore(dir);
    await store.load();
    Directory('${dir.path}/sessions.jsonl').createSync(recursive: true);

    await store.commit(record(11));
    await store.flush();

    // The workout continues; the in-memory list is authoritative and the file
    // is a copy of it.
    expect(store.lastError, isNotNull);
    expect(store.records, hasLength(1));
  });
}
