import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_exports.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_task_form.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';

/// Remaining Employee features against the WorkFlow collection
/// (rev. 2026-11-14T11:14:33Z). Shapes marked "live" were read with
/// read-only GETs on 2026-11-18; every value here is a test double.

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

Uint8List _csv(String text) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);

RawReply csvReply(String name, String text) => RawReply(_csv(text), {
  'content-type': 'text/csv; charset=UTF-8',
  'content-disposition': 'attachment; filename="$name"',
});

/// A timesheet row as the live server answered it.
Map<String, dynamic> timesheetJson(int id, {String status = 'pending'}) => {
  'id': id,
  'date': '2026-11-01',
  'month': '2026-11',
  'user': {'id': 10, 'name': 'Me', 'image': null},
  'company': {'id': 3, 'name': 'Acme'},
  'payment_type': 'monthly',
  'rate': 2500,
  'hours_minutes': 9600,
  'total': 2500,
  'currency': {'code': 'USD', 'symbol': r'$'},
  'status': status,
  'can': {'approve': false, 'reject': false},
};

Map<String, dynamic> timesheetList(List<Object> rows, {int lastPage = 1}) => {
  'success': true,
  'message': 'OK',
  'data': {
    'current_page': 1,
    'data': rows,
    'last_page': lastPage,
    'per_page': 10,
    'total': rows.length,
  },
  'stats': {
    'count': rows.length,
    'approved': 0,
    'pending': rows.length,
    'rejected': 0,
    'total_minutes': 9600,
  },
  'totals': [
    {
      'currency_id': 1,
      'code': 'USD',
      'symbol': r'$',
      'total': 2500,
      'approved': 0,
      'pending': 2500,
    },
  ],
  'available_months': ['2026-11', '2026-10'],
  'facets': {'employees': <Object>[]},
};

/// The documented `GET /timesheets/{id}/details` example.
Map<String, dynamic> detailsJson({bool inSync = true}) => {
  'timesheet': {
    'id': 42,
    'user_id': 10,
    'month': '2026-10',
    'hours': 270,
    'rate': 30,
    'total': 135,
    'status': 'pending',
  },
  'period': {'start': '2026-10-01', 'end': '2026-10-31'},
  'pay_type': 'hourly',
  'pay_basis': 'counted_task_minutes_times_hourly_rate',
  'summary': {
    'projects_count': 1,
    'tasks_count': 2,
    'counted_minutes': 150,
    'tasks_cost': 50,
    'calculated': {'hours': 150, 'total': 75},
    'stored': {'hours': 150, 'total': 75},
    'in_sync': inSync,
  },
  'projects': [
    {
      'project_id': 7,
      'project_title': 'Alpha Portal',
      'tasks_count': 2,
      'counted_minutes': 150,
      'cost': 50,
      'tasks': [
        {
          'id': 101,
          'title': 'Alpha login screen',
          'status': 'completed',
          'task_date': '2026-10-03',
          'start_time': '09:00:00',
          'end_time': '10:00:00',
          'duration_minutes': 60,
          'counted_minutes': 60,
          'cost': 20,
          'sprint_id': 3,
        },
        {
          'id': 102,
          'title': 'Alpha password reset',
          'status': 'in_review',
          'task_date': '2026-10-09',
          'start_time': '09:00:00',
          'end_time': '10:30:00',
          'duration_minutes': 90,
          'counted_minutes': 90,
          'cost': 30,
          'sprint_id': 3,
        },
      ],
    },
  ],
};

/// Pumps [screen] in API mode for an employee signed in as user 10 in
/// company 3, answering by route.
Future<RouteHttpAdapter> pumpEmployeeScreen(
  WidgetTester tester,
  Widget screen, {
  Map<String, (int, Object?)> routes = const {},
  Map<String, (int, Object?) Function(dynamic)> handlers = const {},
  List<Object> overrides = const [],
  Locale locale = const Locale('en'),
  Size size = const Size(390, 1600),
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
      companyId: 3,
      portal: Portal.employee,
    ).toStorage(),
  );
  final adapter = RouteHttpAdapter(
    {
      'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
      ...routes,
    },
    handlers: {for (final e in handlers.entries) e.key: e.value},
  );
  final container = ProviderContainer(
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
      ...overrides.cast(),
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
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

List<String> paths(RouteHttpAdapter a) => [
  for (final r in a.requests) '${r.method} ${r.uri.path}',
];

void main() {
  group('repositories (contract)', () {
    late FakeHttpAdapter http;
    ApiClient client() => ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    );
    setUp(() => http = FakeHttpAdapter());

    test(
      'tasks export sends the list filters and keeps the file name',
      () async {
        http.reply(
          200,
          _csv('Title,Project\nA,B\n'),
          headers: {
            'content-type': 'text/csv; charset=UTF-8',
            'content-disposition':
                'attachment; filename="tasks-2026-11-18.csv"',
          },
        );
        final file = await EmployeeExportsRepository(client()).tasks(
          const TaskQuery(
            search: ' login ',
            status: ApiTaskStatus.inProgress,
            priority: TaskPriority.high,
            projectId: 2,
            sort: TaskSort.plannedDate,
            page: 3,
          ),
          assignedTo: 10,
        );
        final r = http.last;
        expect(r.path, '/api/v1/employee/tasks/export');
        expect(r.queryParameters, {
          'month': 'all',
          'assigned_to': 10,
          'search': 'login',
          'status': 'in_progress',
          'priority': 'high',
          'project_id': 2,
          'sort': '-task_date',
        });
        // No paging: the export is every matching row.
        expect(r.queryParameters.containsKey('page'), isFalse);
        expect(file.fileName, 'tasks-2026-11-18.csv');
        expect(utf8.decode(file.bytes.sublist(3)), startsWith('Title,Project'));
      },
    );

    test('timesheet, project and backlog exports use their routes', () async {
      Future<CsvFile> next(Future<CsvFile> Function() call) {
        http.reply(200, _csv('x'), headers: {'content-type': 'text/csv'});
        return call();
      }

      final repo = EmployeeExportsRepository(client());
      final ts = await next(
        () => repo.timesheets(month: '2026-11', status: 'approved'),
      );
      expect(http.last.path, '/api/v1/employee/timesheets/export');
      expect(http.last.queryParameters, {
        'month': '2026-11',
        'status': 'approved',
      });
      expect(ts.fileName, 'timesheets.csv');
      await next(
        () =>
            repo.projects(search: 'acme', status: ApiProjectStatus.inProgress),
      );
      expect(http.last.path, '/api/v1/employee/projects/export');
      expect(http.last.queryParameters, {
        'search': 'acme',
        'status': 'in_progress',
      });
      await next(() => repo.backlog(projectId: 2));
      expect(http.last.path, '/api/v1/employee/sprints/backlog/export');
      expect(http.last.queryParameters, {'project_id': 2});
      expect(http.last.headers['X-Company'], '3');
    });

    test('an export over 10 000 rows (422) is an error, not a file', () async {
      http.reply(422, failure('Too many rows to export.'));
      await expectLater(
        EmployeeExportsRepository(client()).tasks(const TaskQuery()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiFailureKind.validation)
              .having((e) => e.message, 'message', 'Too many rows to export.'),
        ),
      );
    });

    test('a 200 that is not CSV is never saved', () async {
      http.reply(200, ok(<Object>[]));
      await expectLater(
        EmployeeExportsRepository(client()).backlog(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('project members: live {id, name} rows, id = users.id', () async {
      http.reply(
        200,
        ok([
          {'id': 4, 'name': 'Lead'},
          {'id': 10, 'name': 'Member'},
        ]),
      );
      final people = await WorkOptionsRepository(client()).projectMembers(2);
      expect(http.last.path, '/api/v1/employee/tasks/project-employees/2');
      expect(
        [for (final p in people) (p.userId, p.name)],
        [(4, 'Lead'), (10, 'Member')],
      );
    });

    test('project members: a row without an id is invalid', () async {
      http.reply(
        200,
        ok([
          {'name': 'No id'},
        ]),
      );
      await expectLater(
        WorkOptionsRepository(client()).projectMembers(2),
        throwsA(isA<ApiException>()),
      );
    });

    test('timesheet rows: live shape, filters, never status=all', () async {
      http.reply(200, timesheetList([timesheetJson(7)]));
      final rows = await EmployeeWorkRepository(client()).timesheetRows((
        month: '2026-11',
        status: TimesheetStatus.pending,
        page: 2,
      ));
      expect(http.last.path, '/api/v1/employee/timesheets');
      expect(http.last.queryParameters, {
        'page': 2,
        'month': '2026-11',
        'status': 'pending',
      });
      final t = rows.page.items.single;
      expect(t.id, 7);
      expect(t.minutes, 9600);
      expect(t.total, 2500);
      expect(t.status, TimesheetStatus.pending);
      expect(t.paymentType, 'monthly');
      expect(t.currencySymbol, r'$');
      expect(rows.months, ['2026-11', '2026-10']);

      http.reply(200, timesheetList(const []));
      await EmployeeWorkRepository(client())
          .timesheetRows((month: null, status: null, page: 1));
      expect(http.last.queryParameters, {'page': 1});
    });

    test('timesheet details: the documented example', () async {
      http.reply(200, ok(detailsJson(inSync: false)));
      final b = await EmployeeWorkRepository(client()).timesheetDetails(42);
      expect(http.last.path, '/api/v1/employee/timesheets/42/details');
      expect(b.month, '2026-10');
      expect(b.countedMinutes, 150);
      expect(b.tasksCount, 2);
      expect(b.inSync, isFalse);
      expect(b.projects.single.title, 'Alpha Portal');
      expect([for (final t in b.projects.single.tasks) t.id], [101, 102]);
    });

    test("another employee's timesheet details are refused (403)", () async {
      http.reply(403, failure('Unauthorized access to this timesheet'));
      await expectLater(
        EmployeeWorkRepository(client()).timesheetDetails(1),
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

  group('timesheets screen', () {
    Map<String, (int, Object?) Function(dynamic)> listHandler(
      List<Object> rows,
    ) => {'GET /api/v1/employee/timesheets': (_) => (200, timesheetList(rows))};

    testWidgets('lists my timesheets; View opens the counted tasks', (
      tester,
    ) async {
      final a = await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler([timesheetJson(42)]),
        routes: {
          'GET /api/v1/employee/timesheets/42/details': (
            200,
            ok(detailsJson(inSync: false)),
          ),
        },
      );
      expect(find.byKey(const Key('api-timesheet-42')), findsOneWidget);
      expect(find.textContaining('160h 0m'), findsWidgets);
      expect(find.textContaining('Monthly'), findsOneWidget);
      // No approve or reject for an employee.
      expect(find.text('Approve'), findsNothing);
      await tester.ensureVisible(find.text('View'));
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timesheet-details')), findsOneWidget);
      expect(find.text('Alpha Portal'), findsOneWidget);
      expect(find.text('Alpha login screen'), findsOneWidget);
      expect(find.byKey(const Key('timesheet-out-of-sync')), findsOneWidget);
      // The pay type is labelled as such (36b44d8), not as a rate.
      expect(find.text('Pay type'), findsOneWidget);
      expect(find.text('Hourly'), findsOneWidget);
      expect(paths(a), contains('GET /api/v1/employee/timesheets/42/details'));
    });

    testWidgets('"Total salaries" is the whole amount, not only approved', (
      tester,
    ) async {
      // The live shape: one pending timesheet, so totals[].approved is 0
      // and totals[].total is the whole amount (root-cause audit B).
      await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler([timesheetJson(42)]),
      );
      final metric = find.byKey(const Key('timesheets-total-pay'));
      expect(
        find.descendant(
          of: metric,
          matching: find.text(money(2500, symbol: r'$')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: metric,
          matching: find.text(money(0, symbol: r'$')),
        ),
        findsNothing,
      );
    });

    testWidgets('status and month filters are sent to the server', (
      tester,
    ) async {
      final a = await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler([timesheetJson(42)]),
      );
      await tester.tap(find.byKey(const Key('timesheet-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approved').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timesheet-month-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oct 2026').last);
      await tester.pumpAndSettle();
      final q = a.requests
          .where((r) => r.uri.path == '/api/v1/employee/timesheets')
          .last
          .uri
          .queryParameters;
      expect(q['status'], 'approved');
      expect(q['month'], '2026-10');
    });

    testWidgets('no timesheets: a plain empty state', (tester) async {
      await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler(const []),
      );
      expect(find.byKey(const Key('timesheets-empty')), findsOneWidget);
      expect(find.text('You have no timesheets yet.'), findsOneWidget);
    });

    testWidgets('Export CSV saves the server file with the filters', (
      tester,
    ) async {
      final saved = <CsvFile>[];
      final a = await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler([timesheetJson(42)]),
        routes: {
          'GET /api/v1/employee/timesheets/export': (
            200,
            csvReply('timesheets-2026-11-18.csv', 'Employee,Month\n'),
          ),
        },
        overrides: [
          csvSaverProvider.overrideWithValue((f) async {
            saved.add(f);
            return true;
          }),
        ],
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saved.single.fileName, 'timesheets-2026-11-18.csv');
      expect(find.text('Saved timesheets-2026-11-18.csv.'), findsOneWidget);
      final export = a.requests.singleWhere(
        (r) => r.uri.path == '/api/v1/employee/timesheets/export',
      );
      expect(export.headers['Authorization'], 'Bearer t');
    });

    testWidgets('a refused export says why and saves nothing', (tester) async {
      var saves = 0;
      await pumpEmployeeScreen(
        tester,
        const TimesheetsScreen(),
        handlers: listHandler([timesheetJson(42)]),
        routes: {
          'GET /api/v1/employee/timesheets/export': (
            403,
            failure('You are not authorized to access this resource'),
          ),
        },
        overrides: [
          csvSaverProvider.overrideWithValue((f) async {
            saves++;
            return true;
          }),
        ],
      );
      await tester.tap(find.byKey(const Key('export-csv')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.textContaining("Couldn't export"), findsOneWidget);
    });
  });

  group('task form assignees', () {
    final routes = <String, (int, Object?)>{
      'GET /api/v1/employee/projects/options': (
        200,
        ok([
          {'id': 2, 'title': 'Portal', 'leader_id': 10},
        ]),
      ),
      'GET /api/v1/employee/sprints/options': (200, ok(<Object>[])),
      'GET /api/v1/employee/tasks/project-employees/2': (
        200,
        ok([
          {'id': 10, 'name': 'Me'},
          {'id': 11, 'name': 'Lina'},
        ]),
      ),
    };

    SelectField<int?> assigneeField(WidgetTester tester) =>
        tester.widget<SelectField<int?>>(
          find.byWidgetPredicate(
            (w) => w is SelectField<int?> && w.label == 'Assignee',
          ),
        );

    testWidgets('only members of the project are offered', (tester) async {
      final a = await pumpEmployeeScreen(
        tester,
        const ApiTaskFormScreen(projectId: 2),
        routes: routes,
      );
      final field = assigneeField(tester);
      expect(field.options, [null, 10, 11]);
      expect(field.labelOf(11), 'Lina');
      expect(
        paths(a),
        contains('GET /api/v1/employee/tasks/project-employees/2'),
      );
      // The company-wide list is no longer used for assigning.
      expect(
        paths(a),
        isNot(contains('GET /api/v1/employee/employees/options')),
      );
    });

    testWidgets('members failing to load: an error with retry, no guess', (
      tester,
    ) async {
      await pumpEmployeeScreen(
        tester,
        const ApiTaskFormScreen(projectId: 2),
        routes: {
          ...routes,
          'GET /api/v1/employee/tasks/project-employees/2': (
            500,
            failure('Server Error'),
          ),
        },
      );
      expect(find.byKey(const Key('task-members-error')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectField<int?> && w.label == 'Assignee',
        ),
        findsNothing,
      );
    });
  });
}
