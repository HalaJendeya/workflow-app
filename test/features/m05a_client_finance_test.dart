import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';
import 'client_api_contract_test.dart' show invoicesExample;

/// M05a: client invoices and payments, read-only. Mocked HTTP only; the
/// live server was checked read-only and has no rows for the QA client.

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 25;
  @override
  void onUnauthorized() {}
}

Matcher _kind(ApiFailureKind k) =>
    throwsA(isA<ApiException>().having((e) => e.kind, 'kind', k));

Map<String, dynamic> _invoice(
  int id, {
  int project = 7,
  String status = 'unpaid',
  bool overdue = false,
}) => {
  'id': id,
  'company_id': 3,
  'client_id': 4,
  'project_id': project,
  'currency_id': 1,
  'invoice_date': '2026-10-12',
  'due_date': '2026-11-01',
  'amount': '1000.00',
  'status': status,
  'paid_amount': status == 'paid'
      ? 1000
      : (status == 'partially_paid' ? 400 : 0),
  'remaining_amount': status == 'paid'
      ? 0
      : (status == 'partially_paid' ? 600 : 1000),
  'payment_status': status,
  'is_overdue': overdue,
};

Map<String, dynamic> _invoiceList(
  List<Object> rows, {
  int page = 1,
  int last = 1,
  List<Object>? totals,
}) => {
  'success': true,
  'message': 'Invoices retrieved',
  'data': {
    'current_page': page,
    'per_page': 15,
    'total': last == 1 ? rows.length : 15 * (last - 1) + rows.length,
    'last_page': last,
    'data': rows,
    'stats': {
      'total': rows.length,
      'paid': 0,
      'unpaid': rows.length,
      'partially_paid': 0,
      'overdue': 0,
    },
  },
  'stats': {
    'total': rows.length,
    'paid': 0,
    'unpaid': rows.length,
    'partially_paid': 0,
    'overdue': 0,
  },
  'totals':
      totals ??
      [
        {
          'currency_id': 1,
          'code': 'USD',
          'symbol': r'$',
          'amount': 1000,
          'paid': 0,
          'remaining': 1000,
          'overdue_amount': 0,
        },
      ],
};

/// The saved example row of `PaymentController@index`, plus `direction`.
Map<String, dynamic> _payment(int id, {String direction = 'incoming'}) => {
  'id': id,
  'invoice_id': 12,
  'wallet_id': 2,
  'amount': '300.00',
  'payment_method': 'cash',
  'payment_date': '2026-08-01',
  'direction': direction,
};

Map<String, dynamic> _paymentList(
  List<Object> rows, {
  List<Object>? totals,
  Map<String, dynamic>? stats,
}) => {
  'success': true,
  'message': 'Payments list',
  'data': {
    'current_page': 1,
    'per_page': 15,
    'total': rows.length,
    'last_page': 1,
    'data': rows,
  },
  'stats':
      stats ??
      {'total': rows.length, 'received': 300, 'pending': 0, 'paid_out': 0},
  'totals':
      totals ??
      [
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

/// Company 3 has 105 projects: more than the old 100-project cut-off.
final List<(int, String)> _companyProjects = [
  for (var id = 1; id <= 105; id++)
    (
      id,
      switch (id) {
        7 => 'Customer Portal Revamp',
        8 => 'Billing',
        105 => 'Warehouse Migration',
        _ => 'Project $id',
      },
    ),
];

Map<String, dynamic> _projects(
  List<(int, String)> rows, {
  int page = 1,
  int perPage = 20,
}) => {
  'success': true,
  'message': 'OK',
  'data': {
    'current_page': page,
    'per_page': perPage,
    'total': rows.length,
    'last_page': rows.isEmpty ? 1 : (rows.length + perPage - 1) ~/ perPage,
    'data': [
      for (final (id, title) in rows.skip((page - 1) * perPage).take(perPage))
        {'id': id, 'title': title},
    ],
  },
  'stats': {
    'total': rows.length,
    'pending': 0,
    'in_progress': 0,
    'completed': 0,
  },
};

/// Answers per `X-Company`: company 3 and company 4 hold different data,
/// no header holds none. [gates] hold a path open; status overrides
/// simulate failures.
class _Server implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, Completer<void>> gates = {};
  final Map<String, int> fail = {};

  /// Replaces the normal answer for a path.
  final Map<String, Object> overrides = {};

  /// Holds the invoice list for one `project_id` open.
  final Map<int, Completer<void>> projectGates = {};

  (int, Object?) _reply(RequestOptions o) {
    final path = o.uri.path;
    if (fail[path] case final status?) {
      return (status, failure(status == 404 ? 'Invoice not found' : 'Error'));
    }
    if (overrides[path] case final body?) return (200, body);
    final company = o.headers['X-Company'];
    switch (path) {
      case '/api/v1/client/account':
        return (200, ok({'id': 1, 'email': 'x@test.dev'}));
      case '/api/v1/client/notifications':
        return (
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
        );
      case '/api/v1/client/notifications/unread-count':
        return (200, ok({'unread_count': 0}));
      case '/api/v1/client/projects':
        // Documented server-side `search` and `page`.
        final search = '${o.queryParameters['search'] ?? ''}'.toLowerCase();
        final rows = company == '3'
            ? [
                for (final r in _companyProjects)
                  if (r.$2.toLowerCase().contains(search)) r,
              ]
            : <(int, String)>[];
        return (
          200,
          _projects(
            rows,
            page: int.tryParse('${o.queryParameters['page']}') ?? 1,
            perPage: int.tryParse('${o.queryParameters['per_page']}') ?? 20,
          ),
        );
      case '/api/v1/client/invoices':
        if (company == '4') return (200, _invoiceList([_invoice(41)]));
        if (company != '3') return (200, _invoiceList(const []));
        if (asInt(o.queryParameters['project_id']) case final pid?) {
          return (200, _invoiceList([_invoice(500 + pid, project: pid)]));
        }
        final page = int.tryParse('${o.queryParameters['page']}') ?? 1;
        return (
          200,
          _invoiceList(
            page == 1
                ? [
                    _invoice(12, status: 'partially_paid', overdue: true),
                    _invoice(13, project: 8),
                  ]
                : [_invoice(20)],
            page: page,
            last: 2,
          ),
        );
      case final p when p.startsWith('/api/v1/client/projects/'):
        final id = int.parse(p.split('/').last);
        final match = company == '3'
            ? _companyProjects.where((r) => r.$1 == id)
            : const <(int, String)>[];
        return match.isEmpty
            ? (404, failure('Project not found'))
            : (
                200,
                ok({
                  'id': id,
                  'title': match.first.$2,
                  'status': 'in_progress',
                }),
              );
      case '/api/v1/client/invoices/12':
        return (
          200,
          ok({..._invoice(12, status: 'paid'), 'amount': '1000.00'}),
        );
      case '/api/v1/client/payments':
        if (company == '4') return (200, _paymentList([_payment(91)]));
        if (company != '3') return (200, _paymentList(const [], totals: []));
        return (
          200,
          _paymentList([_payment(31), _payment(32, direction: 'outgoing')]),
        );
    }
    return (404, failure('Not found'));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    await gates[o.uri.path]?.future;
    if (o.uri.path == '/api/v1/client/invoices') {
      await projectGates[asInt(o.queryParameters['project_id'])]?.future;
    }
    final (status, body) = _reply(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  RequestOptions last(String path) =>
      requests.lastWhere((r) => r.uri.path == path);
}

/// After logout, signs in [next].
class _Auth implements AuthRepository {
  Session next = const Session(
    token: 'tkn-a',
    tokenType: 'Bearer',
    userId: 1,
    companyId: 4,
    portal: Portal.client,
  );

  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => next;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(_Server, _Auth)> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  useViewport(tester, size);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 'tkn-a',
      tokenType: 'Bearer',
      userId: 1,
      companyId: 3,
      portal: Portal.client,
    ).toStorage(),
  );
  final server = _Server();
  final auth = _Auth();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'https://api.test',
            credentials: ref.watch(sessionCredentialsProvider),
            adapter: server,
          ),
        ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return (server, auth);
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(scroll, Offset(0, h - 130 - r.bottom));
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await _reveal(tester, target);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _pick(WidgetTester tester, Key chip, String option) async {
  await _tap(tester, find.byKey(chip));
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('option-sheet')),
      matching: find.text(option),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _invoicesTab(WidgetTester tester) async {
  await tester.tap(find.text('Invoices').last);
  await tester.pumpAndSettle();
}

Future<void> _payments(WidgetTester tester) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(const Key('category-Payments')));
}

Finder _view(String card) => find.descendant(
  of: find.byKey(Key(card)),
  matching: find.text('View Details'),
);

void main() {
  group('invoice contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late ClientFinanceRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = ClientFinanceRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
      );
    });

    test('valid financial values from the documented example', () async {
      http.reply(200, invoicesExample());
      final list = await repo.invoices(defaultInvoiceQuery);
      final paid = list.page.items.last;
      expect(paid.amount, 500);
      expect(paid.paidAmount, 500);
      expect(paid.remainingAmount, 0);
      expect(paid.isOverdue, isFalse);
    });

    test('sends sort, project and date filters as documented', () async {
      http.reply(200, invoicesExample());
      await repo.invoices((
        filter: InvoiceFilter.overdue,
        sort: InvoiceSort.highestAmount,
        search: '',
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
        projectId: 7,
        page: 3,
      ));
      expect(http.last.queryParameters, {
        'page': 3,
        'per_page': 15,
        'status': 'overdue',
        'sort': '-amount',
        'from': '2026-10-01',
        'to': '2026-10-31',
        'project_id': 7,
      });
    });

    for (final field in ['paid_amount', 'remaining_amount', 'is_overdue']) {
      test('a missing `$field` is invalid, never a made-up value', () async {
        final body = invoicesExample();
        final rows = (body['data'] as Map<String, dynamic>)['data'] as List;
        (rows.first as Map<String, dynamic>).remove(field);
        http.reply(200, body);
        await expectLater(
          repo.invoices(defaultInvoiceQuery),
          _kind(ApiFailureKind.invalidResponse),
        );
      });
    }

    test('`is_overdue` must be a boolean', () async {
      final body = invoicesExample();
      final rows = (body['data'] as Map<String, dynamic>)['data'] as List;
      (rows.first as Map<String, dynamic>)['is_overdue'] = 'yes';
      http.reply(200, body);
      await expectLater(
        repo.invoices(defaultInvoiceQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('missing stats or a missing count is invalid, not 0', () async {
      final body = invoicesExample();
      (body['data'] as Map<String, dynamic>).remove('stats');
      body.remove('stats');
      http.reply(200, body);
      await expectLater(
        repo.invoices(defaultInvoiceQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
      final partial = invoicesExample();
      ((partial['data'] as Map<String, dynamic>)['stats'] as Map).remove(
        'overdue',
      );
      http.reply(200, partial);
      await expectLater(
        repo.invoices(defaultInvoiceQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('totals are required and every row names its currency', () async {
      final body = invoicesExample()..remove('totals');
      http.reply(200, body);
      await expectLater(
        repo.invoices(defaultInvoiceQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
      final noCode = invoicesExample();
      ((noCode['totals'] as List).first as Map).remove('code');
      http.reply(200, noCode);
      await expectLater(
        repo.invoices(defaultInvoiceQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('invoice details: GET /client/invoices/{id}', () async {
      http.reply(200, ok(_invoice(12, status: 'paid')));
      final i = await repo.invoice(12);
      expect(http.last.path, '/api/v1/client/invoices/12');
      expect(http.last.headers['X-Company'], '25');
      expect(i.status, ApiInvoiceStatus.paid);
      expect(i.remainingAmount, 0);
    });

    test('invoice details: 404, 403, 401 and 5xx are typed', () async {
      for (final (status, kind) in [
        (404, ApiFailureKind.notFound),
        (403, ApiFailureKind.forbidden),
        (401, ApiFailureKind.unauthorized),
        (503, ApiFailureKind.server),
      ]) {
        http.reply(status, failure('x'));
        await expectLater(repo.invoice(12), _kind(kind));
      }
    });

    test('project search: one small page at a time, server-side', () async {
      http.reply(200, _projects(_companyProjects, page: 6));
      final page = await repo.searchProjects((search: ' ware ', page: 6));
      expect(http.last.path, '/api/v1/client/projects');
      expect(http.last.queryParameters, {
        'page': 6,
        'per_page': 20,
        'search': 'ware',
      });
      // Page 6 of 105 holds the projects past the old 100 cut-off.
      expect(page.items.map((p) => p.id), [101, 102, 103, 104, 105]);
      expect(page.hasMore, isFalse);
    });

    test('a project row without a title is invalid', () async {
      http.reply(200, {
        ..._projects(const []),
        'data': {
          'current_page': 1,
          'per_page': 20,
          'total': 1,
          'last_page': 1,
          'data': [
            {'id': 7},
          ],
        },
      });
      await expectLater(
        repo.searchProjects((search: '', page: 1)),
        _kind(ApiFailureKind.invalidResponse),
      );
    });
  });

  group('payment contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late ClientFinanceRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = ClientFinanceRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
      );
    });

    test('rows use the documented example fields', () async {
      http.reply(200, _paymentList([_payment(31)]));
      final list = await repo.payments(defaultPaymentQuery);
      final p = list.page.items.single;
      expect(p.id, 31);
      expect(p.amount, 300);
      expect(p.date, DateTime(2026, 8));
      expect(p.invoiceId, 12);
      expect(p.method, 'cash');
      expect(p.direction, ApiPaymentDirection.incoming);
      expect(list.count, 1);
      expect(list.onlyCurrency?.code, 'USD');
    });

    test('sends status, search and date filters', () async {
      http.reply(200, _paymentList(const []));
      await repo.payments((
        status: PaymentStatusFilter.pending,
        search: ' cash ',
        from: DateTime(2026, 8),
        page: 2,
      ));
      expect(http.last.path, '/api/v1/client/payments');
      expect(http.last.queryParameters, {
        'page': 2,
        'status': 'pending',
        'search': 'cash',
        'from': '2026-08-01',
      });
    });

    test('several currencies: no currency is assumed for rows', () async {
      http.reply(
        200,
        _paymentList(
          [_payment(31)],
          totals: [
            {
              'currency_id': 1,
              'code': 'USD',
              'symbol': r'$',
              'received': 1,
              'pending': 0,
            },
            {
              'currency_id': 2,
              'code': 'ILS',
              'symbol': '₪',
              'received': 1,
              'pending': 0,
            },
          ],
        ),
      );
      expect((await repo.payments(defaultPaymentQuery)).onlyCurrency, isNull);
    });

    test('summary validation: missing count, totals or amounts', () async {
      http.reply(200, _paymentList(const [], stats: {'received': 1}));
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(
        200,
        _paymentList(
          const [],
          totals: [
            {'currency_id': 1, 'code': 'USD', 'pending': 0},
          ],
        ),
      );
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(200, _paymentList(const [])..remove('totals'));
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('a row without amount or date is invalid', () async {
      http.reply(200, _paymentList([_payment(31)..remove('amount')]));
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(200, _paymentList([_payment(31)..remove('payment_date')]));
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('a bad status value surfaces the 422', () async {
      http.reply(422, failure('The selected status is invalid.'));
      await expectLater(
        repo.payments(defaultPaymentQuery),
        _kind(ApiFailureKind.validation),
      );
    });
  });

  group('Invoices screen', () {
    testWidgets('project names, filters, sort and paging reach the server', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _invoicesTab(tester);
      // Project names come from the client's projects.
      expect(find.text('Customer Portal Revamp'), findsWidgets);
      expect(find.text('Billing'), findsWidgets);

      // Page 2, then a filter: back to page 1.
      await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(server.last('/api/v1/client/invoices').queryParameters['page'], 2);
      await _tap(tester, find.byKey(const Key('invoice-filter-overdue')));
      var q = server.last('/api/v1/client/invoices').queryParameters;
      expect(q['status'], 'overdue');
      expect(q['page'], 1);

      await _pick(tester, const Key('invoice-sort'), 'Due date');
      q = server.last('/api/v1/client/invoices').queryParameters;
      expect(q['sort'], 'due_date');
      expect(q['page'], 1);

      await _tap(tester, find.byKey(const Key('invoice-project')));
      await tester.tap(find.byKey(const Key('project-option-8')));
      await tester.pumpAndSettle();
      q = server.last('/api/v1/client/invoices').queryParameters;
      expect(q['project_id'], 8);
      expect(q['page'], 1);
    });

    testWidgets('a project past the first 100 can be found and selected', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _invoicesTab(tester);
      await _tap(tester, find.byKey(const Key('invoice-project')));
      // Page 1 only: no project list is downloaded up front.
      expect(
        server.requests.where(
          (r) =>
              r.uri.path == '/api/v1/client/projects' &&
              r.queryParameters['per_page'] == 20,
        ),
        hasLength(1),
      );
      expect(find.byKey(const Key('project-option-21')), findsNothing);
      // Load more until project 105 (page 6 of 20 per page).
      final more = find.byKey(const Key('project-picker-more'));
      for (var i = 0; i < 6 && more.evaluate().isNotEmpty; i++) {
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      expect(more, findsNothing);
      final last = find.byKey(const Key('project-option-105'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      final q = server.last('/api/v1/client/invoices').queryParameters;
      expect(q['project_id'], 105);
      expect(q['page'], 1);
      expect(find.text('Warehouse Migration ⌄'), findsOneWidget);
      expect(find.byKey(const Key('api-invoice-605')), findsOneWidget);

      // Back to all projects.
      await _tap(tester, find.byKey(const Key('invoice-project')));
      await tester.tap(find.byKey(const Key('project-option-all')));
      await tester.pumpAndSettle();
      expect(
        server
            .last('/api/v1/client/invoices')
            .queryParameters
            .containsKey('project_id'),
        isFalse,
      );
    });

    testWidgets('picker search is sent to the server', (tester) async {
      final (server, _) = await _pump(tester);
      await _invoicesTab(tester);
      await _tap(tester, find.byKey(const Key('invoice-project')));
      await tester.enterText(
        find.byKey(const Key('project-picker-search')),
        'warehouse',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        server.last('/api/v1/client/projects').queryParameters['search'],
        'warehouse',
      );
      expect(find.byKey(const Key('project-option-105')), findsOneWidget);
      expect(find.byKey(const Key('project-option-7')), findsNothing);
    });

    testWidgets('rapid project changes never show a superseded result', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _invoicesTab(tester);
      // Project 7's answer is slow; project 8 is chosen before it arrives.
      server.projectGates[7] = Completer<void>();
      await _tap(tester, find.byKey(const Key('invoice-project')));
      await tester.tap(find.byKey(const Key('project-option-7')));
      // Project 7's spinner never settles while its answer is held.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The chip is still on screen: tap it without settling.
      await tester.tap(find.byKey(const Key('invoice-project')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const Key('project-option-8')));
      await tester.pumpAndSettle();
      server.projectGates[7]!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-invoice-508')), findsOneWidget);
      expect(find.byKey(const Key('api-invoice-507')), findsNothing);
    });

    testWidgets('details load from the server; 404 shows Retry', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _invoicesTab(tester);
      server.gates['/api/v1/client/invoices/12'] = Completer<void>();
      await _tap(tester, _view('api-invoice-12'), settle: false);
      expect(find.byKey(const Key('invoice-details-loading')), findsOneWidget);
      server.gates['/api/v1/client/invoices/12']!.complete();
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('invoice-details'));
      // The server now reports the invoice as paid in full.
      expect(
        find.descendant(of: sheet, matching: find.text('Paid')),
        findsWidgets,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(r'$0')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      server.fail['/api/v1/client/invoices/12'] = 404;
      await _tap(tester, _view('api-invoice-12'));
      expect(find.byKey(const Key('api-error')), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Remaining')),
        findsNothing,
      );
      server.fail.remove('/api/v1/client/invoices/12');
      await tester.tap(find.byKey(const Key('api-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-error')), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.text('Remaining')),
        findsOneWidget,
      );
    });

    testWidgets('list failure shows Retry, which recovers', (tester) async {
      final (server, _) = await _pump(tester, size: const Size(320, 640));
      server.fail['/api/v1/client/invoices'] = 500;
      await _invoicesTab(tester);
      await _reveal(tester, find.byKey(const Key('api-error')));
      expect(find.byKey(const Key('api-invoice-12')), findsNothing);
      server.fail.remove('/api/v1/client/invoices');
      await _tap(tester, find.byKey(const Key('api-retry')));
      await _reveal(tester, find.byKey(const Key('api-invoice-12')));
      expect(find.byKey(const Key('api-error')), findsNothing);
    });
  });

  group('Payments screen', () {
    testWidgets('the payment view is a labelled summary of the row', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _payments(tester);
      await _tap(tester, _view('api-payment-31'));
      final sheet = find.byKey(const Key('payment-summary'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Payment summary · #31'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining("doesn't document a payment's full"),
        ),
        findsOneWidget,
      );
      // No undocumented details request is made.
      expect(
        server.requests.where(
          (r) => r.uri.path.startsWith('/api/v1/client/payments/'),
        ),
        isEmpty,
      );
    });

    testWidgets('an incomplete payment row shows an error, no rows', (
      tester,
    ) async {
      final (server, _) = await _pump(tester, size: const Size(320, 640));
      server.overrides['/api/v1/client/payments'] = _paymentList([
        _payment(31),
        _payment(33)..remove('amount'),
      ]);
      await _payments(tester);
      await _reveal(tester, find.byKey(const Key('api-error')));
      expect(find.byKey(const Key('api-payment-31')), findsNothing);
    });

    testWidgets('rows, single currency and server-side status filter', (
      tester,
    ) async {
      final (server, _) = await _pump(tester);
      await _payments(tester);
      await _reveal(tester, find.byKey(const Key('api-payment-32')));
      expect(find.text(r'$300'), findsWidgets);
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.text('Outgoing'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('payment-status-pending')));
      expect(
        server.last('/api/v1/client/payments').queryParameters['status'],
        'pending',
      );
      // One request feeds metrics and rows.
      expect(
        server.requests.where((r) => r.uri.path == '/api/v1/client/payments'),
        hasLength(2),
      );
    });

    testWidgets('metrics read "—" until the server answers', (tester) async {
      final (server, _) = await _pump(tester);
      server.gates['/api/v1/client/payments'] = Completer<void>();
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(const Key('category-Payments')),
        settle: false,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('api-payments-count')),
          matching: find.text('—'),
        ),
        findsWidgets,
      );
      expect(find.text('0'), findsNothing);
      server.gates['/api/v1/client/payments']!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('error then Retry', (tester) async {
      final (server, _) = await _pump(tester, size: const Size(320, 640));
      server.fail['/api/v1/client/payments'] = 503;
      await _payments(tester);
      await _reveal(tester, find.byKey(const Key('api-error')));
      server.fail.remove('/api/v1/client/payments');
      await _tap(tester, find.byKey(const Key('api-retry')));
      await _reveal(tester, find.byKey(const Key('api-payment-31')));
      expect(find.byKey(const Key('api-error')), findsNothing);
    });
  });

  for (final (label, next) in [
    (
      'same user, another company',
      const Session(
        token: 'tkn-a',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 4,
        portal: Portal.client,
      ),
    ),
    (
      'another account without a company',
      const Session(
        token: 'tkn-b',
        tokenType: 'Bearer',
        userId: 2,
        portal: Portal.client,
      ),
    ),
  ]) {
    testWidgets('isolation: $label never sees company 3 finance', (
      tester,
    ) async {
      final (server, auth) = await _pump(tester);
      auth.next = next;
      await _invoicesTab(tester);
      expect(find.byKey(const Key('api-invoice-12')), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkFlowApp)),
      );
      await container.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      final before = server.requests.length;
      await container
          .read(sessionControllerProvider.notifier)
          .login(email: 'x@test.dev', password: 'x', portal: Portal.client);
      await tester.pumpAndSettle();
      await _invoicesTab(tester);
      await _payments(tester);

      expect(find.byKey(const Key('api-payment-31')), findsNothing);
      expect(find.byKey(const Key('api-invoice-12')), findsNothing);
      final after = server.requests.skip(before).toList();
      expect(after, isNotEmpty);
      for (final r in after) {
        expect(r.headers['Authorization'], 'Bearer ${next.token}');
        expect(r.headers['X-Company'], next.companyId?.toString());
      }
      if (next.companyId == 4) {
        expect(find.byKey(const Key('api-payment-91')), findsOneWidget);
      }
      // The project picker under the new context offers none of company 3's
      // projects.
      await _invoicesTab(tester);
      await _tap(tester, find.byKey(const Key('invoice-project')));
      expect(find.byKey(const Key('project-option-7')), findsNothing);
      expect(
        server.last('/api/v1/client/projects').headers['X-Company'],
        next.companyId?.toString(),
      );
    });
  }
}
