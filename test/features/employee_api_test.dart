import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

/// Live shape of GET /employee/dashboard (values are fixtures).
Map<String, dynamic> dashboard() => ok({
  'myTasks': 5,
  'myHours': 36,
  'myMinutes': 30,
  'totalEarned': 1200,
  'paidSalary': 800,
  'unpaidSalary': 400,
});

Map<String, dynamic> list(Map<String, dynamic> extra) => {
  'success': true,
  'message': 'ok',
  'data': {
    'current_page': 1,
    'data': <Object>[],
    'last_page': 1,
    'per_page': 1,
    'total': 0,
  },
  ...extra,
};

/// Live shape of GET /employee/tasks `stats`.
Map<String, dynamic> tasks() => list({
  'stats': {
    'total': 6,
    'by_status': {
      'backlog': 1,
      'todo': 2,
      'pending': 0,
      'in_progress': 2,
      'in_review': 0,
      'completed': 1,
    },
    'active': 5,
    'logged_minutes': 150,
  },
  'totals': <Object>[],
});

void main() {
  late FakeHttpAdapter http;
  EmployeeWorkRepository repo() => EmployeeWorkRepository(
    ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    ),
  );
  setUp(() => http = FakeHttpAdapter());

  test('dashboard combines hours and minutes', () async {
    http.reply(200, dashboard());
    final s = await repo().dashboard();
    expect(http.last.path, '/api/v1/employee/dashboard');
    expect(s.tasks, 5);
    expect(s.loggedMinutes, 36 * 60 + 30);
    expect(s.unpaid, 400);
  });

  test('dashboard without a documented key is invalid, not zero', () async {
    http.reply(200, ok({'myTasks': 5}));
    await expectLater(
      repo().dashboard(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('task stats keep every server status key', () async {
    http.reply(200, tasks());
    final s = await repo().taskStats();
    expect(http.last.queryParameters, {'per_page': 1, 'month': 'all'});
    expect(s.active, 5);
    expect(s.loggedMinutes, 150);
    expect(s.byStatus.keys, containsAll(['pending', 'in_review']));
  });

  test('timesheet summary reads stats and per-currency totals', () async {
    http.reply(
      200,
      list({
        'stats': {
          'count': 3,
          'approved': 1,
          'pending': 1,
          'rejected': 1,
          'total_minutes': 600,
        },
        'totals': [
          {
            'currency_id': 1,
            'code': 'USD',
            'symbol': r'$',
            'total': 900,
            'approved': 300,
            'pending': 600,
          },
        ],
        'available_months': <Object>[],
        'facets': {'employees': <Object>[]},
      }),
    );
    final s = await repo().timesheets();
    expect(s.totalMinutes, 600);
    expect(s.money.single.approved, 300);
  });

  testWidgets('API-mode employee dashboard shows server figures', (
    tester,
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
        userId: 7,
        companyId: 3,
        portal: Portal.employee,
      ).toStorage(),
    );
    final adapter = RouteHttpAdapter({
      'GET /api/v1/employee/account': (
        200,
        ok({'id': 7, 'email': 'me@test.dev', 'name': 'Me'}),
      ),
      'GET /api/v1/employee/dashboard': (200, dashboard()),
      'GET /api/v1/employee/tasks': (200, tasks()),
      'GET /api/v1/employee/projects': (
        200,
        list({
          'stats': {'total': 0, 'pending': 0, 'in_progress': 0, 'completed': 0},
        }),
      ),
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
              adapter: adapter,
            ),
          ),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Dashboard')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('emp-dash-tasks')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    expect(find.text('36.5'), findsOneWidget);
    // Demo-only sections are not drawn with sample data.
    expect(find.text('Working Hours & Trend'), findsNothing);
  });
}
