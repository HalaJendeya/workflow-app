import 'dart:convert';
import 'dart:io';
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
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/livekit_media_engine.dart';
import 'package:workflow_app/features/profile/presentation/profile_screen.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'conversations_api_test.dart' show conversationRow;

/// Regression for the failed Redmi 8 acceptance (2026-11-15): the user's
/// own taps, through the real shell, reach the implemented features — not a
/// placeholder. Mocked HTTP only; nothing is written to a server.

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, dynamic> _inbox(List<Object> items, {int unread = 0}) => ok({
  'notifications': items,
  'meta': {
    'current_page': 1,
    'last_page': 1,
    'per_page': 20,
    'total': items.length,
    'unread_count': unread,
  },
});

Map<String, dynamic> _notification(
  String id,
  String title, {
  bool read = false,
}) => {
  'id': id,
  'type': 'x',
  'category': 'x',
  'title': title,
  'message': 'Body of $title',
  'data': <String, Object>{},
  'subject': null,
  'actor': null,
  'company_id': 3,
  'is_read': read,
  'read_at': read ? '2026-11-14T10:00:00Z' : null,
  'created_at': '2026-11-14T09:00:00Z',
};

final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, //
]);

void main() {
  late RouteHttpAdapter http;

  int calls(String method, String path) => http.requests
      .where((r) => r.method == method && r.uri.path == path)
      .length;

  Future<void> pumpApi(
    WidgetTester tester, {
    Map<String, (int, Object?)> routes = const {},
    Future<OutgoingFile?> Function()? profilePicker,
  }) async {
    useViewport(tester, const Size(390, 844));
    await loadAppFonts();
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 'tkn',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 3,
        portal: Portal.client,
      ).toStorage(),
    );
    http = RouteHttpAdapter({
      'GET /api/v1/client/account': (
        200,
        ok({'id': 1, 'email': 'c@test.dev', 'name': 'Client QA'}),
      ),
      'GET /api/v1/client/notifications': (200, _inbox(const [])),
      'GET /api/v1/client/conversations': (200, ok([conversationRow()])),
      'GET /api/v1/client/conversations/1': (
        200,
        ok({
          'conversation': conversationRow(messages: const []),
          'receiver': null,
        }),
      ),
      'GET /api/v1/client/conversations/1/messages': (
        200,
        {
          'success': true,
          'message': 'OK',
          'data': <Object>[],
          'meta': {'has_more': false},
        },
      ),
      'POST /api/v1/client/conversations/1/read': (200, ok(null)),
      'GET /api/v1/client/meetings': (
        200,
        ok({
          'data': <Object>[],
          'current_page': 1,
          'last_page': 1,
          'per_page': 15,
          'total': 0,
        }),
      ),
      ...routes,
    });
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
          if (profilePicker != null)
            profileImagePickerProvider.overrideWithValue(profilePicker),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapBell(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Notifications').first);
    await tester.pumpAndSettle();
  }

  group('notifications bell (API mode)', () {
    testWidgets('opens the live inbox; an empty inbox says so', (tester) async {
      await pumpApi(tester);
      final before = calls('GET', '/api/v1/client/notifications');
      await tapBell(tester);
      expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
      expect(find.textContaining('No notifications yet'), findsOneWidget);
      expect(find.text('0 unread'), findsOneWidget);
      // Nothing to mark: no button that would send a write for nothing.
      expect(find.byKey(const Key('notifications-mark-all')), findsNothing);
      expect(calls('GET', '/api/v1/client/notifications'), greaterThan(0));
      expect(before, greaterThan(0), reason: 'the badge already read it');

      // The status filter asks the server.
      await tester.tap(find.byKey(const Key('notifications-filter-unread')));
      await tester.pumpAndSettle();
      final last = http.requests.lastWhere(
        (r) => r.uri.path == '/api/v1/client/notifications',
      );
      expect(last.queryParameters['status'], 'unread');
      expect(find.text('No unread notifications.'), findsOneWidget);
    });

    testWidgets('on another tab the bell opens the inbox, not Home', (
      tester,
    ) async {
      await pumpApi(
        tester,
        routes: {
          'GET /api/v1/client/notifications': (
            200,
            _inbox([
              _notification('n1', 'Invoice issued'),
              _notification('n2', 'Meeting moved', read: true),
            ], unread: 1),
          ),
          'POST /api/v1/client/notifications/n1/read': (
            200,
            ok(_notification('n1', 'Invoice issued', read: true)),
          ),
          'POST /api/v1/client/notifications/read-all': (
            200,
            ok({'updated': 0, 'unread_count': 0}),
          ),
        },
      );
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      await tapBell(tester);
      expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
      expect(find.byKey(const Key('notification-n1')), findsOneWidget);
      expect(find.byKey(const Key('notification-n2')), findsOneWidget);
      expect(find.text('1 unread'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(calls('POST', '/api/v1/client/notifications/n1/read'), 1);
      expect(find.text('0 unread'), findsOneWidget);
      // Still on the Chat tab underneath.
      Navigator.of(tester.element(find.byKey(const Key('notifications-panel'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation-1')), findsOneWidget);
    });

    testWidgets('a failed inbox shows the reason with Retry', (tester) async {
      await pumpApi(
        tester,
        routes: {
          'GET /api/v1/client/notifications': (503, failure('Unavailable')),
        },
      );
      await tapBell(tester);
      expect(find.byKey(const Key('notifications-error')), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);
    });
  });

  testWidgets('mock mode: the bell shows the demo inbox', (tester) async {
    useViewport(tester, const Size(390, 844));
    await loadAppFonts();
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 10,
        portal: Portal.client,
      ).toStorage(),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
          ),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await tapBell(tester);
    expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
    expect(find.byKey(const Key('notifications-empty')), findsNothing);
  });

  testWidgets('a live chat shows only controls that work', (tester) async {
    await pumpApi(tester);
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-1')));
    await tester.pumpAndSettle();
    // Calls happen in meetings; voice messages are not accepted; emoji
    // come from the keyboard: none of them is a dead button here.
    expect(find.byTooltip('Video call'), findsNothing);
    expect(find.byTooltip('Call'), findsNothing);
    expect(find.byKey(const Key('chat-mic')), findsNothing);
    expect(find.byKey(const Key('chat-emoji')), findsNothing);
    // Files and images still attach.
    expect(find.byKey(const Key('chat-attach')), findsOneWidget);
    expect(find.byKey(const Key('chat-image')), findsOneWidget);
  });

  testWidgets('API Meetings offers no create or join-by-code it cannot do', (
    tester,
  ) async {
    await pumpApi(tester);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    final cat = find.byKey(const Key('category-Meetings'));
    await tester.ensureVisible(cat);
    await tester.pumpAndSettle();
    await tester.tap(cat);
    await tester.pumpAndSettle();
    expect(find.text('join by code'), findsNothing);
    expect(find.byKey(const Key('create-fab')), findsNothing);
    expect(find.textContaining('LiveKit'), findsNothing);
    expect(find.textContaining('API'), findsNothing);
  });

  group('profile picture', () {
    Future<void> openProfile(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('build-info')), findsOneWidget);
      expect(find.text('API · api.test · build local'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-profile')));
      await tester.pumpAndSettle();
    }

    testWidgets('Upload New Image picks, checks and uploads', (tester) async {
      await pumpApi(
        tester,
        routes: {
          'POST /api/v1/client/account/image': (
            200,
            ok({
              'id': 1,
              'image': 'users/1.png',
              'image_url': 'https://api.test/storage/users/1.png',
            }),
          ),
        },
        profilePicker: () async => OutgoingFile(name: 'me.png', bytes: _png),
      );
      await openProfile(tester);
      final reads = calls('GET', '/api/v1/client/account');
      final upload = find.byKey(const Key('upload-image'));
      await tester.ensureVisible(upload);
      await tester.tap(upload);
      await tester.pumpAndSettle();
      final post = http.requests.lastWhere(
        (r) => r.uri.path == '/api/v1/client/account/image',
      );
      final form = post.data as FormData;
      expect(form.files.single.key, 'image');
      expect(form.files.single.value.contentType.toString(), 'image/png');
      expect(find.text('Profile picture updated.'), findsOneWidget);
      expect(calls('GET', '/api/v1/client/account'), greaterThan(reads));
    });

    testWidgets('a GIF or an oversized image is refused before upload', (
      tester,
    ) async {
      var next = OutgoingFile(
        name: 'anim.gif',
        bytes: Uint8List.fromList(ascii.encode('GIF89a......')),
      );
      await pumpApi(tester, profilePicker: () async => next);
      await openProfile(tester);
      final upload = find.byKey(const Key('upload-image'));
      await tester.ensureVisible(upload);
      await tester.tap(upload);
      await tester.pumpAndSettle();
      expect(find.textContaining('JPG, PNG or WebP'), findsOneWidget);
      next = OutgoingFile(
        name: 'big.png',
        bytes: Uint8List(2048 * 1024 + 1)..setAll(0, _png),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(upload);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 MB or less'), findsOneWidget);
      expect(calls('POST', '/api/v1/client/account/image'), 0);
    });
  });

  group('wiring of the shipped app', () {
    ProviderContainer container(AppMode mode) {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('API mode uses LiveKit, the file picker and the image picker', () {
      final c = container(AppMode.api);
      expect(c.read(mediaEngineProvider), isA<LiveKitMediaEngine>());
      expect(c.read(attachmentPickerProvider), isNotNull);
      expect(c.read(attachmentSaverProvider), isNotNull);
      expect(c.read(profileImagePickerProvider), isNotNull);
    });

    test('mock mode keeps the demo room (no media engine)', () {
      expect(container(AppMode.mock).read(mediaEngineProvider), isNull);
    });

    test('no shipped string claims a missing LiveKit client or picker', () {
      final en = jsonDecode(
        File('lib/l10n/arb/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final stale = RegExp(
        'LiveKit media client|needs (a file|an image) picker|'
        'meetings backend is (ready|available)|'
        'not supported in Flutter',
        caseSensitive: false,
      );
      final offenders = [
        for (final e in en.entries)
          if (e.value is String && stale.hasMatch(e.value as String)) e.key,
      ];
      expect(offenders, isEmpty);
    });
  });
}
