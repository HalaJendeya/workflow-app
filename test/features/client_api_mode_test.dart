import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import 'client_api_contract_test.dart' show invoicesExample;

/// The whole client app in API mode against path-routed fixtures: screens
/// must show server data or the server's error, never sample records.
void main() {
  Future<RouteHttpAdapter> pumpApi(
    WidgetTester tester,
    Map<String, (int, Object?)> routes,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 2,
        portal: Portal.client,
      ).toStorage(),
    );
    final http = RouteHttpAdapter({
      'GET /api/v1/client/account': (
        200,
        ok({'id': 1, 'email': 'client@test.dev', 'name': 'Test Client'}),
      ),
      'GET /api/v1/client/notifications': (
        200,
        ok({
          'notifications': <Object>[],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 20,
            'total': 0,
            'unread_count': 0,
          },
        }),
      ),
      'GET /api/v1/client/notifications/unread-count': (
        200,
        ok({'unread_count': 0}),
      ),
      ...routes,
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
          ),
          sessionStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: http,
            ),
          ),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    return http;
  }

  testWidgets('Invoices tab lists server invoices with server stats', (
    tester,
  ) async {
    final http = await pumpApi(tester, {
      'GET /api/v1/client/invoices': (200, invoicesExample()),
    });
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('api-invoice-12')), findsOneWidget);
    expect(find.byKey(const Key('api-invoice-13')), findsOneWidget);
    expect(find.text(r'$1,000'), findsOneWidget);
    expect(find.text('Overdue 1'), findsOneWidget);
    // No demo record leaks into API mode.
    expect(find.text('#INV-2026-0234'), findsNothing);

    final call = http.requests.lastWhere(
      (r) => r.uri.path == '/api/v1/client/invoices',
    );
    expect(call.headers['X-Company'], '2');
    expect(call.headers['Authorization'], 'Bearer t');

    await tester.tap(find.byKey(const Key('invoice-filter-paid')));
    await tester.pumpAndSettle();
    // Cards also look up their project's name, so pick the list request.
    expect(
      http.requests
          .lastWhere((r) => r.uri.path == '/api/v1/client/invoices')
          .uri
          .queryParameters['status'],
      'paid',
      reason: 'status filtering is done by the server',
    );
  });

  testWidgets('a server error is shown with retry, never as data', (
    tester,
  ) async {
    await pumpApi(tester, {
      'GET /api/v1/client/invoices': (
        500,
        {'success': false, 'message': 'Server Error', 'errors': <Object>[]},
      ),
    });
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('api-error')), findsOneWidget);
    expect(find.byKey(const Key('api-retry')), findsOneWidget);
    expect(find.byKey(const Key('api-invoice-12')), findsNothing);
  });

  test('local collections refuse writes in API mode', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(invoicesProvider.notifier);
    final invoice = Invoice(
      id: 'x',
      reference: '#X',
      amount: 1,
      currency: 'USD',
      company: 'c',
      client: 'c',
      project: 'p',
      issueDate: DateTime(2026),
      dueDate: DateTime(2026),
      status: InvoiceStatus.paid,
    );
    expect(notifier.add(invoice), isFalse);
    expect(container.read(invoicesProvider), isEmpty);
    expect(container.read(demoModeProvider), isFalse);
  });
}
