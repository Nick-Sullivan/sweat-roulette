import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweat_roulette/app/app.dart';
import 'package:sweat_roulette/app/providers.dart';
import 'package:sweat_roulette/history/data/session_store.dart';
import 'package:sweat_roulette/theme/app_colors.dart';
import 'package:sweat_roulette/theme/app_spacing.dart';
import 'package:sweat_roulette/theme/app_theme.dart';
import 'package:sweat_roulette/theme/app_typography.dart';

void main() {
  testWidgets('the app is dark whatever the platform asks for', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Force the platform into light mode — the app should ignore it.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('1.2.3'),
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        ],
        child: const SweatRouletteApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, SweatColors.dark.canvas);
    expect(theme.extension<SweatColors>(), isNotNull);
    expect(theme.extension<SweatTextStyles>(), isNotNull);
  });

  test('buttons clear the tired-hands minimum', () {
    // VISION.md: "peoples hands will be tired so don't expect the ability for
    // precise button presses". These floors are load-bearing, not cosmetic.
    const states = <WidgetState>{};

    final filled = SweatTheme.dark.filledButtonTheme.style!;
    final outlined = SweatTheme.dark.outlinedButtonTheme.style!;
    final text = SweatTheme.dark.textButtonTheme.style!;

    expect(filled.minimumSize!.resolve(states)!.height, SweatSize.button);
    expect(outlined.minimumSize!.resolve(states)!.height, SweatSize.button);
    expect(
      text.minimumSize!.resolve(states)!.height,
      greaterThanOrEqualTo(SweatSize.minTarget),
    );
    expect(SweatSize.minTarget, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  test('surfaces are flat — separation comes from value, not shadow', () {
    expect(SweatTheme.dark.cardTheme.elevation, 0);
    expect(SweatTheme.dark.appBarTheme.elevation, 0);
    expect(SweatTheme.dark.appBarTheme.scrolledUnderElevation, 0);
  });
}
