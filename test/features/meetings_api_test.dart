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
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';

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

/// Sanitized copy of the collection's "200 — live meeting" example
/// (Employee › Meetings › Get Meeting), with the keys the live server
/// returns on list rows.
Map<String, dynamic> meetingJson({
  int id = 41,
  String status = 'live',
  String type = 'instant',
  String? scheduledAt,
  String? startedAt = '2026-10-22T09:00:00.000000Z',
  String? endedAt,
  int duration = 0,
  int? elapsed = 1325,
  Object? myInvitation,
}) => {
  'id': id,
  'company_id': 7,
  'project_id': 9,
  'conversation_id': null,
  'created_by': 3,
  'creator': {'id': 3, 'name': 'Hana Host', 'avatar': null},
  'project': {'id': 9, 'title': 'Apollo'},
  'title': 'Sprint Planning $id',
  'description': null,
  'meeting_code': 'K7Q2-PX9M',
  'join_url': 'https://app.example/meetings/join/K7Q2-PX9M',
  'type': type,
  'status': status,
  'is_private': false,
  'allow_chat': true,
  'allow_recording': false,
  'allow_screen_share': true,
  'allow_whiteboard': true,
  'allow_file_share': false,
  'max_participants': 100,
  'guest_entry_mode': 'approval',
  'scheduled_at': scheduledAt,
  'started_at': startedAt,
  'ended_at': endedAt,
  'duration': duration,
  'elapsed_seconds': elapsed,
  'peak_participants': 6,
  'peak_members': 4,
  'peak_guests': 2,
  'room_name': 'meeting-x',
  'created_at': '2026-10-22T08:55:00.000000Z',
  'updated_at': '2026-10-22T09:00:00.000000Z',
  'my_invitation': myInvitation,
};

Map<String, dynamic> page(List<Object> rows, {int total = -1}) => ok({
  'current_page': 1,
  'data': rows,
  'last_page': 1,
  'per_page': 10,
  'total': total < 0 ? rows.length : total,
});

/// From the collection's "200 — roster with users and durations".
Map<String, dynamic> participantJson(int id, String name, String role) => {
  'id': id,
  'meeting_id': 41,
  'user_id': id,
  'user': {'id': id, 'name': name, 'avatar': null, 'type': 'employee'},
  'role': role,
  'connection_status': role == 'host' ? 'connected' : 'disconnected',
  'camera_enabled': true,
  'microphone_enabled': true,
  'screen_share_enabled': false,
  'muted_by_host': false,
  'joined_at': '2026-10-22T09:20:00.000000Z',
  'left_at': null,
  'last_seen_at': '2026-10-22T09:21:00.000000Z',
  'duration': 1500,
  'current_session_seconds': 125,
  'created_at': '2026-10-22T09:00:05.000000Z',
  'updated_at': '2026-10-22T09:21:00.000000Z',
};

/// Live shape of `GET …/meeting-invitations` rows (values are fixtures).
Map<String, dynamic> invitationJson(int id, {String status = 'pending'}) => {
  'id': id,
  'meeting_id': 41,
  'user_id': 7,
  'invited_by': 3,
  'user': {'id': 7, 'name': 'Me', 'avatar': null, 'type': 'employee'},
  'inviter': {'id': 3, 'name': 'Hana Host'},
  'status': status,
  'role': 'participant',
  'sent_at': '2026-10-22T08:56:00.000000Z',
  'accepted_at': null,
  'declined_at': null,
  'reminder_sent': false,
  'created_at': '2026-10-22T08:56:00.000000Z',
  'updated_at': '2026-10-22T08:56:00.000000Z',
  'meeting': {
    'id': 41,
    'title': 'Sprint Planning 41',
    'status': 'live',
    'type': 'instant',
    'scheduled_at': null,
  },
};

void main() {
  late FakeHttpAdapter http;
  MeetingsRepository repo([Portal portal = Portal.employee]) =>
      MeetingsRepository(
        ApiClient(
          baseUrl: 'https://api.test',
          credentials: _Creds(),
          adapter: http,
        ),
        portal,
      );
  setUp(() => http = FakeHttpAdapter());

  group('contract', () {
    test('a live meeting maps every documented field', () {
      final m = ApiMeeting.fromJson(
        meetingJson(myInvitation: {'id': 2, 'status': 'pending'}),
      );
      expect(m.id, 41);
      expect(m.status, ApiMeetingStatus.live);
      expect(m.type, ApiMeetingType.instant);
      expect(m.creatorName, 'Hana Host');
      expect(m.projectTitle, 'Apollo');
      expect(m.allowFileShare, isFalse);
      expect(m.maxParticipants, 100);
      expect(m.peakParticipants, 6);
      // Live: the run time is the server's elapsed_seconds, not duration 0.
      expect(m.runSeconds, 1325);
      expect(m.myInvitation, (id: 2, status: 'pending'));
      expect(m.anchor, DateTime.parse('2026-10-22T09:00:00Z').toLocal());
    });

    test('an ended meeting uses duration seconds', () {
      final m = ApiMeeting.fromJson(
        meetingJson(
          status: 'ended',
          endedAt: '2026-10-22T09:06:03.000000Z',
          duration: 363,
          elapsed: 363,
        ),
      );
      expect(m.runSeconds, 363);
      expect(m.endedAt, isNotNull);
    });

    test('a meeting that has not started has no run time or end', () {
      final m = ApiMeeting.fromJson(
        meetingJson(
          status: 'waiting',
          type: 'scheduled',
          scheduledAt: '2030-01-01T10:00:00.000000Z',
          startedAt: null,
          elapsed: null,
        ),
      );
      expect(m.runSeconds, isNull);
      expect(m.anchor, DateTime.parse('2030-01-01T10:00:00Z').toLocal());
      expect(displayStatus(m, DateTime(2026)), MeetingStatus.scheduled);
      expect(displayStatus(m, DateTime(2031)), MeetingStatus.overdue);
    });

    test('an instant waiting meeting is never shown as overdue', () {
      final m = ApiMeeting.fromJson(
        meetingJson(status: 'waiting', startedAt: null, elapsed: null),
      );
      expect(displayStatus(m, DateTime(2031)), MeetingStatus.waiting);
    });

    test('cancelled and unknown statuses are kept apart', () {
      expect(
        displayStatus(
          ApiMeeting.fromJson(meetingJson(status: 'cancelled')),
          DateTime(2026),
        ),
        MeetingStatus.cancelled,
      );
      expect(
        ApiMeeting.fromJson(meetingJson(status: 'archived')).status,
        ApiMeetingStatus.other,
      );
    });

    test('a meeting without id or status is an invalid response', () {
      expect(
        () => ApiMeeting.fromJson({...meetingJson()}..remove('status')),
        throwsA(isA<ApiException>()),
      );
    });

    test('participants read user name, role and connection', () {
      final p = ApiParticipant.fromJson(participantJson(211, 'Hana', 'host'));
      expect(p.name, 'Hana');
      expect(p.isHost, isTrue);
      expect(p.isConnected, isTrue);
      expect(p.userType, 'employee');
    });

    test('own invitations carry the meeting summary', () {
      final i = ApiInvitation.fromJson(invitationJson(2));
      expect(i.isPending, isTrue);
      expect(i.meetingTitle, 'Sprint Planning 41');
      expect(i.inviterName, 'Hana Host');
      expect(i.meetingStatus, ApiMeetingStatus.live);
    });
  });

  group('repository', () {
    test('list sends the documented filters to the role prefix', () async {
      http.reply(200, page([meetingJson()]));
      final p = await repo().list((
        search: ' plan ',
        status: ApiMeetingStatus.live,
        page: 2,
      ));
      expect(http.last.path, '/api/v1/employee/meetings');
      expect(http.last.queryParameters, {
        'page': 2,
        'per_page': 10,
        'search': 'plan',
        'status': 'live',
      });
      expect(p.items.single.id, 41);
      expect(http.last.headers['X-Company'], '3');
    });

    test('client reads use the client prefix', () async {
      http.reply(200, page(const []));
      await repo(Portal.client).list((search: '', status: null, page: 1));
      expect(http.last.path, '/api/v1/client/meetings');
      expect(http.last.queryParameters.containsKey('status'), isFalse);
    });

    test('counts come from each status total', () async {
      for (final t in [6, 0, 5, 1]) {
        http.reply(200, page(const [], total: t));
      }
      final c = await repo().counts();
      expect(c, (total: 6, waiting: 0, live: 5, ended: 1));
      expect(http.requests.map((r) => r.queryParameters['status']).toList(), [
        null,
        'waiting',
        'live',
        'ended',
      ]);
    });

    test('participants request the full roster', () async {
      http.reply(200, page([participantJson(1, 'A', 'host')]));
      final p = await repo().participants(41);
      expect(http.last.path, '/api/v1/employee/meetings/41/participants');
      expect(http.last.queryParameters['per_page'], 100);
      expect(p.items.single.isHost, isTrue);
    });

    test('responding sends the documented status value', () async {
      http
        ..reply(200, ok({'id': 2, 'status': 'accepted'}))
        ..reply(200, ok({'id': 2, 'status': 'declined'}));
      await repo().respond(2, accept: true);
      expect(http.last.method, 'PUT');
      expect(http.last.path, '/api/v1/employee/meeting-invitations/2');
      expect(http.lastJsonBody, {'status': 'accepted'});
      await repo(Portal.client).respond(2, accept: false);
      expect(http.last.path, '/api/v1/client/meeting-invitations/2');
      expect(http.lastJsonBody, {'status': 'declined'});
    });

    test('a refused response is surfaced, not treated as success', () async {
      http.reply(409, failure('Invitation already answered'));
      await expectLater(
        repo().respond(2, accept: true),
        throwsA(isA<ApiException>()),
      );
    });

    test('403 on another company meeting is a forbidden error', () async {
      http.reply(403, failure('You are not authorized to access this'));
      await expectLater(
        repo().get(99),
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

  Future<RouteHttpAdapter> pumpApp(
    WidgetTester tester,
    Portal portal, {
    List<Object>? meetings,
    List<Object> invitations = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(390, 2400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 7,
        companyId: 3,
        portal: portal,
      ).toStorage(),
    );
    final r = portal.name;
    final rows = meetings ?? [meetingJson()];
    final adapter = RouteHttpAdapter(
      {
        'GET /api/v1/$r/account': (
          200,
          ok({'id': 7, 'email': 'me@test.dev', 'name': 'Me'}),
        ),
        'GET /api/v1/$r/meetings/41': (200, ok(rows.first)),
        'GET /api/v1/$r/meetings/41/participants': (
          200,
          page([
            participantJson(211, 'Hana Host', 'host'),
            participantJson(210, 'Sam Member', 'participant'),
          ]),
        ),
        'GET /api/v1/$r/meetings/41/invitations': (
          200,
          page([invitationJson(5, status: 'accepted')]),
        ),
        'GET /api/v1/$r/meeting-invitations': (200, page(invitations)),
        'PUT /api/v1/$r/meeting-invitations/2': (
          200,
          ok({'id': 2, 'status': 'accepted'}),
        ),
      },
      handlers: {
        'GET /api/v1/$r/meetings': (o) {
          final s = o.queryParameters['status'];
          final hits = rows
              .whereType<Map<String, dynamic>>()
              .where((m) => s == null || m['status'] == s)
              .toList();
          return (200, page(hits));
        },
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
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: adapter,
            ),
          ),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Meetings')));
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('employee meetings list, KPIs and details come from the API', (
    tester,
  ) async {
    final adapter = await pumpApp(
      tester,
      Portal.employee,
      meetings: [
        meetingJson(),
        meetingJson(
          id: 42,
          status: 'ended',
          endedAt: '2026-10-22T09:06:03.000000Z',
          duration: 363,
        ),
      ],
    );
    expect(find.textContaining('section is ready'), findsNothing);
    expect(find.byKey(const Key('meeting-41')), findsOneWidget);
    expect(find.byKey(const Key('meeting-42')), findsOneWidget);
    // KPIs come from paginator totals per status.
    expect(find.text('1 Active'), findsOneWidget);

    // Join by code is reported as unavailable instead of failing silently.
    await tester.tap(find.text('join by code').first);
    await tester.pump();
    expect(find.textContaining('no meeting lookup by code'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('meeting-41')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('meeting-41')),
        matching: find.text('View Details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hana Host'), findsWidgets);
    expect(find.text('Sam Member'), findsOneWidget);
    expect(find.text('0h 22m 5s'), findsOneWidget);
    expect(find.byKey(const Key('meeting-invitations')), findsOneWidget);
    expect(
      adapter.requests.any(
        (o) => o.uri.path == '/api/v1/employee/meetings/41/invitations',
      ),
      isTrue,
    );
  });

  testWidgets('client details never request the employee-only invitations', (
    tester,
  ) async {
    final adapter = await pumpApp(
      tester,
      Portal.client,
      meetings: [
        meetingJson(myInvitation: {'id': 2, 'status': 'pending'}),
      ],
      invitations: [invitationJson(2)],
    );
    expect(find.byKey(const Key('my-invitations')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('meeting-41')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('meeting-41')),
        matching: find.text('View Details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meeting-invitations')), findsNothing);
    expect(find.byKey(const Key('your-invitation')), findsOneWidget);
    expect(
      adapter.requests.where((o) => o.uri.path.contains('/invitations')),
      isEmpty,
    );

    await tester.ensureVisible(find.byKey(const Key('accept-invitation-2')));
    await tester.tap(find.byKey(const Key('accept-invitation-2')));
    await tester.pumpAndSettle();
    final put = adapter.requests.lastWhere((o) => o.method == 'PUT');
    expect(put.uri.path, '/api/v1/client/meeting-invitations/2');
    expect(put.data, {'status': 'accepted'});
    expect(find.text('Invitation accepted.'), findsOneWidget);
  });

  testWidgets('a failed meetings request shows retry, not sample data', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 2400) * 3
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
    final adapter = RouteHttpAdapter({
      'GET /api/v1/employee/account': (200, ok({'id': 7, 'name': 'Me'})),
      'GET /api/v1/employee/meetings': (500, failure('Server Error')),
      'GET /api/v1/employee/meeting-invitations': (200, page(const [])),
    });
    await tester.pumpWidget(
      ProviderScope(
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
              adapter: adapter,
            ),
          ),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-Meetings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('api-retry')), findsWidgets);
    expect(find.text('Retrospective'), findsNothing);
  });
}
