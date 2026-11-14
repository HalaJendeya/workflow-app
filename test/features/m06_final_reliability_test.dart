import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';

import '../helpers/fake_http_adapter.dart';

/// M06 final pass: races and failures in the chat thread, the meeting join
/// state and the notification inbox, with repositories whose answers the
/// test releases one by one (Completers). No HTTP leaves the test.

const _me = 1;

class _Creds implements ApiCredentials {
  @override
  String? token = 't';
  @override
  int? companyId = 3;
  @override
  void onUnauthorized() {}
}

ApiClient _client() => ApiClient(
  baseUrl: 'https://api.test',
  credentials: _Creds(),
  adapter: FakeHttpAdapter(),
);

class _Session extends SessionController {
  @override
  Future<Session?> build() async => const Session(
    token: 't',
    tokenType: 'Bearer',
    userId: _me,
    companyId: 3,
    portal: Portal.client,
  );

  void switchCompany(int id) => state = AsyncData(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: _me,
      companyId: id,
      portal: Portal.client,
    ),
  );
}

ApiMessage _m(int id, {int sender = 9}) => ApiMessage(
  id: id,
  senderId: sender,
  senderName: sender == _me ? 'Me' : 'Sara',
  text: 'm$id',
  createdAt: DateTime.utc(2026, 11, 5, 10, id % 60),
  attachments: 0,
);

/// One pending `GET …/messages` call.
typedef _Call = ({int? beforeId, int? afterId, Completer<MessagePage> reply});

class _Chats extends ConversationsRepository {
  new() : super(_client(), Portal.client);

  final calls = <_Call>[];

  @override
  Future<MessagePage> messages(
    int id, {
    int? beforeId,
    int? afterId,
    int limit = messagePageSize,
  }) {
    final c = Completer<MessagePage>();
    calls.add((beforeId: beforeId, afterId: afterId, reply: c));
    return c.future;
  }

  void answer(int i, List<ApiMessage> rows, {bool hasMore = false}) =>
      calls[i].reply.complete(MessagePage(messages: rows, hasMore: hasMore));
}

ProviderContainer _container(List<Object> overrides) {
  final c = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
      ),
      sessionControllerProvider.overrideWith(_Session.new),
      ...overrides.cast(),
    ],
    retry: (_, _) => null,
  );
  addTearDown(c.dispose);
  return c;
}

const _network = ApiException(kind: ApiFailureKind.network, message: 'offline');

void main() {
  group('chat thread races', () {
    late _Chats repo;
    late ProviderContainer c;
    late ConversationThread thread;

    /// Opens conversation 1 with messages 10 and 11 (older history exists).
    Future<void> open() async {
      repo = _Chats();
      c = _container([conversationsRepositoryProvider.overrideWithValue(repo)]);
      await c.read(sessionControllerProvider.future);
      c.listen(conversationThreadProvider(1), (_, _) {});
      await pumpEventQueue();
      repo.answer(0, [_m(10), _m(11)], hasMore: true);
      await c.read(conversationThreadProvider(1).future);
      thread = c.read(conversationThreadProvider(1).notifier);
    }

    List<int> ids() => [
      for (final m in c.read(conversationThreadProvider(1)).value!.messages)
        m.id,
    ];

    test('timer polls that overlap share one request', () async {
      await open();
      final a = thread.poll();
      final b = thread.poll();
      await pumpEventQueue();
      expect(repo.calls, hasLength(2), reason: 'initial load + one poll');
      expect(repo.calls[1].afterId, 11);
      repo.answer(1, [_m(12)]);
      expect(await a, 1);
      expect(await b, 1);
      expect(ids(), [10, 11, 12]);
    });

    test('a fresh poll (after a send) waits and asks again', () async {
      await open();
      final timer = thread.poll();
      final fresh = thread.poll(fresh: true);
      await pumpEventQueue();
      expect(repo.calls, hasLength(2));
      repo.answer(1, [_m(12)]);
      await timer;
      await pumpEventQueue();
      expect(repo.calls, hasLength(3), reason: 'asks again after the first');
      expect(repo.calls[2].afterId, 12);
      repo.answer(2, [_m(13, sender: _me)]);
      expect(await fresh, 0, reason: 'my own message is not "new to read"');
      expect(ids(), [10, 11, 12, 13]);
    });

    test('a sent message and an overlapping poll give one copy', () async {
      await open();
      final poll = thread.poll();
      await pumpEventQueue();
      // The send answers first with the message row…
      thread.addSent(_m(13, sender: _me));
      expect(ids(), [10, 11, 13]);
      // …then the poll that was already running returns it too, with the
      // message that arrived between.
      repo.answer(1, [_m(12), _m(13, sender: _me)]);
      expect(await poll, 1);
      expect(ids(), [10, 11, 12, 13]);
    });

    test('a sent message does not move the poll cursor (no gap)', () async {
      await open();
      thread.addSent(_m(13, sender: _me));
      final poll = thread.poll();
      await pumpEventQueue();
      expect(repo.calls[1].afterId, 11, reason: 'not 13: 12 may exist');
      repo.answer(1, [_m(12), _m(13, sender: _me)]);
      await poll;
      expect(ids(), [10, 11, 12, 13]);
      final next = thread.poll();
      await pumpEventQueue();
      expect(repo.calls[2].afterId, 13);
      repo.answer(2, const []);
      await next;
    });

    test('a failed poll throws and leaves the thread as it was', () async {
      await open();
      final poll = thread.poll();
      await pumpEventQueue();
      repo.calls[1].reply.completeError(_network);
      await expectLater(poll, throwsA(isA<ApiException>()));
      expect(ids(), [10, 11]);
      // The next poll is a new request from the same cursor.
      final again = thread.poll();
      await pumpEventQueue();
      expect(repo.calls[2].afterId, 11);
      repo.answer(2, [_m(12)]);
      expect(await again, 1);
    });

    test(
      'older pages: one request for repeated taps, merged in order',
      () async {
        await open();
        final a = thread.loadEarlier();
        final b = thread.loadEarlier();
        expect(thread.loadingEarlier, isTrue);
        await pumpEventQueue();
        expect(repo.calls, hasLength(2));
        expect(repo.calls[1].beforeId, 10);
        repo.answer(1, [_m(8), _m(9)]);
        await Future.wait([a, b]);
        expect(thread.loadingEarlier, isFalse);
        expect(ids(), [8, 9, 10, 11]);
        expect(
          c.read(conversationThreadProvider(1)).value!.hasEarlier,
          isFalse,
        );
      },
    );

    test('an answer after the chat closed is dropped, not a crash', () async {
      repo = _Chats();
      c = _container([conversationsRepositoryProvider.overrideWithValue(repo)]);
      await c.read(sessionControllerProvider.future);
      final sub = c.listen(conversationThreadProvider(1), (_, _) {});
      await pumpEventQueue();
      repo.answer(0, [_m(10)]);
      await c.read(conversationThreadProvider(1).future);
      final t = c.read(conversationThreadProvider(1).notifier);
      final poll = t.poll();
      await pumpEventQueue();
      sub.close(); // the chat screen leaves; the provider is disposed
      await pumpEventQueue();
      repo.answer(1, [_m(11)]);
      expect(await poll, 0);
    });
  });

  group('meeting join state', () {
    late _Meetings repo;
    late ProviderContainer c;

    setUp(() async {
      repo = _Meetings();
      c = _container([meetingsRepositoryProvider.overrideWithValue(repo)]);
      await c.read(sessionControllerProvider.future);
      c.listen(meetingJoinProvider(41), (_, _) {});
    });

    MeetingJoin join() => c.read(meetingJoinProvider(41).notifier);
    MeetingJoinState state() => c.read(meetingJoinProvider(41));

    test('repeated Join taps send one request', () async {
      final a = join().join();
      final b = join().join();
      expect(state().busy, isTrue);
      expect(repo.joins, hasLength(1));
      repo.joins.single.complete(
        const Joined(participantId: 55, connectionStatus: 'connected'),
      );
      await Future.wait([a, b]);
      expect(state().outcome, isA<Joined>());
      // Joined: Join does nothing more.
      await join().join();
      expect(repo.joins, hasLength(1));
    });

    test('202 stays pending; trying again can admit (200)', () async {
      final first = join().join();
      repo.joins.single.complete(const JoinRequested());
      await first;
      expect(state().outcome, isA<JoinRequested>());
      final again = join().join();
      expect(state().outcome, isA<JoinRequested>(), reason: 'still shown');
      repo.joins[1].complete(
        const Joined(participantId: 56, connectionStatus: 'connected'),
      );
      await again;
      expect(state().outcome, isA<Joined>());
    });

    test('a refusal after 202 keeps the request and shows why', () async {
      final first = join().join();
      repo.joins.single.complete(const JoinRequested());
      await first;
      final again = join().join();
      repo.joins[1].completeError(
        const ApiException(
          kind: ApiFailureKind.forbidden,
          message: 'Your join request was rejected.',
          statusCode: 403,
        ),
      );
      await again;
      expect(state().outcome, isA<JoinRequested>());
      expect(state().error, isA<ApiException>());
      expect(state().busy, isFalse);
    });

    test('leave uses the joined participant id; a failure keeps it', () async {
      final j = join().join();
      repo.joins.single.complete(
        const Joined(participantId: 55, connectionStatus: 'connected'),
      );
      await j;
      repo.leaveError = _network;
      await join().leave();
      expect(repo.left, [55]);
      expect(state().outcome, isA<Joined>(), reason: 'still in the meeting');
      expect(state().error, isNotNull);
      repo.leaveError = null;
      await join().leave();
      expect(repo.left, [55, 55]);
      expect(state().outcome, isNull);
      expect(state().left, isTrue);
    });

    test(
      'the state survives the screen and resets on company switch',
      () async {
        final j = join().join();
        repo.joins.single.complete(const JoinRequested());
        await j;
        // Nothing listens any more (the details screen closed)…
        final again = c.listen(meetingJoinProvider(41), (_, _) {});
        expect(c.read(meetingJoinProvider(41)).outcome, isA<JoinRequested>());
        again.close();
        // …but another company is another context.
        (c.read(sessionControllerProvider.notifier) as _Session).switchCompany(
          4,
        );
        await pumpEventQueue();
        expect(c.read(meetingJoinProvider(41)).outcome, isNull);
      },
    );
  });

  group('notification inbox races', () {
    late _Inbox repo;
    late ProviderContainer c;

    setUp(() async {
      repo = _Inbox();
      c = _container([notificationsRepositoryProvider.overrideWithValue(repo)]);
      await c.read(sessionControllerProvider.future);
      c.listen(notificationsControllerProvider, (_, _) {});
      await c.read(notificationsControllerProvider.future);
    });

    NotificationsController inbox() =>
        c.read(notificationsControllerProvider.notifier);

    test('a double tap marks a notification read once', () async {
      final gate = Completer<void>();
      repo.markGate = gate;
      final a = inbox().markRead('n1');
      final b = inbox().markRead('n1');
      gate.complete();
      await Future.wait([a, b]);
      expect(repo.marked, ['n1']);
      final v = c.read(notificationsControllerProvider).value!;
      expect(v.unreadCount, 1);
      expect(v.items.firstWhere((n) => n.id == 'n1').isRead, isTrue);
    });

    test('mark all and load more do not stack requests', () async {
      final gate = Completer<void>();
      repo.markGate = gate;
      final a = inbox().markAllRead();
      final b = inbox().markAllRead();
      gate.complete();
      await Future.wait([a, b]);
      expect(repo.markAllCalls, 1);
      expect(c.read(notificationsControllerProvider).value!.unreadCount, 0);

      final pageGate = Completer<void>();
      repo.pageGate = pageGate;
      final p1 = inbox().loadMore();
      final p2 = inbox().loadMore();
      pageGate.complete();
      await Future.wait([p1, p2]);
      expect(repo.pages, [1, 2]);
      // n2 came back on page 2 (a new notification shifted the pages): one
      // copy.
      expect(
        c.read(notificationsControllerProvider).value!.items.map((n) => n.id),
        ['n1', 'n2', 'n3'],
      );
    });
  });
}

class _Meetings extends MeetingsRepository {
  new() : super(_client(), Portal.client);

  final joins = <Completer<JoinOutcome>>[];
  final left = <int>[];
  ApiException? leaveError;

  @override
  Future<JoinOutcome> join(int meetingId) {
    final c = Completer<JoinOutcome>();
    joins.add(c);
    return c.future;
  }

  @override
  Future<void> leave(int participantId) async {
    left.add(participantId);
    if (leaveError case final e?) throw e;
  }
}

AppNotification _n(String id, {bool read = false}) =>
    AppNotification(id: id, isRead: read, title: id);

class _Inbox implements NotificationsRepository {
  final marked = <String>[];
  final pages = <int>[];
  int markAllCalls = 0;
  Completer<void>? markGate;
  Completer<void>? pageGate;

  @override
  Future<NotificationInbox> list({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    pages.add(page);
    if (page > 1) await pageGate?.future;
    return NotificationInbox(
      items: page == 1 ? [_n('n1'), _n('n2')] : [_n('n2'), _n('n3')],
      currentPage: page,
      lastPage: 2,
      total: 3,
      unreadCount: 2,
    );
  }

  @override
  Future<AppNotification> markRead(String id) async {
    marked.add(id);
    await markGate?.future;
    return _n(id, read: true);
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    await markGate?.future;
    return 0;
  }

  @override
  Future<int> unreadCount() async => 0;
}
