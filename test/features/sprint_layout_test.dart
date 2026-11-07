import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'sprint_board_api_test.dart' as b;

const _longTitle =
    'Create executive dashboard widgets and a realtime analytics stream '
    'for the regional operations team with drill-down filters';
const _longWord = 'Supercalifragilisticexpialidocious_refactor_of_billing';

Map<String, dynamic> _task(int id, String status, {String? title}) => {
  ...b.taskJson(id, status),
  'title': ?title,
  'assignee': {'id': 10, 'name': 'Lina Dawood Al-Khatib'},
  'sprint': {'id': 2, 'name': 'Sprint 24 — Customer portal hardening'},
};

Map<String, dynamic> _board({
  List<Object> tasks = const [],
  bool sprint = true,
}) {
  final body = b.board(tasks: tasks, sprint: sprint);
  final data = body['data'] as Map<String, dynamic>;
  data['projects'] = [
    for (var i = 0; i < 9; i++)
      {
        'id': 2 + i,
        'title': i == 0
            ? 'Demo Project 01 — Customer Portal Revamp and Billing Migration'
            : 'Project ${i + 1}',
        'leader_id': 4,
        'leader_name': 'Lead',
      },
  ];
  data['selected_project'] = {
    'id': 2,
    'title': 'Demo Project 01 — Customer Portal Revamp and Billing Migration',
    'leader_id': 4,
  };
  return body;
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  AppMode mode = AppMode.api,
  Map<String, (int, Object?)> routes = const {},
}) async {
  useViewport(tester, size);
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
  final adapter = RouteHttpAdapter({
    'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
    'GET /api/v1/employee/sprints': (
      200,
      b.planning(backlog: [_task(9, 'backlog', title: _longTitle)]),
    ),
    'POST /api/v1/employee/kanban/update-status': (200, ok({'id': 1})),
    ...routes,
  });
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        if (mode == AppMode.api)
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
  await tester.tap(find.text('Sprints').last);
  await tester.pumpAndSettle();
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 8; i++) {
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

/// The last card must stay clear of the floating navigation surface.
/// Scrolls [target] into the area between the masthead and the floating
/// navigation surface, where a finger can actually reach it.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    // Built lazily: scroll back up until the list builds it.
    await tester.scrollUntilVisible(
      target,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final navTop = tester.getRect(find.text('Sprints').last).top - 44;
  final r = tester.getRect(target);
  if (r.bottom > navTop) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, navTop - r.bottom - 16),
    );
    await tester.pumpAndSettle();
  }
}

void _expectAboveNav(WidgetTester tester, Finder card) {
  final nav = tester.getRect(find.text('Sprints').last).top - 44;
  expect(tester.getRect(card.last).bottom, lessThanOrEqualTo(nav));
}

void main() {
  for (final MapEntry(key: name, value: size) in phoneViewports.entries) {
    group(name, () {
      testWidgets('API board with long titles fits and scrolls clear', (
        tester,
      ) async {
        await _pump(
          tester,
          size,
          routes: {
            'GET /api/v1/employee/kanban': (
              200,
              _board(
                tasks: [
                  _task(1, 'in_progress', title: _longTitle),
                  _task(2, 'in_progress', title: _longWord),
                  _task(3, 'in_progress'),
                  _task(4, 'todo'),
                ],
              ),
            ),
          },
        );
        await screenshot(tester, 'sprint_api_top_$name');
        for (final c in ['todo', 'inProgress', 'inReview', 'completed']) {
          await _reveal(tester, find.byKey(Key('column-$c')));
          await tester.tap(find.byKey(Key('column-$c')));
          await tester.pumpAndSettle();
          // Each tab label stays on one line inside its tab.
          final tab = tester.getRect(find.byKey(Key('column-$c')));
          final label = tester.getRect(
            find.descendant(
              of: find.byKey(Key('column-$c')),
              matching: find.byType(Text),
            ),
          );
          expect(label.width, lessThanOrEqualTo(tab.width));
          await screenshot(tester, 'sprint_api_column_${c}_$name');
        }
        await _reveal(tester, find.byKey(const Key('column-inProgress')));
        await tester.tap(find.byKey(const Key('column-inProgress')));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        await screenshot(tester, 'sprint_api_end_$name');
        _expectAboveNav(tester, find.byKey(const Key('kanban-3')));
      });

      testWidgets('API move sheet and project picker fit', (tester) async {
        await _pump(
          tester,
          size,
          routes: {
            'GET /api/v1/employee/kanban': (
              200,
              _board(tasks: [_task(1, 'in_progress', title: _longTitle)]),
            ),
          },
        );
        await _reveal(tester, find.byKey(const Key('sprint-project')));
        await tester.tap(find.byKey(const Key('sprint-project')));
        await tester.pumpAndSettle();
        await screenshot(tester, 'sprint_api_projects_$name');
        // The sheet is drawn over the navigation surface, not under it.
        expect(
          tester.getRect(find.byKey(const Key('option-sheet'))).bottom,
          greaterThan(tester.getRect(find.text('Sprints').last).top),
        );
        // Every project can be reached, even when the list is taller than
        // the sheet.
        await tester.scrollUntilVisible(
          find.text('Project 9'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(find.text('Project 9'));
        await tester.pumpAndSettle();
        expect(find.text('Project 9').hitTestable(), findsOne);
        await tester.tap(find.text('Project 9'));
        await tester.pumpAndSettle();

        await _reveal(tester, find.byKey(const Key('kanban-1')));
        await tester.tap(find.byKey(const Key('kanban-1')));
        await tester.pumpAndSettle();
        await screenshot(tester, 'sprint_api_move_$name');
        // The last status is reachable and receives the tap.
        await tester.tap(find.byKey(const Key('move-completed')));
        await tester.pumpAndSettle();
        expect(find.text('Task status updated.'), findsOneWidget);
      });

      testWidgets('API empty column and no sprint states fit', (tester) async {
        await _pump(
          tester,
          size,
          routes: {'GET /api/v1/employee/kanban': (200, _board())},
        );
        expect(find.text('No tasks in this column'), findsOneWidget);
        await screenshot(tester, 'sprint_api_empty_$name');
        await tester.tap(find.text('Backlog'));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        await screenshot(tester, 'sprint_api_backlog_$name');
      });

      testWidgets('API project without a current sprint', (tester) async {
        await _pump(
          tester,
          size,
          routes: {'GET /api/v1/employee/kanban': (200, _board(sprint: false))},
        );
        expect(
          find.text('This project has no current sprint.'),
          findsOneWidget,
        );
      });

      testWidgets('search with the keyboard open does not overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          size,
          routes: {
            'GET /api/v1/employee/kanban': (
              200,
              _board(tasks: [_task(1, 'in_progress')]),
            ),
          },
        );
        await tester.tap(find.byType(TextField).first);
        showKeyboard(tester, size.height * 0.42);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Task 1');
        await tester.pumpAndSettle();
        await screenshot(tester, 'sprint_api_keyboard_$name');
        // The focused field stays above the keyboard.
        final field = tester.getRect(find.byType(TextField).first);
        expect(field.bottom, lessThanOrEqualTo(size.height * 0.58));
      });

      testWidgets('demo board, move sheet and create-sprint dialog fit', (
        tester,
      ) async {
        await _pump(tester, size, mode: AppMode.mock);
        await screenshot(tester, 'sprint_mock_top_$name');
        await _reveal(tester, find.byKey(const Key('kanban-t1')));
        await tester.tap(find.byKey(const Key('kanban-t1')));
        await tester.pumpAndSettle();
        await screenshot(tester, 'sprint_mock_move_$name');
        expect(find.byKey(const Key('move-completed')).hitTestable(), findsOne);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await _reveal(tester, find.byKey(const Key('create-sprint')));
        await tester.tap(find.byKey(const Key('create-sprint')));
        await tester.pumpAndSettle();
        showKeyboard(tester, size.height * 0.42);
        await tester.enterText(find.byKey(const Key('sprint-name')), 'S');
        await tester.pumpAndSettle();
        await screenshot(tester, 'sprint_mock_dialog_$name');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        await screenshot(tester, 'sprint_mock_end_$name');
      });
    });
  }

  testWidgets('a system navigation bar inset never hides the last card', (
    tester,
  ) async {
    const size = Size(360, 740);
    await _pump(
      tester,
      size,
      routes: {
        'GET /api/v1/employee/kanban': (
          200,
          _board(tasks: [for (var i = 1; i <= 4; i++) _task(i, 'in_progress')]),
        ),
      },
    );
    tester.view.padding = const FakeViewPadding(bottom: 48 * 2);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);
    await screenshot(tester, 'sprint_api_inset_360x740');
    _expectAboveNav(tester, find.byKey(const Key('kanban-4')));
  });

  testWidgets('demo create button stays clear of the navigation surface', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 740), mode: AppMode.mock);
    tester.view.padding = const FakeViewPadding(bottom: 48 * 2);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    await screenshot(tester, 'sprint_mock_inset_360x740');
    final fab = tester.getRect(find.byType(CreateFab));
    final nav = tester.getRect(find.text('Sprints').last).top - 44;
    expect(fab.bottom, lessThanOrEqualTo(nav));
  });
}
