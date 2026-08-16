/// **TEMPORARY** — the owner's testing affordance, so the History screen can be
/// judged before six weeks of real sessions exist. Delete this file together
/// with the RESET tile and `kRestSeconds`.
///
/// Everything it invents is obviously invented: the movements come from the
/// catalogue, which is itself all placeholders, and the gaps and outcomes come
/// from a fixed seed. It asserts nothing about training, and it is not a
/// fixture any test should depend on.
library;

import 'dart:math';

import '../../exercises/data/exercise.dart';
import '../../home/state/roll_session.dart';
import '../state/history_providers.dart';
import 'session_record.dart';
import 'session_store.dart';

/// Six weeks of placeholder sessions ending on [today], oldest first.
///
/// Six rather than four so the run always spans a month boundary — the
/// calendar's month-change is the part that needs looking at.
List<SessionRecord> placeholderHistory(
  List<Exercise> catalogue, {
  DateTime? today,
}) {
  // Fixed, so seeding twice produces the same days and the same timestamps.
  // That is what lets [seedHistory] skip what it has already written.
  final random = Random(20260816);
  final last = dayOf(today ?? DateTime.now());

  final records = <SessionRecord>[];

  for (var back = 41; back >= 0; back--) {
    // Rest days, so the grid has gaps to show. Nothing is being claimed about
    // how often anyone should train — this is a pattern of dots.
    if (random.nextInt(10) < 4) continue;

    final day = last.subtract(Duration(days: back));
    final startedAt = DateTime(day.year, day.month, day.day, 18, 30);

    // Any movements at all, in any order — a seeded day is a shape on a
    // calendar, not a plausible workout, and it deliberately does not bother
    // with the roll's one-per-pool rule.
    final picks = [...catalogue]..shuffle(random);
    final count = min(slots - random.nextInt(2), picks.length);
    final roll = random.nextInt(10);

    // Most days finish clean; some carry a bail, some were walked away from.
    final abandonedAt = roll < 2 ? random.nextInt(count) : count;
    final bailedAt = roll >= 2 && roll < 4 ? random.nextInt(count) : -1;

    records.add(
      SessionRecord(
        startedAt: startedAt,
        day: day,
        finishedAt: abandonedAt == count
            ? startedAt.add(const Duration(minutes: 34))
            : null,
        outcome: abandonedAt == count
            ? SessionOutcome.finished
            : SessionOutcome.abandoned,
        slotCount: slots,
        slots: [
          for (var i = 0; i < count; i++)
            SlotRecord(
              id: picks[i].id,
              name: picks[i].name,
              intensity: intensities[random.nextInt(intensities.length)],
              outcome: switch (i) {
                _ when i == bailedAt => SlotOutcome.skipped,
                _ when i < abandonedAt => SlotOutcome.completed,
                _ when i == abandonedAt => SlotOutcome.inProgress,
                _ => SlotOutcome.notReached,
              },
              restBefore: i == 0 ? null : kRestSeconds,
            ),
        ],
      ),
    );
  }

  return records;
}

/// Writes [placeholderHistory] into the store, skipping anything already there.
///
/// Idempotent by way of the fixed seed: pressing the tile twice writes the
/// second time's identical timestamps over nothing at all.
Future<void> seedHistory(
  List<Exercise> catalogue,
  SessionStore store,
  SessionHistory history,
) async {
  final existing = {
    for (final record in store.records) record.startedAt.millisecondsSinceEpoch,
  };

  for (final record in placeholderHistory(catalogue)) {
    if (existing.contains(record.startedAt.millisecondsSinceEpoch)) continue;
    await store.commit(record);
  }

  history.refresh();
}
