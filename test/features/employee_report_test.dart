import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/reports/data/employee_report_repository.dart';
import 'package:workflow_app/features/reports/presentation/employee_report_screen.dart';

import '../helpers/fake_http_adapter.dart';
import 'employee_completion_test.dart' show paths, pumpEmployeeScreen;

/// `GET /employee/report` in the shape the collection's test asserts (and
/// the live server returned on 2026-11-18); values are test doubles.
Map<String, dynamic> reportJson({
  String from = '2026-11-01',
  String to = '2026-11-30',
  List<Map<String, Object?>>? tasks,
  int lastPage = 1,
}) {
  final items =
      tasks ??
      [
        {
          'id': 13,
          'title': 'Write the API notes',
          'status': 'completed',
          'priority': 'high',
          'task_date': '2026-11-04',
          'project': {'id': 2, 'title': 'Portal', 'status': 'in_progress'},
        },
        {
          'id': 14,
          'title': 'Review the board',
          'status': 'todo',
          'priority': 'low',
          'task_date': '2026-11-05',
          'project': {'id': 2, 'title': 'Portal', 'status': 'in_progress'},
        },
      ];
  return {
    'employee': {
      'id': 1,
      'user_id': 10,
      'name': 'Me',
      'email': 'me@test.dev',
      'job_title': 'Developer',
      'is_active': true,
      'roles': ['employee'],
      'company': {'id': 3, 'name': 'Acme'},
    },
    'period': {
      'type': 'month',
      'from': from,
      'to': to,
      'timezone': 'UTC',
      'timesheet_months': {
        'from': from.substring(0, 7),
        'to': to.substring(0, 7),
      },
    },
    'summary': {
      'projects_count': 1,
      'projects_by_association': {'member': 1, 'leader': 1, 'assignee': 1},
      'tasks_count': 2,
      'completed_tasks_count': 1,
      'backlog_tasks_count': 0,
      'todo_tasks_count': 1,
      'in_progress_tasks_count': 0,
      'in_review_tasks_count': 0,
      'pending_tasks_count': 0,
      'task_completion_rate': 50,
      'working_minutes': 9600,
      'working_hours': 160,
      'meetings_count': 2,
      'meeting_invitations': {
        'pending': 1,
        'accepted': 1,
        'declined': 0,
        'expired': 0,
      },
      'meetings_attended': 1,
      'earnings': {
        'source': 'timesheets.total',
        'currency': {'id': 1, 'code': 'USD', 'symbol': r'$'},
        'total': 2500,
        'approved': 0,
        'pending': 2500,
        'rejected': 0,
      },
    },
    'projects': [
      {
        'id': 2,
        'title': 'Portal',
        'status': 'in_progress',
        'association_types': ['member', 'leader'],
        'tasks_count': 2,
        'completed_tasks_count': 1,
      },
    ],
    'tasks': {
      'by_status': {
        'backlog': 0,
        'todo': 1,
        'in_progress': 0,
        'in_review': 0,
        'completed': 1,
        'pending': 0,
      },
      'items': items,
      'pagination': {
        'current_page': 1,
        'last_page': lastPage,
        'per_page': 10,
        'total': lastPage * 10,
      },
    },
    'timesheets': {
      'items': [
        {
          'id': 1,
          'month': '2026-11',
          'date': '2026-11-01',
          'minutes': 9600,
          'hours': 160,
          'hours_text': '160h 0m',
          'status': 'pending',
          'earnings': 2500,
        },
      ],
      'minutes_by_status': {
        'total': 9600,
        'approved': 0,
        'pending': 9600,
        'rejected': 0,
      },
    },
    'meetings': [
      {
        'id': 41,
        'title': 'Daily stand-up',
        'type': 'instant',
        'status': 'live',
        'scheduled_at': null,
        'started_at': '2026-11-10T09:00:00Z',
        'ended_at': null,
        'project': null,
        'invitation_status': 'accepted',
        'attended': true,
        'participant_role': null,
      },
    ],
  };
}

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

void main() {
  group('repository', () {
    late FakeHttpAdapter http;
    EmployeeReportRepository repo() => EmployeeReportRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        credentials: _Creds(),
        adapter: http,
      ),
    );
    setUp(() => http = FakeHttpAdapter());

    test('a month sends year and month; never a person or company', () async {
      http.reply(200, ok(reportJson()));
      final r = await repo().report(
        ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 9), page: 2),
      );
      expect(http.last.path, '/api/v1/employee/report');
      expect(http.last.queryParameters, {
        'year': 2026,
        'month': 9,
        'page': 2,
        'per_page': 10,
      });
      for (final k in ['employee_id', 'user_id', 'company_id', 'from', 'to']) {
        expect(http.last.queryParameters.containsKey(k), isFalse, reason: k);
      }
      expect(r.taskCount, 2);
      expect(r.completedTasks, 1);
      expect(r.workingMinutes, 9600);
      expect(r.earnings.total, 2500);
      expect(r.earnings.symbol, r'$');
      expect(r.projects.single.associations, ['member', 'leader']);
      expect(r.tasks.items.first.projectTitle, 'Portal');
      expect(r.meetings.single.attended, isTrue);
    });

    test('a year sends the year only', () async {
      http.reply(200, ok(reportJson()));
      await repo().report(
        ReportQuery(span: ReportSpan.year, anchor: DateTime(2026, 5)),
      );
      expect(http.last.queryParameters, {
        'year': 2026,
        'page': 1,
        'per_page': 10,
      });
    });

    test(
      'a custom range sends from and to only, never year or month',
      () async {
        http.reply(200, ok(reportJson()));
        await repo().report(
          ReportQuery(
            span: ReportSpan.range,
            anchor: DateTime(2026, 11),
            from: DateTime(2026, 9, 15),
            to: DateTime(2026, 10, 5),
          ),
        );
        expect(http.last.queryParameters, {
          'from': '2026-09-15',
          'to': '2026-10-05',
          'page': 1,
          'per_page': 10,
        });
      },
    );

    test('a range is valid only forwards and up to 366 days', () {
      final d = DateTime(2026);
      expect(ReportQuery.validRange(d, d), isTrue);
      expect(ReportQuery.validRange(d, DateTime(2026, 12, 31)), isTrue); // 365
      expect(ReportQuery.validRange(d, DateTime(2027)), isTrue); // 366
      expect(ReportQuery.validRange(d, DateTime(2027, 1, 2)), isFalse); // 367
      expect(ReportQuery.validRange(d, DateTime(2025, 12, 31)), isFalse);
    });

    test('ranges are equal only when they send the same dates', () {
      ReportQuery r(int day) => ReportQuery(
        span: ReportSpan.range,
        anchor: DateTime(2026, 11, day),
        from: DateTime(2026, 9, day),
        to: DateTime(2026, 10, 5),
      );
      expect(r(1), r(1));
      expect(r(1).hashCode, r(1).hashCode);
      expect(r(1), isNot(r(2)));
      expect(
        r(1),
        isNot(ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 9))),
      );
    });

    test('a missing section is an invalid response, not an empty report', () {
      http.reply(200, ok(reportJson()..remove('timesheets')));
      expect(
        repo().report(
          ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 11)),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('no employee row in the company (404) is an error', () {
      http.reply(404, failure('No employee record for your account'));
      expect(
        repo().report(
          ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 11)),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('equal periods share one query; other months do not', () {
      final a = ReportQuery(span: ReportSpan.year, anchor: DateTime(2026, 2));
      final b = ReportQuery(span: ReportSpan.year, anchor: DateTime(2026, 9));
      final c = ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 2));
      final d = ReportQuery(span: ReportSpan.month, anchor: DateTime(2026, 9));
      expect(a, b);
      expect(c == d, isFalse);
    });
  });

  group('screen', () {
    (int, Object?) answer(dynamic o) => (200, ok(reportJson()));

    testWidgets('shows my figures, sections and opens a task', (tester) async {
      final a = await pumpEmployeeScreen(
        tester,
        const EmployeeReportScreen(),
        handlers: {'GET /api/v1/employee/report': answer},
        routes: {
          'GET /api/v1/employee/tasks/13': (
            200,
            ok({
              'id': 13,
              'title': 'Write the API notes',
              'status': 'completed',
            }),
          ),
        },
      );
      expect(find.byKey(const Key('report-summary')), findsOneWidget);
      expect(find.text('1 of 2'), findsNWidgets(2)); // tasks and meetings
      expect(find.byKey(const Key('report-project-2')), findsOneWidget);
      expect(find.textContaining('Leader'), findsOneWidget);
      expect(find.byKey(const Key('report-timesheet-1')), findsOneWidget);
      expect(find.byKey(const Key('report-meeting-41')), findsOneWidget);
      // Sentence-case labels and plain section names (36b44d8 and the
      // 2026-11-19 emulator review): no upper-case metric label, no
      // module page title as a section heading.
      expect(find.text('Logged time'), findsOneWidget);
      expect(find.text('LOGGED HOURS'), findsNothing);
      for (final (key, title) in [
        ('report-tasks', 'Tasks'),
        ('report-projects', 'Projects'),
        ('report-timesheets', 'Timesheets'),
        ('report-meetings', 'Meetings'),
      ]) {
        expect(
          find.descendant(of: find.byKey(Key(key)), matching: find.text(title)),
          findsOneWidget,
          reason: key,
        );
      }
      expect(find.text('Meetings Management'), findsNothing);
      // The current month: nothing later to step to.
      final next = tester.widget<IconButton>(
        find.byKey(const Key('report-next')),
      );
      expect(next.onPressed, isNull);
      await tester.ensureVisible(find.byKey(const Key('report-task-13')));
      await tester.tap(find.byKey(const Key('report-task-13')));
      await tester.pumpAndSettle();
      expect(paths(a), contains('GET /api/v1/employee/tasks/13'));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
    });

    testWidgets('previous month and year are asked for', (tester) async {
      final a = await pumpEmployeeScreen(
        tester,
        const EmployeeReportScreen(),
        handlers: {'GET /api/v1/employee/report': answer},
      );
      final now = DateTime.now();
      await tester.tap(find.byKey(const Key('report-previous')));
      await tester.pumpAndSettle();
      final prev = DateTime(now.year, now.month - 1);
      var q = a.requests.last.uri.queryParameters;
      expect(q['year'], '${prev.year}');
      expect(q['month'], '${prev.month}');
      await tester.tap(find.byKey(const Key('report-span-year')));
      await tester.pumpAndSettle();
      q = a.requests.last.uri.queryParameters;
      expect(q.containsKey('month'), isFalse);
      expect(find.byKey(const Key('report-period')), findsOneWidget);
    });

    testWidgets('a custom range is chosen in the picker and sent', (
      tester,
    ) async {
      final a = await pumpEmployeeScreen(
        tester,
        const EmployeeReportScreen(),
        handlers: {'GET /api/v1/employee/report': answer},
      );
      final before = a.requests.length;
      // Cancelled: nothing changes and nothing is sent.
      await tester.tap(find.byKey(const Key('report-choose-dates')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(a.requests.length, before);

      // Saved: the last 30 days, offered by default.
      await tester.tap(find.byKey(const Key('report-choose-dates')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      String ymd(DateTime d) => d.toIso8601String().substring(0, 10);
      final q = a.requests.last.uri.queryParameters;
      expect(q['from'], ymd(today.subtract(const Duration(days: 29))));
      expect(q['to'], ymd(today));
      expect(q.containsKey('year'), isFalse);
      expect(q.containsKey('month'), isFalse);
      expect(find.textContaining(' – '), findsOneWidget);
      // A range has no previous or next period.
      for (final k in ['report-previous', 'report-next']) {
        expect(tester.widget<IconButton>(find.byKey(Key(k))).onPressed, isNull);
      }
      // Back to months: year and month again.
      await tester.tap(find.byKey(const Key('report-span-month')));
      await tester.pumpAndSettle();
      final m = a.requests.last.uri.queryParameters;
      expect(m['month'], isNotNull);
      expect(m.containsKey('from'), isFalse);
    });

    testWidgets('a failure is shown with Retry', (tester) async {
      await pumpEmployeeScreen(
        tester,
        const EmployeeReportScreen(),
        handlers: {
          'GET /api/v1/employee/report': (_) => (500, failure('Server Error')),
        },
      );
      expect(find.byKey(const Key('api-error')), findsOneWidget);
      expect(find.byKey(const Key('api-retry')), findsOneWidget);
    });

    testWidgets('an empty period says so in each section', (tester) async {
      await pumpEmployeeScreen(
        tester,
        const EmployeeReportScreen(),
        handlers: {
          'GET /api/v1/employee/report': (_) {
            final r = reportJson(tasks: const []);
            r['projects'] = <Object>[];
            r['meetings'] = <Object>[];
            (r['timesheets'] as Map)['items'] = <Object>[];
            return (200, ok(r));
          },
        },
      );
      expect(find.text('No tasks are dated in this period.'), findsOneWidget);
      expect(find.text('No projects in this period.'), findsOneWidget);
      expect(find.text('No timesheets in this period.'), findsOneWidget);
      expect(find.text('No meetings in this period.'), findsOneWidget);
    });
  });
}
