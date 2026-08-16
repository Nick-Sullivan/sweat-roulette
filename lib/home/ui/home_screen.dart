import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/brand/plate_wheel.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Temporary: a showcase of the design system, not the real home screen.
///
/// It exists so the palette and type can be judged on a device rather than in
/// a hex editor — every value here comes from the theme, so hot-reloading a
/// token in `lib/theme/` updates this page. It gets replaced wholesale by the
/// real home screen once the roll feature lands.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sweat Roulette')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SweatSize.gutter,
          SweatSpace.sm,
          SweatSize.gutter,
          SweatSpace.xxxl,
        ),
        children: [
          _Masthead(version: version),
          const _Section('Palette', child: _Palette()),
          const _Section('Type', child: _TypeScale()),
          const _Section('Actions', child: _Actions()),
          const _Section('Surfaces', child: _Surfaces()),
          const _Section('Reading', child: _BodyCopy()),
        ],
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SweatSpace.xl),
        // The lockup: mark plus wordmark. The app bar already carries the name,
        // so the mark is what this adds.
        const PlateWheel(size: 72),
        const SizedBox(height: SweatSpace.lg),
        Text(
          'Roll the day. Lift what lands.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SweatSpace.xs),
        // Shown so a build on a device is identifiable at a glance —
        // confirms which deploy is actually installed.
        Text(
          'v$version',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sweat = context.sweatColors;

    // Deliberately read through the theme, never `SweatPalette` — if a token
    // isn't reachable from a widget, it isn't a token yet.
    final swatches = <(String, Color, String)>[
      ('canvas', sweat.canvas, 'app background'),
      ('surface', scheme.surface, 'raised card'),
      ('surfaceAlt', sweat.surfaceAlt, 'chip / input'),
      ('outline', scheme.outline, 'hairline'),
      ('outlineStrong', sweat.outlineStrong, 'interactive border'),
      ('primary', scheme.primary, 'cognac — the roll'),
      ('champagne', sweat.champagne, 'reward only'),
      ('onSurface', scheme.onSurface, 'primary text'),
      ('onSurfaceVariant', scheme.onSurfaceVariant, 'secondary text'),
      ('error', scheme.error, 'failure'),
    ];

    return Column(
      children: [
        for (final (name, color, use) in swatches)
          _Swatch(name: name, color: color, use: use),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.use});

  final String name;
  final Color color;
  final String use;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: SweatSpace.md),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(SweatRadius.chip),
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(width: SweatSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                Text(
                  '$hex · $use',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sweat = context.sweatText;

    final samples = <(String, String, TextStyle?)>[
      ('displayLarge', 'Bulgarian Split Squat', text.displayLarge),
      ('displayMedium', 'Incline Press', text.displayMedium),
      ('displaySmall', 'Push Day', text.displaySmall),
      ('headlineMedium', 'Today you rolled', text.headlineMedium),
      ('titleLarge', 'Working sets', text.titleLarge),
      ('titleMedium', 'Set 3 of 4', text.titleMedium),
      ('bodyLarge', 'Stop 1–3 reps short of failure.', text.bodyLarge),
      ('bodyMedium', 'Stop 1–3 reps short of failure.', text.bodyMedium),
      ('bodySmall', 'Logged 12 minutes ago', text.bodySmall),
      ('labelLarge', 'LOG SET', text.labelLarge),
      ('labelMedium', 'PUSH POOL', text.labelMedium),
      ('labelSmall', 'WEEK 4', text.labelSmall),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, sample, style) in samples)
          Padding(
            padding: const EdgeInsets.only(bottom: SweatSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: sweat.sectionLabel),
                const SizedBox(height: SweatSpace.xs),
                Text(sample, style: style),
              ],
            ),
          ),
        // Metrics are a widget rather than a style: the unit is a second span
        // in a second typeface.
        for (final (name, value, unit, small) in const [
          ('metric', '87.5', 'kg', false),
          ('metricSmall', '8 × 3', null, true),
          ('metricSmall + unit', '45', 'min', true),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: SweatSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: sweat.sectionLabel),
                const SizedBox(height: SweatSpace.xs),
                MetricText(value, unit: unit, small: small),
              ],
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The one primary action, at its real size: full-bleed and 88dp tall,
        // so it can be hit without looking.
        SizedBox(
          height: SweatSize.primaryAction,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              textStyle: theme.textTheme.titleLarge?.copyWith(
                letterSpacing: 4.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('ROLL'),
          ),
        ),
        const SizedBox(height: SweatSize.targetGap),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Log set'),
              ),
            ),
            const SizedBox(width: SweatSize.targetGap),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
        const SizedBox(height: SweatSize.targetGap),
        TextButton(onPressed: () {}, child: const Text('Reroll this exercise')),
        const SizedBox(height: SweatSize.targetGap),
        FilledButton(onPressed: null, child: const Text('Disabled')),
      ],
    );
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sweat = context.sweatColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SweatSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Push Day', style: theme.textTheme.displaySmall),
            const SizedBox(height: SweatSpace.md),
            Wrap(
              spacing: SweatSpace.sm,
              runSpacing: SweatSpace.sm,
              children: const [
                Chip(label: Text('CHEST')),
                Chip(label: Text('SHOULDERS')),
                Chip(label: Text('TRICEPS')),
              ],
            ),
            const SizedBox(height: SweatSpace.lg),
            const Divider(),
            const SizedBox(height: SweatSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flat Dumbbell Press',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: SweatSpace.xs),
                      Text(
                        '4 sets · 1–3 RIR',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const MetricText('30', unit: 'kg', small: true),
              ],
            ),
            const SizedBox(height: SweatSpace.lg),
            // The only champagne on the page: a finished thing.
            Row(
              children: [
                Icon(Icons.check_rounded, size: 18, color: sweat.champagne),
                const SizedBox(width: SweatSpace.sm),
                Text(
                  'SET COMPLETE',
                  style: context.sweatText.sectionLabel.copyWith(
                    color: sweat.champagne,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Because the load changes every session, effort is measured in reps '
          'in reserve rather than kilos. End every working set one to three '
          'reps short of failure — close enough to grow, far enough to roll '
          'again tomorrow.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: SweatSpace.md),
        Text(
          'Weekly volume stays between ten and twenty working sets per muscle '
          'group, whatever the dice say.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, {required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SweatSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.sweatText.sectionLabel),
          const SizedBox(height: SweatSpace.lg),
          child,
        ],
      ),
    );
  }
}
