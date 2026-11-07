import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/work/presentation/sprint_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import 'meetings_api_test.dart' as m;
import 'sprint_board_api_test.dart' as b;

/// API-mode screens in Arabic at a 360 px phone width, scrolled to the
/// end; any overflow or build error fails the test.
void main() {
  final routes = <String, (int, Object?)>{
    'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
    'GET /api/v1/employee/meetings': (
      200,
      m.page([
        m.meetingJson(myInvitation: {'id': 2, 'status': 'pending'}),
        m.meetingJson(id: 42, status: 'ended', duration: 363),
      ]),
    ),
    'GET /api/v1/employee/meetings/41': (
      200,
      ok(m.meetingJson(myInvitation: {'id': 2, 'status': 'pending'})),
    ),
    'GET /api/v1/employee/meetings/41/participants': (
      200,
      m.page([m.participantJson(1, 'هناء المضيفة', 'host')]),
    ),
    'GET /api/v1/employee/meetings/41/invitations': (
      200,
      m.page([m.invitationJson(5, status: 'accepted')]),
    ),
    'GET /api/v1/employee/meeting-invitations': (
      200,
      m.page([m.invitationJson(2)]),
    ),
    'GET /api/v1/employee/kanban': (
      200,
      b.board(
        tasks: [b.taskJson(1, 'in_progress'), b.taskJson(2, 'in_review')],
      ),
    ),
    'GET /api/v1/employee/sprints': (
      200,
      b.planning(backlog: [b.taskJson(9, 'backlog')]),
    ),
    'GET /api/v1/employee/tasks': (
      200,
      {
        ...m.page([b.taskJson(3, 'todo')]),
        'stats': {
          'total': 1,
          'by_status': {'todo': 1},
          'active': 1,
          'logged_minutes': 70,
        },
        'totals': <Object>[],
      },
    ),
  };

  for (final (name, screen) in [
    ('meetings', const MeetingsScreen()),
    ('meeting details', const ApiMeetingDetailsScreen(id: 41)),
    ('sprint board', const SprintScreen()),
    ('tasks', const TasksScreen()),
  ]) {
    testWidgets('API-mode $name lays out in Arabic', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 780) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = InMemorySessionStorage();
      await storage.writeAll(
        const Session(
          token: 't',
          tokenType: 'Bearer',
          userId: 10,
          companyId: 3,
          portal: Portal.employee,
        ).toStorage(),
      );
      final adapter = RouteHttpAdapter(routes);
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
              adapter: adapter,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('api-error')), findsNothing);
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
    });
  }
}
