import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/data/meeting_media.dart';
import 'package:workflow_app/features/meetings/presentation/api_meeting_room_screen.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_tools.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_media.dart';
import '../helpers/route_http_adapter.dart';
import 'meetings_api_test.dart' show meetingJson, page;

/// F03: employee meeting collaboration. The employee folder documents the
/// same participant routes as the client's, under `/api/v1/employee` and the
/// same `meetings.view` permission: chat history and send (text or one
/// `file`), attachment download, polls and voting (`option_ids`), notes,
/// decisions and action items. Their writes (create/update/close/approve/
/// complete/convert) need `meetings.update` and host rights and are not
/// offered. Nothing here distinguishes a project lead from a regular
/// employee, so both accounts must behave the same. Every response is a
/// test double; nothing was sent to a live server.

const _e = '/api/v1/employee';

/// Regular employee (company 2) and a project lead (company 2).
const _regular = Session(
  token: 'regular',
  tokenType: 'Bearer',
  userId: 11,
  companyId: 2,
  portal: Portal.employee,
);
const _lead = Session(
  token: 'lead',
  tokenType: 'Bearer',
  userId: 12,
  companyId: 2,
  portal: Portal.employee,
);

Map<String, Object?> _msgPage(List<Object> rows, {int last = 1}) => ok({
  'current_page': 1,
  'data': rows,
  'last_page': last,
  'per_page': 30,
  'total': rows.length,
});

Map<String, Object?> _msg(int id, {String? text, List<int> files = const []}) =>
    {
      'id': id,
      'message': text,
      'attachments': [
        for (final f in files) {'id': f},
      ],
    };

Map<String, Object?> _err(String message, [Map<String, Object>? errors]) => {
  'success': false,
  'message': message,
  'errors': errors ?? <String, Object>{},
};

final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, //
]);

/// Host and administrator writes: never sent by the app for any role.
final _hostWrite = RegExp(
  '/(notes|decisions|action-items|polls|invitations|start|end|cancel|'
  r'mute-all|unmute-all|admit-all|admission-mode)$|'
  '/meeting-(notes|decisions|action-items|guests|join-requests)/|'
  r'/meeting-polls/\d+(/close)?$|/approve$|/reject$|/complete$|'
  r'/convert-to-task$|/mute$|/unmute$',
);

Map<String, (int, Object?)> _routes({bool allowChat = true}) => {
  'GET $_e/account': (200, ok({'id': 11, 'name': 'Employee'})),
  'GET $_e/meetings/41': (
    200,
    ok({...meetingJson(), 'allow_chat': allowChat, 'allow_file_share': true}),
  ),
  'GET $_e/meetings/41/participants': (200, page(const [])),
  'GET $_e/meetings/41/invitations': (200, page(const [])),
  'GET $_e/meetings/41/join-request': (404, _err('Not found')),
  'GET $_e/meetings/41/messages': (200, _msgPage([_msg(20, text: 'Welcome')])),
  'GET $_e/meetings/41/polls': (
    200,
    ok([
      {'id': 5, 'question': 'Release day?'},
    ]),
  ),
  'GET $_e/meeting-polls/5': (
    200,
    ok({
      'id': 5,
      'question': 'Release day?',
      'options': [
        {'id': 51, 'title': 'Monday'},
        {'id': 52, 'title': 'Thursday'},
      ],
    }),
  ),
  'GET $_e/meetings/41/notes': (
    200,
    ok([
      {'id': 7, 'title': 'Planning notes', 'content': 'Ship in two sprints.'},
    ]),
  ),
  'GET $_e/meetings/41/decisions': (
    200,
    ok([
      {'id': 3, 'title': 'Weekly releases', 'status': 'pending'},
    ]),
  ),
  'GET $_e/meetings/41/action-items': (
    200,
    ok([
      {'id': 9, 'title': 'Release checklist', 'status': 'in_progress'},
    ]),
  ),
};

class _Creds implements ApiCredentials {
  const new();
  @override
  String? get token => 't';
  @override
  int? get companyId => 2;
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

/// Signs in [next] after a sign-out.
class _Auth implements AuthRepository {
  Session next = _lead;

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

void main() {
  late RouteHttpAdapter http;
  late ProviderContainer scope;
  final saved = <DownloadedFile>[];
  var pickResult = <OutgoingFile?>[];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Session session = _regular,
    Map<String, (int, Object?)> routes = const {},
    Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
    double textScale = 1,
    bool allowChat = true,
    List<Override> extra = const [],
    bool fakeEngine = false,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    saved.clear();
    final storage = InMemorySessionStorage();
    await storage.writeAll(session.toStorage());
    http = RouteHttpAdapter({
      ..._routes(allowChat: allowChat),
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
        meetingFilePickerProvider.overrideWithValue(
          () async => pickResult.isEmpty ? null : pickResult.removeAt(0),
        ),
        if (!fakeEngine) mediaEngineProvider.overrideWithValue(null),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    scope = container;
    await container.read(sessionControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpTools(
    WidgetTester tester, {
    MeetingTool tool = MeetingTool.chat,
    Session session = _regular,
    Map<String, (int, Object?)> routes = const {},
    Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
    double textScale = 1,
  }) => pump(
    tester,
    ApiMeetingToolsScreen(
      meetingId: 41,
      title: 'Sprint Planning',
      tools: meetingToolsFor(allowChat: true),
      initial: tool,
    ),
    session: session,
    routes: routes,
    handlers: handlers,
    locale: locale,
    size: size,
    textScale: textScale,
  );

  Iterable<RequestOptions> writes() =>
      http.requests.where((r) => r.method != 'GET');

  void expectEmployeeRoutesOnly() {
    for (final r in http.requests) {
      expect(r.uri.path, startsWith(_e), reason: 'employee prefix only');
      expect(r.headers['X-Company'], '2');
    }
  }

  void expectNoHostWrites() => expect(
    writes().where((r) => _hostWrite.hasMatch(r.uri.path)),
    isEmpty,
    reason: 'host and administrator actions are not offered',
  );

  /// Scrolls the lazily built tab bar to [t] and opens it.
  Future<void> openTab(WidgetTester tester, String t) async {
    final tab = find.byKey(Key('meeting-tool-$t'));
    await tester.scrollUntilVisible(
      tab,
      80,
      scrollable: find.descendant(
        of: find.byKey(const Key('meeting-tool-tabs')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  setUp(() => pickResult = []);

  group('contract: employee routes', () {
    late RouteHttpAdapter adapter;
    late MeetingCollaborationRepository repo;

    setUp(() {
      adapter = RouteHttpAdapter({
        ..._routes(),
        'POST $_e/meetings/41/messages': (201, ok({'id': 90})),
        'POST $_e/meeting-polls/5/vote': (200, ok({'id': 5, 'total_votes': 4})),
        'GET $_e/meeting-attachments/70/download': (
          200,
          RawReply(Uint8List.fromList(utf8.encode('agenda')), {
            Headers.contentTypeHeader: 'text/plain',
            'content-disposition': 'attachment; filename="agenda.txt"',
          }),
        ),
      });
      repo = MeetingCollaborationRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: const _Creds(),
          adapter: adapter,
        ),
        Portal.employee,
      );
    });

    test('every read uses /api/v1/employee and X-Company', () async {
      await repo.messages(41, beforeId: 20);
      await repo.polls(41);
      await repo.poll(5);
      await repo.notes(41);
      await repo.decisions(41);
      await repo.actionItems(41);
      final file = await repo.downloadAttachment(70);
      expect(adapter.requests.map((r) => r.uri.path), [
        '$_e/meetings/41/messages',
        '$_e/meetings/41/polls',
        '$_e/meeting-polls/5',
        '$_e/meetings/41/notes',
        '$_e/meetings/41/decisions',
        '$_e/meetings/41/action-items',
        '$_e/meeting-attachments/70/download',
      ]);
      expect(adapter.requests.first.uri.queryParameters['before_id'], '20');
      for (final r in adapter.requests) {
        expect(r.headers['X-Company'], '2');
      }
      expect(file.fileName, 'agenda.txt');
    });

    test('send and vote use the documented employee bodies', () async {
      expect(await repo.sendMessage(41, text: '  Ready  '), 90);
      final send = adapter.requests.last;
      expect(send.method, 'POST');
      expect(send.uri.path, '$_e/meetings/41/messages');
      expect(send.data, {'message': 'Ready'});

      await repo.sendMessage(
        41,
        file: OutgoingFile(name: 'shot.png', bytes: _png),
      );
      final multipart = adapter.requests.last.data as FormData;
      expect(multipart.files.single.key, 'file');
      expect(multipart.fields, isEmpty);

      final vote = await repo.vote(5, [52]);
      expect(adapter.requests.last.uri.path, '$_e/meeting-polls/5/vote');
      expect(adapter.requests.last.data, {
        'option_ids': [52],
      });
      expect(vote.totalVotes, 4);
    });
  });

  group('meeting details (both employee roles)', () {
    for (final (name, session) in [
      ('regular employee', _regular),
      ('project lead', _lead),
    ]) {
      testWidgets('$name: Meeting records open each tool; Back returns', (
        tester,
      ) async {
        await pump(
          tester,
          const ApiMeetingDetailsScreen(id: 41),
          session: session,
        );
        expect(find.byKey(const Key('meeting-records')), findsOneWidget);
        for (final t in [
          'chat',
          'polls',
          'notes',
          'decisions',
          'actionItems',
        ]) {
          expect(find.byKey(Key('meeting-records-$t')), findsOneWidget);
        }
        // The employee-only cards stay.
        expect(find.byKey(const Key('participants')), findsOneWidget);

        final chip = find.byKey(const Key('meeting-records-notes'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.text('Planning notes'), findsOneWidget);
        expect(find.text('View only in the app.'), findsOneWidget);
        // No add, edit, approve or complete control on any panel.
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('meeting-records')), findsOneWidget);
        expectEmployeeRoutesOnly();
        expect(writes(), isEmpty, reason: 'reading records writes nothing');
      });
    }

    testWidgets('chat is not offered when the meeting disallows it', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        allowChat: false,
      );
      expect(find.byKey(const Key('meeting-records-chat')), findsNothing);
      expect(find.byKey(const Key('meeting-records-polls')), findsOneWidget);
    });
  });

  group('read-only panels', () {
    testWidgets('chat history, older page and attachment download', (
      tester,
    ) async {
      await pumpTools(
        tester,
        handlers: {
          'GET $_e/meetings/41/messages': (o) =>
              o.queryParameters['before_id'] == null
              ? (
                  200,
                  _msgPage([
                    _msg(21, text: 'Second'),
                    _msg(20, text: 'Agenda attached', files: [70]),
                  ], last: 2),
                )
              : (200, _msgPage([_msg(12, text: 'First')])),
          'GET $_e/meeting-attachments/70/download': (_) => (
            200,
            RawReply(Uint8List.fromList(utf8.encode('agenda')), {
              Headers.contentTypeHeader: 'text/plain',
              'content-disposition': 'attachment; filename="agenda.txt"',
            }),
          ),
        },
      );
      await tester.tap(find.byKey(const Key('meeting-chat-earlier')));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-attachment-70')));
      await tester.pumpAndSettle();
      expect(find.text('agenda.txt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('attachment-save')));
      await tester.pumpAndSettle();
      expect(saved.single.fileName, 'agenda.txt');
      expectEmployeeRoutesOnly();
      expect(writes(), isEmpty);
    });

    testWidgets('decisions and action items show; filters are documented', (
      tester,
    ) async {
      await pumpTools(tester, tool: MeetingTool.decisions);
      expect(find.text('Weekly releases'), findsOneWidget);
      expect(find.text('View only in the app.'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('meeting-tool-filter-DecisionStatus.approved')),
      );
      await tester.pumpAndSettle();
      expect(http.requests.last.uri.queryParameters['status'], 'approved');
      await openTab(tester, 'actionItems');
      expect(find.text('Release checklist'), findsOneWidget);
      expectNoHostWrites();
    });

    testWidgets('a non-participant gets the notice, no send bar, no retry '
        'storm', (tester) async {
      await pumpTools(
        tester,
        routes: {
          'GET $_e/meetings/41/messages': (
            403,
            _err('You must be a participant of this meeting to use its chat'),
          ),
        },
      );
      expect(find.byKey(const Key('meeting-tool-forbidden')), findsOneWidget);
      expect(find.byKey(const Key('meeting-chat-composer')), findsNothing);
      expect(
        http.requests.where((r) => r.uri.path.endsWith('/messages')),
        hasLength(1),
      );
    });

    testWidgets('a server error shows Retry, which reloads', (tester) async {
      var calls = 0;
      await pumpTools(
        tester,
        tool: MeetingTool.notes,
        handlers: {
          'GET $_e/meetings/41/notes': (_) => ++calls == 1
              ? (500, _err('Server Error'))
              : (
                  200,
                  ok([
                    {'id': 7, 'content': 'Recovered'},
                  ]),
                ),
        },
      );
      await tester.tap(find.byKey(const Key('meeting-tool-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
    });

    testWidgets('empty lists say so', (tester) async {
      await pumpTools(
        tester,
        tool: MeetingTool.polls,
        routes: {'GET $_e/meetings/41/polls': (200, ok(<Object>[]))},
      );
      expect(find.byKey(const Key('meeting-tool-empty')), findsOneWidget);
    });
  });

  group('send and vote (mocked)', () {
    for (final (name, session) in [
      ('regular employee', _regular),
      ('project lead', _lead),
    ]) {
      testWidgets('$name: send once, refresh after it; vote once', (
        tester,
      ) async {
        var sent = false;
        await pumpTools(
          tester,
          session: session,
          handlers: {
            'POST $_e/meetings/41/messages': (_) {
              sent = true;
              return (201, ok({'id': 21}));
            },
            'GET $_e/meetings/41/messages': (o) => (
              200,
              _msgPage([
                if (o.queryParameters['after_id'] == null)
                  _msg(20, text: 'Welcome'),
                if (sent) _msg(21, text: 'Ready for review'),
              ]),
            ),
          },
          routes: {
            'POST $_e/meeting-polls/5/vote': (
              200,
              ok({'id': 5, 'total_votes': 12}),
            ),
          },
        );
        final send = find.byKey(const Key('meeting-chat-send'));
        await tester.enterText(
          find.byKey(const Key('meeting-chat-input')),
          'Ready for review',
        );
        await tester.pump();
        await tester.tap(send);
        await tester.tap(send, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(writes(), hasLength(1));
        expect(writes().single.data, {'message': 'Ready for review'});
        expect(find.byKey(const Key('meeting-message-21')), findsOneWidget);
        expect(http.requests.last.uri.queryParameters['after_id'], '20');

        final polls = find.byKey(const Key('meeting-tool-polls'));
        await tester.tap(polls);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('poll-open-5')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('poll-option-52')));
        await tester.pump();
        final vote = find.byKey(const Key('poll-vote-5'));
        await tester.tap(vote);
        await tester.tap(vote, warnIfMissed: false);
        await tester.pumpAndSettle();
        final votes = writes().where((r) => r.uri.path.endsWith('/vote'));
        expect(votes, hasLength(1));
        expect(votes.single.data, {
          'option_ids': [52],
        });
        expect(find.text('Vote recorded · 12 votes in total'), findsOneWidget);
        expectEmployeeRoutesOnly();
        expectNoHostWrites();
      });
    }

    testWidgets('a file is sent alone under "file"', (tester) async {
      await pumpTools(
        tester,
        routes: {
          'POST $_e/meetings/41/messages': (201, ok({'id': 30})),
        },
      );
      pickResult = [OutgoingFile(name: 'shot.png', bytes: _png)];
      await tester.tap(find.byKey(const Key('meeting-chat-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      final form = writes().single.data as FormData;
      expect(form.files.single.key, 'file');
      expect(find.byKey(const Key('meeting-chat-file')), findsNothing);
    });

    testWidgets('422 keeps the text; Retry sends it again', (tester) async {
      var calls = 0;
      await pumpTools(
        tester,
        handlers: {
          'POST $_e/meetings/41/messages': (_) => ++calls == 1
              ? (
                  422,
                  _err('The given data was invalid.', {
                    'message': ['The message may not be greater than 5000.'],
                  }),
                )
              : (201, ok({'id': 22})),
        },
      );
      await tester.enterText(
        find.byKey(const Key('meeting-chat-input')),
        'Hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Message not sent. The message may not be greater than 5000.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('meeting-chat-retry')));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('403 on send and on vote is said as participants-only', (
      tester,
    ) async {
      await pumpTools(
        tester,
        routes: {
          'POST $_e/meetings/41/messages': (
            403,
            _err('You must be a participant of this meeting to use its chat'),
          ),
          'POST $_e/meeting-polls/5/vote': (
            403,
            _err('You must be a participant of this meeting to use its polls'),
          ),
        },
      );
      await tester.enterText(find.byKey(const Key('meeting-chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Message not sent. Only participants of this meeting can send '
          'messages or vote.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('meeting-tool-polls')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poll-open-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poll-option-51')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('poll-vote-5')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Vote not recorded. Only participants of this meeting can send '
          'messages or vote.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('401 on send ends the session once', (tester) async {
      await pumpTools(
        tester,
        routes: {
          'POST $_e/meetings/41/messages': (401, _err('Unauthenticated.')),
        },
      );
      await tester.enterText(find.byKey(const Key('meeting-chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(writes(), hasLength(1));
      expect(scope.read(sessionControllerProvider).value, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('stale answers (account and company change)', () {
    late _HoldAdapter server;
    late ProviderContainer c;
    late _Auth auth;

    Future<void> boot() async {
      final storage = InMemorySessionStorage();
      await storage.writeAll(_regular.toStorage());
      server = _HoldAdapter({
        ..._routes(),
        'GET $_e/meetings/41/messages': (200, _msgPage([_msg(30, text: 'Hi')])),
        'POST $_e/meetings/41/messages': (201, ok({'id': 31})),
        'POST $_e/meeting-polls/5/vote': (200, ok({'id': 5, 'total_votes': 4})),
      });
      auth = _Auth();
      c = ProviderContainer(
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
              adapter: server,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
    }

    void keep(ProviderListenable<Object?> p) {
      final sub = c.listen(p, (_, _) {});
      addTearDown(sub.close);
    }

    setUp(boot);

    test(
      'a send answered after a company change: no outcome, no re-read',
      () async {
        keep(meetingChatProvider(41));
        keep(meetingMessageSenderProvider(41));
        await c.read(meetingChatProvider(41).future);
        server.holdNext('POST $_e/meetings/41/messages');
        final sending = c
            .read(meetingMessageSenderProvider(41).notifier)
            .send(text: 'Hi');
        await pumpEventQueue();
        await c.read(sessionControllerProvider.notifier).switchCompany(7);
        await c.read(meetingChatProvider(41).future);
        final mark = server.requests.length;
        server.release('POST $_e/meetings/41/messages');
        expect(await sending, isFalse);
        await pumpEventQueue();
        expect(c.read(meetingMessageSenderProvider(41)).value, isNull);
        expect(server.requests.skip(mark), isEmpty, reason: 'no refresh');
        final post = server.requests.singleWhere((r) => r.method == 'POST');
        expect(post.headers['X-Company'], '2');
      },
    );

    test(
      'a vote answered after signing in as another employee is dropped',
      () async {
        keep(pollVoterProvider(5));
        server.holdNext('POST $_e/meeting-polls/5/vote');
        final voting = c
            .read(pollVoterProvider(5).notifier)
            .vote(meetingId: 41, optionIds: [51]);
        await pumpEventQueue();
        await c.read(sessionControllerProvider.notifier).logout();
        await c
            .read(sessionControllerProvider.notifier)
            .login(
              email: 'lead@test.dev',
              password: 'x',
              portal: Portal.employee,
            );
        final mark = server.requests.length;
        server.release('POST $_e/meeting-polls/5/vote');
        expect(await voting, isFalse);
        await pumpEventQueue();
        expect(c.read(pollVoterProvider(5)).value, isNull);
        expect(
          server.requests.skip(mark).where((r) => r.uri.path.contains('poll')),
          isEmpty,
          reason: 'the poll is not re-read for the new account',
        );
      },
    );
  });

  group('live room', () {
    List<Override> room() => [
      mediaEngineProvider.overrideWithValue(FakeMediaEngine()),
      meetingMediaApiProvider.overrideWithValue(_MediaApi()),
      deviceIdStoreProvider.overrideWithValue(MemoryDeviceIdStore()),
    ];

    testWidgets('employee: tool tabs swap the stage and back; media stays', (
      tester,
    ) async {
      await pump(
        tester,
        const ApiMeetingRoomScreen(meetingId: 41, title: 'Sprint Planning'),
        extra: room(),
        fakeEngine: true,
      );
      expect(find.byKey(const Key('meeting-tool-tabs')), findsOneWidget);
      final mediaBefore = http.requests
          .where((r) => r.uri.path.contains('/media/'))
          .length;
      await tester.tap(find.byKey(const Key('meeting-tool-notes')));
      await tester.pumpAndSettle();
      expect(find.text('Planning notes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-tool-notes')));
      await tester.pumpAndSettle();
      expect(find.text('Planning notes'), findsNothing);
      // Opening tools does not leave or rejoin the media room.
      expect(
        http.requests.where((r) => r.uri.path.contains('/media/')).length,
        mediaBefore,
      );
      expectNoHostWrites();
    });
  });

  group('layout', () {
    for (final size in const [
      Size(320, 640),
      Size(360, 740),
      Size(390, 844),
      Size(411, 914),
    ]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'Arabic ${size.width.toInt()} dp x$scale: panels and send bar '
          'with the keyboard up',
          (tester) async {
            await pumpTools(
              tester,
              locale: const Locale('ar'),
              size: size,
              textScale: scale,
            );
            expect(
              Directionality.of(
                tester.element(find.byKey(const Key('meeting-chat-composer'))),
              ),
              TextDirection.rtl,
            );
            await tester.showKeyboard(
              find.byKey(const Key('meeting-chat-input')),
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final send = tester.getRect(
              find.byKey(const Key('meeting-chat-send')),
            );
            expect(send.bottom, lessThanOrEqualTo(size.height - 300 + 0.5));
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            for (final t in ['polls', 'notes', 'decisions', 'actionItems']) {
              await openTab(tester, t);
              expect(tester.takeException(), isNull, reason: t);
            }
            expect(find.text('للعرض فقط في التطبيق.'), findsOneWidget);
          },
        );
      }
    }
  });
}

/// Answers by path (JSON only); records every request as it arrives and
/// holds a chosen one until [release].
class _HoldAdapter implements HttpClientAdapter {
  new(this.routes);

  final Map<String, (int, Object?)> routes;
  final List<RequestOptions> requests = [];
  final _held = <String, Completer<void>>{};

  void holdNext(String key) => _held[key] = Completer<void>();
  void release(String key) => _held.remove(key)!.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final key = '${options.method} ${options.uri.path}';
    await _held[key]?.future;
    final (status, body) = routes[key] ?? (404, _err('Not found'));
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
