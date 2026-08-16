import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui/action_pill.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../state/exercise_providers.dart';
import 'exercise_detail.dart';

/// One movement, with room to explain it.
///
/// A pushed route rather than an expansion in the list or a bottom sheet. The
/// roll screen expands in place because a running session has context worth
/// keeping on screen; browsing has none. And a sheet is capped at a fraction of
/// the screen — a 16:9 still plus a paragraph of the teaching copy VISION.md
/// rule 4 asks for will outgrow it.
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({required this.id, super.key});

  /// From the route. May name nothing — see [_Unknown].
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercise = ref.watch(exerciseByIdProvider)[id];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: exercise == null
                  ? const _Unknown()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SweatSize.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: SweatSpace.lg),
                          Text(
                            exercise.name,
                            style: theme.textTheme.displaySmall,
                          ),
                          ExerciseDetail(exercise: exercise),
                        ],
                      ),
                    ),
            ),
            _ExerciseActionRow(onBack: () => context.pop()),
          ],
        ),
      ),
    );
  }
}

/// An id that resolves to nothing.
///
/// A stale deep link, or an entry removed from the catalogue since something
/// linked to it. It says so rather than throwing: the catalogue is a file the
/// owner edits, and an edit should never be able to crash a screen.
class _Unknown extends StatelessWidget {
  const _Unknown();

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
              'Not in the catalogue'.toUpperCase(),
              style: context.sweatText.sectionLabel,
            ),
            const SizedBox(height: SweatSpace.md),
            Text(
              'This movement is no longer listed.',
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

/// One compartment, because there is one thing to do here.
///
/// Graphite rather than cognac, like every pill that isn't the roll's.
class _ExerciseActionRow extends StatelessWidget {
  const _ExerciseActionRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sweat = context.sweatColors;

    return ActionPill(
      fill: sweat.surfaceAlt,
      ink: scheme.onSurface,
      border: sweat.outlineStrong,
      compartments: [
        PillAction(
          actionKey: const Key('exercise-back'),
          onTap: onBack,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back),
              SizedBox(width: SweatSpace.md),
              Text('BACK'),
            ],
          ),
        ),
      ],
    );
  }
}
