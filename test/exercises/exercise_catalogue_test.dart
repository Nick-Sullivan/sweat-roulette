import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/exercises/data/exercise.dart';
import 'package:sweat_roulette/exercises/data/exercise_catalogue.dart';

/// **The only file that reads the shipped catalogue, and it checks shape only.**
///
/// Not one assertion here names a movement, a pool assignment or a description.
/// That is deliberate and it is the point: the catalogue is the app owner's
/// file, and replacing its contents wholesale must never turn the suite red. If
/// you find yourself wanting to assert that some particular exercise exists,
/// put it in a fixture instead — see `catalogue_fixture.dart`.
///
/// What it *does* guard are the invariants the rest of the app relies on
/// holding, whatever the content is.
void main() {
  test('every id is unique', () {
    // Ids are history's foreign key. Two entries sharing one would make a
    // record ambiguous, and `exerciseByIdProvider` would silently drop one.
    final ids = kExerciseCatalogue.map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every id is non-empty and slug-shaped', () {
    // Ids reach a URL — the detail route is `/exercises/:id` — and a file, so
    // they stay to lower case, digits and hyphens.
    for (final exercise in kExerciseCatalogue) {
      expect(exercise.id, isNotEmpty, reason: exercise.name);
      expect(
        exercise.id,
        matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
        reason: exercise.name,
      );
    }
  });

  test('every name is non-empty and unique', () {
    // Two movements with the same name are indistinguishable in the list, and
    // the search would return a pair with no way to tell them apart.
    final names = kExerciseCatalogue.map((e) => e.name).toList();
    for (final name in names) {
      expect(name.trim(), isNotEmpty);
    }
    expect(names.toSet(), hasLength(names.length));
  });

  test('every pool has something in it', () {
    // The invariant the roll leans on: it draws pools without replacement and
    // takes one exercise from each, so an empty pool would be a slot with
    // nothing in it. `_roll` drops empty pools defensively, but a catalogue
    // that leaves one bare is almost certainly a mistake rather than a choice.
    for (final pool in MovementPool.values) {
      expect(
        kExerciseCatalogue.where((e) => e.pool == pool),
        isNotEmpty,
        reason: '${pool.name} has no exercises',
      );
    }
  });

  test('at least two pools are filled, so a day can always be rolled', () {
    final filled = kExerciseCatalogue.map((e) => e.pool).toSet();
    expect(filled.length, greaterThanOrEqualTo(2));
  });
}
