import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/exercises/data/exercise.dart';
import 'package:sweat_roulette/exercises/data/exercise_filter.dart';

import 'catalogue_fixture.dart';

/// The search, as a pure function. No container, no widget tree — the same way
/// `encodeDay` / `decodeDay` are tested.
void main() {
  List<String> namesOf(List<Exercise> exercises) => [
    for (final e in exercises) e.name,
  ];

  group('with no query', () {
    test('returns the whole catalogue, A–Z', () {
      // The fixture is declared out of order on purpose, so this can tell a
      // working sort from a list that happened to arrive sorted.
      expect(
        namesOf(matchingExercises(kTestCatalogue, '')),
        kTestCatalogueAtoZ,
      );
    });

    test('treats whitespace as no query', () {
      expect(matchingExercises(kTestCatalogue, '   '), hasLength(10));
    });
  });

  group('matching', () {
    test('ignores case in both directions', () {
      expect(namesOf(matchingExercises(kTestCatalogue, 'anvil')), ['Anvil']);
      expect(namesOf(matchingExercises(kTestCatalogue, 'ANVIL')), ['Anvil']);
      expect(namesOf(matchingExercises(kTestCatalogue, 'AnViL')), ['Anvil']);
    });

    test('matches anywhere in the name, not just the start', () {
      // Typing what you remember of a name is the point; a prefix-only match
      // would fail anyone who remembers the second word.
      expect(namesOf(matchingExercises(kTestCatalogue, 'mmer')), ['Hammer']);
    });

    test('trims the query', () {
      expect(namesOf(matchingExercises(kTestCatalogue, '  drum ')), ['Drum']);
    });

    test('keeps results A–Z', () {
      // 'e' hits Bellows, Cauldron, Ember, Forge, Girder, Jetty — enough to
      // tell sorted from catalogue order.
      final found = namesOf(matchingExercises(kTestCatalogue, 'e'));
      expect(found, List.of(found)..sort());
    });

    test('returns nothing when nothing matches', () {
      expect(matchingExercises(kTestCatalogue, 'zzzz'), isEmpty);
    });
  });

  group('what it does not match on', () {
    test('not the id', () {
      // Every fixture id starts `t-`. Ids are internal plumbing — matching them
      // would make a search hit things whose visible name says otherwise.
      expect(matchingExercises(kTestCatalogue, 't-'), isEmpty);
    });

    test('not the pool', () {
      // Typing "core" and getting every core movement sounds helpful right up
      // until you wonder why "core" matched something not called core.
      expect(matchingExercises(kTestCatalogue, 'core'), isEmpty);
      expect(matchingExercises(kTestCatalogue, 'push'), isEmpty);
    });
  });

  test('the pool axis narrows without disturbing the sort', () {
    // Unused by the screen today; taken now so a filter chip row later is an
    // argument rather than a rewrite.
    final push = matchingExercises(kTestCatalogue, '', pool: MovementPool.push);

    expect(namesOf(push), ['Anvil', 'Bellows']);
  });
}
