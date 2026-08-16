import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweat_roulette/app/app.dart';
import 'package:sweat_roulette/app/providers.dart';
import 'package:sweat_roulette/exercises/state/exercise_providers.dart';
import 'package:sweat_roulette/history/data/session_store.dart';
import 'package:sweat_roulette/theme/app_spacing.dart';

import 'catalogue_fixture.dart';

/// The Exercises screen, reached the way it is reached in the app.
///
/// Pumped through the real router rather than in isolation: back pops a route,
/// and a row pushes one, so both need something to pop back to.
void main() {
  Future<void> openExercises(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('1.2.3'),
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
          exerciseCatalogueProvider.overrideWithValue(kTestCatalogue),
        ],
        child: const SweatRouletteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-exercises')));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const Key('exercise-search')), query);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<InkWell>(find.byKey(key)).onTap != null;

  /// The rows currently built, in the order the list builds them.
  ///
  /// Read off the row keys rather than the visible text: a `ListView.builder`
  /// only builds what fits, so `find.text` would silently miss the tail.
  List<String> visibleIds(WidgetTester tester) => [
    for (final element in find.byType(InkWell).evaluate())
      if ((element.widget.key as ValueKey<String>?)?.value.startsWith(
            'exercise-',
          ) ??
          false)
        (element.widget.key! as ValueKey<String>).value.substring(9),
  ];

  group('the list', () {
    testWidgets('runs A–Z', (tester) async {
      await openExercises(tester);

      final shown = visibleIds(tester);
      expect(shown, isNotEmpty);

      // Whatever fits on screen must be the front of the sorted run — the
      // fixture is declared out of order, so this fails on an unsorted list.
      final expected = [
        for (final name in kTestCatalogueAtoZ)
          kTestCatalogue.firstWhere((e) => e.name == name).id,
      ];
      expect(shown, expected.take(shown.length));
    });

    testWidgets('every entry is reachable by scrolling', (tester) async {
      await openExercises(tester);

      await tester.scrollUntilVisible(
        find.byKey(const Key('exercise-t-jetty')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('exercise-t-jetty')), findsOneWidget);
    });

    testWidgets('rows clear the tired-hands floor', (tester) async {
      await openExercises(tester);

      final row = tester.getSize(find.byKey(const Key('exercise-t-anvil')));
      expect(row.height, SweatSize.slot);
      expect(row.height, greaterThanOrEqualTo(SweatSize.minTarget));
    });

    testWidgets('shows a letter where the alphabet turns over', (tester) async {
      await openExercises(tester);

      // One marker per distinct initial, not one per row.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('never names a pool', (tester) async {
      await openExercises(tester);

      // Which pool a movement came from is how the app chooses, not what you
      // do — the same rule the roll screen holds to.
      for (final pool in const ['push', 'pull', 'core', 'PUSH', 'CORE']) {
        expect(find.text(pool), findsNothing, reason: pool);
      }
    });
  });

  group('search', () {
    testWidgets('narrows the list as you type', (tester) async {
      await openExercises(tester);
      await type(tester, 'anv');

      expect(visibleIds(tester), ['t-anvil']);
    });

    testWidgets('ignores case', (tester) async {
      await openExercises(tester);
      await type(tester, 'ANVIL');

      expect(visibleIds(tester), ['t-anvil']);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await openExercises(tester);
      await type(tester, 'zzzz');

      expect(find.text('NOTHING MATCHES'), findsOneWidget);
      expect(visibleIds(tester), isEmpty);
    });

    testWidgets('CLEAR is dead until there is something to clear', (
      tester,
    ) async {
      await openExercises(tester);
      expect(enabled(tester, const Key('exercises-clear')), false);

      await type(tester, 'anv');
      expect(enabled(tester, const Key('exercises-clear')), true);

      await tester.tap(find.byKey(const Key('exercises-clear')));
      await tester.pumpAndSettle();

      expect(enabled(tester, const Key('exercises-clear')), false);
      expect(visibleIds(tester), isNotEmpty);
    });
  });

  group('chrome', () {
    testWidgets('carries no AppBar — back is in the bottom pill', (
      tester,
    ) async {
      await openExercises(tester);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('exercises-back')), findsOneWidget);
    });

    testWidgets('the pill clears the tired-hands floors', (tester) async {
      await openExercises(tester);

      for (final key in const [Key('exercises-back'), Key('exercises-clear')]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.height, SweatSize.primaryAction, reason: '$key');
        expect(
          rect.width,
          greaterThanOrEqualTo(SweatSize.minTarget),
          reason: '$key',
        );
      }
    });

    testWidgets('back returns to the roll screen', (tester) async {
      await openExercises(tester);

      await tester.tap(find.byKey(const Key('exercises-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('primary-action')), findsOneWidget);
    });
  });

  group('one exercise', () {
    testWidgets('opens on its own screen, and comes back', (tester) async {
      await openExercises(tester);
      await tester.tap(find.byKey(const Key('exercise-t-anvil')));
      await tester.pumpAndSettle();

      expect(find.text('Anvil'), findsOneWidget);
      // The same block the roll screen's open card shows.
      expect(find.text('How to'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      await tester.tap(find.byKey(const Key('exercise-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exercises-back')), findsOneWidget);
    });

    testWidgets('keeps the search behind it', (tester) async {
      await openExercises(tester);
      await type(tester, 'anv');

      await tester.tap(find.byKey(const Key('exercise-t-anvil')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-back')));
      await tester.pumpAndSettle();

      // The list is still filtered — coming back should land where you left.
      expect(visibleIds(tester), ['t-anvil']);
    });

    testWidgets('an id that names nothing says so rather than throwing', (
      tester,
    ) async {
      await openExercises(tester);

      // A stale deep link, or an entry removed from the catalogue since
      // something linked to it. Editing that file must never crash a screen.
      GoRouter.of(
        tester.element(find.byKey(const Key('exercises-back'))),
      ).push('/exercises/no-such-movement');
      await tester.pumpAndSettle();

      expect(find.text('NOT IN THE CATALOGUE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('exercise-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercises-back')), findsOneWidget);
    });
  });
}
