import 'package:flutter/foundation.dart';

/// The five movement pools, in VISION.md's order.
///
/// The *members* are VISION.md's — "push/pull/leg push/leg pull/core", named
/// there and transcribed here. **Which exercise belongs to which pool is
/// decided nowhere in this file.** It is a field on [Exercise] that the
/// catalogue fills, and the catalogue is the app owner's.
///
/// Declaration order is the order the roll considers them in before shuffling.
/// Nothing sorts these — reordering them would be this file deciding something
/// about training.
///
/// No persisted string code, deliberately. Nothing writes a pool to disk today
/// (see `SlotRecord`), and an unused code invites someone to persist the
/// ordinal instead. If a pool ever *is* written, follow `SlotOutcome`: a string
/// code, never an ordinal.
enum MovementPool { push, pull, legPush, legPull, core }

/// One movement the app knows about.
///
/// This is the type `SlotRecord.id` was written to resolve against: history
/// stores an id plus a display snapshot precisely so renaming an entry here
/// cannot orphan two years of records, and so a name deleted here still renders
/// honestly there.
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.pool,
    this.image,
    this.howTo,
  });

  /// Stable identity — **written down, never derived.**
  ///
  /// Deriving it from [name] would silently re-key a year of history the first
  /// time a movement is renamed, which is the exact coupling `SlotRecord`'s doc
  /// comment exists to prevent. Lower case, digits and hyphens; the shape is
  /// enforced by `test/exercises/exercise_catalogue_test.dart`, which checks
  /// shape and never content.
  final String id;

  /// What the app shows. The owner's to change freely — history keeps its own
  /// snapshot, so a rename is not a migration.
  final String name;

  /// Exactly one pool.
  ///
  /// Single-valued, and that is load-bearing: it is what makes "one exercise
  /// per pool, no repeats" true by construction in `RollSessionNotifier`, with
  /// no dedupe pass. If an exercise ever needs to sit in two pools this becomes
  /// a `Set<MovementPool>` **and the roll gains an explicit no-repeat check** —
  /// the two changes go together.
  final MovementPool pool;

  /// Asset key for the demonstration still or loop.
  ///
  /// Null everywhere today, and the detail block draws its reserved 16:9 box
  /// instead. The day the first one lands, `pubspec.yaml` gains an `assets:`
  /// section — it has none at all right now, only `fonts:`.
  final String? image;

  /// The "How to" body copy — real explanatory prose, per VISION.md rule 4.
  ///
  /// Null means "not written yet" and the detail block falls back to its marked
  /// placeholder. Nullable rather than required so these can be filled in one
  /// at a time instead of in one sitting.
  final String? howTo;
}
