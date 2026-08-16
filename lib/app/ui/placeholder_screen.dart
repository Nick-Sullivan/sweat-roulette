import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// A destination that exists so navigation can be built and used before the
/// screen behind it is designed.
///
/// One widget serves all three of VISION.md's remaining screens — History,
/// Exercises, Config. When a real screen lands it replaces the route's builder
/// and this stays for the others; when the last one lands, delete the file.
///
/// Unlike the roll screen, this carries an ordinary [AppBar]: the zero-chrome
/// rule is a property of the roll screen, not of the app, and here the bar is
/// carrying the back affordance rather than costing a twelfth of the screen for
/// a title nobody needs.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SweatSize.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Not built yet'.toUpperCase(),
                style: context.sweatText.sectionLabel,
              ),
              const SizedBox(height: SweatSpace.md),
              Text(
                'This screen is named in VISION.md and has not been designed.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
