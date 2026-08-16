import 'exercise.dart';

/// The form a name is matched in.
///
/// `toLowerCase()` and nothing else, deliberately. The obvious next step is an
/// accent fold, so `Präzision` is findable by typing `prazision` — Dart has no
/// `String.normalize` and `intl`'s collator is a dependency this app doesn't
/// carry, so that means a hand-written table of Latin-1 letters. It isn't
/// written because the real names are the owner's and may never need it.
/// **This function is the one place to add it.**
String searchKey(String value) => value.toLowerCase();

/// The catalogue narrowed to [query] and sorted A–Z by name.
///
/// Sorted here rather than in the catalogue file so the file stays in whatever
/// order is convenient to edit — the screen's ordering is the screen's business.
/// The comparison is on [searchKey] so `alpha` and `Alpha` don't sort into two
/// different places.
///
/// Matching is on [Exercise.name] only. Not on [Exercise.id], which is internal,
/// and not on the pool — typing "core" and getting every core movement sounds
/// helpful right up until you wonder why "core" matched something not called
/// core.
///
/// [pool] is a second filter axis, taken now so a chip row later is an argument
/// rather than a rewrite. Nothing passes it today.
List<Exercise> matchingExercises(
  List<Exercise> catalogue,
  String query, {
  MovementPool? pool,
}) {
  final needle = searchKey(query.trim());

  final matches = [
    for (final exercise in catalogue)
      if (pool == null || exercise.pool == pool)
        if (needle.isEmpty || searchKey(exercise.name).contains(needle))
          exercise,
  ];

  return matches
    ..sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));
}
