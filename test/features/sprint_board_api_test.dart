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
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

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

/// A task row with the field names of the task rules and of the live
/// sprint payload (values are fixtures; no cost, which the employee role
/// must not receive).
Map<String, dynamic> taskJson(int id, String status) => {
  'id': id,
  'project_id': 2,
  'sprint_id': 2,
  'assigned_to': 10,
  'title': 'Task $id',
  'description': 'd',
  'story_points': 3,
  'priority': 'urgent',
  'status': status,
  'task_date': '2026-11-02',
  'start_time': '19:50:00',
  'end_time': '21:00:00',
  'assignee': {'id': 10, 'name': 'Lina Dawood'},
  'project': {'id': 2, 'title': 'Portal'},
  'sprint': {'id': 2, 'name': 'Sprint 4'},
  'can': {'update': true, 'delete': false},
};

/// Live shape of GET /employee/kanban (2026-11-07), values are fixtures.
Map<String, dynamic> board({
  List<Object> tasks = const [],
  bool sprint = true,
}) => ok({
  'projects': [
    {'id': 2, 'title': 'Portal', 'leader_id': 4, 'leader_name': 'Lead'},
    {'id': 5, 'title': 'Mobile', 'leader_id': 4, 'leader_name': 'Lead'},
  ],
  'selected_project': {'id': 2, 'title': 'Portal', 'leader_id': 4},
  'sprint': sprint
      ? {
          'id': 2,
          'name': 'Sprint 4',
          'goal': null,
          'status': 'active',
          'start_date': '2026-11-01',
          'end_date': '2026-11-15',
        }
      : null,
  'tasks': tasks,
  'stats': {
    'points_total': 8,
    'points_done': 2,
    'percent_done': 25,
    'by_status': {'todo': 0, 'in_progress': 4, 'in_review': 0, 'completed': 2},
    'days_remaining': 8,
    'members': [
      {'id': 10, 'name': 'Lina', 'image': 'x'},
    ],
  },
  'burndown': <Object>[],
  'velocity': <Object>[],
});

/// Live shape of GET /employee/sprints.
Map<String, dynamic> planning({List<Object> backlog = const []}) => ok({
  'projects': [
    {'id': 2, 'title': 'Portal', 'leader_id': 4, 'leader_name': 'Lead'},
  ],
  'selected_project': {'id': 2, 'title': 'Portal', 'leader_id': 4},
  'sprints': [
    {
      'id': 2,
      'name': 'Sprint 4',
      'goal': null,
      'status': 'active',
      'start_date': '2026-11-01',
      'end_date': '2026-11-15',
      'stats': {
        'task_count': 6,
        'points_total': 8,
        'points_done': 2,
        'by_status': {
          'todo': 0,
          'in_progress': 4,
          'in_review': 0,
          'completed': 2,
        },
      },
    },
  ],
  'backlog': {
    'data': backlog,
    'current_page': 1,
    'last_page': 2,
    'per_page': 5,
    'total': 7,
  },
  'backlog_stats': {'count': 7, 'points': 12},
});

void main() {
  late FakeHttpAdapter http;
  BoardRepository repo() => BoardRepository(
    ApiClient(
      baseUrl: 'https://api.test',
      credentials: _Creds(),
      adapter: http,
    ),
  );
  setUp(() => http = FakeHttpAdapter());

  group('contract', () {
    test('task rows read the documented columns and relations', () {
      final t = ApiTask.fromJson(taskJson(7, 'in_progress'));
      expect(t.status, ApiTaskStatus.inProgress);
      expect(t.priority, TaskPriority.urgent);
      expect(t.storyPoints, 3);
      expect(t.duration, const Duration(minutes: 70));
      expect(t.assigneeName, 'Lina Dawood');
      expect(t.initials, 'LD');
      expect(t.sprintName, 'Sprint 4');
      expect(t.canUpdate, isTrue);
    });

    test('a row with only id and title still renders', () {
      final t = ApiTask.fromJson({'id': 1, 'title': 'x'});
      expect(t.status, ApiTaskStatus.other);
      expect(t.priority, isNull);
      expect(t.duration, isNull);
      expect(t.canUpdate, isNull);
    });

    test('create/update-only values are not renamed', () {
      // `waiting_review` and `done` exist only in the task create/update
      // rules; they are kept as unknown instead of being guessed.
      for (final v in ['waiting_review', 'done']) {
        final t = ApiTask.fromJson({'id': 1, 'title': 'x', 'status': v});
        expect(t.status, ApiTaskStatus.other);
        expect(t.rawStatus, v);
      }
    });

    test('a row without id is invalid', () {
      expect(
        () => ApiTask.fromJson({'title': 'x'}),
        throwsA(isA<ApiException>()),
      );
    });

    test('kanban payload maps sprint, stats and projects', () {
      final b = KanbanBoard.fromJson(
        board(tasks: [taskJson(1, 'todo')])['data'] as Map<String, dynamic>,
      );
      expect(b.projects.map((p) => p.title), ['Portal', 'Mobile']);
      expect(b.selectedProjectId, 2);
      expect(b.sprint!.name, 'Sprint 4');
      expect(b.byStatus[ApiTaskStatus.inProgress], 4);
      expect(b.percentDone, 25);
      expect(b.daysRemaining, 8);
      expect(b.memberCount, 1);
      expect(b.tasks.single.status, ApiTaskStatus.todo);
    });

    test('a project without a current sprint has a null sprint', () {
      final b = KanbanBoard.fromJson(
        board(sprint: false)['data'] as Map<String, dynamic>,
      );
      expect(b.sprint, isNull);
    });

    test('planning payload maps sprints and backlog stats', () {
      final p = SprintPlanning.fromJson(
        planning(backlog: [taskJson(9, 'backlog')])['data']
            as Map<String, dynamic>,
      );
      expect(p.sprints.single.taskCount, 6);
      expect(p.backlog.items.single.status, ApiTaskStatus.backlog);
      expect(p.backlogCount, 7);
      expect(p.backlogPoints, 12);
    });
  });

  group('repository', () {
    test('kanban sends project_id only when chosen', () async {
      http
        ..reply(200, board())
        ..reply(200, board());
      await repo().kanban();
      expect(http.last.path, '/api/v1/employee/kanban');
      expect(http.last.queryParameters, isEmpty);
      await repo().kanban(projectId: 5);
      expect(http.last.queryParameters, {'project_id': 5});
    });

    test('moving a task posts the kanban status values', () async {
      for (final _ in kanbanStatuses) {
        http.reply(200, ok({'id': 1}));
      }
      for (final s in kanbanStatuses) {
        await repo().updateStatus(1, s);
      }
      expect(http.requests.every((r) => r.method == 'POST'), isTrue);
      expect(http.requests.map((r) => (r.data as Map)['status']).toList(), [
        'backlog',
        'todo',
        'in_progress',
        'in_review',
        'completed',
      ]);
      expect(http.last.path, '/api/v1/employee/kanban/update-status');
      expect((http.last.data as Map)['task_id'], 1);
    });

    test('pending is not a kanban status and is never sent', () {
      expect(
        () => kanbanStatusParam(ApiTaskStatus.pending),
        throwsArgumentError,
      );
    });

    test('task rows use month=all and server filters', () async {
      http.reply(
        200,
        ok({
          'current_page': 1,
          'data': [taskJson(3, 'todo')],
          'last_page': 1,
          'per_page': 10,
          'total': 1,
        })..addAll({
          'stats': {'total': 1},
        }),
      );
      final p = await repo().tasks((
        search: ' login ',
        priority: TaskPriority.high,
        page: 2,
      ));
      expect(http.last.path, '/api/v1/employee/tasks');
      expect(http.last.queryParameters, {
        'month': 'all',
        'page': 2,
        'per_page': 10,
        'search': 'login',
        'priority': 'high',
      });
      expect(p.items.single.title, 'Task 3');
    });

    test('a 422 from update-status is surfaced', () async {
      http.reply(422, failure('The status field is invalid.'));
      await expectLater(
        repo().updateStatus(1, ApiTaskStatus.todo),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.validation,
          ),
        ),
      );
    });
  });

  Future<RouteHttpAdapter> pumpBoard(
    WidgetTester tester, {
    List<Object> tasks = const [],
    (int, Object?) move = (200, null),
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1600) * 3
      ..devicePixelRatio = 3;
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
    final adapter = RouteHttpAdapter({
      'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
      'GET /api/v1/employee/kanban': (200, board(tasks: tasks)),
      'GET /api/v1/employee/sprints': (
        200,
        planning(backlog: [taskJson(9, 'backlog')]),
      ),
      'POST /api/v1/employee/kanban/update-status': move.$2 == null
          ? (200, ok({'id': 1}))
          : move,
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
    await tester.tap(find.text('Sprints').last);
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('the board shows the server sprint and its columns', (
    tester,
  ) async {
    await pumpBoard(tester, tasks: [taskJson(1, 'in_progress')]);
    expect(find.textContaining('section is ready'), findsNothing);
    expect(find.text('Portal'), findsOneWidget);
    expect(find.byKey(const Key('sprint-summary')), findsOneWidget);
    expect(find.text('2 / 8 points · 25%'), findsOneWidget);
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
    // Whole-sprint count from stats, not just the visible cards.
    expect(
      find.descendant(
        of: find.byKey(const Key('column-count')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('column-inReview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-1')), findsNothing);
    expect(find.text('No tasks in this column'), findsOneWidget);
  });

  testWidgets('moving a card posts the new status and reloads', (tester) async {
    final adapter = await pumpBoard(
      tester,
      tasks: [taskJson(1, 'in_progress')],
    );
    final before = adapter.requests
        .where((r) => r.uri.path == '/api/v1/employee/kanban')
        .length;
    await tester.tap(find.byKey(const Key('kanban-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-inReview')));
    await tester.pumpAndSettle();
    final post = adapter.requests.lastWhere((r) => r.method == 'POST');
    expect(post.data, {'task_id': 1, 'status': 'in_review'});
    expect(find.text('Task status updated.'), findsOneWidget);
    expect(
      adapter.requests
          .where((r) => r.uri.path == '/api/v1/employee/kanban')
          .length,
      before + 1,
    );
  });

  testWidgets('a refused move shows the server error', (tester) async {
    await pumpBoard(
      tester,
      tasks: [taskJson(1, 'in_progress')],
      move: (403, failure('This action is unauthorized.')),
    );
    await tester.tap(find.byKey(const Key('kanban-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-completed')));
    await tester.pumpAndSettle();
    expect(find.text('Task status updated.'), findsNothing);
    expect(find.text("You don't have access to this."), findsOneWidget);
  });

  testWidgets('backlog tab lists the first backlog page and sprints', (
    tester,
  ) async {
    await pumpBoard(tester);
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-9')), findsOneWidget);
    expect(find.text('Sprints (1)'), findsOneWidget);
    expect(find.text('Showing 1 of 7 backlog tasks.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-sprint')));
    await tester.pump();
    expect(find.textContaining('no sprint create route'), findsOneWidget);
  });

  testWidgets('task rows come from the API with no sample data', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 2400) * 3
      ..devicePixelRatio = 3;
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
    final adapter = RouteHttpAdapter({
      'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
      'GET /api/v1/employee/dashboard': (
        200,
        ok({
          'myTasks': 1,
          'myHours': 1,
          'myMinutes': 10,
          'totalEarned': 0,
          'paidSalary': 0,
          'unpaidSalary': 0,
        }),
      ),
      'GET /api/v1/employee/projects': (
        200,
        ok({
          'current_page': 1,
          'data': <Object>[],
          'last_page': 1,
          'per_page': 1,
          'total': 0,
        }),
      ),
      'GET /api/v1/employee/tasks': (
        200,
        {
          ...ok({
            'current_page': 1,
            'data': [taskJson(3, 'in_progress')],
            'last_page': 1,
            'per_page': 10,
            'total': 1,
          }),
          'stats': {
            'total': 1,
            'by_status': {'in_progress': 1},
            'active': 1,
            'logged_minutes': 70,
          },
          'totals': <Object>[],
        },
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
    await tester.tap(find.byKey(const Key('category-Tasks')));
    await tester.pumpAndSettle();
    expect(find.textContaining('section is ready'), findsNothing);
    expect(find.byKey(const Key('api-task-3')), findsOneWidget);
    expect(find.text('Task 3'), findsOneWidget);
    expect(find.text('1h 10m'), findsOneWidget);
    // Demo rows never appear in API mode.
    expect(find.text('Integrate payment webhooks'), findsNothing);
  });
}
