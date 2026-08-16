import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../history/ui/history_screen.dart';
import '../home/ui/roll_home_screen.dart';
import 'ui/placeholder_screen.dart';

/// VISION.md names four screens; the roll and History are designed. The other
/// two are routed to a placeholder so the navigation can be built and used now,
/// and each route's builder swapped as its screen lands.
///
/// They are children of `/` on purpose: the roll screen stays beneath them in
/// the stack, so `context.pop()` returns to a session exactly where it was left.
///
/// The design-system showcase is still in the tree at `home/ui/home_screen.dart`
/// but is routed nowhere; point '/' at it to review tokens.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RollHomeScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: 'exercises',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Exercises'),
          ),
          GoRoute(
            path: 'config',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Config'),
          ),
        ],
      ),
    ],
  );
});
