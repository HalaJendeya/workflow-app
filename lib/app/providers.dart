import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/data/mock_auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Composition root. Every dependency is a provider so tests can override it.

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('Override appConfigProvider in main().'),
);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);

/// Bridges the current session to the HTTP layer without the network code
/// depending on Riverpod or the auth feature.
class SessionCredentials implements ApiCredentials {
  Session? session;
  void Function()? unauthorizedHandler;

  @override
  String? get token => session?.token;

  @override
  int? get companyId => session?.companyId;

  @override
  void onUnauthorized() => unauthorizedHandler?.call();
}

final sessionCredentialsProvider = Provider<SessionCredentials>(
  (ref) => SessionCredentials(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(
    baseUrl: config.apiBaseUrl,
    credentials: ref.watch(sessionCredentialsProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appConfigProvider).isMock) return MockAuthRepository();
  return ApiAuthRepository(ref.watch(apiClientProvider));
});
