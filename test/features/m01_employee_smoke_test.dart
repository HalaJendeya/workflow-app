import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';

/// M01 essential gate: smoke checks for the employee core screens
/// (Dashboard, Projects, Tasks, Timesheets and their details sheets) in
/// demo mode and against a mocked employee API.

enum _State { populated, empty, error }

const _longTitle =
    'Integrate the regional billing gateway with the customer portal';

Map<String, dynamic> _page(List<Object> rows, {int page = 1, int last = 1}) => {
  'current_page': page,
  'data': rows,
  'last_page': last,
  'per_page': 10,
  'total': last == 1 ? rows.length : 10 * (last - 1) + rows.length,
};

Map<String, dynamic> _task(int id) => {
  'id': id,
  'title': '$_longTitle #$id',
  'status': 'in_progress',
  'priority': 'high',
  'story_points': 3,
  'task_date': '2026-11-10',
  'start_time': '09:00',
  'end_time': '11:30',
  'assignee': {'id': 7, 'name': 'Lina Dawood'},
  'project': {'id': 1, 'title': 'Customer Portal Revamp'},
  'sprint': {'id': 4, 'name': 'Sprint 4'},
};

Map<String, dynamic> _project(int id) => {
  'id': id,
  'title': 'Customer Portal Revamp and Billing Migration $id',
  'status': 'in_progress',
  'completion_percentage': 40,
  'company': {'id': 3, 'name': 'Tech Company'},
  'leader': {'id': 9, 'name': 'Sara Khalil'},
  'members': [
    {'id': 7},
  ],
};

/// The employee API in one of three states; documented shapes only.
class _Server implements HttpClientAdapter {
  _State state = _State.populated;
  final List<RequestOptions> requests = [];

  /// When set, every response waits for it (loading state).
  Completer<void>? gate;

  (int, Object?) _reply(RequestOptions o) {
    final path = o.uri.path;
    if (path == '/api/v1/employee/account') {
      return (200, ok({'id': 7, 'name': 'Lina Dawood'}));
    }
    if (state == _State.error) return (500, failure('Server Error'));
    final empty = state == _State.empty;
    switch (path) {
      case '/api/v1/employee/dashboard':
        return (
          200,
          ok({
            'myTasks': empty ? 0 : 12,
            'myHours': empty ? 0 : 36,
            'myMinutes': 30,
            'totalEarned': empty ? 0 : 98765.5,
            'paidSalary': 0,
            'unpaidSalary': 0,
          }),
        );
      case '/api/v1/employee/tasks':
        final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
        // A search narrows the result to a single page.
        final searching = '${o.queryParameters['search'] ?? ''}'.isNotEmpty;
        final last = empty || searching ? 1 : 2;
        final rows = empty || page > last
            ? <Object>[]
            : [for (var i = 1; i <= 3; i++) _task(page * 10 + i)];
        return (
          200,
          {
            'success': true,
            'message': 'ok',
            'data': _page(rows, page: page, last: last),
            'stats': {
              'total': empty ? 0 : 13,
              'by_status': {
                'backlog': 0,
                'todo': 0,
                'pending': 0,
                'in_progress': empty ? 0 : 13,
                'in_review': 0,
                'completed': 0,
              },
              'active': empty ? 0 : 13,
              'logged_minutes': empty ? 0 : 900,
            },
          },
        );
      case '/api/v1/employee/timesheets':
        return (
          200,
          {
            'success': true,
            'message': 'ok',
            'data': _page(const []),
            'stats': {
              'count': empty ? 0 : 9,
              'approved': empty ? 0 : 4,
              'pending': empty ? 0 : 3,
              'rejected': empty ? 0 : 2,
              'total_minutes': empty ? 0 : 1200,
            },
            'totals': [
              if (!empty)
                {
                  'currency_id': 1,
                  'code': 'USD',
                  'symbol': r'$',
                  'total': 900,
                  'approved': 300,
                  'pending': 600,
                },
            ],
          },
        );
      case '/api/v1/employee/projects':
        return (
          200,
          {
            'success': true,
            'message': 'ok',
            'data': _page([
              if (!empty)
                for (var i = 1; i <= 3; i++) _project(i),
            ]),
            'stats': {
              'total': empty ? 0 : 3,
              'pending': 0,
              'in_progress': empty ? 0 : 3,
              'completed': 0,
            },
          },
        );
    }
    return (404, failure('Not found'));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    await gate?.future;
    final (status, body) = _reply(o);
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

Future<_Server?> _pump(
  WidgetTester tester,
  Size size, {
  double scale = 1.0,
  AppMode mode = AppMode.mock,
  _State state = _State.populated,
  bool navInset = false,
}) async {
  useViewport(tester, size);
  if (navInset) {
    // Android 3-button navigation bar.
    tester.view.padding = const FakeViewPadding(bottom: 48 * 2);
    addTearDown(tester.view.resetPadding);
  }
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
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
  final server = mode == AppMode.api ? (_Server()..state = state) : null;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        if (server != null)
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'https://api.test',
              credentials: ref.watch(sessionCredentialsProvider),
              adapter: server,
            ),
          ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

double _height(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

/// Top of the floating navigation surface, or the screen bottom (less the
/// system inset) on a page pushed above the shell.
double _navTop(WidgetTester tester) {
  final home = find.text('Home').hitTestable();
  if (home.evaluate().isNotEmpty) return tester.getRect(home.last).top - 46;
  return _height(tester) -
      tester.view.padding.bottom / tester.view.devicePixelRatio;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final limit = _navTop(tester) - 8;
  final r = tester.getRect(target);
  if (r.bottom > limit) {
    await tester.drag(scroll, Offset(0, limit - r.bottom));
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _screens = ['Dashboard', 'Projects', 'Tasks', 'Timesheets'];

const _titles = {
  'Dashboard': 'Dashboard',
  'Projects': 'Projects Management',
  'Tasks': 'Tasks Management',
  'Timesheets': 'Timesheets Dashboard',
};

Future<void> _open(
  WidgetTester tester,
  String screen, {
  bool settle = true,
}) async {
  if (screen == 'Projects') {
    await tester.tap(find.text('Projects').last);
  } else {
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(Key('category-$screen')));
    await tester.tap(find.byKey(Key('category-$screen')));
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A spinner never settles: let the page transition finish instead.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(find.text(_titles[screen]!), findsWidgets);
}

/// Scrolls to the end; no card may end under the navigation surface.
Future<void> _checkEnd(WidgetTester tester, String shot) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  for (var i = 0; i < 20; i++) {
    final end = position.maxScrollExtent;
    position.jumpTo(end);
    await tester.pumpAndSettle();
    if (position.maxScrollExtent == end) break;
  }
  await screenshot(tester, shot);
  final navTop = _navTop(tester);
  for (final e in find.byType(ModuleCard).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.attached || !box.hasSize) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.bottom <= 0) continue;
    expect(
      r.bottom,
      lessThanOrEqualTo(navTop + 0.5),
      reason: 'a card ends under the navigation surface ($shot)',
    );
  }
}

/// Opens the first record's details sheet, checks it shows the title and
/// closes it with system back.
Future<void> _details(WidgetTester tester, String screen) async {
  final Finder view;
  switch (screen) {
    case 'Projects':
      view = find.text('View Details').first;
    case 'Tasks' || 'Timesheets':
      view = find.byKey(const Key('action-view')).first;
    default:
      return;
  }
  await _tap(tester, view);
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget, reason: '$screen details did not open');
  await screenshot(tester, 'details_$screen');
  // At 320x640 and text x1.3 the sheet fills the screen, so close it the
  // way an Android user would: the system back action.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(sheet, findsNothing);
}

/// Pushed screens go back to the More menu; the Projects tab has none.
Future<void> _back(WidgetTester tester, String screen) async {
  if (screen == 'Projects') return;
  final scroll = find.byType(Scrollable).first;
  await tester.drag(scroll, const Offset(0, 20000));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('masthead-back')));
  await tester.pumpAndSettle();
  expect(find.byKey(Key('category-$screen')), findsOneWidget);
}

void main() {
  const matrix = <(String, double)>[
    ('320x640', 1.0),
    ('320x640', 1.3),
    ('360x740', 1.0),
    ('360x740', 1.3),
    ('390x844', 1.0),
    ('430x932', 1.0),
  ];
  for (final (name, scale) in matrix) {
    final size = phoneViewports[name]!;
    final tag = '${name}_x$scale';
    group('demo $tag', () {
      for (final screen in _screens) {
        testWidgets('$screen opens, scrolls, shows details and goes back', (
          tester,
        ) async {
          await _pump(tester, size, scale: scale);
          await _open(tester, screen);
          await screenshot(tester, 'emp_${screen}_top_$tag');
          await _details(tester, screen);
          await _checkEnd(tester, 'emp_${screen}_end_$tag');
          await _back(tester, screen);
        });
      }
    });
  }

  group('API mode 320x640 text x1.3', () {
    const size = Size(320, 640);
    for (final screen in _screens) {
      testWidgets('$screen with server data', (tester) async {
        await _pump(tester, size, scale: 1.3, mode: AppMode.api);
        await _open(tester, screen);
        expect(find.byKey(const Key('api-error')), findsNothing);
        if (screen == 'Timesheets') {
          // Timesheet rows are not mapped yet (backend gap): the screen
          // says so instead of listing anything.
          expect(find.byType(BackendPendingNotice), findsOneWidget);
        } else {
          await _details(tester, screen);
        }
        await _checkEnd(tester, 'emp_${screen}_api');
        await _back(tester, screen);
      });

      testWidgets('$screen empty', (tester) async {
        await _pump(
          tester,
          size,
          scale: 1.3,
          mode: AppMode.api,
          state: _State.empty,
        );
        await _open(tester, screen);
        expect(find.byKey(const Key('api-error')), findsNothing);
        await _checkEnd(tester, 'emp_${screen}_api_empty');
      });

      testWidgets('$screen loading', (tester) async {
        final server = await _pump(tester, size, scale: 1.3, mode: AppMode.api);
        server!.gate = Completer<void>();
        await _open(tester, screen, settle: false);
        // Spinners animate forever: pump frames instead of settling.
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await screenshot(tester, 'emp_${screen}_api_loading');
        server.gate!.complete();
        server.gate = null;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('api-error')), findsNothing);
      });

      testWidgets('$screen error, then retry recovers', (tester) async {
        final server = await _pump(
          tester,
          size,
          scale: 1.3,
          mode: AppMode.api,
          state: _State.error,
        );
        await _open(tester, screen);
        final error = find.byKey(const Key('api-error'));
        await _reveal(tester, error.first);
        expect(error, findsWidgets);
        await screenshot(tester, 'emp_${screen}_api_error');
        server!.state = _State.populated;
        final retry = find.byKey(const Key('api-retry'));
        for (var i = 0; i < 5 && retry.evaluate().isNotEmpty; i++) {
          await _reveal(tester, retry.first);
          await tester.tap(retry.first);
          await tester.pumpAndSettle();
        }
        expect(error, findsNothing);
        await _checkEnd(tester, 'emp_${screen}_api_retried');
      });
    }
  });

  group('Android navigation bar inset, 360x740', () {
    for (final screen in _screens) {
      testWidgets('$screen keeps its last card above the system bar', (
        tester,
      ) async {
        await _pump(tester, const Size(360, 740), navInset: true);
        await _open(tester, screen);
        await _checkEnd(tester, 'emp_${screen}_inset');
      });
    }
  });

  testWidgets('Tasks search with the keyboard open at 320x640', (tester) async {
    await _pump(tester, const Size(320, 640), scale: 1.3);
    await _open(tester, 'Tasks');
    final field = find.byKey(const Key('tasks-search'));
    await _reveal(tester, field);
    await tester.tap(field);
    showKeyboard(tester, 640 * 0.42);
    await tester.pumpAndSettle();
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(640 * 0.58 + 1));
    await tester.enterText(field, 'Redis');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-t3')), findsOneWidget);
  });

  group('defect regressions', () {
    testWidgets('API Tasks: a masthead search from page 2 shows results', (
      tester,
    ) async {
      final server = await _pump(
        tester,
        const Size(360, 740),
        mode: AppMode.api,
      );
      await _open(tester, 'Tasks');
      await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(find.byKey(const Key('api-task-21')), findsOneWidget);
      // The masthead search used to keep page 2, which a one-page result
      // does not have: the list went empty with no pager to go back.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'billing');
      // API searches are debounced (400 ms).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final last = server!.requests.lastWhere(
        (r) => r.uri.path == '/api/v1/employee/tasks',
      );
      expect(last.queryParameters['page'], 1);
      await _reveal(tester, find.byKey(const Key('api-task-11')));
      expect(find.byKey(const Key('api-task-11')), findsOneWidget);
      expect(find.text('No records match these filters'), findsNothing);
    });

    testWidgets('API Timesheets: no row filters that contradict the server', (
      tester,
    ) async {
      await _pump(tester, const Size(360, 740), mode: AppMode.api);
      await _open(tester, 'Timesheets');
      // The server counts 4 approved; status chips over the (unloaded)
      // rows used to read "Approved (0)" and the list "No records".
      expect(find.text('4'), findsOneWidget);
      await _checkEnd(tester, 'emp_timesheets_api_filters');
      expect(find.textContaining('(0)'), findsNothing);
      expect(find.text('No records match these filters'), findsNothing);
      expect(find.byKey(const Key('timesheets-search')), findsNothing);
    });
  });

  testWidgets('employee More: every entry opens and the way back works', (
    tester,
  ) async {
    await _pump(tester, const Size(320, 640), scale: 1.3);
    // Pushed above the shell: back returns to More.
    for (final entry in ['Dashboard', 'Tasks', 'Timesheets', 'Meetings']) {
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(Key('category-$entry')));
      expect(tester.takeException(), isNull);
      final back = find.byKey(const Key('masthead-back'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      expect(back, findsOneWidget, reason: '$entry has no back button');
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category-$entry')), findsOneWidget);
    }
    // Shell tabs: the entry switches tab; More is one tap away.
    for (final entry in ['Projects', 'Sprints', 'Conversations']) {
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(Key('category-$entry')));
      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('category-$entry')), findsNothing);
    }
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-Dashboard')), findsOneWidget);
  });

  group('pre-M03 Tasks and Timesheets alignment', () {
    Future<void> tab(WidgetTester tester, String name) =>
        _tap(tester, find.byKey(Key('task-tab-$name')));

    testWidgets('demo Tasks: status chips count, filter and reset paging', (
      tester,
    ) async {
      await _pump(tester, const Size(320, 640), scale: 1.3);
      await _open(tester, 'Tasks');
      // Six demo tasks: three in progress, one completed, none in review
      // (demo tasks have no review state).
      for (final label in [
        'All Tasks 6',
        'In Progress 3',
        'Under Review 0',
        'Completed 1',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // Page 2 of all tasks, then a filter: back to page 1 of the result.
      await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(find.byKey(const Key('task-t5')), findsOneWidget);
      await tab(tester, 'inProgress');
      expect(find.textContaining('Showing 1–3 of 3'), findsOneWidget);
      for (final id in ['t1', 't2', 't3']) {
        await _reveal(tester, find.byKey(Key('task-$id')));
      }
      expect(find.byKey(const Key('task-t5')), findsNothing);
      await tab(tester, 'inReview');
      expect(find.text('No records match these filters'), findsOneWidget);
      await tab(tester, 'completed');
      await _reveal(tester, find.byKey(const Key('task-t5')));
      expect(find.byKey(const Key('task-t1')), findsNothing);
      // Search combines with the status filter.
      await tab(tester, 'all');
      final search = find.byKey(const Key('tasks-search'));
      await _reveal(tester, search);
      await tester.enterText(search, 'Redis');
      await tester.pumpAndSettle();
      await tab(tester, 'inProgress');
      await _reveal(tester, find.byKey(const Key('task-t3')));
      expect(find.byKey(const Key('task-t1')), findsNothing);
    });

    testWidgets('API Tasks: server counts and documented status filter', (
      tester,
    ) async {
      final server = await _pump(
        tester,
        const Size(390, 844),
        mode: AppMode.api,
      );
      await _open(tester, 'Tasks');
      // Counts come from `stats` of GET /employee/tasks.
      for (final label in [
        'All Tasks 13',
        'In Progress 13',
        'Under Review 0',
        'Completed 0',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      RequestOptions lastRows() => server!.requests.lastWhere(
        (r) =>
            r.uri.path == '/api/v1/employee/tasks' &&
            r.queryParameters['per_page'] == 10,
      );
      expect(lastRows().queryParameters.containsKey('status'), isFalse);
      await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(lastRows().queryParameters['page'], 2);
      await tab(tester, 'inReview');
      expect(lastRows().queryParameters['status'], 'in_review');
      expect(lastRows().queryParameters['page'], 1);
      await tab(tester, 'completed');
      expect(lastRows().queryParameters['status'], 'completed');
      await tab(tester, 'all');
      expect(lastRows().queryParameters.containsKey('status'), isFalse);
    });

    testWidgets('API Tasks: typing a search sends one request, not one per '
        'keystroke', (tester) async {
      final server = await _pump(
        tester,
        const Size(390, 844),
        mode: AppMode.api,
      );
      await _open(tester, 'Tasks');
      int searches() => server!.requests
          .where((r) => r.queryParameters.containsKey('search'))
          .length;
      final field = find.byKey(const Key('tasks-search'));
      await _reveal(tester, field);
      for (final text in ['b', 'bi', 'bil', 'bill']) {
        await tester.enterText(field, text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(searches(), 0);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(searches(), 1);
      expect(
        server!.requests
            .lastWhere((r) => r.queryParameters.containsKey('search'))
            .queryParameters['search'],
        'bill',
      );
    });

    testWidgets('demo Timesheets: Figma card, view only, month filter', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 844));
      await _open(tester, 'Timesheets');
      final card = find.byKey(const Key('timesheet-ts0'));
      await _reveal(tester, card);
      for (final label in ['Task', 'Date', 'Hours', 'Rate']) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: card,
          matching: find.text('P04-T04 Implement search filters'),
        ),
        findsOneWidget,
      );
      // The employee role may not approve, reject or delete (403).
      for (final key in ['action-edit', 'action-delete']) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);

      // Month: only that month's timesheets remain.
      final now = DateTime.now();
      final month = DateFormat('MMM yyyy', 'en').format(now);
      await _tap(tester, find.byKey(const Key('timesheet-month-filter')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('option-sheet')),
          matching: find.text(month),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, card);
      // ts5 started five days ago: in another month early in a month.
      if (now.day <= 5) {
        expect(find.byKey(const Key('timesheet-ts5')), findsNothing);
      }
    });
  });
}
