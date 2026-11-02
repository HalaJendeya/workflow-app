import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/app/router.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

Widget _app({required AppMode mode, Locale? locale, SessionStorage? storage}) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(
          storage ?? InMemorySessionStorage(),
        ),
      ],
      child: WorkFlowApp(locale: locale),
    );

void main() {
  group('redirectFor', () {
    const employee = Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 1,
      portal: Portal.employee,
    );

    test('signed out users land on welcome', () {
      expect(
        redirectFor(session: const AsyncData(null), location: Routes.client),
        Routes.welcome,
      );
    });

    test('each role is kept inside its own area', () {
      expect(
        redirectFor(
          session: const AsyncData(employee),
          location: Routes.client,
        ),
        Routes.employee,
      );
      expect(
        redirectFor(
          session: const AsyncData(employee),
          location: Routes.employee,
        ),
        isNull,
      );
    });

    test('splash while the session is restoring', () {
      expect(
        redirectFor(session: const AsyncLoading(), location: Routes.employee),
        Routes.splash,
      );
    });
  });

  testWidgets('signed-out app shows the auth route in English', (tester) async {
    await tester.pumpWidget(
      _app(mode: AppMode.api, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Design pending'), findsOneWidget);
    expect(find.text('auth'), findsOneWidget);
  });

  testWidgets('Arabic renders right-to-left', (tester) async {
    await tester.pumpWidget(
      _app(mode: AppMode.api, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('التصميم قيد الانتظار'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('auth')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('restored employee session opens the employee area', (
    tester,
  ) async {
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 1,
        portal: Portal.employee,
      ).toStorage(),
    );
    await tester.pumpWidget(_app(mode: AppMode.api, storage: storage));
    await tester.pumpAndSettle();
    expect(find.text('employee'), findsOneWidget);
  });

  testWidgets('mock mode is visibly marked as demo', (tester) async {
    await tester.pumpWidget(_app(mode: AppMode.mock));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is Banner && w.message == 'DEMO'),
      findsOneWidget,
    );
  });
}
