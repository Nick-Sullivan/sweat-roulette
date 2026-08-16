import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui/action_pill.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../data/exercise.dart';
import '../data/exercise_filter.dart';
import '../state/exercise_providers.dart';

/// Every movement the app knows about, A–Z.
///
/// ## Shape
///
/// The list fills the screen, the search field sits at the foot of it, and the
/// action pill is beneath that. The field is low on purpose: the keyboard rises
/// to meet it rather than covering it, and it lands where the thumb already is.
/// The cost — worth knowing, because it is the one place it happens — is that
/// the pill rides up with the keyboard instead of staying put.
///
/// ## No pool is shown
///
/// The roll screen's rule reads the same here: which pool a movement came from
/// is how the app chooses, not what you do. The pools exist in the catalogue
/// and steer the roll; they are not a way of browsing.
///
/// ## Chrome
///
/// No [AppBar]. Back is the left compartment of the pill, in the same place on
/// screen the roll screen's menu button and History's back occupy.
class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  /// The query lives here rather than in a provider.
  ///
  /// A [TextEditingController] has to live in `State` anyway — it needs
  /// disposing — and mirroring its text into a `Notifier` would give the same
  /// characters two owners. Nothing outside this screen reads the query, and
  /// unlike a half-finished session it *should* be forgotten on the way out:
  /// coming back to a stale search is worse than coming back to the whole list.
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuilds on every keystroke. Filtering is a `contains` over a few dozen
    // strings — microseconds against a 16ms frame — so there is nothing here to
    // debounce, and a debounce would add both visible latency and a `Timer` to
    // a codebase that has been bitten by pending timers in teardown twice.
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(exerciseCatalogueProvider);
    final matches = matchingExercises(catalogue, _query.text);
    final searching = _query.text.isNotEmpty;

    return Scaffold(
      // On, and it has to be: with the field at the foot of the screen, the
      // keyboard would otherwise cover the thing being typed into.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: matches.isEmpty
                  ? _NoMatch(query: _query.text)
                  : _ExerciseList(exercises: matches),
            ),
            _SearchField(controller: _query),
            _ExercisesActionRow(
              onBack: () => context.pop(),
              onClear: searching ? _query.clear : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The A–Z list.
///
/// Rows are the app's exercise slot — the same 72dp object the roll reveals and
/// History replays, so the catalogue looks like the thing it is a catalogue of.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('exercise-list'),
      // Dragging the list puts the keyboard away — one line, and exactly right
      // for someone holding a phone in one tired hand.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        SweatSize.gutter,
        SweatSpace.lg,
        SweatSize.gutter,
        SweatSpace.lg,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final initial = _initialOf(exercise.name);
        final isFirstOfLetter =
            index == 0 || _initialOf(exercises[index - 1].name) != initial;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfLetter)
              _LetterMarker(initial: initial, first: index == 0),
            _ExerciseRow(exercise: exercise),
            const SizedBox(height: SweatSpace.sm),
          ],
        );
      },
    );
  }

  static String _initialOf(String name) =>
      name.isEmpty ? '' : name[0].toUpperCase();
}

/// Where the alphabet turns over.
///
/// Orientation in a long flat list without adding a single tap target.
/// Deliberately not an A–Z scrubber down the edge: that is exactly the precise
/// press DESIGN.md's 56dp floor exists to rule out.
class _LetterMarker extends StatelessWidget {
  const _LetterMarker({required this.initial, required this.first});

  final String initial;

  /// The first marker needs no space above it — the list padding already
  /// provides it, and doubling up would leave the list starting low.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SweatSpace.xs,
        first ? 0 : SweatSpace.md,
        0,
        SweatSpace.sm,
      ),
      child: Text(initial, style: context.sweatText.sectionLabel),
    );
  }
}

/// One movement in the list.
///
/// No intensity column, unlike the roll's and History's slot: intensity is
/// something a *roll* decides, not something a movement has, so
/// [SweatSize.intensityColumn] deliberately does not appear here.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: SweatSize.slot,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(SweatRadius.card),
      ),
      // Foreground, so a row is a true 72dp rather than 74 — the same reason
      // the roll screen paints its hairline over the child.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SweatRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('exercise-${exercise.id}'),
          onTap: () => context.push('/exercises/${exercise.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SweatSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's first text input.
///
/// A plain [TextField] rather than Material's `SearchBar` or `SearchAnchor` —
/// both bring their own full-screen view and their own chrome, and this screen
/// already is the view. Everything about how it looks comes from
/// `inputDecorationTheme`, so the Config screen's inputs match it without
/// anyone having to remember.
///
/// No `autofocus`: browsing is the main thing you come here to do, and opening
/// onto a keyboard covering half the list is wrong for a screen you reach for
/// to look something up.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SweatSize.gutter,
        SweatSpace.sm,
        SweatSize.gutter,
        0,
      ),
      child: SizedBox(
        height: SweatSize.button,
        child: TextField(
          key: const Key('exercise-search'),
          controller: controller,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Search exercises',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }
}

/// Back, and a way out of a search.
///
/// The same pill as everywhere else, graphite rather than cognac: DESIGN.md
/// reserves the brand fill for the roll and for active states, and this screen
/// contains no action.
///
/// CLEAR is a whole compartment rather than a small ✕ inside the field, because
/// a ✕ inside a field is a sub-floor target and this screen is read one-handed.
/// It dims and stops responding on an empty query, the way History's PREV and
/// NEXT do at the ends.
class _ExercisesActionRow extends StatelessWidget {
  const _ExercisesActionRow({required this.onBack, required this.onClear});

  final VoidCallback onBack;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sweat = context.sweatColors;

    return ActionPill(
      fill: sweat.surfaceAlt,
      ink: scheme.onSurface,
      border: sweat.outlineStrong,
      seamCut: scheme.surfaceContainerLowest,
      seamLight: sweat.outlineStrong,
      compartments: [
        PillAction(
          actionKey: const Key('exercises-back'),
          onTap: onBack,
          child: const Icon(Icons.arrow_back),
        ),
        PillAction(
          actionKey: const Key('exercises-clear'),
          flex: 4,
          onTap: onClear,
          ink: onClear == null ? scheme.onSurfaceVariant : null,
          child: const Text('CLEAR'),
        ),
      ],
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SweatSize.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing matches'.toUpperCase(),
              style: context.sweatText.sectionLabel,
            ),
            const SizedBox(height: SweatSpace.md),
            Text(
              query.trim().isEmpty
                  ? 'The catalogue is empty.'
                  : 'No movement is called “${query.trim()}”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
