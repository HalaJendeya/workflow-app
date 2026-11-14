import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';
import 'meetings_api_test.dart' as m;

const List<double> _scales = [1.0, 1.3];

const _longName = 'Customer Success & Billing Migration Working Group';
const _unbroken =
    'https://api.workflownets.com/api/v1/client/invoices/00000000000000000000'
    '0000000000/attachments/very_long_unbroken_file_name_without_spaces.pdf';

Map<String, dynamic> _message(int id, int sender, String text) => {
  'id': id,
  'conversation_id': 1,
  'sender_id': sender,
  'message': text,
  'type': 'text',
  'status': 'sent',
  'created_at':
      '2026-11-05T${(8 + id ~/ 60).toString().padLeft(2, '0')}:'
      '${(id % 60).toString().padLeft(2, '0')}:00.000000Z',
  'created_at_human': '1 hour ago',
  'sender': {'id': sender, 'name': sender == 1 ? 'Me' : 'Sara', 'image': null},
  'attachments': <Object>[],
};

Map<String, dynamic> _conversation(int id, {List<Object>? messages}) => {
  'id': id,
  'company_id': 2,
  'type': 'team_chat',
  'is_group': true,
  'created_by': 1,
  'title': id == 1 ? _longName : 'Team $id',
  'image': null,
  'unread_count': id.isOdd ? 12 : 0,
  'last_message': _message(2, 9, id == 1 ? _unbroken : 'See you at 3'),
  'last_message_at': '2026-11-05T10:02:00.000000Z',
  'avatar': null,
  'display_name': id == 1 ? _longName : 'Team $id',
  'users': [
    {'id': 1, 'name': 'Me', 'image': null},
    {'id': 9, 'name': 'Sara', 'image': null},
  ],
  'creator': {'id': 1, 'name': 'Me', 'image': null},
  'messages': ?messages,
};

Map<String, dynamic> _notification(int i, {bool read = false}) => {
  'id': 'n$i',
  'type': 'invoice.created',
  'category': 'finance',
  'title': i == 0
      ? 'Invoice #INV-2026-0234 for the Customer Portal Revamp is overdue'
      : 'Notification $i',
  'message': i == 0
      ? 'The invoice for the Customer Portal Revamp and Billing Migration '
            'project is now 14 days overdue. Please review the payment '
            'schedule with your account manager. $_unbroken'
      : 'Message $i',
  'data': <String, dynamic>{},
  'subject': null,
  'actor': null,
  'company_id': 2,
  'is_read': read,
  'read_at': read ? '2026-10-01T10:00:00Z' : null,
  'created_at': '2026-11-05T09:00:00Z',
};

enum _State { populated, empty, error }

/// Client API for chat, meetings, notifications and profile. Every request
/// is recorded; [gate] holds non-session responses open.
class _Server implements HttpClientAdapter {
  _State state = _State.populated;
  Completer<void>? gate;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    final path = o.uri.path;
    if (!path.endsWith('/account')) await gate?.future;
    final (status, body) = _reply(o.method, path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  (int, Object?) _reply(String method, String path) {
    if (path == '/api/v1/client/account') {
      return (
        200,
        ok({
          'id': 1,
          'name': 'Alexandria Johnson-Montgomery',
          'email': 'alexandria.johnson-montgomery@enterprise-example.com',
        }),
      );
    }
    if (method == 'POST') return (200, ok(null));
    if (state == _State.error) return (500, failure('Server Error'));
    final full = state == _State.populated;
    return switch (path) {
      '/api/v1/client/notifications' => (
        200,
        ok({
          'notifications': [
            if (full)
              for (var i = 0; i < 25; i++) _notification(i, read: i.isEven),
          ],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 20,
            'total': full ? 25 : 0,
            'unread_count': full ? 12 : 0,
          },
        }),
      ),
      '/api/v1/client/notifications/unread-count' => (
        200,
        ok({'unread_count': full ? 12 : 0}),
      ),
      '/api/v1/client/conversations' => (
        200,
        ok([
          if (full)
            for (var i = 1; i <= 12; i++) _conversation(i),
        ]),
      ),
      '/api/v1/client/conversations/1' => (
        200,
        ok({
          'conversation': _conversation(
            1,
            messages: [
              for (var i = 1; i <= 60; i++)
                _message(i, i.isEven ? 1 : 9, i == 30 ? _unbroken : 'Msg $i'),
            ],
          ),
        }),
      ),
      '/api/v1/client/meetings' => (
        200,
        m.page([
          if (full)
            for (var i = 41; i < 47; i++)
              {
                ...m.meetingJson(id: i),
                'title': i == 41 ? _longName : 'Meeting $i',
              },
        ]),
      ),
      '/api/v1/client/meetings/41' => (
        200,
        ok({...m.meetingJson(), 'title': _longName}),
      ),
      '/api/v1/client/meetings/41/participants' => (
        200,
        m.page([
          for (var i = 0; i < 20; i++)
            m.participantJson(i, i == 0 ? _longName : 'Person $i', 'member'),
        ]),
      ),
      '/api/v1/client/meeting-invitations' => (200, m.page(const [])),
      _ => (404, failure('Not found')),
    };
  }

  @override
  void close({bool force = false}) {}
}

Future<_Server?> _pump(
  WidgetTester tester,
  Size size,
  double scale, {
  AppMode mode = AppMode.api,
  _State state = _State.populated,
}) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 1,
      companyId: 2,
      portal: Portal.client,
    ).toStorage(),
  );
  final server = mode == AppMode.api ? (_Server()..state = state) : null;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        if (server != null)
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: server,
            ),
          ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

double _height(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

double _navTop(WidgetTester tester) {
  final home = find.text('Home').hitTestable();
  if (home.evaluate().isEmpty) return _height(tester);
  return tester.getRect(home.last).top - 46;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
    await tester.pumpAndSettle();
  }
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final limit = _navTop(tester) - 8;
  final r = tester.getRect(target);
  if (r.bottom > limit) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, limit - r.bottom),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _openMore(WidgetTester tester, String item) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(Key('category-$item')));
  await tester.tap(find.byKey(Key('category-$item')));
  await tester.pumpAndSettle();
}

/// Scrolls to the true end and checks no card is left under the floating
/// navigation surface.
Future<void> _checkEnd(WidgetTester tester, String shot) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  for (var i = 0; i < 20; i++) {
    final end = position.maxScrollExtent;
    position.jumpTo(end);
    await tester.pumpAndSettle();
    if (position.maxScrollExtent == end) break;
  }
  await screenshot(tester, shot);
  final navTop = _navTop(tester);
  for (final e in find.byType(ModuleCard).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.attached || !box.hasSize) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.bottom <= 0) continue;
    expect(
      r.bottom,
      lessThanOrEqualTo(navTop + 0.5),
      reason: 'a card ends under the navigation surface ($shot)',
    );
  }
}

Future<void> _openChat(WidgetTester tester, String key) async {
  await tester.tap(find.text('Chat').last);
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: name, value: size) in phoneViewports.entries) {
    for (final scale in _scales) {
      final tag = '${name}_x$scale';
      group('$name text x$scale', () {
        for (final mode in AppMode.values) {
          final mtag = '${mode.name}_$tag';
          testWidgets('${mode.name}: conversation list and chat', (
            tester,
          ) async {
            await _pump(tester, size, scale, mode: mode);
            await tester.tap(find.text('Chat').last);
            await tester.pumpAndSettle();
            await screenshot(tester, 'cl_chats_top_$mtag');
            // Avatar initials stay on one line inside their circle.
            for (final a in find.byType(WfAvatar).evaluate()) {
              final circle = (a.renderObject! as RenderBox).size;
              final label = find.descendant(
                of: find.byWidget(a.widget),
                matching: find.byType(RichText),
              );
              final p = tester.renderObject<RenderParagraph>(label.first);
              final lines = p
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: 0,
                      extentOffset: p.text.toPlainText().length,
                    ),
                  )
                  .map((b) => b.top.round())
                  .toSet()
                  .length;
              expect(lines, 1, reason: 'avatar initials wrapped');
              final r = tester.getRect(label.first);
              expect(r.width, lessThanOrEqualTo(circle.width));
            }
            // No empty description line between the title and search.
            final title = tester.getRect(find.text('Conversations').first);
            final search = tester.getRect(find.text('Searching....').first);
            expect(search.top - title.bottom, lessThan(60));
            await _checkEnd(tester, 'cl_chats_end_$mtag');

            await _openChat(
              tester,
              mode == AppMode.api ? 'conversation-1' : 'conversation-cv1',
            );
            await screenshot(tester, 'cl_chat_$mtag');
            // Composer reachable with the keyboard open.
            await tester.tap(find.byKey(const Key('chat-input')));
            showKeyboard(tester, size.height * 0.42);
            await tester.pumpAndSettle();
            final limit = size.height * 0.58 + 1;
            for (final k in ['chat-input', 'chat-send']) {
              expect(
                tester.getRect(find.byKey(Key(k))).bottom,
                lessThanOrEqualTo(limit),
              );
            }
            await screenshot(tester, 'cl_chat_keyboard_$mtag');
            tester.view.resetViewInsets();
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            // Oldest and newest messages can be reached.
            final list = find.byType(Scrollable).first;
            await tester.fling(list, const Offset(0, 4000), 4000);
            await tester.pumpAndSettle();
            await screenshot(tester, 'cl_chat_oldest_$mtag');
            await tester.fling(list, const Offset(0, -4000), 4000);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Back').first);
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('chat-input')), findsNothing);
          });

          testWidgets('${mode.name}: meetings list, details and calendar', (
            tester,
          ) async {
            await _pump(tester, size, scale, mode: mode);
            await _openMore(tester, 'Meetings');
            await screenshot(tester, 'cl_meetings_top_$mtag');
            // Month navigation keeps the calendar readable.
            final next = find.byTooltip('Next month');
            await _reveal(tester, next);
            await tester.tap(next);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Previous month'));
            await tester.pumpAndSettle();
            await _checkEnd(tester, 'cl_meetings_end_$mtag');

            final card = mode == AppMode.api
                ? find.byKey(const Key('meeting-41'))
                : find.byKey(const Key('meeting-m3'));
            await _reveal(tester, card);
            await tester.tap(
              find.descendant(of: card, matching: find.text('View Details')),
            );
            await tester.pumpAndSettle();
            await screenshot(tester, 'cl_meeting_details_$mtag');

            await _checkEnd(tester, 'cl_meeting_details_end_$mtag');
            await _reveal(tester, find.byKey(const Key('masthead-back')));
            await tester.tap(find.byKey(const Key('masthead-back')));
            await tester.pumpAndSettle();
            expect(card, findsOneWidget, reason: 'list restored after back');
          });
        }

        testWidgets('demo: meeting room controls and panels fit', (
          tester,
        ) async {
          await _pump(tester, size, scale, mode: AppMode.mock);
          await _openMore(tester, 'Meetings');
          await _reveal(tester, find.text('join by code').first);
          await tester.tap(find.text('join by code').first);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('join-code')),
            'BHU-232-CEK',
          );
          await tester.tap(find.byKey(const Key('form-save')));
          await tester.pumpAndSettle();
          for (final panel in ['Chat', 'Polls', 'Notes']) {
            await tester.tap(find.text(panel).first);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byTooltip('Participants').first);
          await tester.pumpAndSettle();
          await screenshot(tester, 'cl_room_participants_$tag');
          expect(find.byKey(const Key('room-leave')).hitTestable(), findsOne);
        });

        for (final mode in AppMode.values) {
          final mtag = '${mode.name}_$tag';
          testWidgets('${mode.name}: home notifications', (tester) async {
            await _pump(tester, size, scale, mode: mode);
            await screenshot(tester, 'cl_home_top_$mtag');
            await _checkEnd(tester, 'cl_home_end_$mtag');
          });

          testWidgets('${mode.name}: profile and More', (tester) async {
            await _pump(tester, size, scale, mode: mode);
            await tester.tap(find.byKey(const Key('account-menu')).first);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('account-profile')));
            await tester.pumpAndSettle();
            await screenshot(tester, 'cl_profile_top_$mtag');
            await _checkEnd(tester, 'cl_profile_end_$mtag');
            await _reveal(tester, find.byKey(const Key('masthead-back')));
            await tester.tap(find.byKey(const Key('masthead-back')));
            await tester.pumpAndSettle();

            await tester.tap(find.text('More').last);
            await tester.pumpAndSettle();
            await screenshot(tester, 'cl_more_top_$mtag');
            await _checkEnd(tester, 'cl_more_end_$mtag');
          });
        }
      });
    }
  }

  group('API states (360x740, text x1.3)', () {
    const size = Size(360, 740);

    testWidgets('chat keeps one copy of a message sent while loading', (
      tester,
    ) async {
      final server = await _pump(tester, size, 1.3);
      await _openChat(tester, 'conversation-1');
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      server!.gate = Completer<void>();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      server.gate!.complete();
      server.gate = null;
      await tester.pumpAndSettle();
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.uri.path.endsWith('/messages'),
        ),
        hasLength(1),
      );
    });

    testWidgets('conversation list empty and error states', (tester) async {
      final server = await _pump(tester, size, 1.3, state: _State.empty);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      // An empty inbox says so; it does not blame the filters.
      expect(find.text('No conversations yet.'), findsOneWidget);
      expect(find.text('No records match these filters'), findsNothing);
      await screenshot(tester, 'cl_chats_empty');
      server!.state = _State.error;
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      await screenshot(tester, 'cl_chats_error');
    });

    testWidgets('home notifications empty, error and retry', (tester) async {
      final server = await _pump(tester, size, 1.3, state: _State.error);
      await screenshot(tester, 'cl_home_error');
      server!.state = _State.populated;
      final retry = find.text('Retry');
      for (var i = 0; i < 10 && retry.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(retry, findsWidgets);
      for (var i = 0; i < 5 && retry.evaluate().isNotEmpty; i++) {
        await tester.ensureVisible(retry.first);
        await tester.pumpAndSettle();
        await tester.tap(retry.first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Notification 1'), findsWidgets);
    });

    testWidgets('tapping an unread notification only marks it read', (
      tester,
    ) async {
      final server = await _pump(tester, size, 1);
      final card = find.text('Notification 1');
      await _reveal(tester, card.first);
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(
        server!.requests
            .where((r) => r.method == 'POST')
            .map((r) => r.uri.path),
        ['/api/v1/client/notifications/n1/read'],
      );
      // Still on Home: no navigation to an unrelated screen.
      expect(find.text('Notification 1'), findsWidgets);
    });

    testWidgets('meetings loading then error with retry', (tester) async {
      final server = await _pump(tester, size, 1.3, state: _State.error);
      await _openMore(tester, 'Meetings');
      expect(find.byKey(const Key('api-error')), findsWidgets);
      server!.state = _State.populated;
      // Bounded: an unbounded "tap Retry until it is gone" loop hung the
      // first run of this suite forever when a retry did not recover.
      final retry = find.byKey(const Key('api-retry'));
      for (var i = 0; i < 5 && retry.evaluate().isNotEmpty; i++) {
        await _reveal(tester, retry.first);
        await tester.tap(retry.first);
        await tester.pumpAndSettle();
      }
      await screenshot(tester, 'cl_meetings_after_retry');
      expect(find.byKey(const Key('api-error')), findsNothing);
    });

    testWidgets('meeting details load each section once and keep scroll', (
      tester,
    ) async {
      final server = await _pump(tester, size, 1);
      await _openMore(tester, 'Meetings');
      final card = find.byKey(const Key('meeting-41'));
      await _reveal(tester, card);
      await tester.tap(
        find.descendant(of: card, matching: find.text('View Details')),
      );
      await tester.pumpAndSettle();
      int participantCalls() => server!.requests
          .where((r) => r.uri.path.endsWith('/meetings/41/participants'))
          .length;
      // Loaded when the page opens, not when scrolled to.
      expect(participantCalls(), 1);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      for (var i = 0; i < 3; i++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(position.pixels, position.maxScrollExtent);
        position.jumpTo(0);
        await tester.pumpAndSettle();
      }
      expect(participantCalls(), 1, reason: 'no refetch while scrolling');
    });

    testWidgets('rapid switching between communication screens', (
      tester,
    ) async {
      await _pump(tester, size, 1);
      for (var i = 0; i < 3; i++) {
        for (final tab in ['Chat', 'Home', 'More', 'Chat', 'Invoices']) {
          await tester.tap(find.text(tab).last);
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation-1')), findsOneWidget);
      expect(find.byKey(const Key('api-error')), findsNothing);
    });

    testWidgets('returning from a chat restores the list position', (
      tester,
    ) async {
      await _pump(tester, size, 1);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      final target = find.byKey(const Key('conversation-9'));
      await _reveal(tester, target);
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(after, closeTo(before, 1));
    });
  });
}
