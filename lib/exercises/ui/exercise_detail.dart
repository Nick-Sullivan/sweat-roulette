import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../data/exercise.dart';

/// What the app says about a movement when it has room to say it.
///
/// **Every word of the copy in here is a placeholder and is marked as one.**
/// This block was private to the roll screen and is moved verbatim — not one
/// sentence of it is new. VISION.md rule 4 asks the app to teach — "help people
/// learn more about what is and isn't good and healthy" — which makes this real
/// explanatory prose about a movement, and that is the app owner's to write,
/// not Claude's. What is designed here is where the explanation lives and how
/// much room it needs.
///
/// Shared by the roll screen's open card and the Exercises screen, so the same
/// movement is explained the same way wherever you happen to be reading it.
///
/// It draws the exercise and nothing else. The roll screen's "Couldn't do it"
/// strip is **not in here and takes no parameter** — not even an optional one.
/// That strip is about the set you are in the middle of, not about the
/// movement, and a widget with an optional `onSkip` is one `if` away from the
/// Exercises screen offering to skip an exercise nobody is doing. The roll
/// screen composes the two; that composition is the roll screen's business.
class ExerciseDetail extends StatelessWidget {
  const ExerciseDetail({required this.exercise, super.key});

  /// Null when there is nothing to resolve, or when an id didn't — an entry
  /// renamed away or removed, which is what a two-year-old history record looks
  /// like from here. It draws the placeholder rather than an error: there is
  /// always a name above this block, because `SlotRecord` keeps a snapshot of
  /// it for exactly this case.
  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = exercise?.image;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SweatSpace.lg,
        SweatSpace.lg,
        SweatSpace.lg,
        SweatSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reserved, and mostly not filled. A demonstration still or loop goes
          // here; until one does, the box holds the space so the card's
          // proportions are judged with it rather than without.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.sweatColors.canvas,
                borderRadius: BorderRadius.circular(SweatRadius.chip),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: image == null
                  ? Text('Image', style: context.sweatText.sectionLabel)
                  : Image.asset(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: SweatSpace.lg),
          Text('How to', style: context.sweatText.sectionLabel),
          const SizedBox(height: SweatSpace.sm),
          Text(
            exercise?.howTo ?? kPlaceholderHowTo,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// What a movement with no description written yet says instead.
///
/// A named constant rather than an inline literal so it reads as one
/// placeholder that is meant to be replaced wholesale, rather than a sentence
/// somebody might helpfully improve.
const kPlaceholderHowTo =
    'Placeholder — the movement description has not been written. '
    'This block sizes the card for a short paragraph of real copy, '
    'which is the app owner’s to supply.';
