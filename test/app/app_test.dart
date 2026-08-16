import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweat_roulette/app/app.dart';
import 'package:sweat_roulette/app/providers.dart';
import 'package:sweat_roulette/history/data/session_record.dart';
import 'package:sweat_roulette/history/data/session_store.dart';
import 'package:sweat_roulette/home/state/roll_session.dart';
import 'package:sweat_roulette/theme/app_spacing.dart';
import 'package:sweat_roulette/theme/app_typography.dart';
import 'package:sweat_roulette/theme/brand/plate_wheel.dart';

/// The intensity axis, restated here on purpose. If a fourth value appears it
/// either came from a VISION.md change — in which case this set moves with it —
/// or it was invented, and the second is the failure worth catching.
const _intensities = {'Heavy', 'Normal', 'Light'};

/// The pool names must never reach the screen: which pool an exercise came from
/// is how the app chose, not what you do.
const _pools = {'PUSH', 'PULL', 'LEG PUSH', 'LEG PULL', 'CORE'};

void main() {
  late MemorySessionStore store;

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = MemorySessionStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('1.2.3'),
          prefsProvider.overrideWithValue(prefs),
          // In memory, and — deliberately — timerless: the real store debounces
          // its writes, and a pending `Timer` fails a widget test's teardown.
          sessionStoreProvider.overrideWithValue(store),
        ],
        child: const SweatRouletteApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Slots that haven't been rolled into yet — no reveal has happened, but the
  /// reel boundary is already there.
  int ghostCards() => find.byKey(const Key('ghost-head')).evaluate().length;

  /// Rest gaps holding their height with nothing in them: before the first
  /// exercise of a clear day, or before a slot this day skipped.
  int ghostRests() => find.byKey(const Key('ghost-rest')).evaluate().length;

  /// Rest gaps that are actually a rest — idle or already served. The live one
  /// shows a countdown instead, so it isn't counted here.
  int restBars() => find.text('REST · ${kRestSeconds}s').evaluate().length;

  /// Filled cards, counted by their intensity reel — every rolled exercise has
  /// exactly one, and a skipped slot has none. An expanded card still has
  /// exactly one, so the count stays honest mid-session.
  int cards() => _intensities
      .map((v) => find.text(v).evaluate().length)
      .fold(0, (a, b) => a + b);

  /// The reel boundary. Present on filled cards and on ghost slots, absent from
  /// a skipped one.
  int dividers() => find.byKey(const Key('reel-divider')).evaluate().length;

  int unrolled() => find.text('Not rolled').evaluate().length;

  /// The live rest's remaining seconds, or null when no rest is running.
  ///
  /// Read off the widget rather than with `find.text`: [MetricText] sets the
  /// value and its unit as two spans of one rich text — Bebas digits, a Chivo
  /// unit — and carries no plain `data` to match against.
  int? countdown() {
    final found = find
        .byWidgetPredicate((w) => w is MetricText && w.unit == 's')
        .evaluate();
    if (found.isEmpty) return null;
    return int.parse((found.single.widget as MetricText).value);
  }

  /// The one primary action, whatever it currently says.
  String label() {
    final text = find
        .descendant(
          of: find.byKey(const Key('primary-action')),
          matching: find.byType(Text),
        )
        .evaluate()
        .single
        .widget;
    return (text as Text).data!;
  }

  /// Taps the one primary action, whatever it currently says.
  ///
  /// `pumpAndSettle` is safe here only because it stops as soon as no frame is
  /// scheduled — the 220ms growth and the 300ms scroll, and nowhere near the
  /// rest timer's first tick at one second. It advances the fake clock while it
  /// runs, so if those animations ever grew past a second this would start
  /// silently fast-forwarding rests instead of entering them. `'NEXT skips the
  /// remainder of a rest'` is the test that would catch it.
  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('primary-action')));
    await tester.pumpAndSettle();
  }

  /// Opens the sheet behind the narrow button and taps one of its rows.
  Future<void> tapInSheet(WidgetTester tester, Key row) async {
    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(row));
    await tester.pumpAndSettle();
  }

  Future<void> tapReset(WidgetTester tester) =>
      tapInSheet(tester, const Key('reset'));

  /// ROLL, then START — the two taps that get a session under way.
  Future<void> beginSession(WidgetTester tester) async {
    await tapPrimary(tester);
    await tapPrimary(tester);
  }

  group('clear state', () {
    testWidgets('shows three empty slots, already divided into reels', (
      tester,
    ) async {
      await pumpApp(tester);

      // The shape of a day is visible before it exists.
      expect(ghostCards(), 3);

      // Empty slots carry the reel boundary too, so the divider doesn't appear
      // out of nowhere when the roll fills them.
      expect(dividers(), 3);

      // Both rest gaps are held open for the same reason.
      expect(ghostRests(), 2);
      expect(restBars(), 0);

      expect(cards(), 0);
      expect(unrolled(), 0);
      expect(label(), 'ROLL');
    });

    testWidgets('nothing on any state is a dice affordance', (tester) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.casino_outlined), findsNothing);

      await tapPrimary(tester);
      expect(find.byIcon(Icons.casino_outlined), findsNothing);

      await tapPrimary(tester);
      expect(find.byIcon(Icons.casino_outlined), findsNothing);
    });
  });

  group('chrome', () {
    testWidgets('is the action row and nothing else', (tester) async {
      await pumpApp(tester);

      // Navigation costs no vertical space of its own: it shares the row the
      // primary action was already using. An AppBar would have taken ~12% of
      // the screen to hold three icons, and a bottom bar would sit under a
      // thumb aiming for the action.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);

      // The mark belongs to the roll animation, not to any resting state.
      expect(find.byType(PlateWheel), findsNothing);
    });

    testWidgets('the action row clears the tired-hands floors', (tester) async {
      await pumpApp(tester);

      final menu = tester.getRect(find.byKey(const Key('nav-menu')));
      final action = tester.getRect(find.byKey(const Key('primary-action')));

      // Both are the full 88dp primary-action height, edge to edge, so a press
      // on either fills its half right up to the seam.
      expect(menu.height, SweatSize.primaryAction);
      expect(action.height, SweatSize.primaryAction);

      // They meet at a hairline. This deliberately spends DESIGN.md's 12dp gap
      // between adjacent targets — the two halves are one pill, and a dead
      // strip inside it would show as an unlit band the moment either half was
      // pressed. What guards a sloppy tap instead is distance: the seam sits at
      // a fifth of the width, nowhere near where a thumb aims for the action.
      expect(action.left - menu.right, lessThanOrEqualTo(3));

      // The narrow one stays narrow — the action is the thing to press.
      expect(menu.width, lessThan(action.width / 2));
    });

    testWidgets('each screen is reachable through the sheet and comes back', (
      tester,
    ) async {
      await pumpApp(tester);

      // History has no AppBar: like the roll screen, its way back is the left
      // compartment of the bottom pill, so the affordance is in the place the
      // thumb already knows. The two undesigned screens still carry a bar, and
      // are still reached and left the ordinary way.
      final destinations = <(Key, Finder, Future<void> Function())>[
        (
          const Key('nav-history'),
          find.byKey(const Key('history-back')),
          () => tester.tap(find.byKey(const Key('history-back'))),
        ),
        (
          const Key('nav-exercises'),
          find.text('Exercises'),
          () => tester.pageBack(),
        ),
        (const Key('nav-config'), find.text('Config'), () => tester.pageBack()),
      ];

      for (final (row, marker, goBack) in destinations) {
        await tapInSheet(tester, row);
        expect(marker, findsOneWidget, reason: '$row');

        // Back returns to the roll screen rather than rebuilding it.
        await goBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('primary-action')),
          findsOneWidget,
          reason: '$row',
        );
      }
    });

    testWidgets('a session survives leaving the screen', (tester) async {
      await pumpApp(tester);
      await beginSession(tester);
      expect(find.text('How to'), findsOneWidget);

      await tapInSheet(tester, const Key('nav-config'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Walking off to change a setting must not throw the day away.
      expect(find.text('How to'), findsOneWidget);
    });
  });

  group('the roll', () {
    /// Taps without settling, so the reels can be watched rather than
    /// fast-forwarded.
    Future<void> startRoll(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('primary-action')));
      await tester.pump();
    }

    testWidgets('everything spins at once, and stops from the top down', (
      tester,
    ) async {
      await pumpApp(tester);
      await startRoll(tester);

      // Nothing is being decided any more — the action can only stop the
      // watching.
      expect(label(), 'SKIP');

      // No slot sits still while the others turn. A still one would say "this
      // is the one the day didn't fill" before anything had landed.
      expect(ghostCards(), 0);

      // Every reel is loaded with blur frames, so each intensity word is on
      // screen many times over rather than once per card.
      final spinning = cards();
      expect(spinning, greaterThan(slots));

      // As reels stop, their blur frames leave the tree — so the count falls,
      // and only ever falls.
      final counts = <int>[spinning];
      for (var i = 0; i < slots * 2 + 2; i++) {
        await tester.pump(kRevealStep);
        counts.add(cards());
      }
      await tester.pumpAndSettle();

      for (var i = 1; i < counts.length; i++) {
        expect(
          counts[i],
          lessThanOrEqualTo(counts[i - 1]),
          reason: 'reels only ever stop: $counts',
        );
      }
      expect(counts.last, lessThan(spinning), reason: 'they did stop');

      expect(label(), 'START');
      expect(cards(), anyOf(2, 3));
      expect(cards() + unrolled(), 3);
    });

    testWidgets('SKIP lands the whole day at once', (tester) async {
      await pumpApp(tester);
      await startRoll(tester);
      expect(label(), 'SKIP');

      await tapPrimary(tester);

      expect(label(), 'START');
      expect(ghostCards(), 0);
      expect(cards(), anyOf(2, 3));
      expect(cards() + unrolled(), 3);
    });

    testWidgets('the reels do not outlive the screen', (tester) async {
      await pumpApp(tester);
      await startRoll(tester);

      // Leaving mid-roll must cancel the reveal timer — a pending one would
      // fail this test on teardown.
      await tapReset(tester);
      expect(ghostCards(), 3);
      expect(label(), 'ROLL');
    });
  });

  group('rolled state', () {
    testWidgets('fills two or three slots, always showing three', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapPrimary(tester);

      expect(ghostCards(), 0);
      expect(label(), 'START');

      // VISION.md rolls 2 or 3 pools. A short day leaves the third slot in
      // place saying it was skipped, rather than shortening the screen.
      expect(cards(), anyOf(2, 3));
      expect(cards() + unrolled(), 3);

      // A skipped slot has no reels to spin, so it carries no divider.
      expect(dividers(), cards());
    });

    testWidgets('a skipped slot still holds its rest open', (tester) async {
      await pumpApp(tester);

      // The count is random, so one pass proves little.
      for (var i = 0; i < 20; i++) {
        await tapPrimary(tester); // ROLL

        // A rest only carries a time between two exercises that happen — it
        // never leads into a skip.
        expect(restBars(), cards() - 1, reason: 'times sit between exercises');

        // ...but the gap itself is always there, as a ghost. Three slots
        // always account for two rest gaps between them.
        expect(restBars() + ghostRests(), 2, reason: 'two gaps, always');

        await tapReset(tester);
      }
    });

    testWidgets('a short day does not move the cards it shares', (
      tester,
    ) async {
      await pumpApp(tester);

      final tops = <int, Set<double>>{0: {}, 1: {}};
      final counts = <int>{};

      for (var i = 0; i < 30; i++) {
        await tapPrimary(tester);
        counts.add(cards());
        for (final slot in tops.keys) {
          tops[slot]!.add(
            tester.getTopLeft(find.byKey(ValueKey('card-$slot'))).dy,
          );
        }
        await tapReset(tester);
      }

      // The test is only meaningful if both day lengths actually came up.
      expect(counts, containsAll(<int>{2, 3}), reason: '30 rolls saw both');

      // A two-pool day is *shorter*, not a screen whose cards sit somewhere
      // else. This is what the ghost rest bar is for.
      for (final slot in tops.keys) {
        expect(tops[slot], hasLength(1), reason: 'card-$slot moved');
      }
    });

    testWidgets('cards show an intensity, never a pool', (tester) async {
      await pumpApp(tester);

      for (var i = 0; i < 20; i++) {
        await tapPrimary(tester);

        final shown = _intensities.where(
          (v) => find.text(v).evaluate().isNotEmpty,
        );
        expect(shown, isNotEmpty);

        // Pool names are deliberately not surfaced.
        for (final pool in _pools) {
          expect(find.text(pool), findsNothing, reason: pool);
        }

        await tapReset(tester);
      }
    });

    testWidgets('an idle rest stays under the touch-target floor', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapPrimary(tester);

      // It is allowed to be small precisely because you can't press it — NEXT
      // skips a rest, the bar never does. If it ever gains a tap target it has
      // to grow to 56dp first.
      final bar = find.text('REST · ${kRestSeconds}s').first;
      expect(
        find.ancestor(of: bar, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('rest-1'))).height,
        lessThan(SweatSize.minTarget),
      );
    });
  });

  group('session', () {
    testWidgets('START expands the first exercise and nothing else', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapPrimary(tester);

      // The detail belongs to the exercise being worked on, so a rolled-but-
      // not-started day shows none of it.
      expect(find.text('How to'), findsNothing);

      await tapPrimary(tester);

      // Exactly one card is ever open.
      expect(find.text('How to'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);

      // Expanding a card must not change how many cards there are.
      expect(cards() + unrolled(), 3);
      expect(dividers(), cards());
    });

    testWidgets('whatever is being done sits at the top of the screen', (
      tester,
    ) async {
      await pumpApp(tester);

      // Roll until a three-pool day, so there is a second exercise with room
      // above it to scroll away.
      for (var i = 0; i < 40 && cards() != 3; i++) {
        if (cards() != 0) await tapReset(tester);
        await tapPrimary(tester);
      }
      expect(cards(), 3, reason: '40 rolls found a three-pool day');

      await tapPrimary(tester); // START — exercise 0

      // Wherever the first exercise lands is where every focus after it has to
      // arrive. Measured rather than assumed, because the scroll view only
      // fills the viewport once a session is running and the content has
      // outgrown it.
      final viewportTop = tester
          .getTopLeft(find.byKey(const ValueKey('card-0')))
          .dy;

      // Just below the top edge, not jammed against it.
      expect(
        viewportTop,
        moreOrLessEquals(
          tester.getTopLeft(find.byType(SingleChildScrollView)).dy +
              SweatSpace.lg,
          epsilon: 1,
        ),
      );

      await tapPrimary(tester); // NEXT — the rest before exercise 1
      expect(
        // The rest slot carries its connector inset; the bar you actually see
        // is that much lower, and it is the bar that lands flush with the top.
        tester.getTopLeft(find.byKey(const ValueKey('rest-1'))).dy +
            SweatSpace.sm,
        moreOrLessEquals(viewportTop, epsilon: 1),
      );

      await tapPrimary(tester); // NEXT — exercise 1
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('card-1'))).dy,
        moreOrLessEquals(viewportTop, epsilon: 1),
      );

      // Which means the finished one has scrolled off above it.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('card-0'))).dy,
        lessThan(viewportTop),
      );
    });

    testWidgets('the live rest is unmistakable, and counts down', (
      tester,
    ) async {
      await pumpApp(tester);
      await beginSession(tester);

      final idleHeight = tester
          .getSize(find.byKey(const ValueKey('rest-1')))
          .height;

      await tapPrimary(tester); // NEXT — into the rest before exercise 1

      // It stops being a connector and becomes the thing you are doing.
      final liveHeight = tester
          .getSize(find.byKey(const ValueKey('rest-1')))
          .height;
      expect(liveHeight, greaterThan(idleHeight));
      expect(find.byKey(const Key('rest-progress')), findsOneWidget);

      // Exactly one countdown on screen — every other bar reads the full
      // interval as static text.
      final started = countdown();
      expect(started, isNotNull);
      expect(started, lessThanOrEqualTo(kRestSeconds));

      await tester.pump(const Duration(seconds: 1));
      expect(countdown(), started! - 1);

      await tester.pump(const Duration(seconds: 1));
      expect(countdown(), started - 2);

      // The track drains as it goes.
      final track = tester.getSize(find.byKey(const Key('rest-progress')));
      final bar = tester.getSize(find.byKey(const ValueKey('rest-1')));
      expect(track.width, lessThan(bar.width));

      // Tired hands do nothing: run it out and the next exercise opens itself.
      for (var i = 0; i < kRestSeconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rest-progress')), findsNothing);
      expect(find.text('How to'), findsOneWidget);
    });

    testWidgets('NEXT skips the remainder of a rest', (tester) async {
      await pumpApp(tester);
      await beginSession(tester);

      await tapPrimary(tester); // into the rest
      expect(find.text('How to'), findsNothing);
      expect(find.byKey(const Key('rest-progress')), findsOneWidget);

      await tapPrimary(tester); // skip it
      expect(find.text('How to'), findsOneWidget);

      // Skipping must not leave the timer running — a pending one would fail
      // this test on teardown.
      await tester.pumpAndSettle();
    });

    testWidgets('the last exercise says FINISH, not NEXT', (tester) async {
      await pumpApp(tester);

      expect(label(), 'ROLL');
      await tapPrimary(tester);
      expect(label(), 'START');

      await tapPrimary(tester);
      final count = cards();

      // exercise, rest, exercise, rest, ... — two taps per gap.
      for (var i = 0; i < count - 1; i++) {
        expect(label(), 'NEXT', reason: 'exercise $i of $count');
        await tapPrimary(tester); // into the rest
        expect(label(), 'NEXT', reason: 'rest before ${i + 1}');
        await tapPrimary(tester); // skip it
      }

      // Nothing comes after this one, so the button must not say "next".
      expect(label(), 'FINISH');
      await tapPrimary(tester);

      // The finished day is still on screen — nothing was thrown away — and
      // the action starts the next one rather than emptying the screen first.
      expect(label(), 'ROLL');
      expect(find.text('How to'), findsNothing);
      expect(cards() + unrolled(), 3);
      expect(ghostCards(), 0);

      await tapPrimary(tester);
      expect(label(), 'START', reason: 'ROLL rolls, it does not just clear');
    });

    testWidgets('RESET returns to the clear state from anywhere', (
      tester,
    ) async {
      await pumpApp(tester);

      // Rolled, exercising, and mid-rest.
      for (var taps = 1; taps <= 3; taps++) {
        for (var i = 0; i < taps; i++) {
          await tapPrimary(tester);
        }

        await tapReset(tester);

        expect(ghostCards(), 3, reason: '$taps taps in');
        expect(label(), 'ROLL');
        expect(cards(), 0);
        expect(unrolled(), 0);
        expect(restBars(), 0);
        expect(ghostRests(), 2);
      }
    });
  });

  group('what the day leaves behind', () {
    testWidgets('a day walked to FINISH is recorded, every slot done', (
      tester,
    ) async {
      await pumpApp(tester);
      await beginSession(tester);

      while (label() != 'FINISH') {
        await tapPrimary(tester);
      }
      await tapPrimary(tester);

      expect(store.records, hasLength(1));
      final record = store.records.single;

      expect(record.outcome, SessionOutcome.finished);
      expect(record.day, dayOf(DateTime.now()));
      expect(record.isComplete, true);
      expect(
        record.slots.every((s) => s.outcome == SlotOutcome.completed),
        true,
      );

      // Nothing half-written left over for the next launch to recover.
      expect(store.inFlight, isNull);
    });

    testWidgets('the open card offers a way to say you couldn’t do it', (
      tester,
    ) async {
      await pumpApp(tester);

      // Only on the card being worked on: there is nothing to bail on before
      // a session starts.
      await tapPrimary(tester);
      expect(find.byKey(const Key('skip-exercise')), findsNothing);

      await tapPrimary(tester);
      expect(find.byKey(const Key('skip-exercise')), findsOneWidget);

      // Still a fair target after a set, even though it rides at the top of the
      // screen with the open card.
      expect(
        tester.getSize(find.byKey(const Key('skip-exercise'))).height,
        greaterThanOrEqualTo(SweatSize.minTarget),
      );
    });

    testWidgets('bailing marks the slot and moves the session on in one tap', (
      tester,
    ) async {
      await pumpApp(tester);
      await beginSession(tester);

      // The strip is at the foot of the open card, which on this surface is
      // taller than the viewport — the same scroll a thumb would do.
      await tester.ensureVisible(find.byKey(const Key('skip-exercise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skip-exercise')));
      await tester.pumpAndSettle();

      // One tap: the card has closed and the day has moved past it, exactly as
      // NEXT would have.
      expect(find.byKey(const Key('skip-exercise')), findsNothing);
      expect(label(), 'NEXT');

      while (label() != 'FINISH') {
        await tapPrimary(tester);
      }
      await tapPrimary(tester);

      final record = store.records.single;
      expect(record.slots.first.outcome, SlotOutcome.skipped);
      expect(record.shortfalls, 1);
      expect(record.isComplete, false);
    });

    testWidgets('a two-pool day is recorded as complete, not as a miss', (
      tester,
    ) async {
      await pumpApp(tester);

      // Roll until the day comes up short. VISION.md rolls 2 *or* 3 pools, so
      // the empty third slot is the app working — it must not be recorded as
      // something the day fell short of.
      for (var attempt = 0; attempt < 40; attempt++) {
        await tapPrimary(tester); // ROLL
        await tapPrimary(tester); // SKIP the reels
        if (unrolled() == 1) break;
        await tapReset(tester);
      }
      expect(unrolled(), 1, reason: '40 rolls never came up short');

      await tapPrimary(tester); // START
      while (label() != 'FINISH') {
        await tapPrimary(tester);
      }
      await tapPrimary(tester);

      final record = store.records.single;
      expect(record.slots, hasLength(2));
      expect(record.slotCount, 3);
      expect(record.outcomeAt(2), SlotOutcome.notRolled);
      expect(record.shortfalls, 0);
      expect(record.isComplete, true);
    });

    testWidgets('a session left half-done is on the disk as it stood', (
      tester,
    ) async {
      await pumpApp(tester);
      await beginSession(tester);
      await tapPrimary(tester); // into the first rest
      await tapPrimary(tester); // begin the second exercise

      // The app is killed here. Nothing is committed, but the live session is
      // already written — with the tail honestly unreached.
      expect(store.records, isEmpty);

      final live = store.inFlight!;
      expect(live.outcome, SessionOutcome.running);
      expect(live.slots.first.outcome, SlotOutcome.completed);

      // Neither a tick nor a cross on the one that was open — the app does not
      // know how it went, and must not guess in either direction.
      expect(live.slots[1].outcome, SlotOutcome.inProgress);
      expect(live.slots[1].outcome.isShortfall, false);
      expect(live.abandoned().isComplete, false);
    });

    testWidgets('the seed tile fills History without a real session', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(store.records, isEmpty);

      await tapInSheet(tester, const Key('seed-history'));
      await tester.pumpAndSettle();

      expect(store.records, isNotEmpty);
      // Placeholder days only — nothing invented outside the sample list.
      for (final record in store.records) {
        for (final slot in record.slots) {
          expect(sampleNames, contains(slot.name));
        }
      }
    });
  });
}
