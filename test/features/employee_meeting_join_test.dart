import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';

import '../helpers/fake_http_adapter.dart';
import 'employee_completion_test.dart' show paths, pumpEmployeeScreen;
import 'meetings_api_test.dart' show meetingJson, page;

/// Employee join by code (`GET /employee/meetings/by-code/{code}`) and the
/// caller's own join request (`GET/DELETE …/meetings/{id}/join-request`).
/// The by-code 404 shape was read live on 2026-11-18; no join request was
/// created, read or withdrawn on a real server.

class _Creds implements ApiCredentials {
  @override
  String? get token => 't';
  @override
  int? get companyId => 3;
  @override
  void onUnauthorized() {}
}

Map<String, (int, Object?)> _details({String status = 'ended'}) => {
  'GET /api/v1/employee/meetings/41': (200, ok(meetingJson(status: status))),
  'GET /api/v1/employee/meetings/41/participants': (200, page(const [])),
  'GET /api/v1/employee/meetings/41/invitations': (200, page(const [])),
};

void main() {
  group('repository', () {
    late FakeHttpAdapter http;
    MeetingsRepository repo() => MeetingsRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        credentials: _Creds(),
        adapter: http,
      ),
      Portal.employee,
    );
    setUp(() => http = FakeHttpAdapter());

    test('by-code: the code is path-encoded and data {id} read', () async {
      http.reply(200, ok({'id': 41}));
      expect(await repo().meetingIdByCode(' BHU 232/CEK '), 41);
      expect(
        http.last.uri.path,
        '/api/v1/employee/meetings/by-code/BHU%20232%2FCEK',
      );
    });

    test('by-code: an unknown or inaccessible code is 404', () async {
      http.reply(404, failure('Meeting not found'));
      await expectLater(
        repo().meetingIdByCode('NOPE'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.notFound,
          ),
        ),
      );
    });

    test('my join request: documented fields; 404 means none', () async {
      http.reply(200, ok({'id': 9, 'status': 'pending', 'meeting_id': 41}));
      final r = await repo().myJoinRequest(41);
      expect(http.last.path, '/api/v1/employee/meetings/41/join-request');
      expect(r?.id, 9);
      expect(r?.isPending, isTrue);
      http.reply(404, failure('No join request'));
      expect(await repo().myJoinRequest(41), isNull);
    });

    test('my join request: other failures are errors', () async {
      http.reply(403, failure('Forbidden'));
      await expectLater(repo().myJoinRequest(41), throwsA(isA<ApiException>()));
    });

    test('withdraw sends DELETE on the caller\'s own request', () async {
      http.reply(200, ok(null));
      await repo().withdrawJoinRequest(41);
      expect(http.last.method, 'DELETE');
      expect(http.last.path, '/api/v1/employee/meetings/41/join-request');
    });
  });

  group('join by code', () {
    testWidgets('a code opens the meeting details; no password field', (
      tester,
    ) async {
      final a = await pumpEmployeeScreen(
        tester,
        const JoinByCodeScreen(),
        routes: {
          'GET /api/v1/employee/meetings/by-code/ABC-123': (
            200,
            ok({'id': 41}),
          ),
          ..._details(),
          'GET /api/v1/employee/meetings/41/join-request': (
            404,
            failure('No join request'),
          ),
        },
      );
      expect(find.text('Room password'), findsNothing);
      await tester.enterText(find.byKey(const Key('join-code')), 'ABC-123');
      await tester.tap(find.text('Find meeting'));
      await tester.pumpAndSettle();
      expect(
        paths(a),
        contains('GET /api/v1/employee/meetings/by-code/ABC-123'),
      );
      expect(find.byType(ApiMeetingDetailsScreen), findsOneWidget);
      // No join request: nothing about one is shown.
      expect(find.byKey(const Key('my-join-request')), findsNothing);
    });

    testWidgets('an unknown code says so and stays on the form', (
      tester,
    ) async {
      await pumpEmployeeScreen(
        tester,
        const JoinByCodeScreen(),
        routes: {
          'GET /api/v1/employee/meetings/by-code/NOPE': (
            404,
            failure('Meeting not found'),
          ),
        },
      );
      await tester.enterText(find.byKey(const Key('join-code')), 'NOPE');
      await tester.tap(find.text('Find meeting'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No meeting with this code'), findsOneWidget);
      expect(find.byType(JoinByCodeScreen), findsOneWidget);
    });

    testWidgets('the employee Meetings list offers Join by code', (
      tester,
    ) async {
      await pumpEmployeeScreen(
        tester,
        const ApiMeetingsView(),
        handlers: {
          'GET /api/v1/employee/meetings': (_) => (200, page(const [])),
        },
        routes: {
          'GET /api/v1/employee/meeting-invitations': (200, page(const [])),
        },
      );
      await tester.tap(find.byKey(const Key('meetings-join-by-code')));
      await tester.pumpAndSettle();
      expect(find.byType(JoinByCodeScreen), findsOneWidget);
    });
  });

  group('my join request', () {
    testWidgets('pending: shown; withdraw asks first, then deletes', (
      tester,
    ) async {
      var withdrawn = false;
      final a = await pumpEmployeeScreen(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        routes: {..._details(status: 'live')},
        handlers: {
          'GET /api/v1/employee/meetings/41/join-request': (_) => withdrawn
              ? (404, failure('No join request'))
              : (200, ok({'id': 9, 'status': 'pending', 'meeting_id': 41})),
          'DELETE /api/v1/employee/meetings/41/join-request': (_) {
            withdrawn = true;
            return (200, ok(null));
          },
        },
      );
      expect(find.byKey(const Key('my-join-request')), findsOneWidget);
      expect(find.text('Waiting for the host'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('join-request-withdraw')),
      );
      await tester.tap(find.byKey(const Key('join-request-withdraw')));
      await tester.pumpAndSettle();
      // Cancelling the dialog sends nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(paths(a).where((p) => p.startsWith('DELETE')), isEmpty);
      await tester.tap(find.byKey(const Key('join-request-withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join-request-withdraw-confirm')));
      await tester.pumpAndSettle();
      expect(
        paths(a),
        contains('DELETE /api/v1/employee/meetings/41/join-request'),
      );
      expect(find.text('Join request withdrawn.'), findsOneWidget);
      expect(find.byKey(const Key('my-join-request')), findsNothing);
    });

    testWidgets('Check again reads the request again', (tester) async {
      var reads = 0;
      await pumpEmployeeScreen(
        tester,
        const ApiMeetingDetailsScreen(id: 41),
        routes: _details(status: 'live'),
        handlers: {
          'GET /api/v1/employee/meetings/41/join-request': (_) {
            reads++;
            return (
              200,
              ok({
                'id': 9,
                'status': reads == 1 ? 'pending' : 'admitted',
                'meeting_id': 41,
              }),
            );
          },
        },
      );
      await tester.ensureVisible(find.byKey(const Key('join-request-refresh')));
      await tester.tap(find.byKey(const Key('join-request-refresh')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      // A status other than pending is shown as the server gives it.
      expect(find.text('admitted'), findsOneWidget);
      expect(find.byKey(const Key('join-request-withdraw')), findsNothing);
    });
  });
}
