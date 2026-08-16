import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweat_roulette/app/app.dart';
import 'package:sweat_roulette/app/providers.dart';
import 'package:sweat_roulette/history/data/session_record.dart';
import 'package:sweat_roulette/history/data/session_store.dart';
import 'package:sweat_roulette/theme/app_spacing.dart';

/// The History screen, reached the way it is reached in the app.
///
/// Pumped through the real router rather than in isolation: the back
/// compartment pops a route, and a screen whose only exit is a `context.pop()`
/// is worth testing with something to pop back to.
void main() {
  /// A day, named so the assertions can find it. Movement names are the test's
  /// own — nothing here is a fixture anything else should rely on.
  SessionRecord day(
    int dayOfMonth,
    List<SlotOutcome> outcomes, {
    int month = 8,
    SessionOutcome outcome = SessionOutcome.finished,
  }) => SessionRecord(
    startedAt: DateTime(2026, month, dayOfMonth, 18, 30),
    day: DateTime(2026, month, dayOfMonth),
    finishedAt: outcome == SessionOutcome.finished
        ? DateTime(2026, month, dayOfMonth, 19)
        : null,
    outcome: outcome,
    slots: [
      for (final (i, o) in outcomes.indexed)
        SlotRecord(
          id: 'movement-$month-$dayOfMonth-$i',
          name: 'Movement $month/$dayOfMonth/$i',
          intensity: 'Heavy',
          outcome: o,
          restBefore: i == 0 ? null : 90,
        ),
    ],
  );

  /// Three sessions spanning a month boundary, oldest first — the run is
  /// deliberately short so an end is one swipe away, and deliberately crosses
  /// July into August so the grid has to follow.
  List<SessionRecord> threeSessions() => [
    day(30, const [SlotOutcome.completed, SlotOutcome.completed], month: 7),
    day(2, const [
      SlotOutcome.completed,
      SlotOutcome.skipped,
      SlotOutcome.completed,
    ]),
    day(5, const [
      SlotOutcome.completed,
      SlotOutcome.inProgress,
      SlotOutcome.notReached,
    ], outcome: SessionOutcome.abandoned),
  ];

  Future<void> openHistory(
    WidgetTester tester, {
    List<SessionRecord> seed = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('1.2.3'),
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(
            MemorySessionStore(seed: seed),
          ),
        ],
        child: const SweatRouletteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
  }

  /// Towards older sessions: the page to the left.
  ///
  /// A fling rather than a drag — a drag of exactly half a page is right on the
  /// boundary where a [PageView] decides whether to advance or snap back, so it
  /// tests the tolerance rather than the screen.
  Future<void> swipeBack(WidgetTester tester) async {
    await tester.fling(
      find.byKey(const Key('history-pages')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<InkWell>(find.byKey(key)).onTap != null;

  group('chrome', () {
    testWidgets('carries no AppBar — back is in the bottom pill', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());

      // Controls belong where the thumb is, not under the status bar.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('history-back')), findsOneWidget);
    });

    testWidgets('the pill clears the tired-hands floors', (tester) async {
      await openHistory(tester, seed: threeSessions());

      for (final key in const [
        Key('history-back'),
        Key('history-prev'),
        Key('history-next'),
      ]) {
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
      await openHistory(tester, seed: threeSessions());

      await tester.tap(find.byKey(const Key('history-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('primary-action')), findsOneWidget);
      expect(find.byKey(const Key('history-back')), findsNothing);
    });
  });

  group('the calendar', () {
    testWidgets('opens on the month of the most recent session', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('July 2026'), findsNothing);
    });

    testWidgets('always draws the same number of week rows', (tester) async {
      // A band that changed height between months would shove the session
      // below it up and down every time a swipe crossed a boundary.
      await openHistory(tester, seed: threeSessions());
      final august = tester.getSize(find.text('August 2026'));

      final before = tester.getRect(find.byKey(const Key('history-pages'))).top;

      await swipeBack(tester);
      await swipeBack(tester);
      expect(find.text('July 2026'), findsOneWidget);

      expect(
        tester.getRect(find.byKey(const Key('history-pages'))).top,
        before,
      );
      expect(tester.getSize(find.text('July 2026')).height, august.height);
    });

    testWidgets('follows the selection across a month boundary', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());
      expect(find.text('August 2026'), findsOneWidget);

      // Two sessions back is 30 July — the grid has to come with it.
      await swipeBack(tester);
      expect(find.text('August 2026'), findsOneWidget);

      await swipeBack(tester);
      expect(find.text('July 2026'), findsOneWidget);
    });
  });

  group('a session', () {
    testWidgets('names every slot the layout had, filled or not', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());

      // The newest session: done, in progress, never reached.
      expect(find.text('Movement 8/5/0'), findsOneWidget);
      expect(find.text('Movement 8/5/1'), findsOneWidget);
      expect(find.text('Movement 8/5/2'), findsOneWidget);
      expect(find.text('Left unfinished'), findsOneWidget);
    });

    testWidgets('says what the roll left empty, without calling it a miss', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());

      // Back to 30 July: a two-pool day, so the third slot was never rolled.
      await swipeBack(tester);
      await swipeBack(tester);

      expect(find.text('Not rolled'), findsOneWidget);
      // Not the same sentence as a session that stopped early — one is the roll
      // working as VISION.md describes, the other is a shortfall.
      expect(find.text('Not reached'), findsNothing);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('a swipe and the buttons land in the same place', (
      tester,
    ) async {
      await openHistory(tester, seed: threeSessions());

      await swipeBack(tester);
      expect(find.text('Movement 8/2/0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-next')));
      await tester.pumpAndSettle();
      expect(find.text('Movement 8/5/0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-prev')));
      await tester.pumpAndSettle();
      expect(find.text('Movement 8/2/0'), findsOneWidget);
    });
  });

  group('the ends of history', () {
    testWidgets('NEXT is dead on the newest session', (tester) async {
      await openHistory(tester, seed: threeSessions());

      expect(enabled(tester, const Key('history-next')), false);
      expect(enabled(tester, const Key('history-prev')), true);
    });

    testWidgets('PREV is dead on the oldest', (tester) async {
      await openHistory(tester, seed: threeSessions());

      await swipeBack(tester);
      await swipeBack(tester);

      expect(enabled(tester, const Key('history-prev')), false);
      expect(enabled(tester, const Key('history-next')), true);
    });
  });

  group('nothing recorded yet', () {
    testWidgets('says so, and both steps are dead', (tester) async {
      await openHistory(tester);

      expect(find.text('NO SESSIONS YET'), findsOneWidget);
      expect(find.byKey(const Key('history-pages')), findsNothing);

      expect(enabled(tester, const Key('history-prev')), false);
      expect(enabled(tester, const Key('history-next')), false);

      // The way out still works.
      expect(enabled(tester, const Key('history-back')), true);
    });

    testWidgets('still draws the current month', (tester) async {
      await openHistory(tester);

      // An empty calendar is still a calendar — it shows where you are.
      expect(find.byType(GridView), findsNothing);
      final now = DateTime.now();
      expect(find.textContaining('${now.year}'), findsWidgets);
    });
  });
}
