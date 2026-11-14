import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/dashboard/data/client_dashboard_repository.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';

import '../helpers/fake_http_adapter.dart';

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 25;
  @override
  void onUnauthorized() {}
}

/// The collection's saved 200 example for `05 Client / 04 Invoices / List
/// Invoices` ("derived status, amounts, is_overdue and stats"), plus the
/// `totals` row the live server returns beside `data`.
Map<String, dynamic> invoicesExample() => {
  'success': true,
  'message': 'Invoices retrieved',
  'data': {
    'current_page': 1,
    'per_page': 15,
    'total': 2,
    'last_page': 1,
    'data': [
      {
        'id': 12,
        'company_id': 2,
        'client_id': 4,
        'project_id': 7,
        'currency_id': 1,
        'invoice_date': '2026-10-12',
        'due_date': '2026-10-01',
        'amount': '1000.00',
        'status': 'partially_paid',
        'paid_amount': 400,
        'remaining_amount': 600,
        'payment_status': 'partially_paid',
        'is_overdue': true,
      },
      {
        'id': 13,
        'company_id': 2,
        'client_id': 4,
        'project_id': 7,
        'currency_id': 1,
        'invoice_date': '2026-10-13',
        'due_date': '2026-12-01',
        'amount': '500.00',
        'status': 'paid',
        'paid_amount': 500,
        'remaining_amount': 0,
        'payment_status': 'paid',
        'is_overdue': false,
      },
    ],
    'stats': {
      'total': 2,
      'paid': 1,
      'unpaid': 0,
      'partially_paid': 1,
      'overdue': 1,
    },
  },
  'stats': {'total': 2, 'paid': 1, 'unpaid': 0, 'partially_paid': 1},
  'totals': [
    {
      'currency_id': 1,
      'code': 'USD',
      'symbol': r'$',
      'amount': 1500,
      'paid': 900,
      'remaining': 600,
      'overdue_amount': 600,
    },
  ],
};

void main() {
  late FakeHttpAdapter http;
  ApiClient client() => ApiClient(
    baseUrl: 'https://api.test',
    credentials: _Creds(),
    adapter: http,
  );

  setUp(() => http = FakeHttpAdapter());

  group('client invoices', () {
    const q = (
      filter: InvoiceFilter.partiallyPaid,
      sort: InvoiceSort.newest,
      search: ' INV ',
      from: null,
      to: null,
      projectId: null,
      page: 2,
    );

    test('parses the documented example and sends server filters', () async {
      http.reply(200, invoicesExample());
      final list = await ClientFinanceRepository(client()).invoices(q);

      expect(http.last.path, '/api/v1/client/invoices');
      expect(http.last.headers['X-Company'], '25');
      expect(http.last.queryParameters, {
        'page': 2,
        'per_page': 15,
        'status': 'partially_paid',
        'sort': '-invoice_date',
        'search': 'INV',
      });
      final first = list.page.items.first;
      expect(first.amount, 1000);
      expect(first.paidAmount, 400);
      expect(first.remainingAmount, 600);
      expect(first.status, ApiInvoiceStatus.partiallyPaid);
      expect(first.isOverdue, isTrue);
      expect(first.invoiceDate, DateTime(2026, 10, 12));
      expect(list.page.items.last.status, ApiInvoiceStatus.paid);
      expect(list.stats.overdue, 1);
      expect(list.currencies[1]?.symbol, r'$');
      expect(list.page.total, 2);
    });

    test('a bad filter value surfaces the 422, not an empty list', () async {
      http.reply(
        422,
        failure(
          'Validation Error',
          errors: {
            'status': ['The selected status is invalid.'],
          },
        ),
      );
      await expectLater(
        ClientFinanceRepository(client()).invoices(q),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.validation,
          ),
        ),
      );
    });

    test('an unknown status value is rejected as invalid response', () async {
      final body = invoicesExample();
      final rows = (body['data'] as Map<String, dynamic>)['data'] as List;
      (rows.first as Map<String, dynamic>)['status'] = 'refunded';
      http.reply(200, body);
      await expectLater(
        ClientFinanceRepository(client()).invoices(q),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('403 from another company is not turned into success', () async {
      http.reply(
        403,
        failure('You are not authorized to act in the requested company.'),
      );
      await expectLater(
        ClientFinanceRepository(client()).invoices(q),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.forbidden,
          ),
        ),
      );
    });
  });

  test('payments read stats.total, per-currency totals and rows', () async {
    // Shape seen live on GET /client/payments (empty account) plus one
    // documented totals row.
    http.reply(200, {
      'success': true,
      'message': 'Payments retrieved',
      'data': {
        'current_page': 1,
        'data': <Object>[],
        'last_page': 1,
        'per_page': 1,
        'total': 3,
      },
      'totals': [
        {
          'currency_id': 2,
          'code': 'ILS',
          'symbol': '₪',
          'received': 400,
          'pending': 50,
          'paid_out': 0,
        },
      ],
      'stats': {'total': 3, 'received': 400, 'pending': 50, 'paid_out': 0},
    });
    final s = await ClientFinanceRepository(client())
        .payments(defaultPaymentQuery);
    expect(http.last.path, '/api/v1/client/payments');
    expect(http.last.queryParameters, {'page': 1});
    expect(s.count, 3);
    expect(s.totals.single.code, 'ILS');
    expect(s.totals.single.received, 400);
  });

  group('projects', () {
    Map<String, dynamic> body(Map<String, dynamic> row) => {
      'success': true,
      'message': 'Projects retrieved',
      'data': {
        'current_page': 1,
        'data': [row],
        'last_page': 1,
        'per_page': 10,
        'total': 1,
      },
      'stats': {'total': 1, 'pending': 0, 'in_progress': 1, 'completed': 0},
      'totals': <Object>[],
      'facets': {
        'statuses': ['pending', 'in_progress', 'completed'],
        'clients': <Object>[],
      },
    };

    test('client rows carry budget and currency', () async {
      http.reply(
        200,
        body({
          'id': 7,
          'title': 'Portal',
          'status': 'in_progress',
          'budget': '2500.00',
          'currency': {
            'id': 1,
            'code': 'USD',
            'name': 'Dollar',
            'symbol': r'$',
          },
          'completion_percentage': 40,
        }),
      );
      final list = await ProjectsRepository(
        client(),
        Portal.client,
      ).list((search: '', status: ApiProjectStatus.inProgress, page: 1));
      expect(http.last.path, '/api/v1/client/projects');
      expect(http.last.queryParameters['status'], 'in_progress');
      final p = list.page.items.single;
      expect(p.title, 'Portal');
      expect(p.budget, 2500);
      expect(p.currencySymbol, r'$');
      expect(p.completion, 40);
      expect(list.stats.inProgress, 1);
    });

    test('employee rows have no budget and use the employee prefix', () async {
      http.reply(200, body({'id': 8, 'title': 'API', 'status': 'pending'}));
      final list = await ProjectsRepository(
        client(),
        Portal.employee,
      ).list((search: 'api', status: null, page: 1));
      expect(http.last.path, '/api/v1/employee/projects');
      expect(http.last.queryParameters['search'], 'api');
      expect(list.page.items.single.budget, isNull);
      expect(list.page.items.single.status, ApiProjectStatus.pending);
    });

    test('a row without a title is an invalid response', () async {
      http.reply(200, body({'id': 9, 'status': 'pending'}));
      await expectLater(
        ProjectsRepository(
          client(),
          Portal.client,
        ).list((search: '', status: null, page: 1)),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('client dashboard reads the three live counts', () async {
    http.reply(
      200,
      ok({'projectsCount': 4, 'projectsCompleted': 1, 'projectsInProgress': 2}),
    );
    final s = await ClientDashboardRepository(client()).summary();
    expect(http.last.path, '/api/v1/client/dashboard');
    expect((s.projects, s.completed, s.inProgress), (4, 1, 2));
  });

  test('unauthenticated envelope maps to unauthorized', () async {
    // Live: {"success":false,"message":"Unauthenticated.","errors":[]}
    http.reply(401, {
      'success': false,
      'message': 'Unauthenticated.',
      'errors': <Object>[],
    });
    await expectLater(
      ClientDashboardRepository(client()).summary(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.unauthorized,
        ),
      ),
    );
  });
}
