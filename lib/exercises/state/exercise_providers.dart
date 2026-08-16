import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise.dart';
import '../data/exercise_catalogue.dart';

/// Every movement the app knows about.
///
/// A provider rather than a bare global, and the indirection pays for itself
/// twice. **A test overrides it with its own fixture**, so no test ever asserts
/// on the shipped catalogue — one that did would lock the owner's content and
/// fail the day they replaced it. And a later source — a Config-filtered list,
/// a downloaded one — is an override here rather than a rewrite of every
/// caller.
final exerciseCatalogueProvider = Provider<List<Exercise>>(
  (ref) => kExerciseCatalogue,
);

/// The same catalogue, keyed by [Exercise.id].
///
/// The roll screen resolves a `RolledExercise.id` through this to draw the
/// detail block, and History will when it gains one. Built once rather than a
/// `firstWhere` per frame.
///
/// A lookup can miss: an id recorded last year may name an entry since removed.
/// Callers take `Exercise?` and say something honest, rather than asserting.
final exerciseByIdProvider = Provider<Map<String, Exercise>>(
  (ref) => {for (final e in ref.watch(exerciseCatalogueProvider)) e.id: e},
);
