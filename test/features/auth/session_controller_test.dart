import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

class _MockAuth extends Mock implements AuthRepository;

const _session = Session(
  token: 't',
  tokenType: 'Bearer',
  userId: 7,
  companyId: 25,
  portal: Portal.employee,
);

void main() {
  late _MockAuth auth;
  late InMemorySessionStorage storage;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        sessionStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    auth = _MockAuth();
    storage = InMemorySessionStorage();
    registerFallbackValue(Portal.client);
  });

  test('starts signed out with empty storage', () async {
    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future), isNull);
  });

  test('login persists the session and feeds credentials', () async {
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        portal: any(named: 'portal'),
      ),
    ).thenAnswer((_) async => _session);
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);

    await c
        .read(sessionControllerProvider.notifier)
        .login(email: 'a@b.co', password: 'x', portal: Portal.employee);

    expect(c.read(sessionControllerProvider).value?.userId, 7);
    expect(c.read(sessionCredentialsProvider).token, 't');
    expect((await storage.readAll())['portal'], 'employee');
  });

  test('a 401 ends an open session and reports the expiry once', () async {
    await storage.writeAll(_session.toStorage());
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    expect(c.read(sessionExpiryProvider), 0);

    c.read(sessionCredentialsProvider).onUnauthorized();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(sessionControllerProvider).value, isNull);
    expect(c.read(sessionCredentialsProvider).token, isNull);
    expect(await storage.readAll(), isEmpty);
    expect(c.read(sessionExpiryProvider), 1);
  });

  test('a 401 while signed out is not reported as an expiry', () async {
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    c.read(sessionCredentialsProvider).onUnauthorized();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(sessionExpiryProvider), 0);
  });

  test('a portal mismatch stores nothing and opens no session', () async {
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        portal: any(named: 'portal'),
      ),
    ).thenThrow(const PortalMismatch(Portal.client));
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await expectLater(
      c
          .read(sessionControllerProvider.notifier)
          .login(email: 'a@b.co', password: 'x', portal: Portal.client),
      throwsA(isA<PortalMismatch>()),
    );
    expect(c.read(sessionControllerProvider).value, isNull);
    expect(c.read(sessionCredentialsProvider).token, isNull);
    expect(await storage.readAll(), isEmpty);
  });

  test('restores a stored session on start', () async {
    await storage.writeAll(_session.toStorage());
    final c = makeContainer();
    final restored = await c.read(sessionControllerProvider.future);
    expect(restored?.companyId, 25);
    expect(c.read(sessionCredentialsProvider).companyId, 25);
  });

  test('corrupt storage is cleared instead of crashing', () async {
    await storage.writeAll({'token': 't'});
    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future), isNull);
    expect(await storage.readAll(), isEmpty);
  });

  test('logout clears locally even when the server call fails', () async {
    await storage.writeAll(_session.toStorage());
    when(() => auth.logout()).thenThrow(
      const ApiException(kind: ApiFailureKind.network, message: 'offline'),
    );
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);

    await c.read(sessionControllerProvider.notifier).logout();

    expect(c.read(sessionControllerProvider).value, isNull);
    expect(await storage.readAll(), isEmpty);
  });

  test('a 401 from the API signs the user out', () async {
    await storage.writeAll(_session.toStorage());
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);

    c.read(sessionCredentialsProvider).onUnauthorized();
    await pumpEventQueue();

    expect(c.read(sessionControllerProvider).value, isNull);
  });

  test('failed login leaves state untouched and rethrows', () async {
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        portal: any(named: 'portal'),
      ),
    ).thenThrow(
      const ApiException(kind: ApiFailureKind.unauthorized, message: 'bad'),
    );
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);

    await expectLater(
      c
          .read(sessionControllerProvider.notifier)
          .login(email: 'a@b.co', password: 'x', portal: Portal.client),
      throwsA(isA<ApiException>()),
    );
    expect(c.read(sessionControllerProvider).value, isNull);
  });
}
