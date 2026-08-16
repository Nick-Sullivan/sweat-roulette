import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/history/data/session_record.dart';

/// The on-disk shape, on its own. No container, no widgets — this is the format
/// contract, and it is the thing a future cloud upload and a future downgrade
/// both depend on.
void main() {
  SlotRecord slot(
    String name,
    String intensity,
    SlotOutcome outcome, {
    int? restBefore,
  }) => SlotRecord(
    id: name.toLowerCase().replaceAll(' ', '-'),
    name: name,
    intensity: intensity,
    outcome: outcome,
    restBefore: restBefore,
  );

  SessionRecord finishedDay() => SessionRecord(
    startedAt: DateTime(2026, 8, 15, 18, 30),
    day: DateTime(2026, 8, 15),
    finishedAt: DateTime(2026, 8, 15, 19, 4),
    outcome: SessionOutcome.finished,
    slots: [
      slot('Incline Press', 'Heavy', SlotOutcome.completed),
      slot(
        'Flat Dumbbell Press',
        'Normal',
        SlotOutcome.completed,
        restBefore: 110,
      ),
      slot(
        'Bulgarian Split Squat',
        'Light',
        SlotOutcome.completed,
        restBefore: 123,
      ),
    ],
  );

  SessionRecord? roundTrip(SessionRecord record) => SessionRecord.fromJson(
    jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>,
  );

  group('round trip', () {
    test('a finished day survives encode and decode', () {
      final back = roundTrip(finishedDay())!;

      expect(back.startedAt, DateTime(2026, 8, 15, 18, 30));
      expect(back.day, DateTime(2026, 8, 15));
      expect(back.finishedAt, DateTime(2026, 8, 15, 19, 4));
      expect(back.outcome, SessionOutcome.finished);
      expect(back.slotCount, 3);

      expect(back.slots.map((s) => s.name), [
        'Incline Press',
        'Flat Dumbbell Press',
        'Bulgarian Split Squat',
      ]);
      expect(back.slots.map((s) => s.id).first, 'incline-press');
      expect(back.slots.map((s) => s.intensity), ['Heavy', 'Normal', 'Light']);
      expect(back.slots.every((s) => s.outcome == SlotOutcome.completed), true);

      // The first slot has no gap above it, and says so by absence.
      expect(back.slots.first.restBefore, isNull);
      expect(back.slots[1].restBefore, 110);
    });

    test('an unfinished day carries no finish time', () {
      final abandoned = finishedDay().abandoned();
      final back = roundTrip(abandoned)!;

      expect(back.outcome, SessionOutcome.abandoned);
      expect(back.finishedAt, isNull);
      expect(back.toJson().containsKey('e'), false);
    });
  });

  group('byte budget', () {
    // The whole "compresses well" argument rests on the line staying short and
    // its keys staying identical from line to line. This is what fails when
    // someone helpfully renames `x` to `exercises`.
    test('a three-exercise day stays under 300 bytes', () {
      final bytes = utf8.encode(jsonEncode(finishedDay().toJson())).length;
      expect(bytes, lessThan(300));
    });

    test('the whole record is single-letter keys', () {
      final json = finishedDay().toJson();
      expect(json.keys.every((k) => k.length == 1), true, reason: '$json');

      final slot = (json['x']! as List).first! as Map<String, Object?>;
      expect(slot.keys.every((k) => k.length == 1), true, reason: '$slot');
    });
  });

  group('tolerating a newer build', () {
    // This pair is the no-migration claim, made executable. Adding an outcome
    // must not need `v` to move.
    test('an unknown outcome code decodes rather than throwing', () {
      final outcome = SlotOutcome.fromCode('zzz');
      expect(outcome, SlotOutcome.unknown);
    });

    test('an unknown outcome is never counted as a shortfall', () {
      // The conservative direction to fail in: an older build must not invent a
      // failure a newer build never told it about.
      expect(SlotOutcome.unknown.isShortfall, false);
      expect(SlotOutcome.notRolled.isShortfall, false);
      expect(SlotOutcome.inProgress.isShortfall, false);

      expect(SlotOutcome.notReached.isShortfall, true);
      expect(SlotOutcome.skipped.isShortfall, true);
    });

    test('a record from a future schema version decodes to null', () {
      final json = finishedDay().toJson()..['v'] = kSchemaVersion + 1;
      expect(SessionRecord.fromJson(json), isNull);
    });

    test('a record missing its day or start decodes to null', () {
      expect(
        SessionRecord.fromJson(finishedDay().toJson()..remove('s')),
        isNull,
      );
      expect(
        SessionRecord.fromJson(finishedDay().toJson()..remove('d')),
        isNull,
      );
    });
  });

  group('the calendar bucket', () {
    test('is the local day, not a UTC one', () {
      // A late session belongs to the evening it started on. Deriving the
      // bucket from the instant would move it to tomorrow anywhere east of
      // Greenwich, and move it back again if the phone changed timezone.
      final late = DateTime(2026, 8, 15, 23, 30);
      final early = DateTime(2026, 8, 16, 0, 30);

      expect(dayOf(late), DateTime(2026, 8, 15));
      expect(dayOf(early), DateTime(2026, 8, 16));
      expect(dayOf(late) == dayOf(early), false);
    });

    test('encodes and decodes as a padded plain date', () {
      expect(encodeDay(DateTime(2026, 1, 2)), '2026-01-02');
      expect(decodeDay('2026-01-02'), DateTime(2026, 1, 2));
      expect(decodeDay('nonsense'), isNull);
      expect(decodeDay(7), isNull);
    });
  });

  group('a slot the roll never filled', () {
    late SessionRecord twoPoolDay;

    setUp(() {
      twoPoolDay = SessionRecord(
        startedAt: DateTime(2026, 8, 15, 18, 30),
        day: DateTime(2026, 8, 15),
        finishedAt: DateTime(2026, 8, 15, 19),
        outcome: SessionOutcome.finished,
        slots: [
          slot('Incline Press', 'Heavy', SlotOutcome.completed),
          slot(
            'Flat Dumbbell Press',
            'Light',
            SlotOutcome.completed,
            restBefore: 97,
          ),
        ],
      );
    });

    test('is absent from the bytes entirely', () {
      final json = roundTrip(twoPoolDay)!.toJson();
      expect((json['x']! as List), hasLength(2));
    });

    test('is synthesised as notRolled when the screen asks for it', () {
      expect(twoPoolDay.outcomeAt(0), SlotOutcome.completed);
      expect(twoPoolDay.outcomeAt(1), SlotOutcome.completed);
      expect(twoPoolDay.outcomeAt(2), SlotOutcome.notRolled);
    });

    test('does not make a clean two-pool day read as a shortfall', () {
      // VISION.md rolls 2 *or* 3 pools. A two-pool day walked to the end is the
      // app working correctly, and must count as complete.
      expect(twoPoolDay.shortfalls, 0);
      expect(twoPoolDay.isComplete, true);
    });
  });

  test('a bailed slot is a shortfall, and the day is not complete', () {
    final bailed = SessionRecord(
      startedAt: DateTime(2026, 8, 15, 18, 30),
      day: DateTime(2026, 8, 15),
      outcome: SessionOutcome.finished,
      slots: [
        slot('Incline Press', 'Heavy', SlotOutcome.completed),
        slot('Flat Dumbbell Press', 'Light', SlotOutcome.skipped),
      ],
    );

    expect(bailed.shortfalls, 1);
    expect(bailed.isComplete, false);
  });
}
