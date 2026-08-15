import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve everything platform-dependent up front, then hand it to the
  // provider scope — no async lookups hiding behind the widget tree.
  final info = await PackageInfo.fromPlatform();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appVersionProvider.overrideWithValue(info.version),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const SweatRouletteApp(),
    ),
  );
}
