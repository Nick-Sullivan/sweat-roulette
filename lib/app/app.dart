import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/state/session_recorder.dart';
import '../theme/app_theme.dart';
import 'router.dart';

class SweatRouletteApp extends ConsumerWidget {
  const SweatRouletteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both are watched purely to bring them into existence: a lazy provider
    // nobody watches never subscribes, and the recorder would then miss every
    // session. Neither value ever changes, so this costs no rebuilds.
    ref.watch(sessionRecorderProvider);
    ref.watch(sessionFlushProvider);

    return MaterialApp.router(
      title: 'Sweat Roulette',
      debugShowCheckedModeBanner: false,
      // Dark-only, regardless of the system setting: both slots get the same
      // theme so a device in light mode can't half-apply one.
      theme: SweatTheme.dark,
      darkTheme: SweatTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
