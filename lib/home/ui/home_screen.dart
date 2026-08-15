import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sweat Roulette')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 96,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Nothing here yet.', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // Shown so a build on a device is identifiable at a glance —
            // confirms which deploy is actually installed.
            Text(
              'v$version',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
