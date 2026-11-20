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
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_tools.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'meetings_api_test.dart' show meetingJson;

/// Client C4: the client's documented meeting writes — `Send Chat Message`
/// (text, or one file under `file`) and `Vote In Poll` (`option_ids`).
/// Note, decision, action-item and poll writes need `meetings.update`,
/// which the client role lacks (collection: "Permission Boundary (expected
/// 403)"), so the app offers none and these tests check that no such
/// request is ever made. Every response here is a test double; nothing was
/// sent to a live server.

const _base = '/api/v1/client';

Map<String, dynamic> _msgPage(List<Object> rows) => ok({
  'current_page': 1,
  'data': rows,
  'last_page': 1,
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

final _zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4]);
final _mp4 = Uint8List.fromList([0, 0, 0, 0x18, ...ascii.encode('ftypisom')]);
final _mp3 = Uint8List.fromList([...ascii.encode('ID3'), 4, 0, 0, 0xFF]);
final _exe = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00, 0x03, 0xFF, 0xFE]);

/// Writes a client must never attempt (403 for the role).
final _forbiddenWrite = RegExp(
  r'/(notes|decisions|action-items|polls)$|'
  '/meeting-(notes|decisions|action-items)/|'
  r'/meeting-polls/\d+(/close)?$|/approve$|/reject$',
);

class _Creds implements ApiCredentials {
  const new();
  @override
  String? get token => 't';
  @override
  int? get companyId => 5;
  @override
  void onUnauthorized() {}
}

void main() {
  group('contract: documented write requests', () {
    late RouteHttpAdapter adapter;
    late MeetingCollaborationRepository repo;

    MeetingCollaborationRepository repoWith(RouteHttpAdapter a) =>
        MeetingCollaborationRepository(
          ApiClient(
            baseUrl: 'https://api.test',
            credentials: const _Creds(),
            adapter: a,
          ),
          Portal.client,
        );

    setUp(() {
      adapter = RouteHttpAdapter({
        'POST $_base/meetings/41/messages': (
          201,
          ok({
            'id': 90,
            'attachments': [
              {'id': 700},
            ],
          }),
        ),
        'POST $_base/meeting-polls/5/vote': (
          200,
          ok({'id': 5, 'total_votes': 11}),
        ),
      });
      repo = repoWith(adapter);
    });

    test('text goes as the documented JSON body {message}', () async {
      final id = await repo.sendMessage(41, text: '  Hello team  ');
      expect(id, 90);
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '$_base/meetings/41/messages');
      expect(r.data, {'message': 'Hello team'});
      expect(r.headers['X-Company'], '5');
      expect(r.headers['Authorization'], 'Bearer t');
    });

    test('a file goes as multipart under the single key "file"', () async {
      var progress = 0.0;
      await repo.sendMessage(
        41,
        text: 'Agenda',
        file: OutgoingFile(name: 'agenda.png', bytes: _png),
        onProgress: (p) => progress = p,
      );
      final form = adapter.requests.single.data as FormData;
      expect(Map.fromEntries(form.fields), {'message': 'Agenda'});
      expect(form.files.map((f) => f.key), ['file']);
      expect(form.files.single.value.filename, 'agenda.png');
      expect(form.files.single.value.contentType.toString(), 'image/png');
      expect(progress, 1);
    });

    test('a file alone sends no message field', () async {
      await repo.sendMessage(
        41,
        file: OutgoingFile(name: 'a.zip', bytes: _zip),
      );
      final form = adapter.requests.single.data as FormData;
      expect(form.fields, isEmpty);
      expect(form.files.single.value.contentType.toString(), 'application/zip');
    });

    test('invalid sends never reach the server', () async {
      expect(() => repo.sendMessage(41, text: '   '), throwsArgumentError);
      expect(() => repo.sendMessage(41, text: 'x' * 5001), throwsArgumentError);
      expect(() => repo.vote(5, const []), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });

    test('vote sends option_ids and reads id + total_votes', () async {
      final r = await repo.vote(5, [51]);
      expect(r, (pollId: 5, totalVotes: 11));
      final req = adapter.requests.single;
      expect(req.uri.path, '$_base/meeting-polls/5/vote');
      expect(req.data, {
        'option_ids': [51],
      });
    });

    test('a created message without id is an invalid response', () async {
      final r = repoWith(
        RouteHttpAdapter({
          'POST $_base/meetings/41/messages': (201, ok(<String, Object>{})),
          'POST $_base/meeting-polls/5/vote': (200, ok({'id': 5})),
        }),
      );
      await expectLater(
        r.sendMessage(41, text: 'Hi'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
      await expectLater(
        r.vote(5, [51]),
        throwsA(isA<ApiException>()),
        reason: 'total_votes is required by the collection test',
      );
    });

    test('403 (non-participant) and 422 keep their kinds', () async {
      final r = repoWith(
        RouteHttpAdapter({
          'POST $_base/meetings/41/messages': (
            403,
            _err('You must be a participant of this meeting to use its chat'),
          ),
          'POST $_base/meeting-polls/5/vote': (
            422,
            _err('The given data was invalid.', {
              'option_ids': ['The selected option is invalid.'],
            }),
          ),
        }),
      );
      await expectLater(
        r.sendMessage(41, text: 'Hi'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.forbidden,
          ),
        ),
      );
      await expectLater(
        r.vote(5, [99]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.validation,
          ),
        ),
      );
    });
  });

  group('meeting file rules (route mimetypes, 10 MB)', () {
    test('allowed types are recognised by content', () {
      expect(sniffMeetingMime(_png), 'image/png');
      expect(sniffMeetingMime(_zip), 'application/zip');
      expect(sniffMeetingMime(_mp4), 'video/mp4');
      expect(sniffMeetingMime(_mp3), 'audio/mpeg');
      expect(
        sniffMeetingMime(Uint8List.fromList(utf8.encode('notes'))),
        'text/plain',
      );
      for (final b in [_png, _zip, _mp4, _mp3]) {
        expect(checkMeetingFile(OutgoingFile(name: 'f', bytes: b)), isNull);
      }
    });

    test('empty, too large and other types are refused before upload', () {
      expect(
        checkMeetingFile(OutgoingFile(name: 'e', bytes: Uint8List(0))),
        AttachmentProblem.empty,
      );
      expect(
        checkMeetingFile(
          OutgoingFile(
            name: 'big.png',
            bytes: Uint8List(MeetingFileRules.maxBytes + 1)
              ..setRange(0, _png.length, _png),
          ),
        ),
        AttachmentProblem.tooLarge,
      );
      // A name proves nothing: an executable called .pdf is refused.
      expect(
        checkMeetingFile(OutgoingFile(name: 'x.pdf', bytes: _exe)),
        AttachmentProblem.typeNotAllowed,
      );
    });
  });

  group('notifiers: one submit at a time, refresh after success', () {
    late RouteHttpAdapter http;
    late ProviderContainer container;

    Future<void> boot(Map<String, (int, Object?)> routes) async {
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
      http = RouteHttpAdapter(routes);
      container = ProviderContainer(
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
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.future);
    }

    test('a second send while one is on the way is dropped', () async {
      await boot({
        'GET $_base/meetings/41/messages': (200, _msgPage([_msg(1)])),
        'POST $_base/meetings/41/messages': (201, ok({'id': 2})),
      });
      final sub = container.listen(meetingChatProvider(41), (_, _) {});
      addTearDown(sub.close);
      final senderSub = container.listen(
        meetingMessageSenderProvider(41),
        (_, _) {},
      );
      addTearDown(senderSub.close);
      await container.read(meetingChatProvider(41).future);
      final sender = container.read(meetingMessageSenderProvider(41).notifier);
      final results = await Future.wait([
        sender.send(text: 'Hi'),
        sender.send(text: 'Hi'),
      ]);
      expect(results, [true, false]);
      expect(http.requests.where((r) => r.method == 'POST'), hasLength(1));
      // Refresh after the send reads only what is newer (after_id).
      expect(http.requests.last.uri.queryParameters['after_id'], '1');
      expect(container.read(meetingMessageSenderProvider(41)).value, 2);
    });

    test('a second vote while one is on the way is dropped; the poll and '
        'list are read again after success', () async {
      await boot({
        'GET $_base/meetings/41/polls': (
          200,
          ok([
            {'id': 5, 'question': 'Q'},
          ]),
        ),
        'GET $_base/meeting-polls/5': (
          200,
          ok({
            'id': 5,
            'options': [
              {'id': 51, 'title': 'A'},
            ],
          }),
        ),
        'POST $_base/meeting-polls/5/vote': (
          200,
          ok({'id': 5, 'total_votes': 3}),
        ),
      });
      final subs = [
        container.listen(meetingPollsProvider(41), (_, _) {}),
        container.listen(meetingPollProvider(5), (_, _) {}),
        container.listen(pollVoterProvider(5), (_, _) {}),
      ];
      addTearDown(() {
        for (final s in subs) {
          s.close();
        }
      });
      await container.read(meetingPollsProvider(41).future);
      await container.read(meetingPollProvider(5).future);
      final reads = http.requests.length;
      final voter = container.read(pollVoterProvider(5).notifier);
      final results = await Future.wait([
        voter.vote(meetingId: 41, optionIds: [51]),
        voter.vote(meetingId: 41, optionIds: [51]),
      ]);
      expect(results, [true, false]);
      await container.read(meetingPollsProvider(41).future);
      await container.read(meetingPollProvider(5).future);
      final after = http.requests
          .skip(reads)
          .map((r) => '${r.method} ${r.uri.path}');
      expect(after.where((r) => r.startsWith('POST')), hasLength(1));
      expect(after, contains('GET $_base/meetings/41/polls'));
      expect(after, contains('GET $_base/meeting-polls/5'));
      expect(container.read(pollVoterProvider(5)).value?.totalVotes, 3);
    });
  });

  group('widgets', () {
    late RouteHttpAdapter http;
    late ProviderContainer scope;
    var pickResult = <OutgoingFile?>[];

    Future<void> pump(
      WidgetTester tester, {
      MeetingTool tool = MeetingTool.chat,
      Map<String, (int, Object?)> routes = const {},
      Map<String, (int, Object?) Function(RequestOptions)> handlers = const {},
      Locale locale = const Locale('en'),
      bool fileShare = true,
      Size size = const Size(390, 844),
      double textScale = 1,
      List<Override> extra = const [],
    }) async {
      useViewport(tester, size, ratio: 3);
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
      http = RouteHttpAdapter({
        'GET $_base/account': (200, ok({'id': 1, 'name': 'Client'})),
        'GET $_base/meetings/41': (
          200,
          ok({
            ...meetingJson(),
            'allow_chat': true,
            'allow_file_share': fileShare,
          }),
        ),
        'GET $_base/meetings/41/messages': (
          200,
          _msgPage([_msg(20, text: 'Welcome')]),
        ),
        'GET $_base/meetings/41/polls': (
          200,
          ok([
            {'id': 5, 'question': 'Release day?'},
          ]),
        ),
        'GET $_base/meeting-polls/5': (
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
        'GET $_base/meetings/41/notes': (
          200,
          ok([
            {'id': 7, 'title': 'Plan', 'content': 'Two sprints'},
          ]),
        ),
        'GET $_base/meetings/41/decisions': (
          200,
          ok([
            {'id': 3, 'title': 'Weekly releases', 'status': 'pending'},
          ]),
        ),
        'GET $_base/meetings/41/action-items': (
          200,
          ok([
            {'id': 9, 'title': 'Checklist', 'status': 'pending'},
          ]),
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
          meetingFilePickerProvider.overrideWithValue(
            () async => pickResult.isEmpty ? null : pickResult.removeAt(0),
          ),
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
            home: ApiMeetingToolsScreen(
              meetingId: 41,
              title: 'Sprint Planning',
              tools: meetingToolsFor(allowChat: true),
              initial: tool,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<RequestOptions> posts() =>
        http.requests.where((r) => r.method != 'GET');

    void expectNoForbiddenWrites() => expect(
      posts().where((r) => _forbiddenWrite.hasMatch(r.uri.path)),
      isEmpty,
      reason: 'clients lack meetings.update: no note/decision/item/poll write',
    );

    setUp(() => pickResult = []);

    testWidgets('send: text posts once, clears, and the chat refreshes', (
      tester,
    ) async {
      var sent = false;
      await pump(
        tester,
        handlers: {
          'POST $_base/meetings/41/messages': (_) {
            sent = true;
            return (201, ok({'id': 21}));
          },
          'GET $_base/meetings/41/messages': (o) => (
            200,
            _msgPage([
              if (o.queryParameters['after_id'] == null)
                _msg(20, text: 'Welcome'),
              if (sent) _msg(21, text: 'Ready for review'),
            ]),
          ),
        },
      );
      final send = find.byKey(const Key('meeting-chat-send'));
      expect(
        tester.widget<IconButton>(send).onPressed,
        isNull,
        reason: 'nothing to send yet',
      );
      await tester.enterText(
        find.byKey(const Key('meeting-chat-input')),
        'Ready for review',
      );
      await tester.pump();
      // Two quick taps: one request.
      await tester.tap(send);
      await tester.tap(send, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(posts(), hasLength(1));
      expect(posts().single.data, {'message': 'Ready for review'});
      expect(find.byKey(const Key('meeting-message-21')), findsOneWidget);
      expect(
        http.requests.last.uri.queryParameters['after_id'],
        '20',
        reason: 'refresh reads only newer messages',
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('meeting-chat-input')),
      );
      expect(field.controller!.text, isEmpty);
      expectNoForbiddenWrites();
    });

    testWidgets('send: 422 keeps the text and Retry sends it again', (
      tester,
    ) async {
      var calls = 0;
      await pump(
        tester,
        handlers: {
          'POST $_base/meetings/41/messages': (_) => ++calls == 1
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
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('meeting-chat-input')))
            .controller!
            .text,
        'Hello',
      );
      await tester.tap(find.byKey(const Key('meeting-chat-retry')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(const Key('meeting-chat-send-error')), findsNothing);
    });

    testWidgets('send: 401 and 403 are said as such', (tester) async {
      await pump(
        tester,
        routes: {
          'POST $_base/meetings/41/messages': (
            403,
            _err('You must be a participant of this meeting to use its chat'),
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
    });

    testWidgets('a non-participant gets the notice and no send bar', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'GET $_base/meetings/41/messages': (
            403,
            _err('You must be a participant of this meeting to use its chat'),
          ),
        },
      );
      expect(find.byKey(const Key('meeting-tool-forbidden')), findsOneWidget);
      expect(find.byKey(const Key('meeting-chat-composer')), findsNothing);
    });

    testWidgets('401 on send ends the session once (sign-in follows)', (
      tester,
    ) async {
      await pump(
        tester,
        routes: {
          'POST $_base/meetings/41/messages': (401, _err('Unauthenticated.')),
        },
      );
      await tester.enterText(find.byKey(const Key('meeting-chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(posts(), hasLength(1));
      // The app-wide rule: a 401 ends the session; the router then shows
      // sign-in. Nothing is retried on its own.
      expect(scope.read(sessionControllerProvider).value, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('attach: a refused file is said and never uploaded', (
      tester,
    ) async {
      pickResult = [OutgoingFile(name: 'tool.pdf', bytes: _exe)];
      await pump(tester);
      await tester.tap(find.byKey(const Key('meeting-chat-attach')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Only images, PDF, text, MP4, MP3 and ZIP files can be shared in a '
          'meeting.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('meeting-chat-file')), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('meeting-chat-send')))
            .onPressed,
        isNull,
      );
      expect(posts(), isEmpty);
    });

    testWidgets('attach: a file is sent alone, then cleared', (tester) async {
      pickResult = [OutgoingFile(name: 'minutes.zip', bytes: _zip)];
      await pump(
        tester,
        routes: {
          'POST $_base/meetings/41/messages': (
            201,
            ok({
              'id': 23,
              'attachments': [
                {'id': 701},
              ],
            }),
          ),
        },
      );
      await tester.tap(find.byKey(const Key('meeting-chat-attach')));
      await tester.pumpAndSettle();
      expect(find.text('minutes.zip'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      final form = posts().single.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.fields, isEmpty);
      expect(find.byKey(const Key('meeting-chat-file')), findsNothing);
    });

    testWidgets('attach: the server refusing the file keeps it for retry', (
      tester,
    ) async {
      pickResult = [OutgoingFile(name: 'shot.png', bytes: _png)];
      await pump(
        tester,
        routes: {
          'POST $_base/meetings/41/messages': (
            422,
            _err('The given data was invalid.', {
              'file': ['File sharing is disabled for this meeting.'],
            }),
          ),
        },
      );
      await tester.tap(find.byKey(const Key('meeting-chat-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Message not sent. File sharing is disabled for this meeting.',
        ),
        findsOneWidget,
      );
      expect(find.text('shot.png'), findsOneWidget);
      expect(find.byKey(const Key('meeting-chat-retry')), findsOneWidget);
    });

    testWidgets('no attach button when the meeting disallows file sharing', (
      tester,
    ) async {
      await pump(tester, fileShare: false);
      expect(find.byKey(const Key('meeting-chat-composer')), findsOneWidget);
      expect(find.byKey(const Key('meeting-chat-attach')), findsNothing);
    });

    testWidgets('vote: choose, vote once, total shown, poll re-read', (
      tester,
    ) async {
      await pump(
        tester,
        tool: MeetingTool.polls,
        routes: {
          'POST $_base/meeting-polls/5/vote': (
            200,
            ok({'id': 5, 'total_votes': 12}),
          ),
        },
      );
      await tester.tap(find.byKey(const Key('poll-open-5')));
      await tester.pumpAndSettle();
      final vote = find.byKey(const Key('poll-vote-5'));
      expect(
        tester.widget<ButtonStyleButton>(vote).onPressed,
        isNull,
        reason: 'no option chosen',
      );
      await tester.tap(find.byKey(const Key('poll-option-52')));
      await tester.pump();
      final pollReads = http.requests
          .where((r) => r.uri.path == '$_base/meeting-polls/5')
          .length;
      await tester.tap(vote);
      await tester.tap(vote, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(posts(), hasLength(1));
      expect(posts().single.data, {
        'option_ids': [52],
      });
      expect(find.text('Vote recorded · 12 votes in total'), findsOneWidget);
      expect(
        http.requests
            .where((r) => r.uri.path == '$_base/meeting-polls/5')
            .length,
        greaterThan(pollReads),
        reason: 'the poll is read again after the vote',
      );
      expect(
        tester.widget<ButtonStyleButton>(vote).onPressed,
        isNull,
        reason: 'the same choice is not sent again',
      );
      expectNoForbiddenWrites();
    });

    testWidgets('vote: 422 (closed poll) and 403 are shown; Vote retries', (
      tester,
    ) async {
      var calls = 0;
      await pump(
        tester,
        tool: MeetingTool.polls,
        handlers: {
          'POST $_base/meeting-polls/5/vote': (_) => switch (++calls) {
            1 => (
              422,
              _err('The given data was invalid.', {
                'option_ids': ['This poll is closed.'],
              }),
            ),
            _ => (
              403,
              _err(
                'You must be a participant of this meeting to use its polls',
              ),
            ),
          },
        },
      );
      await tester.tap(find.byKey(const Key('poll-open-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poll-option-51')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('poll-vote-5')));
      await tester.pumpAndSettle();
      expect(
        find.text('Vote not recorded. This poll is closed.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('poll-vote-5')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Vote not recorded. Only participants of this meeting can send '
          'messages or vote.',
        ),
        findsOneWidget,
      );
      expect(calls, 2);
    });

    testWidgets('notes, decisions and action items offer no write', (
      tester,
    ) async {
      await pump(tester, tool: MeetingTool.notes);
      for (final t in ['notes', 'decisions', 'actionItems']) {
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
        expect(find.byKey(const Key('meeting-tool-read-only')), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      }
      expect(find.text('Checklist'), findsOneWidget);
      expect(posts(), isEmpty);
    });

    testWidgets('Arabic RTL: send bar and vote', (tester) async {
      await pump(
        tester,
        locale: const Locale('ar'),
        routes: {
          'POST $_base/meetings/41/messages': (201, ok({'id': 24})),
          'POST $_base/meeting-polls/5/vote': (
            200,
            ok({'id': 5, 'total_votes': 3}),
          ),
        },
      );
      expect(find.text('اكتب رسالة للمشاركين…'), findsOneWidget);
      // The send arrow mirrors itself (matchTextDirection).
      expect(Icons.send_rounded.matchTextDirection, isTrue);
      final attach = tester.getCenter(
        find.byKey(const Key('meeting-chat-attach')),
      );
      final send = tester.getCenter(find.byKey(const Key('meeting-chat-send')));
      expect(attach.dx, greaterThan(send.dx), reason: 'RTL: attach at start');
      await tester.enterText(
        find.byKey(const Key('meeting-chat-input')),
        'مرحبًا',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('meeting-chat-send')));
      await tester.pumpAndSettle();
      expect(posts().single.data, {'message': 'مرحبًا'});

      await tester.tap(find.byKey(const Key('meeting-tool-polls')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poll-open-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poll-option-51')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('poll-vote-5')));
      await tester.pumpAndSettle();
      expect(find.text('تم تسجيل صوتك · 3 أصوات إجمالًا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('responsive: viewports × text scale, keyboard up', () {
      setUpAll(loadAppFonts);
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final v in phoneViewports.entries) {
          for (final scale in const [1.0, 1.3]) {
            testWidgets('${locale.languageCode} ${v.key} x$scale', (
              tester,
            ) async {
              pickResult = [
                OutgoingFile(
                  name: 'a-very-long-file-name-for-the-meeting-minutes.pdf',
                  bytes: Uint8List.fromList(ascii.encode('%PDF-1.4')),
                ),
              ];
              await pump(
                tester,
                locale: locale,
                size: v.value,
                textScale: scale,
              );
              await tester.tap(find.byKey(const Key('meeting-chat-attach')));
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byKey(const Key('meeting-chat-input')),
                'A long line of text ' * 12,
              );
              showKeyboard(tester, v.value.height * 0.42, ratio: 3);
              await tester.pumpAndSettle();
              final send = find.byKey(const Key('meeting-chat-send'));
              expect(send.hitTestable(), findsOneWidget);
              expect(
                tester.getBottomLeft(send).dy,
                lessThanOrEqualTo(v.value.height * 0.58),
                reason: 'send stays above the keyboard',
              );
              await screenshot(
                tester,
                'c4_chat_${locale.languageCode}_${v.key}_x$scale',
              );

              await tester.tap(find.byKey(const Key('meeting-tool-polls')));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('poll-open-5')));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('poll-option-51')));
              await tester.pump();
              final vote = find.byKey(const Key('poll-vote-5'));
              await tester.ensureVisible(vote);
              await tester.pumpAndSettle();
              expect(vote.hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    });
  });
}
