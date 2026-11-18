import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/categories/presentation/client_categories.dart';
import 'package:workflow_app/features/categories/presentation/employee_categories.dart';
import 'package:workflow_app/features/companies/presentation/companies_screen.dart';
import 'package:workflow_app/features/conversations/presentation/conversations_screens.dart';
import 'package:workflow_app/features/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_details_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/overview/presentation/overview_screen.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/features/work/presentation/sprint_screen.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';

import '../helpers/viewport.dart';

/// Android Back through the real router (demo data): it returns to the
/// previous meaningful screen, keeps list state, and leaves the app only
/// from Home. The Redmi 8 run found More → Projects → Back closed the app.

late List<String> _exits;

/// What the app last told Android with `setFrameworkHandlesBack`.
bool? _frameworkHandlesBack;

Future<void> _pump(WidgetTester tester, Portal portal) async {
  useViewport(tester, const Size(390, 844));
  await loadAppFonts();
  _exits = [];
  _frameworkHandlesBack = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') _exits.add(call.method);
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        _frameworkHandlesBack = call.arguments as bool;
      }
      return null;
    },
  );
  // A running app: the framework reports Back handling only once resumed.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.mock, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

/// Android system Back as Android 13+ delivers it with predictive back (on
/// by default when targeting API 36): if the app last said it cannot handle
/// Back, the system closes the app without asking Flutter. The emulator run
/// (Android 16) found More → Tasks → Task Details → Back → Back closed the
/// app this way; the Redmi 8 (older Android) always asks Flutter.
Future<void> _back(WidgetTester tester) async {
  if (_frameworkHandlesBack == false) {
    _exits.add('system closed the app');
    return;
  }
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// The screen the user sees (not an offstage tab or a covered route).
void _onTop(Type screen) => expect(
  find.byType(screen).hitTestable(),
  findsOneWidget,
  reason: '$screen should be on top',
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f.hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _bar(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable().last);
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester, String entry) async {
  await _bar(tester, 'More');
  await _tap(tester, find.byKey(Key('category-$entry')));
}

void main() {
  group('employee', () {
    testWidgets('More → Projects → Back returns to More, then Home, then '
        'exits', (tester) async {
      await _pump(tester, Portal.employee);
      _onTop(OverviewScreen);
      await _more(tester, 'Projects');
      _onTop(ProjectsScreen);
      await _back(tester);
      _onTop(EmployeeCategoriesScreen);
      expect(_exits, isEmpty, reason: 'Back from Projects closed the app');
      await _back(tester);
      _onTop(OverviewScreen);
      expect(_exits, isEmpty);
      await _back(tester);
      expect(_exits, ['SystemNavigator.pop']);
    });

    testWidgets('More → Sprints and More → Conversations come back to More', (
      tester,
    ) async {
      await _pump(tester, Portal.employee);
      for (final (entry, screen) in [
        ('Sprints', SprintScreen),
        ('Conversations', ConversationsScreen),
      ]) {
        await _more(tester, entry);
        _onTop(screen);
        await _back(tester);
        _onTop(EmployeeCategoriesScreen);
      }
      expect(_exits, isEmpty);
    });

    testWidgets('More → Tasks → Task Details → Back keeps the filter', (
      tester,
    ) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Tasks');
      _onTop(TasksScreen);
      await _tap(tester, find.byKey(const Key('task-filters')));
      await _tap(tester, find.byKey(const Key('filter-status-inProgress')));
      await _tap(tester, find.byKey(const Key('task-filters-apply')));
      expect(find.byKey(const Key('active-filter-status')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('task-t1')));
      _onTop(DemoTaskDetailsScreen);
      await _back(tester);
      _onTop(TasksScreen);
      expect(find.byKey(const Key('active-filter-status')), findsOneWidget);
      await _back(tester);
      _onTop(EmployeeCategoriesScreen);
      expect(_exits, isEmpty);
    });

    testWidgets('a tab switch keeps a screen opened from More', (tester) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Tasks');
      await _bar(tester, 'Chat');
      _onTop(ConversationsScreen);
      await _back(tester);
      // Back to the More tab, Tasks still open on it.
      _onTop(TasksScreen);
      await _back(tester);
      _onTop(EmployeeCategoriesScreen);
    });

    testWidgets('More → Meetings → Meeting Details → Back', (tester) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Meetings');
      _onTop(MeetingsScreen);
      await _tap(tester, find.byKey(const Key('meeting-m1')));
      _onTop(MeetingDetailsScreen);
      await _back(tester);
      _onTop(MeetingsScreen);
      await _back(tester);
      _onTop(EmployeeCategoriesScreen);
      expect(_exits, isEmpty);
    });

    testWidgets('Dashboard → Projects → Back returns to the Dashboard', (
      tester,
    ) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Dashboard');
      _onTop(EmployeeDashboardScreen);
      await _tap(tester, find.byKey(const Key('view-backlog')));
      _onTop(SprintScreen);
      await _back(tester);
      _onTop(EmployeeDashboardScreen);
      await _tap(tester, find.byKey(const Key('all-tasks')));
      _onTop(TasksScreen);
      await _tap(tester, find.byKey(const Key('task-t1')));
      _onTop(DemoTaskDetailsScreen);
      await _back(tester);
      _onTop(TasksScreen);
      await _back(tester);
      _onTop(EmployeeDashboardScreen);
      await _back(tester);
      _onTop(EmployeeCategoriesScreen);
      expect(_exits, isEmpty);
    });

    testWidgets('Back walks visited tabs once each, without loops', (
      tester,
    ) async {
      await _pump(tester, Portal.employee);
      await _bar(tester, 'Projects');
      await _bar(tester, 'Chat');
      await _bar(tester, 'Projects');
      await _bar(tester, 'Chat');
      await _back(tester);
      _onTop(ProjectsScreen);
      await _back(tester);
      _onTop(OverviewScreen);
      await _back(tester);
      expect(_exits, hasLength(1));
    });

    testWidgets('re-tapping the current tab returns to its first screen', (
      tester,
    ) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Meetings');
      _onTop(MeetingsScreen);
      await _bar(tester, 'More');
      _onTop(EmployeeCategoriesScreen);
      // Another tab and back keeps what was open there.
      await _more(tester, 'Tasks');
      await _bar(tester, 'Chat');
      await _bar(tester, 'More');
      _onTop(TasksScreen);
    });

    testWidgets('a sheet closes first on Back, the tab stays', (tester) async {
      await _pump(tester, Portal.employee);
      await _more(tester, 'Tasks');
      await _tap(tester, find.byKey(const Key('task-filters')));
      expect(find.byKey(const Key('task-filter-sheet')), findsOneWidget);
      await _back(tester);
      expect(find.byKey(const Key('task-filter-sheet')), findsNothing);
      _onTop(TasksScreen);
    });
  });

  group('client', () {
    testWidgets('More → Companies / Invoices / Chat come back to More', (
      tester,
    ) async {
      await _pump(tester, Portal.client);
      for (final (entry, screen) in [
        ('Companies', CompaniesScreen),
        ('Invoices', InvoicesScreen),
        ('Conversations', ConversationsScreen),
      ]) {
        await _more(tester, entry);
        _onTop(screen);
        await _back(tester);
        _onTop(ClientCategoriesScreen);
      }
      await _back(tester);
      _onTop(OverviewScreen);
      expect(_exits, isEmpty);
      await _back(tester);
      expect(_exits, hasLength(1));
    });

    testWidgets('More → Projects / Meetings → Back returns to More', (
      tester,
    ) async {
      await _pump(tester, Portal.client);
      await _more(tester, 'Projects');
      _onTop(ProjectsScreen);
      await _back(tester);
      _onTop(ClientCategoriesScreen);
      await _more(tester, 'Meetings');
      _onTop(MeetingsScreen);
      await _tap(tester, find.byKey(const Key('meeting-m1')));
      _onTop(MeetingDetailsScreen);
      await _back(tester);
      _onTop(MeetingsScreen);
      await _back(tester);
      _onTop(ClientCategoriesScreen);
      expect(_exits, isEmpty);
    });
  });
}
