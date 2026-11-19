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
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/projects/presentation/api_projects_view.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_task_form.dart';
import 'package:workflow_app/features/work/presentation/api_task_list_screen.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';

/// M07 — Employee projects, tasks and sprints against the WorkFlow
/// collection (rev. 2026-11-14T11:14:33Z). Every response here is a test
/// double shaped from the documented contract (and, where noted, from
/// shapes seen live earlier); none is captured live traffic.

typedef _Reply = (int, Object?);

Map<String, dynamic> _task(
  int id, {
  int project = 2,
  int? assignee = 10,
  String status = 'todo',
  bool? canUpdate = true,
}) => {
  'id': id,
  'title': 'Task $id',
  'description': 'About task $id.',
  'status': status,
  'priority': 'high',
  'story_points': 3,
  'task_date': '2026-11-02',
  'start_time': '09:00:00',
  'end_time': '10:30:00',
  'assignee': assignee == null ? null : {'id': assignee, 'name': 'U$assignee'},
  'project': {'id': project, 'title': project == 2 ? 'Portal' : 'Mobile'},
  'sprint': {'id': 4, 'name': 'Sprint 4'},
  'can': canUpdate == null ? null : {'update': canUpdate, 'delete': false},
};

Map<String, dynamic> _page(List<Object> rows) => ok({
  'current_page': 1,
  'data': rows,
  'last_page': 1,
  'per_page': 10,
  'total': rows.length,
});

/// `GET /employee/tasks/{id}` as api.workflownets.com answered it on
/// 2026-11-17 (keys observed live; values here are invented).
Map<String, dynamic> _liveDetails(Map<String, dynamic> row) {
  final assignee = row['assignee'] as Map?;
  final project = row['project'] as Map;
  final sprint = row['sprint'] as Map?;
  return {
    'task': {
      'id': row['id'],
      'project_id': project['id'],
      'sprint_id': sprint?['id'],
      'assigned_to': assignee?['id'],
      'title': row['title'],
      'description': row['description'],
      'story_points': row['story_points'],
      'priority': row['priority'],
      'status': row['status'],
      'completed_at': null,
      'completed_by': null,
      'task_date': row['task_date'],
      'start_time': row['start_time'],
      'end_time': row['end_time'],
      'duration': 90,
      'assigned_user': assignee == null
          ? null
          : {...assignee, 'email': 'hidden@test.dev', 'is_active': 1},
      'project': {...project, 'company_id': 3, 'leader_id': 10},
      'sprint': sprint,
      'work_logs': <Object>[],
    },
    'duration_formatted': '1.5h',
    'assigned_user_name': assignee?['name'],
    'project_name': project['title'],
    'sprint_name': sprint?['name'],
  };
}

/// A fake WorkFlow backend for the employee role, answering by method,
/// path and (for tenancy) the `X-Company` header.
class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  /// Company id → projects the signed-in user leads (`led=1`).
  final Map<String, List<Map<String, Object?>>> led = {
    '3': [
      {'id': 2, 'title': 'Portal', 'leader_id': 10},
    ],
    '4': [],
  };

  final List<Map<String, dynamic>> tasks = [
    _task(3, status: 'in_progress'),
    _task(5, canUpdate: false),
    _task(6, project: 5),
  ];

  /// Backlog rows of `GET /sprints` (none unless a test adds some).
  final List<Map<String, dynamic>> backlog = [];

  _Reply? createReply;
  _Reply? updateReply;

  /// Answer `GET /tasks/{id}` in the shape seen live on 2026-11-17:
  /// the model nested under `data.task`, no `assignee` and no `can`.
  bool nestedDetails = false;

  List<RequestOptions> where(String method, String path) => [
    for (final r in requests)
      if (r.method == method && r.uri.path == path) r,
  ];

  _Reply _route(RequestOptions o) {
    final p = o.uri.path.replaceFirst('/api/v1/employee', '');
    final q = o.uri.queryParameters;
    final company = '${o.headers['X-Company']}';
    switch ((o.method, p)) {
      case ('GET', '/account'):
        return (200, ok({'id': 10, 'name': 'Me'}));
      case ('GET', '/dashboard'):
        return (
          200,
          ok({
            'myTasks': 1,
            'myHours': 0,
            'myMinutes': 0,
            'totalEarned': 0,
            'paidSalary': 0,
            'unpaidSalary': 0,
          }),
        );
      case ('GET', '/projects/options'):
        if (q['led'] == '1') return (200, ok(led[company] ?? const []));
        return (
          200,
          ok([
            {'id': 2, 'title': 'Portal', 'leader_id': 10},
            {'id': 5, 'title': 'Mobile', 'leader_id': 77},
          ]),
        );
      case ('GET', '/sprints/options'):
        return (
          200,
          ok([
            {'id': 4, 'name': 'Sprint 4', 'status': 'active'},
          ]),
        );
      case ('GET', '/employees/options'):
        return (
          200,
          ok([
            {'user_id': 10, 'name': 'Me', 'image': null},
            {'user_id': 11, 'name': 'Lina', 'image': null},
          ]),
        );
      case ('GET', '/projects'):
        return (
          200,
          {
            ..._page([
              {
                'id': 2,
                'title': 'Portal',
                'status': 'in_progress',
                'completion_percentage': 40,
              },
            ]),
            'stats': {
              'total': 1,
              'pending': 0,
              'in_progress': 1,
              'completed': 0,
            },
          },
        );
      case ('GET', '/projects/2'):
        return (200, ok({'id': 2, 'title': 'Portal', 'status': 'in_progress'}));
      case ('GET', '/tasks'):
        final rows = tasks.where((t) {
          if (q['project_id'] case final id?) {
            if ('${(t['project'] as Map)['id']}' != id) return false;
          }
          if (q['assigned_to'] case final a?) {
            if ('${(t['assignee'] as Map?)?['id']}' != a) return false;
          }
          return true;
        }).toList();
        return (
          200,
          {
            ..._page(rows),
            'stats': {
              'total': rows.length,
              'by_status': <String, int>{},
              'active': rows.length,
              'logged_minutes': 0,
            },
          },
        );
      case ('POST', '/tasks'):
        return createReply ?? (201, ok({'id': 99}));
      case ('GET', '/kanban'):
        return (
          200,
          ok({
            'projects': [
              {'id': 2, 'title': 'Portal'},
              {'id': 5, 'title': 'Mobile'},
            ],
            'selected_project': {'id': 2, 'title': 'Portal'},
            'sprint': {
              'id': 4,
              'name': 'Sprint 4',
              'status': 'active',
              'start_date': '2026-11-01',
              'end_date': '2026-11-15',
            },
            'tasks': [tasks.first],
            'stats': {
              'by_status': {'in_progress': 1},
            },
          }),
        );
      case ('GET', '/sprints'):
        return (
          200,
          ok({
            'projects': [
              {'id': 2, 'title': 'Portal'},
            ],
            'selected_project': {'id': 2, 'title': 'Portal'},
            'sprints': [
              {'id': 4, 'name': 'Sprint 4', 'status': 'active'},
            ],
            'backlog': {
              'data': backlog,
              'current_page': 1,
              'last_page': 1,
              'per_page': 5,
              'total': backlog.length,
            },
            'backlog_stats': {'count': backlog.length, 'points': 0},
          }),
        );
    }
    // Live row shape (2026-11-18): `{id, name}`, `id` = users.id.
    if (o.method == 'GET' && p.startsWith('/tasks/project-employees/')) {
      return (
        200,
        ok([
          {'id': 10, 'name': 'Me'},
          {'id': 11, 'name': 'Lina'},
        ]),
      );
    }
    final task = RegExp(r'^/tasks/(\d+)$').firstMatch(p);
    if (task != null) {
      final id = int.parse(task.group(1)!);
      final row = tasks.where((t) => t['id'] == id).firstOrNull;
      if (row == null) return (404, failure('Not found'));
      if (o.method == 'GET') {
        return (200, ok(nestedDetails ? _liveDetails(row) : row));
      }
      if (o.method == 'PUT') {
        if (updateReply case final r?) return r;
        row.addAll((o.data as Map).cast<String, dynamic>());
        return (200, ok({'id': id}));
      }
    }
    return (404, failure('Not found'));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    // CSV exports: the documented file reply (BOM, attachment).
    if (options.method == 'GET' && options.uri.path.endsWith('/export')) {
      final name = options.uri.pathSegments.reversed.skip(1).first;
      return ResponseBody.fromBytes(
        [0xEF, 0xBB, 0xBF, ...utf8.encode('Title\r\n"A, ""b"""\r\n')],
        200,
        headers: {
          Headers.contentTypeHeader: ['text/csv; charset=UTF-8'],
          'content-disposition': ['attachment; filename="$name.csv"'],
        },
      );
    }
    final (status, body) = _route(options);
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
}

class _Auth implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => const Session(
    token: 'tkn-b',
    tokenType: 'Bearer',
    userId: 11,
    companyId: 4,
    portal: Portal.employee,
  );

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Server> _pump(
  WidgetTester tester, {
  bool lead = true,
  Size size = const Size(390, 1400),
  double scale = 1,
  AppPreferences? prefs,
  CsvSaver? saver,
  void Function(_Server)? prepare,
}) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 'tkn-a',
      tokenType: 'Bearer',
      userId: 10,
      companyId: 3,
      portal: Portal.employee,
    ).toStorage(),
  );
  final server = _Server();
  if (!lead) server.led['3'] = [];
  prepare?.call(server);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(_Auth()),
        if (prefs != null) initialPreferencesProvider.overrideWithValue(prefs),
        if (saver != null) csvSaverProvider.overrideWithValue(saver),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'https://api.test',
            credentials: ref.watch(sessionCredentialsProvider),
            adapter: server,
          ),
        ),
      ],
      child: WorkFlowApp(locale: prefs == null ? const Locale('en') : null),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(const Key('category-Tasks')));
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
  group('contract and repository', () {
    late FakeHttpAdapter http;
    ApiClient client() => ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    );
    setUp(() => http = FakeHttpAdapter());

    test('task details: the live nested shape is read as a task row', () async {
      http.reply(200, ok(_liveDetails(_task(3, status: 'in_progress'))));
      final t = await BoardRepository(client()).task(3);
      expect(t.id, 3);
      expect(t.title, 'Task 3');
      expect(t.status, ApiTaskStatus.inProgress);
      expect(t.assigneeId, 10);
      expect(t.assigneeName, 'U10');
      expect(t.projectId, 2);
      expect(t.projectTitle, 'Portal');
      expect(t.sprintId, 4);
      expect(t.canUpdate, isNull);
      expect(t.duration, const Duration(minutes: 90));
      final row = ApiTask.fromJson(_task(3, canUpdate: false));
      expect(t.withPermissionsFrom(row).canUpdate, isFalse);
    });

    test('task list sends the documented project, sprint and sort', () async {
      http
        ..reply(200, _page([]))
        ..reply(200, _page([]));
      final repo = BoardRepository(client());
      await repo.tasks(
        const TaskQuery(
          scope: TaskScope.team,
          projectId: 2,
          sprintId: 4,
          sort: TaskSort.plannedDate,
        ),
      );
      expect(http.last.queryParameters, {
        'month': 'all',
        'page': 1,
        'per_page': 10,
        'project_id': 2,
        'sprint_id': 4,
        'sort': '-task_date',
      });
      // The default sort is the route's own and is not sent.
      await repo.tasks(const TaskQuery(scope: TaskScope.team));
      expect(http.last.queryParameters.containsKey('sort'), isFalse);
    });

    test('kanban asks for scope=all only when told to', () async {
      http
        ..reply(200, ok({'projects': <Object>[], 'tasks': <Object>[]}))
        ..reply(200, ok({'projects': <Object>[], 'tasks': <Object>[]}));
      final repo = BoardRepository(client());
      await repo.kanban(projectId: 2);
      expect(http.last.queryParameters, {'project_id': 2});
      await repo.kanban(projectId: 2, all: true);
      expect(http.last.queryParameters, {'project_id': 2, 'scope': 'all'});
    });

    test('create posts the documented fields and returns data.id', () async {
      http.reply(201, ok({'id': 41}));
      final id = await BoardRepository(client()).createTask(
        TaskDraft(
          projectId: 2,
          title: '  Build login  ',
          taskDate: DateTime(2026, 11, 20),
          priority: TaskPriority.high,
          status: ApiTaskStatus.inReview,
          storyPoints: 3,
          start: (hour: 9, minute: 5),
          end: (hour: 11, minute: 0),
        ),
      );
      expect(id, 41);
      expect(http.last.method, 'POST');
      expect(http.last.path, '/api/v1/employee/tasks');
      // Empty optional fields (sprint, assignee, description) are left out;
      // nothing like a cost or due date is ever sent.
      expect(http.lastJsonBody, {
        'project_id': 2,
        'title': 'Build login',
        'story_points': 3,
        'priority': 'high',
        'status': 'in_review',
        'task_date': '2026-11-20',
        'start_time': '09:05',
        'end_time': '11:00',
      });
    });

    test('a create answer without data.id is invalid, not a success', () {
      http.reply(201, ok(<String, Object>{}));
      expect(
        BoardRepository(client()).createTask(
          TaskDraft(projectId: 2, title: 'x', taskDate: DateTime(2026)),
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

    test('update sends only what changed; clearing sends null', () async {
      final row = ApiTask.fromJson(_task(3));
      final original = TaskDraft.fromTask(row);
      http.reply(200, ok({'id': 3}));
      await BoardRepository(client()).updateTask(
        3,
        TaskDraft(
          projectId: original.projectId,
          title: 'Renamed',
          taskDate: original.taskDate,
          sprintId: original.sprintId,
          description: original.description,
          storyPoints: original.storyPoints,
          priority: original.priority,
          status: original.status,
          start: original.start,
          end: original.end,
        ),
        original,
      );
      expect(http.last.method, 'PUT');
      expect(http.last.path, '/api/v1/employee/tasks/3');
      // Title changed, assignee cleared (null); nothing else is sent.
      expect(http.lastJsonBody, {'title': 'Renamed', 'assigned_to': null});
    });

    test('no request when nothing changed', () async {
      final original = TaskDraft.fromTask(ApiTask.fromJson(_task(3)));
      await BoardRepository(client()).updateTask(3, original, original);
      expect(http.requests, isEmpty);
    });

    test('task rows keep project and sprint ids from their relations', () {
      final t = ApiTask.fromJson(_task(6, project: 5));
      expect(t.projectId, 5);
      expect(t.sprintId, 4);
      final bare = ApiTask.fromJson({'id': 1, 'title': 'x'});
      expect(bare.projectId, isNull);
      expect(() => TaskDraft.fromTask(bare), throwsA(isA<ApiException>()));
    });

    test('options routes: led=1, project_id, user_id', () async {
      http
        ..reply(
          200,
          ok([
            {'id': 2, 'title': 'Portal', 'leader_id': 10},
          ]),
        )
        ..reply(
          200,
          ok([
            {'id': 4, 'name': 'S4', 'status': 'planned'},
          ]),
        )
        ..reply(
          200,
          ok([
            {'user_id': 11, 'name': 'Lina', 'image': null},
          ]),
        );
      final repo = WorkOptionsRepository(client());
      final led = await repo.projects(led: true);
      expect(http.last.path, '/api/v1/employee/projects/options');
      expect(http.last.queryParameters, {'led': 1});
      expect(led.single.leaderId, 10);
      final sprints = await repo.sprints(2);
      expect(http.last.queryParameters, {'project_id': 2});
      expect(sprints.single.status, 'planned');
      final people = await repo.people();
      expect(http.last.path, '/api/v1/employee/employees/options');
      expect(people.single.userId, 11);
    });

    test('documented time rules', () {
      expect(taskTimeProblem(null, null), isNull);
      expect(taskTimeProblem((hour: 9, minute: 0), null), isNull);
      expect(
        taskTimeProblem(null, (hour: 10, minute: 0)),
        TaskTimeProblem.endWithoutStart,
      );
      expect(
        taskTimeProblem((hour: 10, minute: 0), (hour: 10, minute: 0)),
        TaskTimeProblem.endNotAfterStart,
      );
      expect(
        taskTimeProblem((hour: 9, minute: 0), (hour: 13, minute: 1)),
        TaskTimeProblem.overFourHours,
      );
      expect(
        taskTimeProblem((hour: 9, minute: 0), (hour: 13, minute: 0)),
        isNull,
      );
    });
  });

  group('tasks', () {
    testWidgets('not a lead: no Add Task and no Edit', (tester) async {
      await _pump(tester, lead: false);
      await _openTasks(tester);
      expect(find.byType(CreateFab), findsNothing);
      await _tap(tester, find.byKey(const Key('api-task-3')));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
      expect(find.byKey(const Key('task-actions')), findsNothing);
    });

    testWidgets('lead creates a task; lists are read again', (tester) async {
      final server = await _pump(tester);
      await _openTasks(tester);
      final listsBefore = server.where('GET', '/api/v1/employee/tasks').length;
      await _tap(tester, find.byType(CreateFab));
      expect(find.byKey(const Key('api-task-form')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('api-task-title')),
        'Write tests',
      );
      await _tap(tester, find.byKey(const Key('form-save')));
      final post = server.where('POST', '/api/v1/employee/tasks').single;
      final body = post.data as Map;
      expect(body['project_id'], 2);
      expect(body['title'], 'Write tests');
      expect(body['status'], 'todo');
      expect(body['priority'], 'medium');
      expect('${body['task_date']}', matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(body.containsKey('assigned_to'), isFalse);
      expect(post.headers['X-Company'], '3');
      expect(find.text('Task created.'), findsOneWidget);
      expect(find.byKey(const Key('api-task-form')), findsNothing);
      expect(
        server.where('GET', '/api/v1/employee/tasks').length,
        greaterThan(listsBefore),
      );
    });

    for (final (status, body, text) in [
      (
        403,
        failure('Only project leader or company admin can create tasks'),
        'Only the project’s leader can create or edit its tasks.',
      ),
      (
        409,
        failure('Approved month'),
        'This month’s timesheet is already approved, '
            'so the task can’t be changed.',
      ),
      (
        422,
        failure(
          'Invalid',
          errors: {
            'end_time': ['The task may last at most 4 hours.'],
          },
        ),
        'The task may last at most 4 hours.',
      ),
    ]) {
      testWidgets('a refused create ($status) keeps the form and says why', (
        tester,
      ) async {
        final server = await _pump(tester);
        server.createReply = (status, body);
        await _openTasks(tester);
        await _tap(tester, find.byType(CreateFab));
        await tester.enterText(find.byKey(const Key('api-task-title')), 'X');
        await _tap(tester, find.byKey(const Key('form-save')));
        expect(find.byKey(const Key('api-task-form')), findsOneWidget);
        expect(find.byKey(const Key('api-task-error')), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        expect(find.text('Task created.'), findsNothing);
      });
    }

    testWidgets('lead edits a task: only the change is sent', (tester) async {
      final server = await _pump(tester);
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('api-task-3')));
      await _tap(tester, find.byKey(const Key('task-actions')));
      await _tap(tester, find.byKey(const Key('task-edit')));
      expect(find.byKey(const Key('api-task-project-fixed')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('api-task-title')),
        'Renamed',
      );
      await _tap(tester, find.byKey(const Key('form-save')));
      final put = server.where('PUT', '/api/v1/employee/tasks/3').single;
      expect(put.data, {'title': 'Renamed'});
      expect(find.text('Task saved.'), findsOneWidget);
      // The details show the server's state after the write.
      expect(find.text('Renamed'), findsWidgets);
    });

    testWidgets('edit never sends defaults for fields the row lacked', (
      tester,
    ) async {
      final server = await _pump(tester);
      server.tasks.first
        ..remove('priority')
        ..remove('status')
        ..remove('task_date')
        ..remove('start_time')
        ..remove('end_time');
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('api-task-3')));
      await _tap(tester, find.byKey(const Key('task-actions')));
      await _tap(tester, find.byKey(const Key('task-edit')));
      await tester.enterText(find.byKey(const Key('api-task-title')), 'Only');
      await _tap(tester, find.byKey(const Key('form-save')));
      final put = server.where('PUT', '/api/v1/employee/tasks/3').single;
      expect(put.data, {'title': 'Only'});
    });

    testWidgets('live nested details: no error, Edit and status offered', (
      tester,
    ) async {
      final server = await _pump(tester);
      server.nestedDetails = true;
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('api-task-3')));
      expect(server.where('GET', '/api/v1/employee/tasks/3'), isNotEmpty);
      expect(find.text('Retry'), findsNothing);
      // Times are labelled as times, not dates.
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('Start date'), findsNothing);
      await _tap(tester, find.byKey(const Key('task-actions')));
      expect(find.byKey(const Key('task-edit')), findsOneWidget);
    });

    testWidgets("live nested details keep the row's can.update false", (
      tester,
    ) async {
      final server = await _pump(tester);
      server.nestedDetails = true;
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('api-task-5')));
      expect(find.text('Retry'), findsNothing);
      expect(find.byKey(const Key('task-actions')), findsNothing);
    });

    testWidgets('no Edit when the row says can.update false', (tester) async {
      await _pump(tester);
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('api-task-5')));
      expect(find.byKey(const Key('task-actions')), findsNothing);
    });

    testWidgets('no Edit on a project the user does not lead', (tester) async {
      await _pump(tester);
      await _openTasks(tester);
      await _tap(tester, find.byKey(const Key('task-scope-team')));
      await _tap(tester, find.byKey(const Key('api-task-6')));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
      expect(find.byKey(const Key('task-actions')), findsNothing);
    });

    testWidgets('project filter and sort are sent to the server', (
      tester,
    ) async {
      final server = await _pump(tester);
      await _openTasks(tester);
      // Project and sort live in one sheet and are applied together: one
      // request with both, not one per choice.
      final before = server.where('GET', '/api/v1/employee/tasks').length;
      await _tap(tester, find.byKey(const Key('task-filters')));
      await _tap(tester, find.byKey(const Key('filter-project-5')));
      await _tap(tester, find.byKey(const Key('filter-sort-plannedDate')));
      expect(server.where('GET', '/api/v1/employee/tasks').length, before);
      await _tap(tester, find.byKey(const Key('task-filters-apply')));
      final sent = server.where('GET', '/api/v1/employee/tasks');
      final rows = sent
          .skip(before)
          .where((r) => r.uri.queryParameters['per_page'] != '1')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.uri.queryParameters['project_id'], '5');
      expect(rows.single.uri.queryParameters['sort'], '-task_date');
      expect(rows.single.uri.queryParameters['page'], '1');
      // Both shown as active filters, with a way back.
      expect(find.byKey(const Key('active-filter-project')), findsOneWidget);
      expect(find.byKey(const Key('active-filter-sort')), findsOneWidget);
      expect(find.text('Filters (2)'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('reset-filters')));
      final reset = server.where('GET', '/api/v1/employee/tasks').last;
      expect(reset.uri.queryParameters.containsKey('project_id'), isFalse);
      expect(reset.uri.queryParameters.containsKey('sort'), isFalse);
      expect(find.byKey(const Key('active-filter-project')), findsNothing);
    });
  });

  testWidgets('opening Tasks sends each request once', (tester) async {
    final server = await _pump(tester);
    final before = server.requests.length;
    await _openTasks(tester);
    final sent = [
      for (final r in server.requests.skip(before)) '${r.method} ${r.uri}',
    ];
    // Measured: rows, figures, project options (filter) and led projects
    // (Add Task); the led list is shared with More, so it is not re-read.
    expect(sent.toSet().length, sent.length, reason: sent.join(' | '));
    expect(sent, hasLength(4), reason: sent.join(' | '));
  });

  group('projects', () {
    testWidgets('details lead to sprints, tasks and the board', (tester) async {
      final server = await _pump(tester);
      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      // Project create/update are 403 for employees: no Add Project.
      expect(find.byType(CreateFab), findsNothing);
      await _tap(tester, find.text('View Details').first);
      expect(find.byKey(const Key('project-related')), findsOneWidget);
      expect(find.byKey(const Key('project-you-lead')), findsOneWidget);
      expect(find.byKey(const Key('project-add-task')), findsOneWidget);
      expect(find.byKey(const Key('project-task-3')), findsOneWidget);
      // Only this project's tasks are asked for.
      expect(
        server
            .where('GET', '/api/v1/employee/tasks')
            .any((r) => r.uri.queryParameters['project_id'] == '2'),
        isTrue,
      );
      await _tap(tester, find.byKey(const Key('project-sprint-4')));
      expect(find.byKey(const Key('api-task-list')), findsOneWidget);
      final sprint = server.where('GET', '/api/v1/employee/tasks').last;
      expect(sprint.uri.queryParameters['sprint_id'], '4');
      expect(sprint.uri.queryParameters['project_id'], '2');
      // The sprint's tasks never come from GET /sprints/{id} (S1).
      expect(
        server.requests.any((r) => r.uri.path.contains('/sprints/4')),
        isFalse,
      );
      await _tap(tester, find.byKey(const Key('api-task-list-back')));
      await _tap(tester, find.byKey(const Key('project-open-board')));
      final board = server.where('GET', '/api/v1/employee/kanban').last;
      expect(board.uri.queryParameters['project_id'], '2');
      expect(find.text('Sprint 4'), findsWidgets);
    });

    testWidgets('not a lead: no Add task in project details', (tester) async {
      await _pump(tester, lead: false);
      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('View Details').first);
      expect(find.byKey(const Key('project-related')), findsOneWidget);
      expect(find.byKey(const Key('project-add-task')), findsNothing);
      expect(find.byKey(const Key('project-you-lead')), findsNothing);
    });
  });

  group('board', () {
    testWidgets('a lead may switch to the whole team (scope=all)', (
      tester,
    ) async {
      final server = await _pump(tester);
      await tester.tap(find.text('Sprints').last);
      await tester.pumpAndSettle();
      expect(
        server
            .where('GET', '/api/v1/employee/kanban')
            .first
            .uri
            .queryParameters,
        isNot(contains('scope')),
      );
      await _tap(tester, find.byKey(const Key('board-scope-team')));
      final all = server.where('GET', '/api/v1/employee/kanban').last;
      expect(all.uri.queryParameters, {'project_id': '2', 'scope': 'all'});
      await _tap(tester, find.byKey(const Key('board-scope-mine')));
      expect(
        server.where('GET', '/api/v1/employee/kanban').last.uri.queryParameters,
        {'project_id': '2'},
      );
    });

    testWidgets('not a lead: no scope switch, never scope=all', (tester) async {
      final server = await _pump(tester, lead: false);
      await tester.tap(find.text('Sprints').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('board-scope')), findsNothing);
      expect(
        server
            .where('GET', '/api/v1/employee/kanban')
            .any((r) => r.uri.queryParameters.containsKey('scope')),
        isFalse,
      );
    });

    testWidgets('a sprint row opens its tasks', (tester) async {
      final server = await _pump(tester);
      await tester.tap(find.text('Sprints').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Backlog'));
      await _tap(tester, find.byKey(const Key('sprint-row-4')));
      expect(find.byKey(const Key('api-task-list')), findsOneWidget);
      expect(
        server
            .where('GET', '/api/v1/employee/tasks')
            .last
            .uri
            .queryParameters['sprint_id'],
        '4',
      );
      expect(find.byKey(const Key('api-task-3')), findsOneWidget);
    });
  });

  testWidgets('home: the Tasks card lists my tasks with their real count', (
    tester,
  ) async {
    final server = await _pump(tester);
    expect(find.text('Projects 3'), findsOneWidget);
    expect(find.text('Projects 0'), findsNothing);
    final home = server
        .where('GET', '/api/v1/employee/tasks')
        .where((r) => r.uri.queryParameters['per_page'] == '3')
        .toList();
    expect(home, isNotEmpty);
    expect(home.first.uri.queryParameters['assigned_to'], '10');
    await _tap(tester, find.byKey(const Key('home-task-3')));
    expect(find.byKey(const Key('task-details')), findsOneWidget);
  });

  testWidgets('isolation: lead-only controls follow the account and company', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _openTasks(tester);
    expect(find.byType(CreateFab), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkFlowApp)),
    );
    await container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();
    final before = server.requests.length;
    await container
        .read(sessionControllerProvider.notifier)
        .login(email: 'x@test.dev', password: 'x', portal: Portal.employee);
    await tester.pumpAndSettle();
    await _openTasks(tester);
    // Company 4: this account leads nothing, so nothing lead-only shows.
    expect(find.byType(CreateFab), findsNothing);
    final options = server.requests
        .skip(before)
        .where((r) => r.uri.path == '/api/v1/employee/projects/options')
        .toList();
    expect(options, isNotEmpty);
    for (final r in options) {
      expect(r.headers['Authorization'], 'Bearer tkn-b');
      expect(r.headers['X-Company'], '4');
    }
  });

  group('CSV export: exactly what the list shows', () {
    Map<String, String> withoutPaging(RequestOptions r) => {
      for (final e in r.uri.queryParameters.entries)
        if (e.key != 'page' && e.key != 'per_page') e.key: e.value,
    };

    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets('tasks: search, project and sort as the list', (tester) async {
      final saved = <CsvFile>[];
      final server = await _pump(
        tester,
        saver: (f) async {
          saved.add(f);
          return true;
        },
      );
      await _openTasks(tester);
      await search(tester, ' Task ');
      await _tap(tester, find.byKey(const Key('task-filters')));
      await _tap(tester, find.byKey(const Key('filter-project-2')));
      await _tap(tester, find.byKey(const Key('filter-sort-plannedDate')));
      await _tap(tester, find.byKey(const Key('task-filters-apply')));
      final list = server
          .where('GET', '/api/v1/employee/tasks')
          .where((r) => r.uri.queryParameters['per_page'] != '1')
          .last;
      await _tap(tester, find.byKey(const Key('export-csv')));
      final export = server.where('GET', '/api/v1/employee/tasks/export');
      expect(export, hasLength(1));
      expect(withoutPaging(export.single), withoutPaging(list));
      expect(export.single.uri.queryParameters, {
        'month': 'all',
        // My tasks (the default scope), as the list.
        'assigned_to': '10',
        'search': 'Task',
        'project_id': '2',
        'sort': '-task_date',
      });
      expect(saved.single.fileName, 'tasks.csv');
      expect(
        utf8.decode(saved.single.bytes.sublist(3)),
        'Title\r\n"A, ""b"""\r\n',
      );
      expect(find.text('Saved tasks.csv.'), findsOneWidget);
      // Exporting never changes the list.
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    testWidgets('projects: search and status as the list', (tester) async {
      final server = await _pump(tester, saver: (_) async => true);
      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      await search(tester, 'Portal');
      await _tap(tester, find.text('All Status ⌄'));
      await _tap(tester, find.text('Completed').last);
      final list = server.where('GET', '/api/v1/employee/projects').last;
      await _tap(tester, find.byKey(const Key('export-csv')));
      final export = server
          .where('GET', '/api/v1/employee/projects/export')
          .single;
      expect(withoutPaging(export), withoutPaging(list));
      expect(export.uri.queryParameters, {
        'search': 'Portal',
        'status': 'completed',
      });
    });

    testWidgets('backlog: the project and the search box', (tester) async {
      final server = await _pump(
        tester,
        saver: (_) async => true,
        prepare: (s) => s.backlog.addAll([_task(8), _task(9)]),
      );
      await tester.tap(find.text('Sprints').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Backlog'));
      await search(tester, ' Task 8 ');
      expect(find.text('Task 8'), findsOneWidget);
      expect(find.text('Task 9'), findsNothing);
      await _tap(tester, find.byKey(const Key('export-csv')));
      final export = server
          .where('GET', '/api/v1/employee/sprints/backlog/export')
          .single;
      expect(export.uri.queryParameters, {
        'project_id': '2',
        'search': 'Task 8',
      });
      expect(find.text('Saved backlog.csv.'), findsOneWidget);
    });
  });

  group('layouts: RTL, dark, small phone with large text', () {
    final modes = <(String, Size, double, AppPreferences)>[
      (
        'Arabic dark 390x844',
        const Size(390, 844),
        1,
        const AppPreferences(
          language: LanguagePreference.arabic,
          appearance: AppearancePreference.dark,
        ),
      ),
      (
        'English light 320x640 x1.3',
        const Size(320, 640),
        1.3,
        const AppPreferences(),
      ),
    ];
    for (final (name, size, scale, prefs) in modes) {
      testWidgets('task form, task list and project details: $name', (
        tester,
      ) async {
        await _pump(tester, size: size, scale: scale, prefs: prefs);
        final arabic = prefs.language == LanguagePreference.arabic;
        BuildContext ctx() => tester.element(find.byType(Scaffold).first);

        unawaited(openApiTaskForm(ctx(), projectId: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('api-task-form')), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.byKey(const Key('api-task-form'))),
          ),
          arabic ? TextDirection.rtl : TextDirection.ltr,
        );
        // Save stays reachable at the end of the form.
        await tester.ensureVisible(find.byKey(const Key('form-save')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byKey(const Key('api-task-form'))))
            .pop();
        await tester.pumpAndSettle();

        unawaited(
          openApiTaskList(
            ctx(),
            title: 'Sprint 4 with a long name that has to wrap on small phones',
            subtitle: 'Active',
            query: const TaskQuery(scope: TaskScope.team, sprintId: 4),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('api-task-3')), findsOneWidget);
        await _tap(tester, find.byKey(const Key('api-task-list-back')));

        unawaited(
          showApiProjectDetails(
            ctx(),
            const ProjectRecord(
              id: 2,
              title: 'Portal',
              status: ApiProjectStatus.inProgress,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('project-related')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('project-task-3')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
