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
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';

/// Content-first Tasks (API mode): one search, My/Team only for a lead,
/// and one Filters sheet for status, project, priority and sort.
/// Every filter is still sent to `GET /employee/tasks`; a change starts on
/// page 1; the sheet sends one request for all its choices. Mocked HTTP.

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _statuses = ['todo', 'in_progress', 'completed'];
const _priorities = ['low', 'medium', 'high'];

Map<String, Object?> _task(int id) => {
  'id': id,
  'title': 'Task $id',
  'description': null,
  'status': _statuses[id % 3],
  'priority': _priorities[id % 3],
  'story_points': 1,
  'task_date': '2026-11-02',
  'assignee': {'id': 10, 'name': 'Me'},
  'project': {
    'id': id.isEven ? 2 : 5,
    'title': id.isEven ? 'Portal' : 'Mobile',
  },
  'can': {'update': false, 'delete': false},
};

class _Server {
  bool leads = true;
  final List<Map<String, Object?>> rows = [
    for (var i = 1; i <= 24; i++) _task(i),
  ];

  late final adapter = RouteHttpAdapter(
    const {},
    handlers: {
      'GET /api/v1/employee/projects/options': (o) {
        final led = '${o.queryParameters['led']}' == '1';
        return (
          200,
          ok([
            if (!led || leads) ...[
              {'id': 2, 'title': 'Portal', 'leader_id': null},
              {'id': 5, 'title': 'Mobile', 'leader_id': null},
            ],
          ]),
        );
      },
      'GET /api/v1/employee/tasks': (o) {
        final q = o.queryParameters;
        String? p(String k) => q[k]?.toString();
        final hits = rows.where((t) {
          if (p('status') case final s? when t['status'] != s) return false;
          if (p('priority') case final s? when t['priority'] != s) {
            return false;
          }
          if (p('project_id') case final s?
              when '${(t['project']! as Map)['id']}' != s) {
            return false;
          }
          if (p('search') case final s? when s.isNotEmpty) {
            return '${t['title']}'.contains(s);
          }
          return true;
        }).toList();
        final per = int.parse(p('per_page') ?? '10');
        final page = int.parse(p('page') ?? '1');
        final last = (hits.length / per).ceil().clamp(1, 999);
        int count(String s) => rows.where((t) => t['status'] == s).length;
        return (
          200,
          {
            ...ok({
              'current_page': page,
              'data': hits.skip((page - 1) * per).take(per).toList(),
              'last_page': last,
              'per_page': per,
              'total': hits.length,
            }),
            'stats': {
              'total': rows.length,
              'by_status': {for (final s in _statuses) s: count(s)},
              'active': rows.length - count('completed'),
              'logged_minutes': 90,
            },
          },
        );
      },
    },
  );

  /// Row requests (not the per_page=1 figures request).
  List<Map<String, dynamic>> get rowQueries => [
    for (final r in adapter.requests)
      if (r.method == 'GET' &&
          r.uri.path == '/api/v1/employee/tasks' &&
          '${r.queryParameters['per_page']}' != '1')
        r.queryParameters,
  ];
}

Future<_Server> _pump(
  WidgetTester tester, {
  bool leads = true,
  Size size = const Size(390, 1400),
  double scale = 1,
  AppPreferences? prefs,
}) async {
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
  final server = _Server()..leads = leads;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.api, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(_Auth()),
        if (prefs != null) initialPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'https://api.test',
            credentials: ref.watch(sessionCredentialsProvider),
            adapter: server.adapter,
          ),
        ),
      ],
      child: WorkFlowApp(locale: prefs == null ? const Locale('en') : null),
    ),
  );
  await tester.pumpAndSettle();
  // More → Tasks, by the labels of the language in use.
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  await tester.tap(find.text(l10n.navMore).last);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(Key('category-${l10n.navTasks}')));
  return server;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _applyFilters(WidgetTester tester, List<String> choices) async {
  await _tap(tester, find.byKey(const Key('task-filters')));
  for (final c in choices) {
    await _tap(tester, find.byKey(Key('filter-$c')));
  }
  await _tap(tester, find.byKey(const Key('task-filters-apply')));
}

void main() {
  testWidgets('a non-lead sees no My/Team switch; a lead does', (tester) async {
    await _pump(tester, leads: false);
    expect(find.byKey(const Key('tasks-search')), findsOneWidget);
    expect(find.byKey(const Key('task-scope')), findsNothing);
    expect(find.byKey(const Key('create-fab')), findsNothing);
  });

  testWidgets('a lead switches to Team tasks: assigned_to is dropped', (
    tester,
  ) async {
    final server = await _pump(tester);
    expect(find.byKey(const Key('task-scope')), findsOneWidget);
    expect(server.rowQueries.last['assigned_to'], 10);
    await _tap(tester, find.byKey(const Key('task-scope-team')));
    expect(server.rowQueries.last.containsKey('assigned_to'), isFalse);
  });

  testWidgets('one search field; status sits in the sheet with server counts', (
    tester,
  ) async {
    final server = await _pump(tester);
    expect(find.byType(TextField), findsOneWidget);
    // Redmi 8 acceptance: no always-visible status chips on the screen.
    expect(find.byKey(const Key('task-status')), findsNothing);
    expect(find.text('All Tasks 24'), findsNothing);
    await _tap(tester, find.byKey(const Key('task-filters')));
    for (final label in [
      'All Tasks 24',
      'To do 8',
      'In Progress 8',
      // No in_review in by_status: no number is guessed.
      'Under Review',
      'Completed 8',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await _tap(tester, find.byKey(const Key('filter-status-todo')));
    await _tap(tester, find.byKey(const Key('task-filters-apply')));
    expect(server.rowQueries.last['status'], 'todo');
    expect(server.rowQueries.last['page'], 1);
    expect(find.text('8 tasks'), findsOneWidget);
    expect(find.text('Filters (1)'), findsOneWidget);
    expect(find.byKey(const Key('active-filter-status')), findsOneWidget);
    // The same choice again sends nothing.
    final n = server.rowQueries.length;
    await _applyFilters(tester, ['status-todo']);
    expect(server.rowQueries.length, n);
  });

  testWidgets('status counts hide in the sheet once a project is drafted', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, find.byKey(const Key('task-filters')));
    expect(find.text('Completed 8'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('filter-project-5')));
    // Scope totals no longer describe a project's list.
    expect(find.text('Completed 8'), findsNothing);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('status, project, priority and sort go in one request', (
    tester,
  ) async {
    final server = await _pump(tester);
    final before = server.rowQueries.length;
    await _applyFilters(tester, [
      'status-inProgress',
      'project-2',
      'priority-low',
      'sort-title',
    ]);
    expect(server.rowQueries.length, before + 1);
    final q = server.rowQueries.last;
    expect(q['status'], 'in_progress');
    expect(q['project_id'], 2);
    expect(q['priority'], 'low');
    expect(q['sort'], 'title');
    expect(q['assigned_to'], 10);
    expect(find.text('Filters (4)'), findsOneWidget);
    // Removing the status chip keeps the rest.
    await _tap(tester, find.byTooltip('Remove filter: In Progress'));
    expect(server.rowQueries.last.containsKey('status'), isFalse);
    expect(server.rowQueries.last['project_id'], 2);
  });

  testWidgets('the sheet applies project, priority and sort in one request', (
    tester,
  ) async {
    final server = await _pump(tester);
    final before = server.rowQueries.length;
    await _applyFilters(tester, ['project-5', 'priority-high', 'sort-title']);
    expect(server.rowQueries.length, before + 1);
    final q = server.rowQueries.last;
    expect(q['project_id'], 5);
    expect(q['priority'], 'high');
    expect(q['sort'], 'title');
    expect(q['page'], 1);
    expect(find.text('Filters (3)'), findsOneWidget);
    for (final k in ['project', 'priority', 'sort']) {
      expect(find.byKey(Key('active-filter-$k')), findsOneWidget);
    }
    expect(find.text('Mobile'), findsWidgets);
    expect(find.byKey(const Key('task-result-count')), findsOneWidget);
  });

  // Emulator acceptance (Android 16): choices did not stick. Android sends
  // new window metrics (insets, IME) while the sheet is open, the sheet's
  // builder ran again, and the draft went back to the applied filters.
  testWidgets('choices survive a metrics change while the sheet is open', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _tap(tester, find.byKey(const Key('task-filters')));
    await _tap(tester, find.byKey(const Key('filter-status-inProgress')));
    await _tap(tester, find.byKey(const Key('filter-project-5')));
    // What Android does: new insets/padding reach MediaQuery.
    tester.view.viewInsets = const FakeViewPadding(bottom: 1);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 96);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('filter-sort-title')));
    await _tap(tester, find.byKey(const Key('task-filters-apply')));
    final q = server.rowQueries.last;
    expect(q['status'], 'in_progress');
    expect(q['project_id'], 5);
    expect(q['sort'], 'title');
    expect(find.text('Filters (3)'), findsOneWidget);
  });

  testWidgets('removing one active filter keeps the others', (tester) async {
    final server = await _pump(tester);
    await _applyFilters(tester, ['project-5', 'priority-high']);
    await _tap(tester, find.byTooltip('Remove filter: High'));
    final q = server.rowQueries.last;
    expect(q.containsKey('priority'), isFalse);
    expect(q['project_id'], 5);
    expect(find.text('Filters (1)'), findsOneWidget);
  });

  testWidgets('dismissing the sheet sends nothing and keeps the page', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
    expect(server.rowQueries.last['page'], 2);
    final n = server.rowQueries.length;
    await _tap(tester, find.byKey(const Key('task-filters')));
    await _tap(tester, find.byKey(const Key('filter-priority-low')));
    await tester.tapAt(const Offset(20, 20)); // outside the sheet
    await tester.pumpAndSettle();
    expect(server.rowQueries.length, n);
    expect(find.byKey(const Key('task-filter-sheet')), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('a filter after paging starts again on page 1', (tester) async {
    final server = await _pump(tester);
    await _tap(tester, find.widgetWithText(ChoiceChip, '3'));
    expect(server.rowQueries.last['page'], 3);
    await _applyFilters(tester, ['priority-low']);
    expect(server.rowQueries.last['page'], 1);
    expect(server.rowQueries.last['priority'], 'low');
  });

  testWidgets('Reset filters clears status, project, priority and sort', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _applyFilters(tester, [
      'status-completed',
      'project-2',
      'sort-plannedDate',
    ]);
    await _tap(tester, find.byKey(const Key('reset-filters')));
    final q = server.rowQueries.last;
    for (final k in ['status', 'project_id', 'priority', 'sort']) {
      expect(q.containsKey(k), isFalse, reason: k);
    }
    expect(q['assigned_to'], 10);
    expect(find.byKey(const Key('reset-filters')), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('the sheet Reset clears the draft before applying', (
    tester,
  ) async {
    final server = await _pump(tester);
    await _applyFilters(tester, ['priority-high']);
    await _tap(tester, find.byKey(const Key('task-filters')));
    await _tap(tester, find.byKey(const Key('task-filters-reset')));
    await _tap(tester, find.byKey(const Key('task-filters-apply')));
    expect(server.rowQueries.last.containsKey('priority'), isFalse);
    expect(find.text('Filters'), findsOneWidget);
  });

  for (final (name, size, scale, prefs) in [
    (
      'Arabic dark 320x640 x1.3',
      const Size(320, 640),
      1.3,
      const AppPreferences(
        language: LanguagePreference.arabic,
        appearance: AppearancePreference.dark,
      ),
    ),
    ('English light 320x640 x1.3', const Size(320, 640), 1.3, null),
  ]) {
    testWidgets('filter bar and sheet lay out: $name', (tester) async {
      await _pump(tester, size: size, scale: scale, prefs: prefs);
      final arabic = prefs != null;
      await _applyFilters(tester, ['project-5', 'priority-high']);
      expect(tester.takeException(), isNull);
      final bar = find.byKey(const Key('task-filter-bar'));
      expect(
        Directionality.of(tester.element(bar)),
        arabic ? TextDirection.rtl : TextDirection.ltr,
      );
      await _tap(tester, find.byKey(const Key('task-filters')));
      expect(find.byKey(const Key('task-filter-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Apply stays reachable at the bottom of the sheet.
      await _tap(tester, find.byKey(const Key('task-filters-apply')));
      expect(find.byKey(const Key('task-filter-sheet')), findsNothing);
    });
  }
}
