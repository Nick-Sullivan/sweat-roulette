import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'history/data/file_session_store.dart';
import 'history/data/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve everything platform-dependent up front, then hand it to the
  // provider scope — no async lookups hiding behind the widget tree.
  final info = await PackageInfo.fromPlatform();
  final prefs = await SharedPreferences.getInstance();

  // Application *support*, not documents: on iOS, Documents is the directory
  // the user browses in Files, and this is app-managed data. Both are in the OS
  // backup set, which is what VISION.md's "the phone is the one source" needs.
  //
  // This is the only place `path_provider` is called. Keeping it here is what
  // lets the store be tested against a temp directory with no platform channel.
  final support = await getApplicationSupportDirectory();
  final store = FileSessionStore(Directory('${support.path}/history'));
  await store.load();

  // A session that was under way when the app was last killed. Recorded as
  // abandoned before the first frame, so History is complete and the roll
  // screen opens clear rather than halfway through a day.
  final orphan = store.inFlight;
  if (orphan != null) await store.commit(orphan.abandoned());

  runApp(
    ProviderScope(
      overrides: [
        appVersionProvider.overrideWithValue(info.version),
        prefsProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(store),
      ],
      child: const SweatRouletteApp(),
    ),
  );
}
