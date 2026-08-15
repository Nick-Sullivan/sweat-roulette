import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolved in `main()` and injected via [ProviderScope.overrides] — nothing is
/// looked up lazily from a service locator, so a widget test can supply its own
/// values without touching platform channels.

/// The running app's version name (e.g. `2026.08.15.7`).
final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('appVersionProvider must be overridden'),
);

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);
