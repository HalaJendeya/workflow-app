import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/application/session_scope.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/companies/data/client_companies_repository.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/data/meeting_media.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_media.dart';

/// C5 security fix: a request started in company A must never change what
/// company B shows. Every test holds a request at the HTTP double, switches
/// company (or signs out), then releases it, and checks that the late
/// answer is dropped, that no follow-up request leaves under the wrong
/// company, and that the request kept the company it was sent with. All
/// responses are test doubles; nothing is sent to a live server.

const _c = '/api/v1/client';

/// One recorded request: method, path, query and the X-Company it carried.
typedef _Sent = ({
  String method,
  String path,
  Map<String, String> query,
  String? company,
});

/// Answers by `METHOD /path`; a request whose key is in [hold] waits until
/// the test releases it. The handler sees the request's own X-Company, so
/// company A and B answer differently.
class GateServer implements HttpClientAdapter {
  new(this.routes);

  final Map<String, (int, Object?) Function(RequestOptions o, String? company)>
  routes;

  /// Armed holds (the next request to the key) and taken ones (a request
  /// waiting for [release]). Only that one request waits.
  final hold = <String, Completer<void>>{};
  final _waiting = <String, Completer<void>>{};
  final sent = <_Sent>[];

  /// Holds the next request to [key] until [release].
  void holdNext(String key) => hold[key] = Completer<void>();
  void release(String key) =>
      (_waiting.remove(key) ?? hold.remove(key))!.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    final key = '${o.method} ${o.uri.path}';
    final company = o.headers['X-Company'] as String?;
    sent.add((
      method: o.method,
      path: o.uri.path,
      query: o.uri.queryParameters,
      company: company,
    ));
    final gate = hold.remove(key);
    if (gate != null) {
      _waiting[key] = gate;
      await gate.future;
    }
    final handler = routes[key];
    final (status, body) = handler == null
        ? (
            404,
            {'success': false, 'message': 'Not found', 'errors': <Object>[]},
          )
        : handler(o, company);
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

Map<String, Object?> _meetingPage(List<Object> rows, {bool older = false}) =>
    ok({
      'current_page': 1,
      'last_page': older ? 2 : 1,
      'per_page': 30,
      'total': rows.length,
      'data': rows,
    });

Map<String, Object?> _mm(int id, String text) => {
  'id': id,
  'message': text,
  'attachments': <Object>[],
};

/// Meeting chat: company 3 has message 30, company 7 message 70; an
/// older page (`before_id`) answers with the company's own old message.
(int, Object?) _meetingMessages(RequestOptions o, String? co) {
  if (o.uri.queryParameters['before_id'] != null) {
    return (200, _meetingPage([_mm(co == '3' ? 3 : 7, 'old $co')]));
  }
  if (o.uri.queryParameters['after_id'] != null) {
    return (200, _meetingPage([_mm(co == '3' ? 31 : 71, 'new $co')]));
  }
  return (
    200,
    _meetingPage([_mm(co == '3' ? 30 : 70, 'first $co')], older: true),
  );
}

Map<String, Object?> _cm(int id, String text, {int sender = 9}) => {
  'id': id,
  'sender_id': sender,
  'sender': {'id': sender, 'name': 'Someone'},
  'message': text,
  'created_at': '2026-11-20T10:00:${id.toString().padLeft(2, '0')}Z',
  'attachments': <Object>[],
};

/// Conversation 5: company 3 holds 30 (+ older 3, newer 31), company 7
/// holds 70 (+ older 7, newer 71).
(int, Object?) _convMessages(RequestOptions o, String? co) {
  final q = o.uri.queryParameters;
  final List<Object> rows;
  var more = false;
  if (q['before_id'] != null) {
    rows = [_cm(co == '3' ? 3 : 7, 'old $co')];
  } else if (q['after_id'] != null) {
    rows = [_cm(co == '3' ? 31 : 71, 'new $co')];
  } else {
    rows = [_cm(co == '3' ? 30 : 70, 'first $co')];
    more = true;
  }
  return (
    200,
    {
      'success': true,
      'message': 'OK',
      'data': rows,
      'meta': {'has_more': more, 'oldest_id': null, 'newest_id': null},
    },
  );
}

Map<String, Object?> _notification(String id, {bool read = false}) => {
  'id': id,
  'is_read': read,
  'type': 'x',
  'category': 'x',
  'data': <String, Object>{},
  'subject': null,
  'actor': null,
  'title': 'n $id',
};

(int, Object?) _notifications(RequestOptions o, String? co) {
  final page = int.parse(o.uri.queryParameters['page'] ?? '1');
  return (
    200,
    ok({
      'notifications': [_notification('$co-p$page')],
      'meta': {
        'current_page': page,
        'last_page': 2,
        'total': 2,
        'unread_count': 2,
      },
    }),
  );
}

final _routes = <String, (int, Object?) Function(RequestOptions, String?)>{
  'GET $_c/meetings/41/messages': _meetingMessages,
  'POST $_c/meetings/41/messages': (_, co) => (201, ok({'id': 99})),
  'GET $_c/meeting-polls/5': (_, co) => (
    200,
    ok({
      'id': 5,
      'options': [
        {'id': 51, 'title': 'A'},
      ],
    }),
  ),
  'GET $_c/meetings/41/polls': (_, co) => (200, ok(<Object>[])),
  'POST $_c/meeting-polls/5/vote': (_, co) =>
      (200, ok({'id': 5, 'total_votes': 4})),
  'POST $_c/meetings/41/join': (_, co) =>
      (200, ok({'id': 600, 'connection_status': 'connected'})),
  'GET $_c/meetings/41/participants': (_, co) => (
    200,
    ok({
      'current_page': 1,
      'last_page': 1,
      'per_page': 100,
      'total': 0,
      'data': <Object>[],
    }),
  ),
  'GET $_c/conversations/5/messages': _convMessages,
  'GET $_c/notifications': _notifications,
  'POST $_c/notifications/3-p1/read': (_, co) =>
      (200, ok(_notification('3-p1', read: true))),
  'POST $_c/notifications/read-all': (_, co) => (200, ok({'unread_count': 0})),
  'GET $_c/dashboard': (_, co) => (
    200,
    ok({'projectsCount': 1, 'projectsCompleted': 0, 'projectsInProgress': 1}),
  ),
  'POST $_c/meetings/41/media/join': (_, co) => (
    200,
    ok({
      'participant': {'id': 600},
      'media': {
        'token': 'lk-token',
        'url': 'wss://media.example.test',
        'room': 'room-$co',
      },
    }),
  ),
  'POST $_c/meetings/41/media/leave': (_, co) => (
    200,
    ok({
      'participant': {'id': 600},
    }),
  ),
  'POST /api/v1/logout': (_, co) => (200, ok(null)),
};

late GateServer server;
late ProviderContainer c;
late FakeMediaEngine engine;

Future<void> _boot({List<Override> extra = const []}) async {
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 1,
      companyId: 3,
      portal: Portal.client,
    ).toStorage(),
  );
  server = GateServer(_routes);
  engine = FakeMediaEngine();
  c = ProviderContainer(
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
          adapter: server,
        ),
      ),
      mediaEngineProvider.overrideWithValue(engine),
      deviceIdStoreProvider.overrideWithValue(MemoryDeviceIdStore()),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  await c.read(sessionControllerProvider.future);
}

Future<void> _switchTo(int company) =>
    c.read(sessionControllerProvider.notifier).switchCompany(company);

/// Keeps [p] alive for the test, as a screen watching it would.
void _keep(ProviderListenable<Object?> p) {
  final sub = c.listen(p, (_, _) {});
  addTearDown(sub.close);
}

/// Requests sent after [from] (an index into the record).
Iterable<_Sent> _after(int from) => server.sent.skip(from);

void main() {
  setUp(_boot);

  group('scope token', () {
    test('a new scope on every switch, also A → B → A and sign-out', () async {
      final a1 = c.read(sessionScopeProvider);
      expect(c.read(sessionScopeProvider), same(a1), reason: 'stable');
      await _switchTo(7);
      await _switchTo(3);
      final a2 = c.read(sessionScopeProvider);
      expect((a2.userId, a2.companyId), (1, 3));
      expect(a2, isNot(same(a1)), reason: 'A → B → A is not the old A');
      await c.read(sessionControllerProvider.notifier).logout();
      expect(c.read(sessionScopeProvider).userId, isNull);
    });
  });

  group('meeting chat (the reproduced leak)', () {
    Future<void> open() async {
      _keep(meetingChatProvider(41));
      await c.read(meetingChatProvider(41).future);
    }

    MeetingChat chatOf() => c.read(meetingChatProvider(41).notifier);

    List<String?> texts() => [
      for (final m in c.read(meetingChatProvider(41)).value!.items) m.text,
    ];

    test('an older page asked in A is dropped after switching to B', () async {
      await open();
      final chat = chatOf();
      expect(texts(), ['first 3']);
      server.holdNext('GET $_c/meetings/41/messages');
      final earlier = chat.loadEarlier();
      await pumpEventQueue();
      await _switchTo(7);
      expect(
        (await c.read(meetingChatProvider(41).future)).items.single.id,
        70,
      );
      server.release('GET $_c/meetings/41/messages');
      await earlier;
      await pumpEventQueue();
      expect(texts(), ['first 7'], reason: 'nothing of company 3');
      final held = server.sent.firstWhere((r) => r.query['before_id'] != null);
      expect(held.company, '3', reason: 'sent with its own company');
    });

    test('a refresh asked in A is dropped after switching to B', () async {
      await open();
      final chat = chatOf();
      server.holdNext('GET $_c/meetings/41/messages');
      final refresh = chat.refresh();
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(meetingChatProvider(41).future);
      server.release('GET $_c/meetings/41/messages');
      await refresh;
      await pumpEventQueue();
      expect(texts(), ['first 7']);
    });

    test(
      'rapid A → B → A: an answer from the first A is still dropped',
      () async {
        await open();
        final chat = chatOf();
        server.holdNext('GET $_c/meetings/41/messages');
        final earlier = chat.loadEarlier();
        await pumpEventQueue();
        await _switchTo(7);
        await c.read(meetingChatProvider(41).future);
        await _switchTo(3);
        await c.read(meetingChatProvider(41).future);
        server.release('GET $_c/meetings/41/messages');
        await earlier;
        await pumpEventQueue();
        expect(texts(), ['first 3'], reason: 'no older page merged');
      },
    );

    test('same company: earlier pages and refreshes still apply', () async {
      await open();
      final chat = chatOf();
      await chat.loadEarlier();
      await chat.refresh();
      expect(texts(), ['old 3', 'first 3', 'new 3']);
    });
  });

  group('C4 send and vote', () {
    test('a send answered after the switch: no outcome, no re-read', () async {
      _keep(meetingChatProvider(41));
      _keep(meetingMessageSenderProvider(41));
      await c.read(meetingChatProvider(41).future);
      server.holdNext('POST $_c/meetings/41/messages');
      final sending = c
          .read(meetingMessageSenderProvider(41).notifier)
          .send(text: 'Hi');
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(meetingChatProvider(41).future);
      final mark = server.sent.length;
      server.release('POST $_c/meetings/41/messages');
      expect(await sending, isFalse);
      await pumpEventQueue();
      final sender = c.read(meetingMessageSenderProvider(41));
      expect(sender.value, isNull, reason: 'no "sent" shown under B');
      expect(sender.hasError, isFalse);
      expect(_after(mark), isEmpty, reason: 'no refresh, no retry');
      final post = server.sent.singleWhere((r) => r.method == 'POST');
      expect(post.company, '3');
    });

    test('a vote answered after the switch: no result, no re-read', () async {
      _keep(pollVoterProvider(5));
      server.holdNext('POST $_c/meeting-polls/5/vote');
      final voting = c
          .read(pollVoterProvider(5).notifier)
          .vote(meetingId: 41, optionIds: [51]);
      await pumpEventQueue();
      await _switchTo(7);
      final mark = server.sent.length;
      server.release('POST $_c/meeting-polls/5/vote');
      expect(await voting, isFalse);
      await pumpEventQueue();
      expect(c.read(pollVoterProvider(5)).value, isNull);
      expect(_after(mark), isEmpty);
    });

    test('same company: send refreshes, vote re-reads', () async {
      _keep(meetingChatProvider(41));
      _keep(meetingMessageSenderProvider(41));
      _keep(pollVoterProvider(5));
      await c.read(meetingChatProvider(41).future);
      expect(
        await c.read(meetingMessageSenderProvider(41).notifier).send(text: 'x'),
        isTrue,
      );
      expect(server.sent.last.query['after_id'], '30');
      expect(
        await c
            .read(pollVoterProvider(5).notifier)
            .vote(meetingId: 41, optionIds: [51]),
        isTrue,
      );
      expect(c.read(pollVoterProvider(5)).value?.totalVotes, 4);
    });
  });

  group('conversation thread', () {
    Future<void> open() async {
      _keep(conversationThreadProvider(5));
      await c.read(conversationThreadProvider(5).future);
    }

    ConversationThread threadOf() =>
        c.read(conversationThreadProvider(5).notifier);

    List<int> ids() => [
      for (final m in c.read(conversationThreadProvider(5)).value!.messages)
        m.id,
    ];

    test('paging and polling from A never land in B', () async {
      await open();
      final thread = threadOf();
      server.holdNext('GET $_c/conversations/5/messages');
      final earlier = thread.loadEarlier();
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(conversationThreadProvider(5).future);
      server.release('GET $_c/conversations/5/messages');
      await earlier;
      await pumpEventQueue();
      expect(ids(), [70]);

      // A poll held across a switch back: dropped, and the poll that
      // waits for it (fresh) asks nothing more under the new company.
      server.holdNext('GET $_c/conversations/5/messages');
      final running = thread.poll();
      final fresh = thread.poll(fresh: true);
      await pumpEventQueue();
      await _switchTo(3);
      await c.read(conversationThreadProvider(5).future);
      final mark = server.sent.length;
      server.release('GET $_c/conversations/5/messages');
      expect(await running, 0);
      expect(await fresh, 0);
      await pumpEventQueue();
      expect(ids(), [30]);
      expect(_after(mark), isEmpty, reason: 'no follow-up poll');
    });

    test("overlapping: a page started in B is not merged into A's", () async {
      await open();
      final thread = threadOf();
      server.holdNext('GET $_c/conversations/5/messages');
      final inA = thread.loadEarlier();
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(conversationThreadProvider(5).future);
      // B asks for its own older page; it must not join A's request.
      final inB = thread.loadEarlier();
      await pumpEventQueue();
      expect(
        server.sent
            .where((r) => r.query['before_id'] != null)
            .map((r) => r.company),
        ['3', '7'],
      );
      await inB;
      server.release('GET $_c/conversations/5/messages');
      await inA;
      await pumpEventQueue();
      expect(ids(), [7, 70]);
    });

    test('a sent message from A is not added in B', () async {
      await open();
      final scopeA = c.read(sessionScopeProvider);
      await _switchTo(7);
      await c.read(conversationThreadProvider(5).future);
      c
          .read(conversationThreadProvider(5).notifier)
          .addSent(
            ApiMessage.fromJson(_cm(32, 'mine', sender: 1)),
            scope: scopeA,
          );
      expect(ids(), [70]);
    });

    test('same company: paging and polling still apply', () async {
      await open();
      final thread = threadOf();
      await thread.loadEarlier();
      expect(await thread.poll(), 1);
      expect(ids(), [3, 30, 31]);
    });
  });

  group('meeting join', () {
    test('a join answered after the switch is not applied', () async {
      _keep(meetingJoinProvider(41));
      server.holdNext('POST $_c/meetings/41/join');
      final joining = c.read(meetingJoinProvider(41).notifier).join();
      await pumpEventQueue();
      await _switchTo(7);
      final mark = server.sent.length;
      server.release('POST $_c/meetings/41/join');
      await joining;
      await pumpEventQueue();
      expect(c.read(meetingJoinProvider(41)).outcome, isNull);
      expect(c.read(meetingJoinProvider(41)).busy, isFalse);
      expect(_after(mark), isEmpty, reason: 'no participants re-read');
    });
  });

  group('notifications', () {
    final all = notificationsControllerProvider(NotificationFilter.all);

    List<String> idsOf() => [for (final n in c.read(all).value!.items) n.id];

    test('load more, mark read and mark all from A are dropped in B', () async {
      _keep(all);
      await c.read(all.future);
      expect(idsOf(), ['3-p1']);

      server.holdNext('GET $_c/notifications');
      final more = c.read(all.notifier).loadMore();
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(all.future);
      server.release('GET $_c/notifications');
      await more;
      await pumpEventQueue();
      expect(idsOf(), ['7-p1'], reason: 'no page 2 of company 3');

      await _switchTo(3);
      await c.read(all.future);
      server.holdNext('POST $_c/notifications/3-p1/read');
      final marking = c.read(all.notifier).markRead('3-p1');
      await pumpEventQueue();
      await _switchTo(7);
      await c.read(all.future);
      final mark = server.sent.length;
      server.release('POST $_c/notifications/3-p1/read');
      await marking;
      await pumpEventQueue();
      expect(idsOf(), ['7-p1']);
      expect(c.read(all).value!.unreadCount, 2);
      expect(_after(mark), isEmpty, reason: 'no reload of other filters');

      server.holdNext('POST $_c/notifications/read-all');
      final markAll = c.read(all.notifier).markAllRead();
      await pumpEventQueue();
      await _switchTo(3);
      await c.read(all.future);
      expect(c.read(all).value!.items.single.isRead, isFalse);
      server.release('POST $_c/notifications/read-all');
      await markAll;
      await pumpEventQueue();
      expect(c.read(all).value!.items.single.isRead, isFalse);
    });

    test("a reload (polling the inbox) in A is replaced by B's", () async {
      _keep(all);
      await c.read(all.future);
      server.holdNext('GET $_c/notifications');
      c.read(all.notifier).refreshIfStale(DateTime(2100));
      await pumpEventQueue();
      await _switchTo(7);
      final b = await c.read(all.future);
      server.release('GET $_c/notifications');
      await pumpEventQueue();
      expect(b.items.single.id, '7-p1');
      expect(idsOf(), ['7-p1']);
    });

    test('same company: load more and mark read still apply', () async {
      _keep(all);
      await c.read(all.future);
      await c.read(all.notifier).loadMore();
      expect(idsOf(), ['3-p1', '3-p2']);
      await c.read(all.notifier).markRead('3-p1');
      expect(c.read(all).value!.items.first.isRead, isTrue);
    });
  });

  group('meeting media', () {
    test('media/join answered after the switch: no room; its own company '
        'is told the device left', () async {
      _keep(meetingMediaProvider(41));
      server.holdNext('POST $_c/meetings/41/media/join');
      final joining = c.read(meetingMediaProvider(41).notifier).join();
      await pumpEventQueue();
      await pumpEventQueue();
      await _switchTo(7);
      server.release('POST $_c/meetings/41/media/join');
      await joining;
      await pumpEventQueue();
      expect(engine.rooms, isEmpty, reason: 'no room opened under B');
      expect(c.read(meetingMediaProvider(41)).phase, MediaPhase.idle);
      final leave = server.sent.singleWhere(
        (r) => r.path.endsWith('/media/leave'),
      );
      expect(leave.company, '3', reason: 'the company it joined in');
      expect(
        server.sent
            .where((r) => r.path.endsWith('/media/join'))
            .map((r) => r.company),
        ['3'],
      );
    });

    test('a switch while in the room leaves in the joined company', () async {
      _keep(meetingMediaProvider(41));
      await c.read(meetingMediaProvider(41).notifier).join();
      expect(c.read(meetingMediaProvider(41)).phase, MediaPhase.connected);
      await _switchTo(7);
      await pumpEventQueue();
      expect(engine.rooms.single.disconnected, isTrue);
      final leave = server.sent.lastWhere(
        (r) => r.path.endsWith('/media/leave'),
      );
      expect(leave.company, '3');
    });
  });

  group('sign-out and the company switch', () {
    test('a sign-out during a load drops it and sends nothing more', () async {
      _keep(meetingChatProvider(41));
      await c.read(meetingChatProvider(41).future);
      server.holdNext('GET $_c/meetings/41/messages');
      final earlier = c.read(meetingChatProvider(41).notifier).loadEarlier();
      await pumpEventQueue();
      await c.read(sessionControllerProvider.notifier).logout();
      final mark = server.sent.length;
      server.release('GET $_c/meetings/41/messages');
      await earlier.catchError((Object _) {});
      await pumpEventQueue();
      // Nothing continues the stale request (no older page, nothing for
      // company 3); the signed-out reload itself carries no company.
      expect(
        _after(mark)
            .where((r) => r.company == '3' || r.query.containsKey('before_id')),
        isEmpty,
      );
      expect(_after(mark).map((r) => r.company).toSet(), {null});
    });

    test(
      'a sign-out during the company check: no switch is reported',
      () async {
        _keep(companySwitchProvider);
        server.holdNext('GET $_c/dashboard');
        final switching = c.read(companySwitchProvider.notifier).switchTo(7);
        await pumpEventQueue();
        await c.read(sessionControllerProvider.notifier).logout();
        server.release('GET $_c/dashboard');
        expect(await switching, isFalse);
        expect(c.read(sessionControllerProvider).value, isNull);
      },
    );
  });
}
