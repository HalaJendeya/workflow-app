import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'conversations_api_test.dart' show conversationRow;
import 'meetings_api_test.dart' show meetingJson, page, participantJson;

/// M06: client conversations, meetings and notifications. Mocked HTTP only;
/// live checks were read-only GETs (no conversation, meeting or
/// notification exists for the QA client).

class _Creds implements ApiCredentials {
  @override
  String? token = 'tkn';
  @override
  int? companyId = 3;
  @override
  void onUnauthorized() {}
}

Matcher _kind(ApiFailureKind k) =>
    throwsA(isA<ApiException>().having((e) => e.kind, 'kind', k));

Map<String, dynamic> _msg(int id, String text, {int sender = 9}) => {
  'id': id,
  'conversation_id': 1,
  'sender_id': sender,
  'message': text,
  'type': 'text',
  'created_at':
      '2026-11-05T10:${(id % 60).toString().padLeft(2, '0')}:00.000000Z',
  'sender': {'id': sender, 'name': sender == 1 ? 'Me' : 'Sara', 'image': null},
  'attachments': <Object>[],
};

/// `GET …/messages`: `{success, message, data[], meta}` (not via the usual
/// envelope builder, but the same keys).
Map<String, dynamic> _messages(List<Object> rows, {bool hasMore = false}) => {
  'success': true,
  'message': 'OK',
  'data': rows,
  'meta': {'has_more': hasMore, 'oldest_id': null, 'newest_id': null},
};

Map<String, dynamic> _options({
  String type = 'client_chat',
  bool groups = false,
}) => ok({
  'role': 'client',
  'default_type': type,
  'can_create_group': groups,
  'users': [
    {'id': 9, 'name': 'Sara Khalil', 'image': null},
  ],
});

void main() {
  group('conversation contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late ConversationsRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = ConversationsRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
        Portal.client,
      );
    });

    test('messages: latest page, cursors and has_more', () async {
      http.reply(200, _messages([_msg(12, 'b'), _msg(11, 'a')], hasMore: true));
      final page = await repo.messages(1);
      expect(http.last.path, '/api/v1/client/conversations/1/messages');
      expect(http.last.queryParameters, {'limit': 30});
      expect(http.last.headers['X-Company'], '3');
      expect(page.messages.map((m) => m.id), [11, 12]);
      expect(page.hasMore, isTrue);

      http.reply(200, _messages(const []));
      await repo.messages(1, beforeId: 11);
      expect(http.last.queryParameters, {'limit': 30, 'before_id': 11});
      http.reply(200, _messages(const []));
      await repo.messages(1, afterId: 12);
      expect(http.last.queryParameters, {'limit': 30, 'after_id': 12});
    });

    test('messages: missing meta or has_more is invalid', () async {
      http.reply(200, _messages(const [])..remove('meta'));
      await expectLater(
        repo.messages(1),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(200, {
        ..._messages(const []),
        'meta': {'oldest_id': null},
      });
      await expectLater(
        repo.messages(1),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('messages: a conversation the caller is not in is a 404', () async {
      http.reply(404, failure('Conversation not found'));
      await expectLater(repo.messages(99), _kind(ApiFailureKind.notFound));
    });

    test('available-users: type, groups and people', () async {
      http.reply(200, _options());
      final o = await repo.availableUsers();
      expect(http.last.path, '/api/v1/client/conversations/available-users');
      expect(o.defaultType, 'client_chat');
      expect(o.canCreateGroup, isFalse);
      expect(o.users.single, (id: 9, name: 'Sara Khalil'));
    });

    test('available-users: missing default_type or users is invalid', () async {
      http.reply(200, ok({'can_create_group': false, 'users': <Object>[]}));
      await expectLater(
        repo.availableUsers(),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(
        200,
        ok({'default_type': 'client_chat', 'can_create_group': false}),
      );
      await expectLater(
        repo.availableUsers(),
        _kind(ApiFailureKind.invalidResponse),
      );
    });

    test('create: documented body, returns data.id', () async {
      http.reply(201, ok({'id': 77, 'users': <Object>[]}));
      final id = await repo.create(users: [9], type: 'client_chat');
      expect(http.last.method, 'POST');
      expect(http.last.path, '/api/v1/client/conversations');
      expect(http.lastJsonBody, {
        'users': [9],
        'type': 'client_chat',
      });
      expect(id, 77);
      http.reply(201, ok({'id': 78, 'users': <Object>[]}));
      await repo.create(users: [9, 10], type: 'team_chat', title: ' Team ');
      expect(http.lastJsonBody['title'], 'Team');
    });

    test('create: a 422 is surfaced, never a fake id', () async {
      http.reply(
        422,
        failure(
          'Validation Error',
          errors: {
            'users': ['The users field is required.'],
          },
        ),
      );
      await expectLater(
        repo.create(users: const [], type: 'client_chat'),
        _kind(ApiFailureKind.validation),
      );
    });
  });

  group('meeting join contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late MeetingsRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = MeetingsRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
        Portal.client,
      );
    });

    test('200: joined with the participant row', () async {
      http.reply(200, ok({'id': 55, 'connection_status': 'connected'}));
      final outcome = await repo.join(41);
      expect(http.last.method, 'POST');
      expect(http.last.path, '/api/v1/client/meetings/41/join');
      expect(
        outcome,
        isA<Joined>()
            .having((j) => j.participantId, 'participantId', 55)
            .having((j) => j.connectionStatus, 'status', 'connected'),
      );
    });

    test('202: a join request waits for the host', () async {
      http.reply(
        202,
        ok({
          'join_request': {'id': 5, 'status': 'pending'},
        }),
      );
      expect(await repo.join(41), isA<JoinRequested>());
    });

    test('200 without the participant fields is invalid', () async {
      http.reply(200, ok({'id': 55}));
      await expectLater(repo.join(41), _kind(ApiFailureKind.invalidResponse));
    });

    test('403 and 422 are typed failures', () async {
      http.reply(403, failure('Forbidden'));
      await expectLater(repo.join(41), _kind(ApiFailureKind.forbidden));
      http.reply(422, failure('The meeting has ended.'));
      await expectLater(repo.join(41), _kind(ApiFailureKind.validation));
    });

    test('leave: POST meeting-participants/{id}/leave', () async {
      http.reply(200, ok({'id': 55}));
      await repo.leave(55);
      expect(http.last.path, '/api/v1/client/meeting-participants/55/leave');
    });
  });

  group('notification contract (mocked HTTP)', () {
    late FakeHttpAdapter http;
    late ApiNotificationsRepository repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = ApiNotificationsRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
        Portal.client,
      );
    });

    Map<String, dynamic> inbox({Map<String, dynamic>? meta, Object? isRead}) =>
        ok({
          'notifications': [
            {
              'id': 'n1',
              'type': 'meeting',
              'category': 'meetings',
              'title': 'Invited',
              'message': 'You were invited',
              'data': <String, dynamic>{},
              'subject': null,
              'actor': null,
              'company_id': 3,
              'is_read': isRead ?? false,
              'read_at': null,
              'created_at': '2026-11-05T10:00:00.000000Z',
            },
          ],
          'meta':
              meta ??
              {
                'current_page': 1,
                'last_page': 1,
                'per_page': 20,
                'total': 1,
                'unread_count': 1,
              },
        });

    test('list reads the documented meta', () async {
      http.reply(200, inbox());
      final i = await repo.list();
      expect(http.last.path, '/api/v1/client/notifications');
      expect(i.unreadCount, 1);
      expect(i.items.single.isRead, isFalse);
    });

    test('a missing meta count is invalid, never 0', () async {
      http.reply(
        200,
        inbox(
          meta: {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
        ),
      );
      await expectLater(repo.list(), _kind(ApiFailureKind.invalidResponse));
    });

    test('is_read must be a boolean', () async {
      http.reply(200, inbox(isRead: 'no'));
      await expectLater(repo.list(), _kind(ApiFailureKind.invalidResponse));
    });

    test('unread-count and read-all require unread_count', () async {
      http.reply(200, ok(<String, dynamic>{}));
      await expectLater(
        repo.unreadCount(),
        _kind(ApiFailureKind.invalidResponse),
      );
      http.reply(200, ok({'updated': 2}));
      await expectLater(
        repo.markAllRead(),
        _kind(ApiFailureKind.invalidResponse),
      );
    });
  });

  group('screens (mocked API)', () {
    late RouteHttpAdapter http;
    late List<Object> older;
    late List<Object> newer;
    late (int, Object?) Function(RequestOptions) join;
    late (int, Object?) Function(RequestOptions) send;
    late bool pollFails;

    int count(String path) =>
        http.requests.where((r) => r.uri.path == path).length;
    RequestOptions last(String path) =>
        http.requests.lastWhere((r) => r.uri.path == path);

    Future<void> pump(
      WidgetTester tester, {
      Map<String, (int, Object?)> routes = const {},
    }) async {
      useViewport(tester, const Size(390, 844));
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
      older = [_msg(9, 'From last week')];
      newer = [];
      join = (_) => (200, ok({'id': 55, 'connection_status': 'connected'}));
      send = (_) => (
        200,
        ok({
          'message': {'id': 13, 'conversation_id': 1},
        }),
      );
      pollFails = false;
      http = RouteHttpAdapter(
        {
          'GET /api/v1/client/account': (
            200,
            ok({'id': 1, 'email': 'c@test.dev'}),
          ),
          'GET /api/v1/client/notifications': (
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
          'GET /api/v1/client/notifications/unread-count': (
            200,
            ok({'unread_count': 0}),
          ),
          'GET /api/v1/client/conversations/1': (
            200,
            ok({
              'conversation': conversationRow(messages: [_msg(10, 'Hello')]),
              'receiver': null,
            }),
          ),
          'POST /api/v1/client/conversations/1/read': (200, ok(null)),
          'POST /api/v1/client/conversations/1/messages': (
            200,
            ok({
              'message': {'id': 13, 'conversation_id': 1},
            }),
          ),
          'GET /api/v1/client/conversations/available-users': (200, _options()),
          'POST /api/v1/client/conversations': (
            201,
            ok({'id': 1, 'users': <Object>[]}),
          ),
          'GET /api/v1/client/meetings': (200, page([meetingJson()])),
          'GET /api/v1/client/meeting-invitations': (200, page(const [])),
          'GET /api/v1/client/meetings/41': (200, ok(meetingJson())),
          'GET /api/v1/client/meetings/41/participants': (
            200,
            page([participantJson(3, 'Hana Host', 'host')]),
          ),
          'POST /api/v1/client/meeting-participants/55/leave': (
            200,
            ok({'id': 55}),
          ),
          'PUT /api/v1/client/conversations/1': (200, ok({'id': 1})),
          'DELETE /api/v1/client/conversations/1': (200, ok(null)),
          ...routes,
        },
        handlers: {
          // Account A sees conversation 1; account B (another token or
          // company) sees none.
          'GET /api/v1/client/conversations': (o) =>
              o.headers['Authorization'] == 'Bearer tkn-a' &&
                  o.headers['X-Company'] == '3'
              ? (200, ok([conversationRow()]))
              : (200, ok(<Object>[])),
          'GET /api/v1/client/conversations/1/messages': (o) {
            final q = o.queryParameters;
            if (q.containsKey('before_id')) return (200, _messages(older));
            if (q.containsKey('after_id')) {
              if (pollFails) return (503, failure('Service Unavailable'));
              final rows = [...newer];
              newer = [];
              return (200, _messages(rows));
            }
            return (
              200,
              _messages([_msg(10, 'Hello'), _msg(11, 'Ready?')], hasMore: true),
            );
          },
          'POST /api/v1/client/meetings/41/join': (o) => join(o),
          'POST /api/v1/client/conversations/1/messages': (o) => send(o),
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                mode: AppMode.api,
                apiBaseUrl: 'https://api.test',
              ),
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

    Future<void> openChat(WidgetTester tester) async {
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('chat: latest page, load earlier, polling, no reload', (
      tester,
    ) async {
      await pump(tester);
      await openChat(tester);
      expect(find.text('Ready?'), findsOneWidget);
      expect(count('/api/v1/client/conversations/1/read'), 1);

      // Older history on demand (before_id = oldest loaded).
      await tester.tap(find.byKey(const Key('chat-load-earlier')));
      await tester.pumpAndSettle();
      expect(
        last('/api/v1/client/conversations/1/messages')
            .queryParameters['before_id'],
        10,
      );
      expect(find.text('From last week'), findsOneWidget);
      expect(find.byKey(const Key('chat-load-earlier')), findsNothing);

      // A poll brings a newer message and marks it read; the chat stays
      // on screen (no full reload, no spinner).
      newer = [_msg(12, 'New from Sara')];
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('New from Sara'), findsOneWidget);
      expect(
        last('/api/v1/client/conversations/1/messages')
            .queryParameters['after_id'],
        11,
      );
      expect(count('/api/v1/client/conversations/1/read'), 2);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);

      // Sending polls for the new message instead of reloading.
      newer = [_msg(13, 'On my way', sender: 1)];
      await tester.enterText(find.byKey(const Key('chat-input')), 'On my way');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('On my way'), findsOneWidget);
      expect(count('/api/v1/client/conversations/1'), 1);
      // Leaving the chat stops polling.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      final polls = count('/api/v1/client/conversations/1/messages');
      await tester.pump(const Duration(seconds: 30));
      expect(count('/api/v1/client/conversations/1/messages'), polls);
    });

    int gets(String path) => http.requests
        .where((r) => r.method == 'GET' && r.uri.path == path)
        .length;
    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
      for (final st in states) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
    }

    int polls() => http.requests
        .where(
          (r) =>
              r.uri.path == '/api/v1/client/conversations/1/messages' &&
              r.queryParameters.containsKey('after_id'),
        )
        .length;
    int sends() => http.requests
        .where(
          (r) =>
              r.method == 'POST' &&
              r.uri.path == '/api/v1/client/conversations/1/messages',
        )
        .length;

    testWidgets('chat: a refused send stays as "Not sent"; Retry sends it', (
      tester,
    ) async {
      await pump(tester);
      send = (_) => (503, failure('Service Unavailable'));
      await openChat(tester);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Draft');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      // The input is free for the next message; the refused one is in the
      // thread, marked, with Retry — not lost and not shown as delivered.
      expect(find.byKey(const Key('chat-message-failed')), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(sends(), 1);

      // The server is back and answers with the full message row: it shows
      // at once, once.
      send = (_) => (200, ok({'message': _msg(13, 'Draft', sender: 1)}));
      await tester.tap(find.byKey(const Key('chat-message-retry')));
      await tester.pumpAndSettle();
      expect(sends(), 2);
      expect(find.byKey(const Key('chat-message-failed')), findsNothing);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.byKey(const ValueKey('message-server-13')), findsOneWidget);
      // The next poll returns the same message: still one copy.
      newer = [_msg(13, 'Draft', sender: 1)];
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('chat: Discard drops a refused message without sending', (
      tester,
    ) async {
      await pump(tester);
      send = (_) => (422, failure('Validation Error'));
      await openChat(tester);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Oops');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-message-discard')));
      await tester.pumpAndSettle();
      expect(find.text('Oops'), findsNothing);
      expect(sends(), 1);
    });

    testWidgets('chat: a send never skips a message that arrived before it', (
      tester,
    ) async {
      await pump(tester);
      send = (_) => (200, ok({'message': _msg(13, 'Mine', sender: 1)}));
      await openChat(tester);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Mine');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      // Message 12 reached the server before mine (13): the next poll still
      // asks from 11.
      newer = [_msg(12, 'Between'), _msg(13, 'Mine', sender: 1)];
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      final q = http.requests
          .lastWhere((r) => r.queryParameters.containsKey('after_id'))
          .queryParameters;
      expect(q['after_id'], 11);
      expect(find.text('Between'), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
    });

    testWidgets('chat: offline polls say so quietly and recover', (
      tester,
    ) async {
      await pump(tester);
      await openChat(tester);
      pollFails = true;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      // The thread stays; only a line says the app is retrying.
      expect(find.byKey(const Key('chat-offline')), findsOneWidget);
      expect(find.text('Ready?'), findsOneWidget);
      pollFails = false;
      newer = [_msg(12, 'Back online')];
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-offline')), findsNothing);
      expect(find.text('Back online'), findsOneWidget);
    });

    testWidgets('chat: no polling in the background or under a sheet', (
      tester,
    ) async {
      await pump(tester);
      await openChat(tester);
      final before = polls();
      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(const Duration(seconds: 35));
      expect(polls(), before, reason: 'paused: no requests');
      // Back in the foreground: one catch-up poll at once.
      newer = [_msg(12, 'While away')];
      lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpAndSettle();
      expect(polls(), before + 1);
      expect(find.text('While away'), findsOneWidget);

      // The info sheet covers the chat: the timer skips.
      await tester.tap(find.byTooltip('Conversation info'));
      await tester.pumpAndSettle();
      final covered = polls();
      await tester.pump(const Duration(seconds: 25));
      expect(polls(), covered);
    });

    testWidgets('chat info: rename a group and delete it for me', (
      tester,
    ) async {
      await pump(tester);
      await openChat(tester);
      await tester.tap(find.byTooltip('Conversation info'));
      await tester.pumpAndSettle();
      expect(find.text('Me, Sara'), findsOneWidget, reason: 'participants');

      await tester.tap(find.byKey(const Key('conversation-rename')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('conversation-title')),
        'Launch team',
      );
      await tester.tap(find.byKey(const Key('conversation-title-save')));
      await tester.pumpAndSettle();
      final put = http.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.uri.path, '/api/v1/client/conversations/1');
      expect(put.data, {'title': 'Launch team'});
      expect(find.text('Conversation renamed.'), findsOneWidget);
      // The detail is read again (the new title), without a full-screen
      // spinner in between.
      expect(gets('/api/v1/client/conversations/1'), 2);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);

      await tester.tap(find.byTooltip('Conversation info'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-delete-for-me')));
      await tester.pumpAndSettle();
      // Confirmation first: nothing is deleted on the first tap.
      expect(http.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();
      expect(
        http.requests.where((r) => r.method == 'DELETE').single.uri.path,
        '/api/v1/client/conversations/1',
      );
      // Back on the list with the outcome.
      expect(find.byKey(const Key('chat-input')), findsNothing);
      expect(find.text('Conversation deleted for you.'), findsOneWidget);
    });

    testWidgets('chat info: a refused rename keeps the old name', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'PUT /api/v1/client/conversations/1': (403, failure('Forbidden')),
        },
      );
      await openChat(tester);
      await tester.tap(find.byTooltip('Conversation info'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-rename')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('conversation-title')), 'X');
      await tester.tap(find.byKey(const Key('conversation-title-save')));
      await tester.pumpAndSettle();
      expect(find.text("You don't have access to this."), findsOneWidget);
      expect(gets('/api/v1/client/conversations/1'), 1, reason: 'no reload');
      expect(find.byKey(const Key('conversation-rename')), findsOneWidget);
    });

    testWidgets('a failed history load shows Retry inside the chat', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'GET /api/v1/client/conversations/1/messages': (
            500,
            failure('Server Error'),
          ),
        },
      );
      http.handlers.remove('GET /api/v1/client/conversations/1/messages');
      await openChat(tester);
      // The conversation detail's own messages stay visible.
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byKey(const Key('api-error')), findsOneWidget);
    });

    testWidgets('the list refreshes in place every 30 s', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      final before = count('/api/v1/client/conversations');
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(count('/api/v1/client/conversations'), before + 1);
      expect(find.byKey(const Key('conversation-1')), findsOneWidget);
    });

    testWidgets('new conversation: client direct chat from available-users', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      // can_create_group is false for a client: no type or group name.
      expect(find.byKey(const Key('group-name')), findsNothing);
      expect(find.text('Conversation type'), findsNothing);
      await tester.tap(find.byKey(const Key('participant-9')));
      await tester.pumpAndSettle();
      final create = find.byKey(const Key('create-conversation'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      final post = last('/api/v1/client/conversations');
      expect(post.method, 'POST');
      expect(post.data, {
        'users': [9],
        'type': 'client_chat',
      });
      // The new conversation opens.
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
    });

    testWidgets('new conversation: a refused create stays on the form', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'POST /api/v1/client/conversations': (
            403,
            failure('You are not authorized to access this resource'),
          ),
        },
      );
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('participant-9')));
      await tester.pumpAndSettle();
      final create = find.byKey(const Key('create-conversation'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text("You don't have access to this."), findsOneWidget);
      expect(create, findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);
    });

    /// Scrolls [target] into view and clear of the floating navigation.
    Future<void> reveal(WidgetTester tester, Finder target) async {
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final r = tester.getRect(target);
      if (r.bottom > 844 - 130) {
        await tester.drag(scroll, Offset(0, 844 - 130 - r.bottom));
        await tester.pumpAndSettle();
      }
    }

    Future<void> openMeeting(WidgetTester tester) async {
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      final cat = find.byKey(const Key('category-Meetings'));
      await tester.ensureVisible(cat);
      await tester.pumpAndSettle();
      await tester.tap(cat);
      await tester.pumpAndSettle();
      final view = find.descendant(
        of: find.byKey(const Key('meeting-41')),
        matching: find.text('View Details'),
      );
      await reveal(tester, view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('participants')), findsOneWidget);
      await reveal(tester, find.byKey(const Key('meeting-join')));
    }

    testWidgets('meeting: join (200) says there is no audio/video; leave', (
      tester,
    ) async {
      await pump(tester);
      await openMeeting(tester);
      await tester.tap(find.byKey(const Key('meeting-join')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Audio and video aren't"), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-leave')));
      await tester.pumpAndSettle();
      expect(count('/api/v1/client/meeting-participants/55/leave'), 1);
      expect(find.text('You left the meeting.'), findsOneWidget);
      expect(find.byKey(const Key('meeting-join')), findsOneWidget);
    });

    testWidgets('meeting: 202 is a pending join request, not a join', (
      tester,
    ) async {
      await pump(tester);
      join = (_) => (
        202,
        ok({
          'join_request': {'id': 5, 'status': 'pending'},
        }),
      );
      await openMeeting(tester);
      await tester.tap(find.byKey(const Key('meeting-join')));
      await tester.pumpAndSettle();
      expect(find.textContaining('The host must admit you'), findsOneWidget);
      expect(find.byKey(const Key('meeting-leave')), findsNothing);
      expect(find.byKey(const Key('meeting-join')), findsNothing);
    });

    testWidgets('meeting: a refused join keeps the Join button', (
      tester,
    ) async {
      await pump(tester);
      join = (_) => (403, failure('Forbidden'));
      await openMeeting(tester);
      await tester.tap(find.byKey(const Key('meeting-join')));
      await tester.pumpAndSettle();
      expect(find.text("You don't have access to this."), findsOneWidget);
      expect(find.byKey(const Key('meeting-join')), findsOneWidget);
    });

    testWidgets('meeting: a pending request survives reopening; try again', (
      tester,
    ) async {
      await pump(tester);
      join = (_) => (
        202,
        ok({
          'join_request': {'id': 5, 'status': 'pending'},
        }),
      );
      await openMeeting(tester);
      await tester.tap(find.byKey(const Key('meeting-join')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meeting-join-again')), findsOneWidget);
      // Leave the details and come back: still pending, no fresh Join.
      Navigator.of(tester.element(find.byKey(const Key('participants')))).pop();
      await tester.pumpAndSettle();
      final view = find.descendant(
        of: find.byKey(const Key('meeting-41')),
        matching: find.text('View Details'),
      );
      await reveal(tester, view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('meeting-join-card')));
      expect(find.byKey(const Key('meeting-join')), findsNothing);
      expect(find.textContaining('The host must admit you'), findsOneWidget);
      int joins() => http.requests
          .where((r) => r.uri.path == '/api/v1/client/meetings/41/join')
          .length;
      expect(joins(), 1);

      // The host admitted the request: trying again joins.
      join = (_) => (200, ok({'id': 55, 'connection_status': 'connected'}));
      await tester.tap(find.byKey(const Key('meeting-join-again')));
      await tester.pumpAndSettle();
      expect(joins(), 2);
      expect(find.byKey(const Key('meeting-leave')), findsOneWidget);
    });

    testWidgets('meeting: a failed leave says why and keeps Leave', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'POST /api/v1/client/meeting-participants/55/leave': (
            500,
            failure('Server Error'),
          ),
        },
      );
      await openMeeting(tester);
      await tester.tap(find.byKey(const Key('meeting-join')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meeting-leave')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meeting-join-error')), findsOneWidget);
      expect(find.byKey(const Key('meeting-leave')), findsOneWidget);
    });

    testWidgets('meeting: an ended meeting offers no Join', (tester) async {
      await pump(
        tester,
        routes: {
          'GET /api/v1/client/meetings/41': (
            200,
            ok(meetingJson(status: 'ended', endedAt: '2026-10-22T10:00:00Z')),
          ),
        },
      );
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      final cat = find.byKey(const Key('category-Meetings'));
      await tester.ensureVisible(cat);
      await tester.pumpAndSettle();
      await tester.tap(cat);
      await tester.pumpAndSettle();
      final view = find.descendant(
        of: find.byKey(const Key('meeting-41')),
        matching: find.text('View Details'),
      );
      await reveal(tester, view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      // The details are open (participants card) and offer no Join.
      expect(find.byKey(const Key('participants')), findsOneWidget);
      expect(find.byKey(const Key('meeting-join-card')), findsNothing);
      // The client never asks for the per-meeting invitations route,
      // which does not exist for the client role.
      expect(count('/api/v1/client/meetings/41/invitations'), 0);
    });

    testWidgets('isolation: another account sees none of these chats', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation-1')), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkFlowApp)),
      );
      await container.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      final before = http.requests.length;
      await container
          .read(sessionControllerProvider.notifier)
          .login(email: 'b@test.dev', password: 'x', portal: Portal.client);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation-1')), findsNothing);
      final after = http.requests.skip(before).toList();
      expect(after, isNotEmpty);
      for (final r in after) {
        expect(r.headers['Authorization'], 'Bearer tkn-b');
        expect(r.headers['X-Company'], '4');
      }
    });
  });
}

/// Signs in account B (company 4); logout always succeeds.
class _Auth implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
    required Portal portal,
  }) async => const Session(
    token: 'tkn-b',
    tokenType: 'Bearer',
    userId: 2,
    companyId: 4,
    portal: Portal.client,
  );

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
