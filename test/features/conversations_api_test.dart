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
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';

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

Map<String, dynamic> _message(int id, int sender, String name, String text) => {
  'id': id,
  'conversation_id': 1,
  'sender_id': sender,
  'message': text,
  'type': 'text',
  'status': 'sent',
  'created_at': '2026-11-05T10:0$id:00.000000Z',
  'created_at_human': '1 hour ago',
  'sender': {'id': sender, 'name': name, 'image': null},
  'attachments': <Object>[],
};

/// Shape of one row of GET /employee/conversations on the live server.
Map<String, dynamic> conversationRow({List<Object>? messages}) => {
  'id': 1,
  'company_id': 3,
  'type': 'team_chat',
  'is_group': true,
  'created_by': 7,
  'title': 'Design team',
  'image': null,
  'unread_count': 2,
  'last_message': _message(2, 9, 'Sara', 'See you at 3'),
  'last_message_at': '2026-11-05T10:02:00.000000Z',
  'avatar': null,
  'display_name': 'Design team',
  'users': [
    {'id': 7, 'name': 'Me', 'image': null},
    {'id': 9, 'name': 'Sara', 'image': null},
  ],
  'creator': {'id': 7, 'name': 'Me', 'image': null},
  'messages': ?messages,
};

void main() {
  group('repository', () {
    late FakeHttpAdapter http;
    ConversationsRepository repo(Portal p) => ConversationsRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        credentials: _Creds(),
        adapter: http,
      ),
      p,
    );
    setUp(() => http = FakeHttpAdapter());

    test('list maps the live row shape', () async {
      http.reply(200, ok([conversationRow()]));
      final list = await repo(Portal.employee).list();
      expect(http.last.path, '/api/v1/employee/conversations');
      expect(http.last.headers['X-Company'], '3');
      final c = list.single;
      expect(c.name, 'Design team');
      expect(c.isGroup, isTrue);
      expect(c.unread, 2);
      expect(c.members, ['Me', 'Sara']);
      expect(c.messages.single.text, 'See you at 3');
    });

    test('open reads data.conversation with oldest message first', () async {
      http.reply(
        200,
        ok({
          'conversation': conversationRow(
            messages: [
              _message(2, 9, 'Sara', 'second'),
              _message(1, 7, 'Me', 'first'),
            ],
          ),
          'receiver': null,
          'messages_meta': {'has_more': false, 'oldest_id': 1, 'newest_id': 2},
        }),
      );
      final c = await repo(Portal.client).open(1);
      expect(http.last.path, '/api/v1/client/conversations/1');
      expect(c.messages.map((m) => m.text), ['first', 'second']);
    });

    test('send posts multipart message text', () async {
      http.reply(200, ok({'message': _message(3, 7, 'Me', 'hello')}));
      await repo(Portal.client).send(1, 'hello');
      expect(http.last.method, 'POST');
      expect(http.last.path, '/api/v1/client/conversations/1/messages');
      final form = http.last.data as FormData;
      expect(
        {for (final f in form.fields) f.key: f.value},
        {'message': 'hello', 'type': 'text'},
      );
    });

    test('a non-member is refused with 403, not an empty chat', () async {
      http.reply(403, failure('You are not a member of this conversation.'));
      await expectLater(
        repo(Portal.employee).open(1),
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

  group('API mode screens', () {
    Future<RouteHttpAdapter> pump(
      WidgetTester tester, {
      required (int, Object?) sendReply,
    }) async {
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
      final http = RouteHttpAdapter({
        'GET /api/v1/employee/account': (
          200,
          ok({'id': 7, 'email': 'me@test.dev', 'name': 'Me'}),
        ),
        'GET /api/v1/employee/conversations': (200, ok([conversationRow()])),
        'GET /api/v1/employee/conversations/1': (
          200,
          ok({
            'conversation': conversationRow(
              messages: [
                _message(1, 7, 'Me', 'first'),
                _message(2, 9, 'Sara', 'See you at 3'),
              ],
            ),
          }),
        ),
        'POST /api/v1/employee/conversations/1/read': (200, ok(null)),
        'POST /api/v1/employee/conversations/1/messages': sendReply,
      });
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
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      return http;
    }

    testWidgets('list, open, mark read and send', (tester) async {
      final http = await pump(
        tester,
        sendReply: (200, ok({'message': _message(3, 7, 'Me', 'hi')})),
      );
      expect(find.text('Design team'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conversation-1')));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
      expect(
        http.requests.any(
          (r) => r.uri.path == '/api/v1/employee/conversations/1/read',
        ),
        isTrue,
      );

      await tester.enterText(find.byKey(const Key('chat-input')), 'hi');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(
        http.requests.where((r) => r.method == 'POST').map((r) => r.uri.path),
        contains('/api/v1/employee/conversations/1/messages'),
      );
    });

    testWidgets('a rejected send shows the error and keeps the text', (
      tester,
    ) async {
      await pump(
        tester,
        sendReply: (
          422,
          failure(
            'Validation Error',
            errors: {
              'message': ['The message field must not be greater than 5000.'],
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('conversation-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'hi');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget, reason: 'still in the input');
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
