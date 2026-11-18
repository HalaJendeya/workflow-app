import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/presentation/conversations_screens.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/route_http_adapter.dart';
import '../../helpers/viewport.dart';

/// M10: a notification opens its task, conversation or meeting. The
/// `subject {type, id}` shapes and types were read live (read-only) on
/// 2026-11-17/18; every value here is a test double.

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, Object?> _n(
  String id,
  String title, {
  Map<String, Object?>? subject,
  bool read = false,
}) => {
  'id': id,
  'type': 'x',
  'category': 'x',
  'title': title,
  'message': 'Body of $title',
  'data': <String, Object>{},
  'subject': subject,
  'actor': null,
  'company_id': 3,
  'is_read': read,
  'read_at': read ? '2026-11-14T10:00:00Z' : null,
  'created_at': '2026-11-14T09:00:00Z',
};

void main() {
  group('subject → target', () {
    AppNotification n(Object? subject) =>
        AppNotification.fromJson({..._n('1', 't'), 'subject': subject});

    test('task, conversation and meeting with a numeric id', () {
      expect(n({'type': 'task', 'id': 13}).target, (
        kind: NotificationTargetKind.task,
        id: 13,
      ));
      expect(n({'type': 'conversation', 'id': '5'}).target, (
        kind: NotificationTargetKind.conversation,
        id: 5,
      ));
      expect(n({'type': 'meeting', 'id': 41}).target, (
        kind: NotificationTargetKind.meeting,
        id: 41,
      ));
    });

    test('unknown types, no id or no subject open nothing', () {
      expect(n({'type': 'invoice', 'id': 1}).target, isNull);
      expect(n({'type': 'task'}).target, isNull);
      expect(n({'type': 'task', 'id': 'x'}).target, isNull);
      expect(n(null).target, isNull);
    });
  });

  late RouteHttpAdapter http;

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, Object?>> items, {
    Portal portal = Portal.employee,
  }) async {
    useViewport(tester, const Size(390, 1400));
    await loadAppFonts();
    final role = portal.name;
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      Session(
        token: 'tkn',
        tokenType: 'Bearer',
        userId: 10,
        companyId: 3,
        portal: portal,
      ).toStorage(),
    );
    http = RouteHttpAdapter(
      {
        'GET /api/v1/$role/account': (200, ok({'id': 10, 'name': 'Me'})),
        'GET /api/v1/employee/tasks/13': (
          200,
          ok({'id': 13, 'title': 'Fix the login', 'status': 'todo'}),
        ),
        'GET /api/v1/$role/meetings/41': (
          200,
          ok({
            'id': 41,
            'title': 'Stand-up',
            'code': 'ABC-123',
            'type': 'instant',
            'status': 'ended',
          }),
        ),
      },
      handlers: {
        'GET /api/v1/$role/notifications': (RequestOptions o) => (
          200,
          ok({
            'notifications': items,
            'meta': {
              'current_page': 1,
              'last_page': 1,
              'per_page': 20,
              'total': items.length,
              'unread_count': items.where((n) => n['is_read'] == false).length,
            },
          }),
        ),
        for (final i in items)
          'POST /api/v1/$role/notifications/${i['id']}/read': (_) =>
              (200, ok({...i, 'is_read': true})),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
          ),
          sessionStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_Auth()),
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
  }

  List<String> sent() => [
    for (final r in http.requests) '${r.method} ${r.uri.path}',
  ];

  Future<void> tapHome(WidgetTester tester, String id) async {
    final f = find.byKey(Key('home-notification-$id'));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('a task notification is marked read and opens the task', (
    tester,
  ) async {
    await pump(tester, [
      _n('n1', 'Task assigned', subject: {'type': 'task', 'id': 13}),
    ]);
    expect(find.byKey(const Key('notification-opens')), findsOneWidget);
    await tapHome(tester, 'n1');
    expect(sent(), contains('POST /api/v1/employee/notifications/n1/read'));
    expect(sent(), contains('GET /api/v1/employee/tasks/13'));
    expect(find.byKey(const Key('task-details')), findsOneWidget);
    expect(find.text('Fix the login'), findsOneWidget);
    // Back returns to Home.
    await tester.tap(find.byKey(const Key('task-details-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-notification-n1')), findsOneWidget);
  });

  testWidgets('a read chat notification opens the chat without a write', (
    tester,
  ) async {
    await pump(tester, [
      _n(
        'n2',
        'New message',
        subject: {'type': 'conversation', 'id': 5},
        read: true,
      ),
    ]);
    await tapHome(tester, 'n2');
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(sent().where((s) => s.contains('/notifications/n2/read')), isEmpty);
  });

  testWidgets('a meeting notification opens the meeting', (tester) async {
    await pump(tester, [
      _n('n3', 'Invited', subject: {'type': 'meeting', 'id': 41}),
    ]);
    await tapHome(tester, 'n3');
    expect(find.byType(ApiMeetingDetailsScreen), findsOneWidget);
    expect(sent(), contains('GET /api/v1/employee/meetings/41'));
  });

  testWidgets('the bell panel opens the subject above the panel', (
    tester,
  ) async {
    await pump(tester, [
      _n('n1', 'Task assigned', subject: {'type': 'task', 'id': 13}),
    ]);
    await tester.tap(find.bySemanticsLabel('Notifications').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-n1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-details')), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-details-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
  });

  testWidgets('without a known subject a tap only marks read', (tester) async {
    await pump(tester, [
      _n('n4', 'Invoice paid', subject: {'type': 'invoice', 'id': 9}),
    ]);
    expect(find.byKey(const Key('notification-opens')), findsNothing);
    await tapHome(tester, 'n4');
    expect(sent(), contains('POST /api/v1/employee/notifications/n4/read'));
    expect(find.byKey(const Key('task-details')), findsNothing);
  });

  testWidgets('a client never opens a task (no client task route)', (
    tester,
  ) async {
    await pump(tester, [
      _n('n5', 'Task', subject: {'type': 'task', 'id': 13}, read: true),
    ], portal: Portal.client);
    expect(find.byKey(const Key('notification-opens')), findsNothing);
    expect(sent().where((s) => s.contains('/tasks/')), isEmpty);
  });
}
