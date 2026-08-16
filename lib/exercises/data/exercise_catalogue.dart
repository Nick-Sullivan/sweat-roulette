import 'exercise.dart';

/// **The whole catalogue. Replace this list — that is the only edit needed.**
///
/// Nothing reads it except `exerciseCatalogueProvider`, and **no test asserts on
/// any name, pool assignment or description in here.** The one test that reads
/// this file checks shape only — ids unique and slug-shaped, names unique, every
/// pool non-empty — so it passes over any content you put in.
///
/// ## Every entry below is a placeholder, and is named as one
///
/// They are NATO alphabet words, not movements, round-robined across the five
/// pools in order. The assignment is therefore arbitrary and claims nothing.
///
/// That matters more than it looks. The names this replaces — `Incline Press`,
/// `Bulgarian Split Squat` — were real movements, and the comment above them
/// said they were safe *because no pool existed*, so naming one asserted
/// nothing about it. The moment an entry carries a [MovementPool] that stops
/// being true: putting a real movement in a real pool is a claim about
/// training, and those are the app owner's to make, not Claude's.
///
/// The names are also spread across the alphabet on purpose, because the
/// Exercises screen lists them A–Z and a list of `Placeholder 1…25` would sort
/// into one indistinguishable run.
///
/// ## Adding an entry
///
/// - `id` — lower case, digits and hyphens. **Never change one once history
///   contains it**; rename [Exercise.name] freely instead.
/// - `name` — free.
/// - `pool` — one of the five.
/// - `image` and `howTo` — leave null until there is something to put in them.
const kExerciseCatalogue = <Exercise>[
  Exercise(id: 'alpha', name: 'Alpha movement', pool: MovementPool.push),
  Exercise(id: 'bravo', name: 'Bravo movement', pool: MovementPool.pull),
  Exercise(id: 'charlie', name: 'Charlie movement', pool: MovementPool.legPush),
  Exercise(id: 'delta', name: 'Delta movement', pool: MovementPool.legPull),
  Exercise(id: 'echo', name: 'Echo movement', pool: MovementPool.core),

  Exercise(id: 'foxtrot', name: 'Foxtrot movement', pool: MovementPool.push),
  Exercise(id: 'golf', name: 'Golf movement', pool: MovementPool.pull),
  Exercise(id: 'hotel', name: 'Hotel movement', pool: MovementPool.legPush),
  Exercise(id: 'india', name: 'India movement', pool: MovementPool.legPull),
  Exercise(id: 'juliett', name: 'Juliett movement', pool: MovementPool.core),

  Exercise(id: 'kilo', name: 'Kilo movement', pool: MovementPool.push),
  Exercise(id: 'lima', name: 'Lima movement', pool: MovementPool.pull),
  Exercise(id: 'mike', name: 'Mike movement', pool: MovementPool.legPush),
  Exercise(
    id: 'november',
    name: 'November movement',
    pool: MovementPool.legPull,
  ),
  Exercise(id: 'oscar', name: 'Oscar movement', pool: MovementPool.core),

  Exercise(id: 'papa', name: 'Papa movement', pool: MovementPool.push),
  Exercise(id: 'quebec', name: 'Quebec movement', pool: MovementPool.pull),
  Exercise(id: 'romeo', name: 'Romeo movement', pool: MovementPool.legPush),
  Exercise(id: 'sierra', name: 'Sierra movement', pool: MovementPool.legPull),
  Exercise(id: 'tango', name: 'Tango movement', pool: MovementPool.core),

  Exercise(id: 'uniform', name: 'Uniform movement', pool: MovementPool.push),
  Exercise(id: 'victor', name: 'Victor movement', pool: MovementPool.pull),
  Exercise(id: 'whiskey', name: 'Whiskey movement', pool: MovementPool.legPush),
  Exercise(id: 'xray', name: 'X-ray movement', pool: MovementPool.legPull),
  Exercise(id: 'yankee', name: 'Yankee movement', pool: MovementPool.core),
];
