import 'package:sweat_roulette/exercises/data/exercise.dart';

/// A catalogue for tests to roll, list and search against.
///
/// **Deliberately not `kExerciseCatalogue`.** A test that reads the shipped
/// catalogue locks the app owner's content: the day they replace that file with
/// their real movements, every assertion naming `Alpha movement` fails, and the
/// failure says nothing about the code. So everything except
/// `exercise_catalogue_test.dart` — which checks shape and never content —
/// overrides `exerciseCatalogueProvider` with this.
///
/// Shared across four test files rather than re-declared in each, unlike the
/// small `find`-helpers those files keep local. A fixture is a contract several
/// tests assert against; four drifting copies of one would be four different
/// contracts.
///
/// Two entries per pool, so the roll always has a choice to make within a pool
/// and can still fill three slots. Names are objects, not movements, and are
/// declared out of alphabetical order on purpose — the Exercises screen sorts
/// A–Z, and a fixture already in order could not tell a working sort from a
/// missing one.
const kTestCatalogue = <Exercise>[
  Exercise(id: 't-forge', name: 'Forge', pool: MovementPool.legPush),
  Exercise(id: 't-anvil', name: 'Anvil', pool: MovementPool.push),
  Exercise(id: 't-jetty', name: 'Jetty', pool: MovementPool.core),
  Exercise(id: 't-drum', name: 'Drum', pool: MovementPool.legPull),
  Exercise(id: 't-hammer', name: 'Hammer', pool: MovementPool.legPush),
  Exercise(id: 't-cauldron', name: 'Cauldron', pool: MovementPool.pull),
  Exercise(id: 't-ingot', name: 'Ingot', pool: MovementPool.legPull),
  Exercise(id: 't-ember', name: 'Ember', pool: MovementPool.core),
  Exercise(id: 't-bellows', name: 'Bellows', pool: MovementPool.push),
  Exercise(id: 't-girder', name: 'Girder', pool: MovementPool.pull),
];

/// The fixture's names, A–Z — what a correctly sorted list should read.
const kTestCatalogueAtoZ = [
  'Anvil',
  'Bellows',
  'Cauldron',
  'Drum',
  'Ember',
  'Forge',
  'Girder',
  'Hammer',
  'Ingot',
  'Jetty',
];
