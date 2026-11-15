import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  // Language and theme are read before the first frame, so a chosen
  // override never flashes the device default first.
  final preferences = SecurePreferencesStore();
  final initial = await loadPreferences(preferences);
  runApp(
    ProviderScope(
      // Failed requests surface to the user with a Retry action instead of
      // being retried silently.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        preferencesStoreProvider.overrideWithValue(preferences),
        initialPreferencesProvider.overrideWithValue(initial),
        if (config.isMock)
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
      ],
      child: const WorkFlowApp(),
    ),
  );
}
