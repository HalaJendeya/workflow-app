import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';

/// API mode: My Tasks (the default) asks `GET /employee/tasks` with
/// `assigned_to` = the signed-in user and shows only rows assigned to them;
/// Team tasks drops the filter; a tap opens the details; status changes
/// follow `can.update`; one account or company never sees another's.

Map<String, dynamic> _task(
  int id, {
  required int? assignee,
  String status = 'todo',
  bool canUpdate = true,
  String? description = 'What this task is about.',
}) => {
  'id': id,
  'title': 'Task $id',
  'description': description,
  'status': status,
  'priority': 'high',
  'story_points': 3,
  'task_date': '2026-11-02',
  'start_time': '09:00:00',
  'end_time': '10:30:00',
  'assignee': assignee == null
      ? null
      : {'id': assignee, 'name': 'User $assignee'},
  'project': {'id': 2, 'title': 'Portal'},
  'sprint': {'id': 4, 'name': 'Sprint 4'},
  'can': {'update': canUpdate, 'delete': false},
};

/// Tasks per company; the server answers by the request's `X-Company`.
class _Server {
  final Map<String, List<Map<String, dynamic>>> tasks = {
    '3': [
      _task(3, assignee: 10, status: 'in_progress'),
      _task(4, assignee: 11),
      _task(5, assignee: 10, canUpdate: false, description: null),
    ],
    '4': [_task(8, assignee: 11)],
  };

  /// A server that ignores `assigned_to` (to prove the client checks rows).
  bool ignoreAssignee = false;

  /// Reply to update-status; null = success.
  (int, Object?)? moveReply;

  /// Fail `GET /employee/tasks/{id}`.
  bool failDetails = false;

  /// Whether the signed-in account leads a project (`led=1`): Team tasks
  /// is offered only then.
  bool leads = false;

  late final adapter = RouteHttpAdapter(
    const {},
    handlers: {
      'GET /api/v1/employee/projects/options': (o) {
        final led = '${o.queryParameters['led']}' == '1';
        return (
          200,
          ok([
            if (!led || leads) {'id': 2, 'title': 'Portal', 'leader_id': null},
          ]),
        );
      },
      'GET /api/v1/employee/tasks': (o) {
        final rows = _rows(o).where((t) {
          final a = o.queryParameters['assigned_to'];
          if (a == null || ignoreAssignee) return true;
          return (t['assignee'] as Map?)?['id'] == a;
        }).toList();
        final mine = rows.where((t) => t['status'] != 'completed');
        return (
          200,
          {
            ...ok({
              'current_page': 1,
              'data': rows,
              'last_page': 1,
              'per_page': 10,
              'total': rows.length,
            }),
            'stats': {
              'total': rows.length,
              'by_status': <String, int>{},
              'active': mine.length,
              'logged_minutes': 0,
            },
          },
        );
      },
      'POST /api/v1/employee/kanban/update-status': (o) {
        if (moveReply case final r?) return r;
        final body = o.data as Map;
        for (final t in _rows(o)) {
          if (t['id'] == body['task_id']) t['status'] = body['status'];
        }
        return (200, ok(<String, Object>{}));
      },
    },
  );

  List<Map<String, dynamic>> _rows(RequestOptions o) =>
      tasks['${o.headers['X-Company']}'] ?? const [];

  /// Details: answered per id from the company's rows.
  (int, Object?) details(RequestOptions o) {
    if (failDetails) return (503, failure('Unavailable'));
    final id = int.parse(o.uri.pathSegments.last);
    final t = _rows(o).where((t) => t['id'] == id).firstOrNull;
    return t == null ? (404, failure('Not found')) : (200, ok(t));
  }
}

/// Routes `GET /employee/tasks/{id}` (the adapter matches whole paths).
class _Adapter implements HttpClientAdapter {
  new(this.server);

  final _Server server;
  List<RequestOptions> get requests => server.adapter.requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final p = options.uri.path;
    if (options.method == 'GET' &&
        RegExp(r'^/api/v1/employee/tasks/\d+$').hasMatch(p)) {
      server.adapter.requests.add(options);
      return RouteHttpAdapter(
        const {},
        handlers: {'GET $p': server.details},
      ).fetch(options, null, cancelFuture);
    }
    return server.adapter.fetch(options, null, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

class _Auth implements AuthRepository {
  Session next = const Session(
    token: 'tkn-b',
    tokenType: 'Bearer',
    userId: 11,
    companyId: 4,
    portal: Portal.employee,
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
  bool leads = false,
}) async {
  useViewport(tester, size);
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
  final server = _Server()..leads = leads;
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
            adapter: _Adapter(server),
          ),
        ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return (server, auth);
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  final item = find.byKey(const Key('category-Tasks'));
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

List<RequestOptions> _taskLists(_Server s) => s.adapter.requests
    .where((r) => r.method == 'GET' && r.uri.path == '/api/v1/employee/tasks')
    .toList();

void main() {
  testWidgets('My Tasks is the default and asks for my tasks only', (
    tester,
  ) async {
    final (server, _) = await _pump(tester);
    await _openTasks(tester);
    expect(find.byKey(const Key('api-task-3')), findsOneWidget);
    expect(find.byKey(const Key('api-task-5')), findsOneWidget);
    expect(find.byKey(const Key('api-task-4')), findsNothing);
    // Rows and figures both ask for the signed-in user's tasks.
    final lists = _taskLists(server);
    expect(lists, isNotEmpty);
    for (final r in lists) {
      expect(r.queryParameters['assigned_to'], 10);
    }
    // The card: title, description, status; no code, sprint or points.
    final card = find.byKey(const Key('api-task-3'));
    expect(
      find.descendant(
        of: card,
        matching: find.text('What this task is about.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Sprint 4')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('#3')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('3 pts')),
      findsNothing,
    );
    // No description: nothing made up.
    expect(
      find.descendant(
        of: find.byKey(const Key('api-task-5')),
        matching: find.byKey(const Key('task-description')),
      ),
      findsNothing,
    );
  });

  testWidgets('Team tasks drops the filter; back to My Tasks restores it', (
    tester,
  ) async {
    final (server, _) = await _pump(tester, leads: true);
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('task-scope-team')));
    expect(find.byKey(const Key('api-task-4')), findsOneWidget);
    expect(
      _taskLists(server).last.queryParameters.containsKey('assigned_to'),
      isFalse,
    );
    await _tap(tester, find.byKey(const Key('task-scope-mine')));
    expect(find.byKey(const Key('api-task-4')), findsNothing);
  });

  testWidgets(
    'a server that ignores assigned_to: others are left out, said so',
    (tester) async {
      final (server, _) = await _pump(tester);
      server.ignoreAssignee = true;
      await _openTasks(tester);
      expect(find.byKey(const Key('api-task-4')), findsNothing);
      expect(find.byKey(const Key('tasks-hidden-notice')), findsOneWidget);
    },
  );

  testWidgets('tap opens full details; back returns to the list', (
    tester,
  ) async {
    final (server, _) = await _pump(tester);
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('api-task-3')));
    expect(find.byKey(const Key('task-details')), findsOneWidget);
    expect(
      server.adapter.requests.any(
        (r) => r.uri.path == '/api/v1/employee/tasks/3',
      ),
      isTrue,
    );
    for (final text in [
      'Portal',
      'Sprint 4',
      'High',
      'User 10',
      '3 pts',
      '1h 30m',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // Employees get no cost, and the API has no due date.
    expect(find.text('Due date'), findsNothing);
    // Edit/delete have no employee route in the app: no menu.
    expect(find.byKey(const Key('task-actions')), findsNothing);
    await _tap(tester, find.byKey(const Key('task-details-back')));
    expect(find.byKey(const Key('task-details')), findsNothing);
    expect(find.byKey(const Key('api-task-3')), findsOneWidget);
  });

  testWidgets('status change: allowed, sent, list refreshed', (tester) async {
    final (server, _) = await _pump(tester);
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('api-task-3')));
    await _tap(tester, find.byKey(const Key('task-change-status')));
    await _tap(tester, find.byKey(const Key('status-completed')));
    final move = server.adapter.requests.lastWhere(
      (r) => r.uri.path == '/api/v1/employee/kanban/update-status',
    );
    expect(move.data, {'task_id': 3, 'status': 'completed'});
    expect(find.text('Task status updated.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('task-details-status')),
        matching: find.text('Completed'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('status change refused by the server: message, status kept', (
    tester,
  ) async {
    final (server, _) = await _pump(tester);
    server.moveReply = (403, failure('This action is unauthorized.'));
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('api-task-3')));
    await _tap(tester, find.byKey(const Key('task-change-status')));
    await _tap(tester, find.byKey(const Key('status-completed')));
    // The refusal is reported (localized), not swallowed.
    expect(
      find.text("You don't have permission to perform this action."),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('task-details-status')),
        matching: find.text('In Progress'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('can.update false: no status control', (tester) async {
    await _pump(tester);
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('api-task-5')));
    expect(find.byKey(const Key('task-details')), findsOneWidget);
    expect(find.byKey(const Key('task-change-status')), findsNothing);
    expect(find.text('No description'), findsOneWidget);
  });

  testWidgets('details refresh fails: the row stays, with a retry', (
    tester,
  ) async {
    final (server, _) = await _pump(tester);
    server.failDetails = true;
    await _openTasks(tester);
    await _tap(tester, find.byKey(const Key('api-task-3')));
    expect(find.byKey(const Key('task-details-stale')), findsOneWidget);
    expect(find.byKey(const Key('task-details-title')), findsOneWidget);
    server.failDetails = false;
    await _tap(tester, find.text('Retry'));
    expect(find.byKey(const Key('task-details-stale')), findsNothing);
  });

  testWidgets('isolation: another account and company see only their tasks', (
    tester,
  ) async {
    final (server, _) = await _pump(tester);
    await _openTasks(tester);
    expect(find.byKey(const Key('api-task-3')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkFlowApp)),
    );
    await container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();
    final before = server.adapter.requests.length;
    await container
        .read(sessionControllerProvider.notifier)
        .login(email: 'x@test.dev', password: 'x', portal: Portal.employee);
    await tester.pumpAndSettle();
    await _openTasks(tester);
    expect(find.byKey(const Key('api-task-3')), findsNothing);
    expect(find.byKey(const Key('api-task-8')), findsOneWidget);
    final after = server.adapter.requests
        .skip(before)
        .where((r) => r.uri.path == '/api/v1/employee/tasks')
        .toList();
    expect(after, isNotEmpty);
    for (final r in after) {
      expect(r.headers['Authorization'], 'Bearer tkn-b');
      expect(r.headers['X-Company'], '4');
      expect(r.queryParameters['assigned_to'], 11);
    }
  });
}
