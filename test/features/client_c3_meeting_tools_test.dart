import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/data/meeting_media.dart';
import 'package:workflow_app/features/meetings/presentation/api_meeting_room_screen.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_media.dart';
import '../helpers/route_http_adapter.dart';
import 'meetings_api_test.dart' show meetingJson, page;

/// Client C3: read-only meeting collaboration (chat, polls, notes,
/// decisions, action items, attachment download). Fixtures carry only the
/// fields the WorkFlow collection documents for these routes, plus a few
/// undocumented keys the app must ignore. Every response is a test double;
/// none of these routes was read live as a client (live, a non-participant
/// gets 403 — see docs/api-contract-gaps.md C16–C21).

const _base = '/api/v1/client';

Map<String, dynamic> _msgPage(
  List<Object> rows, {
  int current = 1,
  int last = 1,
}) => ok({
  'current_page': current,
  'data': rows,
  'last_page': last,
  'per_page': 30,
  'total': rows.length,
});

Map<String, dynamic> _msg(int id, {String? text, List<int> files = const []}) =>
    {
      'id': id,
      'message': text,
      'attachments': [
        for (final f in files) {'id': f},
      ],
      // Undocumented: never shown.
      'user': {'id': 9, 'name': 'Undocumented Sender'},
    };

const (int, Map<String, Object>) _forbidden = (
  403,
  {
    'success': false,
    'message': 'You must be a participant of this meeting to use its notes',
    'errors': <Object>[],
  },
);

Map<String, (int, Object?)> _routes({bool allowChat = true}) => {
  'GET $_base/account': (200, ok({'id': 1, 'name': 'Client'})),
  'GET $_base/meetings/41': (
    200,
    ok({...meetingJson(status: 'ended'), 'allow_chat': allowChat}),
  ),
  'GET $_base/meetings/41/participants': (200, page(const [])),
  'GET $_base/meetings/41/polls': (
    200,
    ok([
      {'id': 5, 'question': 'Release day?'},
      {'id': 6},
    ]),
  ),
  'GET $_base/meeting-polls/5': (
    200,
    ok({
      'id': 5,
      'question': 'Release day?',
      'options': [
        {'id': 51, 'title': 'Monday', 'votes_count': 7},
        {'id': 52, 'title': 'Thursday', 'votes_count': 3},
      ],
    }),
  ),
  'GET $_base/meetings/41/notes': (
    200,
    ok([
      {
        'id': 7,
        'title': 'Planning notes',
        'content': 'Ship in two sprints.',
        'status': 'published',
        'is_shared': true,
      },
      {'id': 8, 'title': null, 'content': 'Draft idea', 'status': 'draft'},
    ]),
  ),
};

void main() {
  late RouteHttpAdapter http;
  final saved = <DownloadedFile>[];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Portal portal = Portal.client,
    Map<String, (int, Object?)> routes = const {},
    Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
    Locale locale = const Locale('en'),
    List<Override> extra = const [],
    bool fakeEngine = false,
    bool allowChat = true,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    saved.clear();
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 1,
        companyId: 2,
        portal: portal,
      ).toStorage(),
    );
    http = RouteHttpAdapter({
      ..._routes(allowChat: allowChat),
      'GET /api/v1/employee/account': (200, ok({'id': 1, 'name': 'Emp'})),
      'GET /api/v1/employee/meetings/41': (200, ok(meetingJson())),
      'GET /api/v1/employee/meetings/41/participants': (200, page(const [])),
      'GET /api/v1/employee/meetings/41/invitations': (200, page(const [])),
      'GET /api/v1/employee/meetings/41/join-request': (
        404,
        {'success': false, 'message': 'Not found', 'errors': <Object>[]},
      ),
      ...routes,
    }, handlers: handlers);
    final container = ProviderContainer(
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
            adapter: http,
          ),
        ),
        attachmentSaverProvider.overrideWithValue((file, _) async {
          saved.add(file);
          return true;
        }),
        if (!fakeEngine) mediaEngineProvider.overrideWithValue(null),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// No request of these tests may change anything on the server.
  void expectReadOnly() => expect(
    http.requests.where((r) => r.method != 'GET').map((r) => r.uri.path),
    isEmpty,
    reason: 'C3 is read-only: no send, vote, join or edit',
  );

  Future<void> openRecords(WidgetTester tester, String tool) async {
    final chip = find.byKey(Key('meeting-records-$tool'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  group('contract: documented fields only', () {
    test('message: id, message, attachments[].id; nothing else', () {
      final m = MeetingMessage.fromJson(_msg(3, text: 'Hi', files: [70, 71]));
      expect(m.id, 3);
      expect(m.text, 'Hi');
      expect(m.attachmentIds, [70, 71]);
      final fileOnly = MeetingMessage.fromJson(_msg(4, files: [72]));
      expect(fileOnly.text, isNull);
      expect(
        () => MeetingMessage.fromJson({'message': 'x'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => MeetingMessage.fromJson({
          'id': 1,
          'attachments': [<String, Object>{}],
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('poll details require options with id and title', () {
      final p = MeetingPollDetails.fromJson({
        'id': 5,
        'options': [
          {'id': 51, 'title': 'Monday'},
        ],
      });
      expect(p.options.single, (id: 51, title: 'Monday'));
      expect(
        () => MeetingPollDetails.fromJson({'id': 5}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => MeetingPollDetails.fromJson({
          'id': 5,
          'options': [
            {'id': 51},
          ],
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('note content, decision and action item title are required', () {
      expect(
        () => MeetingNote.fromJson({'id': 1}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => MeetingDecision.fromJson({'id': 1}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => MeetingActionItem.fromJson({'id': 1}),
        throwsA(isA<ApiException>()),
      );
      final a = MeetingActionItem.fromJson({
        'id': 1,
        'title': 'Checklist',
        'status': 'in_progress',
        'priority': 'urgent',
        'due_date': '2026-10-31',
        'assigned_to': 4,
      });
      expect(a.status, ActionItemStatus.inProgress);
      expect(a.priority, ActionItemPriority.urgent);
      expect(a.dueDate, DateTime(2026, 10, 31));
      // Unknown values are not guessed.
      final d = MeetingDecision.fromJson({
        'id': 2,
        'title': 'T',
        'status': 'escalated',
      });
      expect(d.status, isNull);
    });
  });

  group('repository: exact documented requests', () {
    late RouteHttpAdapter adapter;
    late MeetingCollaborationRepository repo;

    setUp(() {
      adapter = RouteHttpAdapter(
        {},
        handlers: {
          'GET $_base/meetings/41/messages': (_) => (200, _msgPage(const [])),
          'GET $_base/meetings/41/decisions': (_) => (200, ok(<Object>[])),
          'GET $_base/meetings/41/action-items': (_) => (200, ok(<Object>[])),
          'GET $_base/meeting-attachments/70/download': (_) => (
            200,
            RawReply(Uint8List.fromList(utf8.encode('hello')), {
              Headers.contentTypeHeader: 'text/plain',
              'content-disposition': 'attachment; filename="minutes.txt"',
            }),
          ),
        },
      );
      repo = MeetingCollaborationRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: const _Creds(),
          adapter: adapter,
        ),
        Portal.client,
      );
    });

    test('messages: per_page, before_id, after_id', () async {
      await repo.messages(41);
      await repo.messages(41, beforeId: 10);
      await repo.messages(41, afterId: 20);
      final q = [for (final r in adapter.requests) r.uri.queryParameters];
      expect(q[0], {'per_page': '30'});
      expect(q[1], {'per_page': '30', 'before_id': '10'});
      expect(q[2], {'per_page': '30', 'after_id': '20'});
      expect(adapter.requests.first.headers['X-Company'], '5');
    });

    test('status filters use the documented wire values', () async {
      await repo.decisions(41, status: DecisionStatus.approved);
      await repo.actionItems(41, status: ActionItemStatus.inProgress);
      await repo.actionItems(41);
      expect(adapter.requests[0].uri.queryParameters, {'status': 'approved'});
      expect(adapter.requests[1].uri.queryParameters, {
        'status': 'in_progress',
      });
      expect(adapter.requests[2].uri.queryParameters, isEmpty);
    });

    test('attachment download keeps bytes and the server file name', () async {
      final f = await repo.downloadAttachment(70);
      expect(utf8.decode(f.bytes), 'hello');
      expect(f.fileName, 'minutes.txt');
      expect(
        adapter.requests.single.uri.path,
        '$_base/meeting-attachments/70/download',
      );
    });

    test('a list that is not a list is an invalid response', () async {
      final bad = RouteHttpAdapter({
        'GET $_base/meetings/41/notes': (200, ok({'id': 1})),
      });
      final r = MeetingCollaborationRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: const _Creds(),
          adapter: bad,
        ),
        Portal.client,
      );
      await expectLater(r.notes(41), throwsA(isA<ApiException>()));
    });
  });

  group('meeting details entry (client only)', () {
    testWidgets('client: Meeting records lists every tool', (tester) async {
      await pump(tester, const ApiMeetingDetailsScreen(id: 41));
      expect(find.byKey(const Key('meeting-records')), findsOneWidget);
      for (final t in ['chat', 'polls', 'notes', 'decisions', 'actionItems']) {
        expect(find.byKey(Key('meeting-records-$t')), findsOneWidget);
      }
      expectReadOnly();
    });

    testWidgets('chat is not offered when the meeting disallows it', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        allowChat: false,
      );
      expect(find.byKey(const Key('meeting-records-chat')), findsNothing);
      expect(find.byKey(const Key('meeting-records-notes')), findsOneWidget);
    });

    testWidgets('employee details are unchanged (no records card)', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        portal: Portal.employee,
      );
      expect(find.byKey(const Key('meeting-records')), findsNothing);
      expect(
        http.requests.where((r) => r.uri.path.contains('/notes')),
        isEmpty,
      );
    });
  });

  group('panels', () {
    testWidgets('notes: title and content; draft badge; Back returns', (
      tester,
    ) async {
      await pump(tester, const ApiMeetingDetailsScreen(id: 41));
      await openRecords(tester, 'notes');
      expect(find.text('Planning notes'), findsOneWidget);
      expect(find.text('Ship in two sprints.'), findsOneWidget);
      expect(find.text('Draft idea'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meeting-records')), findsOneWidget);
      expectReadOnly();
    });

    testWidgets('a non-participant sees the participants-only notice', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        routes: {'GET $_base/meetings/41/notes': _forbidden},
      );
      await openRecords(tester, 'notes');
      expect(find.byKey(const Key('meeting-tool-forbidden')), findsOneWidget);
      expect(
        find.text(
          'Only participants of this meeting can see this. Join the '
          'meeting to view it.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('meeting-tool-retry')), findsNothing);
    });

    testWidgets('a server error shows Retry, which reloads', (tester) async {
      var calls = 0;
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        handlers: {
          'GET $_base/meetings/41/decisions': (_) => ++calls == 1
              ? (500, {'success': false, 'message': 'x', 'errors': <Object>[]})
              : (
                  200,
                  ok([
                    {
                      'id': 3,
                      'title': 'Adopt weekly releases',
                      'description': 'From Q3',
                      'status': 'approved',
                      'assigned_to': 4,
                    },
                  ]),
                ),
        },
      );
      await openRecords(tester, 'decisions');
      expect(find.byKey(const Key('meeting-tool-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-tool-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Adopt weekly releases'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
    });

    testWidgets('decisions filter sends the documented status', (tester) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        handlers: {
          'GET $_base/meetings/41/decisions': (_) => (200, ok(<Object>[])),
        },
      );
      await openRecords(tester, 'decisions');
      expect(find.byKey(const Key('meeting-tool-empty')), findsOneWidget);
      expect(find.text('No decisions yet.'), findsOneWidget);
      final rejected = find.byKey(
        const Key('meeting-tool-filter-DecisionStatus.rejected'),
      );
      await tester.ensureVisible(rejected);
      await tester.pumpAndSettle();
      await tester.tap(rejected);
      await tester.pumpAndSettle();
      expect(
        http.requests
            .lastWhere((r) => r.uri.path.endsWith('/decisions'))
            .uri
            .queryParameters,
        {'status': 'rejected'},
      );
    });

    testWidgets('action items: status, priority, due date', (tester) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        routes: {
          'GET $_base/meetings/41/action-items': (
            200,
            ok([
              {
                'id': 9,
                'title': 'Prepare release checklist',
                'description': null,
                'status': 'in_progress',
                'priority': 'high',
                'due_date': '2026-10-31',
                'assigned_to': 4,
              },
            ]),
          ),
        },
      );
      await openRecords(tester, 'actionItems');
      expect(find.text('Prepare release checklist'), findsOneWidget);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Priority: High'), findsOneWidget);
      expect(find.text('Due date: Oct 31, 2026'), findsOneWidget);
      expectReadOnly();
    });

    testWidgets('polls: question, options on demand, no results', (
      tester,
    ) async {
      await pump(tester, const ApiMeetingDetailsScreen(id: 41));
      await openRecords(tester, 'polls');
      expect(find.text('Release day?'), findsOneWidget);
      expect(find.text('Poll 6'), findsOneWidget, reason: 'no question sent');
      expect(
        http.requests.where((r) => r.uri.path.contains('meeting-polls')),
        isEmpty,
        reason: 'options load only when a poll is opened',
      );
      await tester.tap(find.byKey(const Key('poll-open-5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('poll-option-51')), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);
      // Undocumented per-option counts are not shown.
      expect(find.textContaining('7'), findsNothing);
      expect(
        find.text("Per-option results aren't available in the app yet."),
        findsOneWidget,
      );
      // C4: voting is offered (client_c4_meeting_interactions_test.dart);
      // opening a poll alone sends nothing.
      expect(find.byKey(const Key('meeting-tool-read-only')), findsNothing);
      expectReadOnly();
    });

    testWidgets('chat: text and files, earlier page, no sender guessed', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        handlers: {
          'GET $_base/meetings/41/messages': (o) =>
              o.queryParameters['before_id'] == null
              ? (
                  200,
                  _msgPage([
                    _msg(21, text: 'Second'),
                    _msg(20, text: 'Agenda attached', files: [70]),
                  ], last: 2),
                )
              : (200, _msgPage([_msg(12, text: 'First')])),
          'GET $_base/meeting-attachments/70/download': (_) => (
            200,
            RawReply(Uint8List.fromList(utf8.encode('agenda')), {
              Headers.contentTypeHeader: 'text/plain',
              'content-disposition': 'attachment; filename="agenda.txt"',
            }),
          ),
        },
      );
      await openRecords(tester, 'chat');
      // Ordered by id, so the older message comes first.
      final y20 = tester.getTopLeft(
        find.byKey(const Key('meeting-message-20')),
      );
      final y21 = tester.getTopLeft(
        find.byKey(const Key('meeting-message-21')),
      );
      expect(y20.dy, lessThan(y21.dy));
      expect(find.text('Undocumented Sender'), findsNothing);

      await tester.tap(find.byKey(const Key('meeting-chat-earlier')));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(
        http.requests
            .lastWhere((r) => r.uri.path.endsWith('/messages'))
            .uri
            .queryParameters['before_id'],
        '20',
      );
      expect(find.byKey(const Key('meeting-chat-earlier')), findsNothing);

      await tester.tap(find.byKey(const Key('meeting-attachment-70')));
      await tester.pumpAndSettle();
      expect(find.text('agenda.txt'), findsOneWidget);
      expect(find.byKey(const Key('attachment-text')), findsOneWidget);
      await tester.tap(find.byKey(const Key('attachment-save')));
      await tester.pumpAndSettle();
      expect(saved.single.fileName, 'agenda.txt');
      expectReadOnly();
    });

    testWidgets('a failed download says so and shows nothing', (tester) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        routes: {
          'GET $_base/meetings/41/messages': (
            200,
            _msgPage([
              _msg(20, files: [70]),
            ]),
          ),
          'GET $_base/meeting-attachments/70/download': (
            404,
            {'success': false, 'message': 'Not found', 'errors': <Object>[]},
          ),
        },
      );
      await openRecords(tester, 'chat');
      await tester.tap(find.byKey(const Key('meeting-attachment-70')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't download the file:"),
        findsOneWidget,
      );
      expect(find.byKey(const Key('attachment-save')), findsNothing);
    });

    testWidgets('Arabic RTL: every panel builds without overflow', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        locale: const Locale('ar'),
        routes: {
          'GET $_base/meetings/41/messages': (
            200,
            _msgPage([
              _msg(20, text: 'مرحبًا بالجميع', files: [70]),
            ]),
          ),
          'GET $_base/meetings/41/decisions': (200, ok(<Object>[])),
          'GET $_base/meetings/41/action-items': (200, ok(<Object>[])),
        },
      );
      await openRecords(tester, 'chat');
      expect(find.text('مرحبًا بالجميع'), findsOneWidget);
      for (final t in ['polls', 'notes', 'decisions', 'actionItems']) {
        final tab = find.byKey(Key('meeting-tool-$t'));
        await tester.scrollUntilVisible(
          tab,
          80,
          scrollable: find.descendant(
            of: find.byKey(const Key('meeting-tool-tabs')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(tab);
        await tester.pumpAndSettle();
      }
      expect(find.text('لا توجد بنود عمل بعد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('live room (client tabs)', () {
    List<Override> room(FakeMediaEngine engine) => [
      mediaEngineProvider.overrideWithValue(engine),
      meetingMediaApiProvider.overrideWithValue(_MediaApi()),
      deviceIdStoreProvider.overrideWithValue(MemoryDeviceIdStore()),
    ];

    testWidgets('client: tabs swap the stage for a tool and back', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingRoomScreen(meetingId: 41, title: 'Sprint Planning'),
        extra: room(FakeMediaEngine()),
        fakeEngine: true,
      );
      expect(find.byKey(const Key('meeting-tool-tabs')), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-tool-notes')));
      await tester.pumpAndSettle();
      expect(find.text('Planning notes'), findsOneWidget);
      // Tapping the selected tab returns to the stage.
      await tester.tap(find.byKey(const Key('meeting-tool-notes')));
      await tester.pumpAndSettle();
      expect(find.text('Planning notes'), findsNothing);
      expect(
        http.requests.where(
          (r) => r.method != 'GET' && !r.uri.path.contains('/media/'),
        ),
        isEmpty,
      );
    });

    testWidgets('employee room is unchanged (no tool tabs)', (tester) async {
      await pump(
        tester,
        const ApiMeetingRoomScreen(meetingId: 41, title: 'Sprint Planning'),
        portal: Portal.employee,
        extra: room(FakeMediaEngine()),
        fakeEngine: true,
      );
      expect(find.byKey(const Key('meeting-tool-tabs')), findsNothing);
    });
  });
}

class _Creds implements ApiCredentials {
  const new();
  @override
  String? get token => 't';
  @override
  int? get companyId => 5;
  @override
  void onUnauthorized() {}
}

class _MediaApi implements MeetingMediaApi {
  @override
  Future<MediaJoinOutcome> join(int meetingId, String deviceId) async =>
      const MediaGranted(
        participantId: 55,
        credentials: MediaCredentials(
          token: 'test-token',
          url: 'wss://media.example.test',
          room: 'room-uuid',
        ),
      );

  @override
  Future<void> state(int meetingId, {bool? microphone, bool? camera}) async {}

  @override
  Future<void> leave(int meetingId, String deviceId, {int? companyId}) async {}
}
