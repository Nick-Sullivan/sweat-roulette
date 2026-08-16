import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../exercises/ui/exercise_screen.dart';
import '../exercises/ui/exercises_screen.dart';
import '../history/ui/history_screen.dart';
import '../home/ui/roll_home_screen.dart';
import 'ui/placeholder_screen.dart';

/// VISION.md names four screens; only Config is still undesigned, and it is
/// routed to a placeholder so the navigation can be built and used now. Swap
/// its builder when the screen lands, then delete the placeholder.
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
            builder: (context, state) => const ExercisesScreen(),
            routes: [
              // A child of the list, so backing out of a movement lands on the
              // list before it lands on the session.
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ExerciseScreen(id: state.pathParameters['id']!),
              ),
            ],
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
