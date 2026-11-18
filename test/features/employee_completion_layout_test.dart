import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/data/auth_repository.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/features/reports/presentation/employee_report_screen.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/presentation/api_timesheets.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'employee_completion_test.dart'
    show detailsJson, timesheetJson, timesheetList;
import 'employee_report_test.dart' show reportJson;
import 'meetings_api_test.dart' show meetingJson, page;

/// The new Employee screens in Arabic (RTL) and dark mode, and on a 320 px
/// phone with 130 % text: no overflow or build error, the content scrolls
/// to its end, and the layout direction follows the language. Mocked HTTP.

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _routes = <String, (int, Object?)>{
  'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
  'GET /api/v1/employee/report': (200, ok(reportJson())),
  'GET /api/v1/employee/timesheets/42/details': (
    200,
    ok(detailsJson(inSync: false)),
  ),
  'GET /api/v1/employee/meetings/41': (200, ok(meetingJson())),
  'GET /api/v1/employee/meetings/41/participants': (200, page(const [])),
  'GET /api/v1/employee/meetings/41/invitations': (200, page(const [])),
  'GET /api/v1/employee/meetings/41/join-request': (
    200,
    ok({'id': 9, 'status': 'pending', 'meeting_id': 41}),
  ),
  'GET /api/v1/employee/tasks': (
    200,
    {
      ...page(const []),
      'stats': {
        'total': 0,
        'by_status': <String, int>{},
        'active': 0,
        'logged_minutes': 0,
      },
    },
  ),
};

void main() {
  final modes = <(String, Size, double, AppPreferences)>[
    (
      'Arabic dark 390x844',
      const Size(390, 844),
      1,
      const AppPreferences(
        language: LanguagePreference.arabic,
        appearance: AppearancePreference.dark,
      ),
    ),
    (
      'Arabic light 360x740 x1.3',
      const Size(360, 740),
      1.3,
      const AppPreferences(language: LanguagePreference.arabic),
    ),
    (
      'English light 320x640 x1.3',
      const Size(320, 640),
      1.3,
      const AppPreferences(),
    ),
  ];

  for (final (name, size, scale, prefs) in modes) {
    testWidgets('report, timesheets, join by code, join request: $name', (
      tester,
    ) async {
      useViewport(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts();
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
      final http = RouteHttpAdapter(
        _routes,
        handlers: {
          'GET /api/v1/employee/timesheets': (_) =>
              (200, timesheetList([timesheetJson(42), timesheetJson(43)])),
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                mode: AppMode.api,
                apiBaseUrl: 'https://api.test',
              ),
            ),
            sessionStorageProvider.overrideWithValue(storage),
            authRepositoryProvider.overrideWithValue(_Auth()),
            initialPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWith(
              (ref) => ApiClient(
                baseUrl: 'https://api.test',
                credentials: ref.watch(sessionCredentialsProvider),
                adapter: http,
              ),
            ),
          ],
          child: const WorkFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      final arabic = prefs.language == LanguagePreference.arabic;
      BuildContext shell() => tester.element(find.byType(Scaffold).first);

      Future<void> check(Widget page, Key key) async {
        unawaited(
          Navigator.of(
            shell(),
            rootNavigator: true,
          ).push(MaterialPageRoute<void>(builder: (_) => page)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$key');
        final f = find.byKey(key);
        expect(f, findsOneWidget, reason: '$key');
        expect(
          Directionality.of(tester.element(f)),
          arabic ? TextDirection.rtl : TextDirection.ltr,
        );
        // Manual review only (SCREENSHOT_DIR set); a no-op otherwise.
        await screenshot(
          tester,
          '${name.replaceAll(' ', '_')}_${key.toString().replaceAll(RegExp(r'\W'), '')}',
        );
        final scroll = find.byType(Scrollable).last;
        for (var i = 0; i < 10; i++) {
          await tester.drag(scroll, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$key scrolled');
        }
        Navigator.of(tester.element(f)).pop();
        await tester.pumpAndSettle();
      }

      await check(const EmployeeReportScreen(), const Key('employee-report'));
      await check(const TimesheetsScreen(), const Key('api-timesheet-42'));
      await check(
        TimesheetDetailsScreen(row: ApiTimesheet.fromJson(timesheetJson(42))),
        const Key('timesheet-details'),
      );
      await check(const JoinByCodeScreen(), const Key('join-code'));
      await check(
        const ApiMeetingDetailsScreen(id: 41),
        const Key('my-join-request'),
      );
      await check(const TasksScreen(), const Key('export-csv'));
    });
  }
}
