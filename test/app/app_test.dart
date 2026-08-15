import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweat_roulette/app/app.dart';
import 'package:sweat_roulette/app/providers.dart';

void main() {
  testWidgets('app boots to the home screen and shows its version', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('1.2.3'),
          prefsProvider.overrideWithValue(prefs),
        ],
        child: const SweatRouletteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Sweat Roulette'), findsOneWidget);
    expect(find.text('v1.2.3'), findsOneWidget);
  });
}
