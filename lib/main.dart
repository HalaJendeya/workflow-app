import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  runApp(
    ProviderScope(
      // Failed requests surface to the user with a Retry action instead of
      // being retried silently.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        if (config.isMock)
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
      ],
      child: const WorkFlowApp(),
    ),
  );
}
