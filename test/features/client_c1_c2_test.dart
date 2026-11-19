import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/finance/presentation/payments_screen.dart';
import 'package:workflow_app/features/overview/presentation/overview_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import 'client_api_contract_test.dart' show invoicesExample;

/// Client C1 + C2: the client home without the employee-only Tasks card,
/// and the documented invoice and payment CSV exports
/// (`GET /client/{invoices|payments}/export`, collection "Added
/// 2026-10-26"). Every response is a test double shaped like the
/// collection; nothing here was read from the live server.

const _bom = [0xEF, 0xBB, 0xBF];

/// A server-style export: BOM, the documented header, one Arabic row
/// whose first field carries a comma, a quote and a line break.
Uint8List _csv(String header, {bool rows = true}) => Uint8List.fromList([
  ..._bom,
  ...utf8.encode(
    '$header\r\n'
    '${rows ? '"INV-1, ""a""\nb",شركة البوابة,9.5\r\n' : ''}',
  ),
]);

final String _invoiceHeader = const [
  'Invoice',
  'Client',
  'Project',
  'Date',
  'Due date',
  'Amount',
  'Currency',
  'Paid',
  'Remaining',
  'Status',
].join(',');
const _paymentHeader = 'Invoice,Date,Method,Wallet,Amount,Currency,Status';

RawReply _file(Uint8List bytes, String name) => RawReply(bytes, {
  Headers.contentTypeHeader: 'text/csv; charset=UTF-8',
  'content-disposition': 'attachment; filename="$name"',
});

Map<String, dynamic> _payments() => {
  'success': true,
  'message': 'Payments list',
  'data': {
    'current_page': 1,
    'per_page': 15,
    'total': 1,
    'last_page': 1,
    'data': [
      {
        'id': 31,
        'invoice_id': 5,
        'amount': '300.00',
        'payment_method': 'cash',
        'payment_date': '2026-08-01',
        'direction': 'incoming',
      },
    ],
  },
  'stats': {'total': 1, 'received': 300, 'pending': 0, 'paid_out': 0},
  'totals': [
    {
      'currency_id': 1,
      'code': 'USD',
      'symbol': r'$',
      'received': 300,
      'pending': 0,
      'paid_out': 0,
    },
  ],
};

Map<String, (int, Object?)> _base(Portal portal) => {
  'GET /api/v1/${portal.name}/account': (
    200,
    ok({'id': 1, 'email': 'qa@test.dev', 'name': 'QA'}),
  ),
  'GET /api/v1/${portal.name}/notifications': (
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
  'GET /api/v1/${portal.name}/notifications/unread-count': (
    200,
    ok({'unread_count': 0}),
  ),
  'GET /api/v1/employee/tasks': (
    200,
    ok({
      'current_page': 1,
      'per_page': 5,
      'total': 0,
      'last_page': 1,
      'data': <Object>[],
    }),
  ),
  'GET /api/v1/client/invoices': (200, invoicesExample()),
  'GET /api/v1/client/payments': (200, _payments()),
};

/// What the save dialog was given; `cancel` makes it answer "cancelled".
class _Saver {
  final saved = <CsvFile>[];
  bool cancel = false;

  Future<bool> call(CsvFile f) async {
    if (cancel) return false;
    saved.add(f);
    return true;
  }
}

void main() {
  late RouteHttpAdapter http;
  late _Saver saver;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Portal portal = Portal.client,
    AppMode mode = AppMode.api,
    int? companyId = 2,
    Map<String, (int, Object?)> routes = const {},
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 1,
        companyId: companyId,
        portal: portal,
      ).toStorage(),
    );
    http = RouteHttpAdapter({..._base(portal), ...routes});
    saver = _Saver();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'https://api.test',
            credentials: ref.watch(sessionCredentialsProvider),
            adapter: http,
          ),
        ),
        csvSaverProvider.overrideWithValue(saver.call),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RequestOptions last(String path) =>
      http.requests.lastWhere((r) => r.uri.path == path);

  group('C1 client home', () {
    testWidgets('API mode: no employee Tasks card, notifications kept', (
      tester,
    ) async {
      await pump(tester, const OverviewScreen());
      expect(find.byKey(const Key('home-tasks-card')), findsNothing);
      expect(find.text('Add a personal micro-task'), findsNothing);
      expect(find.text('This feature is not available yet.'), findsNothing);
      // The rest of the home stays: greeting masthead and notifications.
      expect(find.textContaining('Welcome back'), findsOneWidget);
      expect(find.text('Notifications'), findsWidgets);
      // A client never asks for employee tasks.
      expect(
        http.requests.where((r) => r.uri.path.startsWith('/api/v1/employee')),
        isEmpty,
      );
    });

    testWidgets('employee API home keeps its Tasks card', (tester) async {
      await pump(tester, const OverviewScreen(), portal: Portal.employee);
      expect(find.byKey(const Key('home-tasks-card')), findsOneWidget);
    });

    testWidgets('demo mode keeps the Figma Tasks card for clients', (
      tester,
    ) async {
      await pump(tester, const OverviewScreen(), mode: AppMode.mock);
      expect(find.byKey(const Key('home-tasks-card')), findsOneWidget);
    });
  });

  group('C2 invoice export', () {
    const route = 'GET /api/v1/client/invoices/export';

    testWidgets('sends the list filters and sort, no paging, and saves the '
        'file byte for byte', (tester) async {
      final bytes = _csv(_invoiceHeader);
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {route: (200, _file(bytes, 'invoices-2026-11-19.csv'))},
      );
      expect(find.text('Export Report'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invoice-filter-overdue')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invoices-search')),
        '  acme ',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();

      final call = last('/api/v1/client/invoices/export');
      expect(call.method, 'GET');
      expect(call.uri.queryParameters, {
        'status': 'overdue',
        'sort': '-invoice_date',
        'search': 'acme',
      });
      expect(call.headers['X-Company'], '2');
      expect(call.headers['Accept'], 'text/csv');
      expect(saver.saved.single.fileName, 'invoices-2026-11-19.csv');
      expect(saver.saved.single.bytes, bytes, reason: 'BOM and UTF-8 intact');
      expect(
        utf8.decode(saver.saved.single.bytes.sublist(3)),
        contains('شركة البوابة'),
      );
      expect(find.text('Saved invoices-2026-11-19.csv.'), findsOneWidget);
    });

    testWidgets('sort and date range reach the export', (tester) async {
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {route: (200, _file(_csv(_invoiceHeader), 'i.csv'))},
      );
      await tester.tap(find.byKey(const Key('invoice-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highest amount').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      final q = last('/api/v1/client/invoices/export').uri.queryParameters;
      expect(q['sort'], '-amount');
      expect(q.containsKey('page'), isFalse);
      expect(q.containsKey('per_page'), isFalse);
    });

    testWidgets('no company known: X-Company is omitted', (tester) async {
      await pump(
        tester,
        const InvoicesScreen(),
        companyId: null,
        routes: {route: (200, _file(_csv(_invoiceHeader), 'i.csv'))},
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      final call = last('/api/v1/client/invoices/export');
      expect(call.headers.containsKey('X-Company'), isFalse);
      expect(call.headers['Authorization'], 'Bearer t');
    });

    testWidgets('an empty export (header only) is still saved', (tester) async {
      final bytes = _csv(_invoiceHeader, rows: false);
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {route: (200, _file(bytes, 'invoices.csv'))},
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saver.saved.single.bytes, bytes);
    });

    testWidgets('422 too many rows: says how to fix it, saves nothing', (
      tester,
    ) async {
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {
          route: (
            422,
            {
              'success': false,
              'message':
                  'Too many rows to export. Narrow the filter '
                  '(maximum 10000).',
              'errors': <String, Object>{},
            },
          ),
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saver.saved, isEmpty);
      expect(
        find.text(
          "Couldn't export: too many rows. Narrow the filters to 10,000 "
          'rows or fewer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a JSON 200 is never saved as a CSV', (tester) async {
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {
          route: (200, ok({'id': 1})),
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saver.saved, isEmpty);
      expect(find.textContaining("Couldn't export:"), findsOneWidget);
    });

    testWidgets('cancelling the save dialog says nothing was saved', (
      tester,
    ) async {
      await pump(
        tester,
        const InvoicesScreen(),
        routes: {route: (200, _file(_csv(_invoiceHeader), 'i.csv'))},
      );
      saver.cancel = true;
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved'), findsNothing);
      expect(find.textContaining("Couldn't export"), findsNothing);
    });

    testWidgets('Arabic: the chip is translated and RTL builds', (
      tester,
    ) async {
      await pump(
        tester,
        const InvoicesScreen(),
        locale: const Locale('ar'),
        routes: {route: (200, _file(_csv(_invoiceHeader), 'i.csv'))},
      );
      expect(find.text('تصدير التقرير'), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saver.saved, hasLength(1));
    });
  });

  group('C2 payment export', () {
    const route = 'GET /api/v1/client/payments/export';

    testWidgets('sends the payment filters without paging and saves', (
      tester,
    ) async {
      final bytes = _csv(_paymentHeader);
      await pump(
        tester,
        const PaymentsScreen(),
        routes: {route: (200, _file(bytes, 'payments.csv'))},
      );
      expect(find.byKey(const Key('payments-export')), findsOneWidget);
      expect(find.text('Export Report'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('payments-search')), 'cash');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();

      final call = last('/api/v1/client/payments/export');
      expect(call.uri.queryParameters, {'search': 'cash'});
      expect(call.headers['X-Company'], '2');
      expect(saver.saved.single.bytes, bytes);
      expect(find.text('Saved payments.csv.'), findsOneWidget);
    });

    testWidgets('403: a permission message, not the too-many-rows one', (
      tester,
    ) async {
      await pump(
        tester,
        const PaymentsScreen(),
        routes: {
          route: (
            403,
            {'success': false, 'message': 'Forbidden', 'errors': <Object>[]},
          ),
        },
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saver.saved, isEmpty);
      expect(find.textContaining("Couldn't export:"), findsOneWidget);
      expect(find.textContaining('too many rows'), findsNothing);
    });
  });

  group('repository: exact documented query', () {
    test('invoices: every filter, wire names, no paging', () async {
      final adapter = RouteHttpAdapter({
        'GET /api/v1/client/invoices/export': (
          200,
          _file(_csv(_invoiceHeader), 'x.csv'),
        ),
      });
      final repo = ClientFinanceRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: const _Creds(),
          adapter: adapter,
        ),
      );
      await repo.invoicesCsv((
        filter: InvoiceFilter.partiallyPaid,
        sort: InvoiceSort.dueSoonest,
        search: ' q ',
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
        projectId: 7,
        page: 4,
      ));
      expect(adapter.requests.single.uri.queryParameters, {
        'status': 'partially_paid',
        'sort': 'due_date',
        'search': 'q',
        'from': '2026-10-01',
        'to': '2026-10-31',
        'project_id': '7',
      });
      expect(adapter.requests.single.headers['X-Company'], '5');
    });

    test('payments: status, search, from; "all" sends no status', () async {
      final adapter = RouteHttpAdapter({
        'GET /api/v1/client/payments/export': (
          200,
          _file(_csv(_paymentHeader), 'x.csv'),
        ),
      });
      final repo = ClientFinanceRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: const _Creds(),
          adapter: adapter,
        ),
      );
      await repo.paymentsCsv((
        status: PaymentStatusFilter.pending,
        search: 'stripe',
        from: DateTime(2026, 11),
        page: 3,
      ));
      await repo.paymentsCsv(defaultPaymentQuery);
      expect(adapter.requests.first.uri.queryParameters, {
        'status': 'pending',
        'search': 'stripe',
        'from': '2026-11-01',
      });
      expect(adapter.requests.last.uri.queryParameters, isEmpty);
    });
  });
}

class _Creds implements ApiCredentials {
  const new();
  @override
  String? get token => 't';
  @override
  int? get companyId => 5;
  @override
  void onUnauthorized() {}
}
