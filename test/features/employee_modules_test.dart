import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

/// Demo-mode flows for the employee screens built from Figma.
void main() {
  Future<void> pumpEmployee(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 2,
        companyId: 1,
        portal: Portal.employee,
      ).toStorage(),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
          ),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: const WorkFlowApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder page() => find
      .descendant(
        of: find.byType(CustomScrollView).last,
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openFromMore(WidgetTester tester, String item) async {
    await tab(tester, 'More');
    await tester.scrollUntilVisible(
      find.byKey(Key('category-$item')),
      200,
      scrollable: page(),
    );
    await tester.tap(find.byKey(Key('category-$item')));
    await tester.pumpAndSettle();
  }

  testWidgets('Employee nav shows Sprints and moves a kanban card', (
    tester,
  ) async {
    await pumpEmployee(tester);
    expect(find.text('Sprints'), findsOneWidget);
    await tab(tester, 'Sprints');
    expect(find.text('Sprint & Backlog'), findsOneWidget);
    expect(find.byKey(const Key('kanban-t1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kanban-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-t1')), findsNothing);

    await tester.tap(find.byKey(const Key('column-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-t1')), findsOneWidget);
  });

  testWidgets('Tasks Management via More: filter by priority and delete', (
    tester,
  ) async {
    await pumpEmployee(tester);
    await openFromMore(tester, 'Tasks');
    expect(find.text('Tasks Management'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tasks-search')),
      200,
      scrollable: page(),
    );
    await tester.enterText(find.byKey(const Key('tasks-search')), 'Redis');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-t3')),
      200,
      scrollable: page(),
    );
    expect(find.byKey(const Key('task-t1')), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('task-t3')),
        matching: find.byKey(const Key('action-delete')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-t3')), findsNothing);
  });

  testWidgets('Timesheets: the status filter narrows the records', (
    tester,
  ) async {
    await pumpEmployee(tester);
    await openFromMore(tester, 'Timesheets');
    expect(find.text('Timesheets Dashboard'), findsOneWidget);
    final filter = find.byKey(const Key('timesheet-status-filter'));
    await tester.scrollUntilVisible(filter, 200, scrollable: page());
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('option-sheet')),
        matching: find.text('Rejected'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('timesheet-ts2')),
      200,
      scrollable: page(),
    );
    expect(find.byKey(const Key('timesheet-ts0')), findsNothing);
  });

  testWidgets('Dashboard: task widgets link to Tasks and Sprints', (
    tester,
  ) async {
    await pumpEmployee(tester);
    await openFromMore(tester, 'Dashboard');
    expect(find.text('Working Hours & Trend'), findsOneWidget);
    // Six demo tasks: one completed, two high/urgent still open.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2 high priority'), findsOneWidget);

    await tester.tap(find.byKey(const Key('all-tasks')));
    await tester.pumpAndSettle();
    expect(find.text('Tasks Management'), findsOneWidget);
    await tester.tap(find.byKey(const Key('masthead-back')).last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('view-backlog')),
      200,
      scrollable: page(),
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('view-backlog'))),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-t1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-backlog')));
    await tester.pumpAndSettle();
    expect(find.text('Sprint & Backlog'), findsOneWidget);
  });
}
