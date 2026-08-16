import 'package:flutter/foundation.dart';

/// The on-disk shape of one workout, and the codes it is written with.
///
/// ## Why JSON lines
///
/// VISION.md: the phone is the one and only source, with cloud upload arriving
/// later. That makes the format a *transport* as much as a store, and rules out
/// an opaque binary box. A record is ~250 bytes, so a session a day is ~90KB a
/// year — but every line repeats the same keys and the same handful of names,
/// which is the best case there is for gzip. A year compresses about 15:1, to
/// under 6KB. Nothing needs compressing at rest; the file stays plain text so it
/// can be read, recovered and `adb shell cat`-ed by hand.
///
/// One consequence worth writing down for whoever builds the upload: a *single*
/// line gzipped alone barely compresses at all — the header dominates. Batch,
/// don't stream per record.
///
/// ## What [kSchemaVersion] is for
///
/// It is the *shape* version, and it bumps only when an existing field changes
/// meaning or type, or a required one is removed. It deliberately does **not**
/// bump for:
///
/// - a new optional field — readers ignore keys they don't know;
/// - a new [SlotOutcome] code — readers decode unknown codes to
///   [SlotOutcome.unknown] and render them neutrally.
///
/// That is the whole extension mechanism, and it is why the outcome codes are
/// strings rather than enum ordinals: an ordinal is a promise about ordering
/// that a later edit quietly breaks.
///
/// A line written by a *newer* build is kept verbatim, never parsed and never
/// deleted — see `SessionStore`. Because the log is append-only, a downgrade
/// cannot destroy data it doesn't understand.
const kSchemaVersion = 1;

/// How a whole session ended.
enum SessionOutcome {
  /// Walked to FINISH.
  finished('f'),

  /// Under way when the app stopped, and recovered at the next launch.
  abandoned('a'),

  /// Currently under way. Only ever appears in the live file.
  running('r'),

  /// Written by a build newer than this one.
  unknown('?');

  const SessionOutcome(this.code);

  final String code;

  static SessionOutcome fromCode(Object? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => unknown);
}

/// What became of one slot in the day.
///
/// Distinct from `SlotStatus` in the roll session, which is *how a slot draws
/// right now* and includes display-only reel states. This is what happened.
enum SlotOutcome {
  /// Worked through, and the session moved past it.
  completed('c'),

  /// The user said they couldn't do this one and moved on.
  skipped('s'),

  /// Reached and under way when the session stopped. Neither a success nor a
  /// failure — the app genuinely does not know. Only survives on an abandoned
  /// record; a clean FINISH leaves none.
  inProgress('i'),

  /// The session ended before this one came up.
  notReached('n'),

  /// The roll only filled two slots.
  ///
  /// **This is not a shortfall.** VISION.md rolls 2 *or* 3 pools, so an empty
  /// third slot is the app working correctly.
  ///
  /// It never appears in the file: [SessionRecord.slots] holds only what the
  /// roll filled, and this is synthesised for indices past the end. A renderer
  /// that had never heard of it therefore *cannot* draw an unfilled slot as a
  /// miss, because there is nothing there to draw. The value exists so a UI
  /// switch over outcomes stays total.
  notRolled('-'),

  /// A code written by a build newer than this one.
  unknown('?');

  const SlotOutcome(this.code);

  final String code;

  static SlotOutcome fromCode(Object? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => unknown);

  /// Whether this reads as something the day fell short of.
  ///
  /// The one place the "an unfilled slot is not a failure" rule lives. Anything
  /// that tints, counts or scores a slot keys off *this*, never off the enum
  /// identity — which is why [notRolled], [inProgress] and [unknown] are all
  /// explicitly false rather than falling out of a default. An older build
  /// meeting a newer code invents no failure it wasn't told about.
  bool get isShortfall => this == notReached || this == skipped;
}

/// One rolled exercise, as it was on the day.
@immutable
class SlotRecord {
  const SlotRecord({
    required this.id,
    required this.name,
    required this.intensity,
    required this.outcome,
    this.restBefore,
  });

  /// Stable catalogue id. Renaming an exercise must not orphan two years of
  /// history, so identity and display are two fields, not one.
  ///
  /// Today this is a slug over a placeholder name — an identity *mechanism*,
  /// not a catalogue. The real one is the app owner's to supply.
  final String id;

  /// The display name as it was rolled.
  ///
  /// A snapshot, kept even though [id] is the identity: if a catalogue entry is
  /// later renamed, deleted, or excluded in Config, History still has something
  /// honest to render. Measured cost of keeping it: about 140 bytes a year once
  /// compressed.
  final String name;

  /// The intensity as it was rolled.
  ///
  /// Stored as the display string rather than a code. `intensities` is the
  /// owner's list to change, and a code table over content someone else owns is
  /// a second thing to keep in step; gzip makes the difference immaterial.
  final String intensity;

  final SlotOutcome outcome;

  /// Rest served *before* this slot, in seconds. Null on the first slot, which
  /// has no gap above it.
  final int? restBefore;

  Map<String, Object?> toJson() => {
    'i': id,
    'n': name,
    't': intensity,
    'o': outcome.code,
    if (restBefore != null) 'r': restBefore,
  };

  static SlotRecord fromJson(Map<String, Object?> json) => SlotRecord(
    id: json['i'] as String? ?? '',
    name: json['n'] as String? ?? '',
    intensity: json['t'] as String? ?? '',
    outcome: SlotOutcome.fromCode(json['o']),
    restBefore: json['r'] as int?,
  );
}

/// One workout: when it was, what it rolled, and what became of each of it.
@immutable
class SessionRecord {
  const SessionRecord({
    required this.startedAt,
    required this.day,
    required this.outcome,
    required this.slots,
    this.finishedAt,
    this.slotCount = 3,
  });

  /// When ROLL was pressed. The record's identity, and its sort order.
  final DateTime startedAt;

  /// The local calendar day the session started on — the History grid's bucket.
  ///
  /// Frozen at write time rather than derived from [startedAt] on read.
  /// A 9pm session must land on the evening it started, not tomorrow in UTC,
  /// and a bucket re-derived at read time silently moves if the phone changes
  /// timezone or DST flips. Midnight local, so it compares cleanly.
  final DateTime day;

  /// Null while the session is still running, and on an abandoned one.
  final DateTime? finishedAt;

  final SessionOutcome outcome;

  /// Only the slots the roll actually filled — two or three of them. A slot the
  /// day didn't fill has no entry at all; see [SlotOutcome.notRolled].
  final List<SlotRecord> slots;

  /// How many slots the layout had on the day, so a short day still knows it
  /// was short even if the app's slot count later changes.
  final int slotCount;

  /// The outcome of slot [i], synthesising the ones the roll never filled.
  ///
  /// Use this rather than indexing [slots] directly — it is what keeps a
  /// two-pool day from reading as a one-slot shortfall.
  SlotOutcome outcomeAt(int i) =>
      i < slots.length ? slots[i].outcome : SlotOutcome.notRolled;

  /// How many slots the day fell short on. Zero for a clean two-pool day.
  int get shortfalls => slots.where((s) => s.outcome.isShortfall).length;

  /// Every slot the roll filled was worked through.
  ///
  /// Deliberately stronger than "no shortfalls": a slot still
  /// [SlotOutcome.inProgress] when the app was killed is not a shortfall — the
  /// app does not know how it went — but it is not a finished day either, and a
  /// calendar that marked it done would be claiming something it wasn't told.
  bool get isComplete =>
      slots.isNotEmpty &&
      slots.every((s) => s.outcome == SlotOutcome.completed);

  /// The same session, marked as never finished. Used at startup to close out a
  /// session the app was killed in the middle of.
  SessionRecord abandoned() => SessionRecord(
    startedAt: startedAt,
    day: day,
    outcome: SessionOutcome.abandoned,
    slots: slots,
    slotCount: slotCount,
  );

  Map<String, Object?> toJson() => {
    'v': kSchemaVersion,
    'd': encodeDay(day),
    's': startedAt.millisecondsSinceEpoch ~/ 1000,
    if (finishedAt != null) 'e': finishedAt!.millisecondsSinceEpoch ~/ 1000,
    'o': outcome.code,
    if (slotCount != 3) 'k': slotCount,
    'x': [for (final s in slots) s.toJson()],
  };

  /// Null when the line is not a record this build can read — a torn write, or
  /// a shape from a newer version. Callers keep such lines rather than dropping
  /// them; see `SessionStore`.
  static SessionRecord? fromJson(Map<String, Object?> json) {
    if (json['v'] != kSchemaVersion) return null;

    final started = json['s'];
    final day = decodeDay(json['d']);
    if (started is! int || day == null) return null;

    final finished = json['e'];
    final slots = json['x'];

    return SessionRecord(
      startedAt: DateTime.fromMillisecondsSinceEpoch(started * 1000),
      day: day,
      finishedAt: finished is int
          ? DateTime.fromMillisecondsSinceEpoch(finished * 1000)
          : null,
      outcome: SessionOutcome.fromCode(json['o']),
      slotCount: json['k'] as int? ?? 3,
      slots: [
        if (slots is List)
          for (final slot in slots)
            if (slot is Map<String, Object?>) SlotRecord.fromJson(slot),
      ],
    );
  }
}

/// `YYYY-MM-DD`, and back.
///
/// Hand-rolled rather than `toIso8601String().substring(0, 10)`: that goes
/// through a full timestamp, and the whole point of the day field is that no
/// time of day is involved.
String encodeDay(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
}

DateTime? decodeDay(Object? value) {
  if (value is! String) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

/// Midnight on the local day [moment] falls in.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
