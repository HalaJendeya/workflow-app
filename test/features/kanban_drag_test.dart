import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';
import 'sprint_board_api_test.dart' as b;

const _longTitle =
    'Create executive dashboard widgets and a realtime analytics stream '
    'for the regional operations team with drill-down filters';

/// A tiny in-memory kanban server: the board reflects accepted moves, so a
/// refresh after a move shows what the server stored. POSTs can be held
/// open with [gate] to observe the pending state, or refused with [refuse].
class _Server implements HttpClientAdapter {
  new(this.tasks);

  final Map<int, Map<String, dynamic>> tasks;
  final List<RequestOptions> requests = [];
  Completer<void>? gate;
  (int, Object?)? refuse;

  List<RequestOptions> get posts =>
      requests.where((r) => r.method == 'POST').toList();

  int get boardReads =>
      requests.where((r) => r.uri.path == '/api/v1/employee/kanban').length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    final (status, body) = switch ('${o.method} ${o.uri.path}') {
      'GET /api/v1/employee/account' => (200, ok({'id': 10, 'name': 'Me'})),
      'GET /api/v1/employee/kanban' => (
        200,
        b.board(tasks: tasks.values.toList()),
      ),
      'GET /api/v1/employee/sprints' => (200, b.planning()),
      'POST /api/v1/employee/kanban/update-status' => await _post(o),
      _ => (404, failure('Not found')),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Future<(int, Object?)> _post(RequestOptions o) async {
    await gate?.future;
    if (refuse case final r?) return r;
    final data = o.data as Map<String, dynamic>;
    final id = data['task_id'] as int;
    tasks[id] = {...tasks[id]!, 'status': data['status']};
    return (200, ok({'id': id, 'status': data['status']}));
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _task(
  int id,
  String status, {
  String? title,
  bool canUpdate = true,
}) => {
  ...b.taskJson(id, status),
  'title': ?title,
  'can': {'update': canUpdate, 'delete': false},
};

Future<_Server> _pumpApi(
  WidgetTester tester,
  List<Map<String, dynamic>> tasks, {
  Size size = const Size(360, 740),
}) async {
  useViewport(tester, size);
  await loadAppFonts();
  final server = _Server({for (final t in tasks) t['id'] as int: t});
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
            adapter: server,
          ),
        ),
      ],
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sprints').last);
  await tester.pumpAndSettle();
  return server;
}

Future<void> _pumpMock(WidgetTester tester, Size size) async {
  useViewport(tester, size);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    const Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
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
  await tester.tap(find.text('Sprints').last);
  await tester.pumpAndSettle();
}

/// Brings [target] into the open area above the floating navigation.
Future<void> _reveal(WidgetTester tester, Finder target) async {
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

/// Long-presses [card], checks the drop bar, hovers [target] and releases.
/// Returns whether the target was highlighted while hovered.
Future<bool> _drag(
  WidgetTester tester,
  Finder card,
  Finder target, {
  String? shot,
}) async {
  await _reveal(tester, card);
  // Read before lifting: while held, the card is on screen twice (the
  // dimmed original and the lifted copy).
  final from = tester.getCenter(card);
  final g = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pump();
  expect(find.byKey(const Key('kanban-drop-bar')), findsOneWidget);
  expect(find.byKey(const Key('kanban-drag-feedback')), findsOneWidget);
  // Small steps, as a finger moves.
  final to = tester.getCenter(target);
  for (var i = 1; i <= 5; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 5)!);
    await tester.pump();
  }
  final hovered = find
      .descendant(
        of: target,
        matching: find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              (w.decoration as BoxDecoration?)?.border is Border &&
              ((w.decoration! as BoxDecoration).border! as Border).top.width ==
                  2,
        ),
      )
      .evaluate()
      .isNotEmpty;
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(const Key('kanban-drop-bar')),
      matching: find.byType(Text),
    ),
  )) {
    final p = tester.renderObject<RenderParagraph>(find.byWidget(t));
    expect(p.didExceedMaxLines, isFalse, reason: '"${t.data}" is cut off');
  }
  if (shot != null) await screenshot(tester, shot);
  await g.up();
  await tester.pump();
  return hovered;
}

Finder _drop(String status) => find.byKey(Key('drop-$status'));

Future<void> _openColumn(WidgetTester tester, String c) async {
  await _reveal(tester, find.byKey(Key('column-$c')));
  await tester.tap(find.byKey(Key('column-$c')));
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: name, value: size) in phoneViewports.entries) {
    group(name, () {
      testWidgets('API: drag a long-titled card to a nonadjacent column', (
        tester,
      ) async {
        final server = await _pumpApi(tester, size: size, [
          _task(1, 'todo', title: _longTitle),
          _task(2, 'in_progress'),
        ]);
        await _openColumn(tester, 'todo');
        final readsBefore = server.boardReads;
        final hovered = await _drag(
          tester,
          find.byKey(const Key('kanban-1')),
          _drop('completed'),
          shot: 'kanban_dragging_$name',
        );
        expect(hovered, isTrue, reason: 'the drop target is highlighted');
        await tester.pumpAndSettle();
        await screenshot(tester, 'kanban_drag_done_$name');

        expect(server.posts.single.data, {'task_id': 1, 'status': 'completed'});
        expect(find.text('Task status updated.'), findsOneWidget);
        expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
        // Reconciled with the server, which now stores the new status.
        expect(server.boardReads, readsBefore + 1);
        expect(find.byKey(const Key('kanban-1')), findsNothing);
        await _openColumn(tester, 'completed');
        expect(find.byKey(const Key('kanban-1')), findsOneWidget);
        expect(find.byKey(const Key('kanban-pending')), findsNothing);
      });

      testWidgets('API: drop into an empty column via the page tabs', (
        tester,
      ) async {
        final server = await _pumpApi(tester, size: size, [
          _task(2, 'in_progress'),
        ]);
        await _openColumn(tester, 'inProgress');
        await _drag(
          tester,
          find.byKey(const Key('kanban-2')),
          find.byKey(const Key('column-inReview')),
        );
        await tester.pumpAndSettle();
        expect((server.posts.single.data as Map)['status'], 'in_review');
        await _openColumn(tester, 'inReview');
        expect(find.byKey(const Key('kanban-2')), findsOneWidget);
      });

      testWidgets('demo: drag moves the card and it shows in its column', (
        tester,
      ) async {
        await _pumpMock(tester, size);
        final hovered = await _drag(
          tester,
          find.byKey(const Key('kanban-t1')),
          _drop('completed'),
        );
        expect(hovered, isTrue);
        await tester.pumpAndSettle();
        expect(find.textContaining('Saved on this device'), findsOneWidget);
        expect(find.byKey(const Key('kanban-t1')), findsNothing);
        await _openColumn(tester, 'completed');
        expect(find.byKey(const Key('kanban-t1')), findsOneWidget);
        await screenshot(tester, 'kanban_drag_mock_$name');
      });
    });
  }

  testWidgets('API: a pending move shows a spinner and blocks re-dragging', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    server.gate = Completer<void>();
    await _drag(tester, find.byKey(const Key('kanban-1')), _drop('todo'));
    await tester.pump();
    // Shown at once in its destination, marked as saving. (The spinner
    // never settles, so frames are pumped for a fixed time here.)
    expect(find.byKey(const Key('kanban-1')), findsNothing);
    await tester.tap(find.byKey(const Key('column-todo')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
    expect(find.byKey(const Key('kanban-pending')), findsOneWidget);
    expect(find.text('Task status updated.'), findsNothing);

    // While saving the card can be neither dragged nor tapped again.
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('kanban-1'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('kanban-1')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('kanban-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('move-completed')), findsNothing);

    server.gate!.complete();
    await tester.pumpAndSettle();
    expect(server.posts, hasLength(1));
    expect(find.byKey(const Key('kanban-pending')), findsNothing);
    expect(find.text('Task status updated.'), findsOneWidget);
  });

  testWidgets('API: a refused move restores the card and shows the error', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    server.refuse = (403, failure('Only the project leader can do this.'));
    await _drag(tester, find.byKey(const Key('kanban-1')), _drop('completed'));
    await tester.pumpAndSettle();
    expect(find.text('Task status updated.'), findsNothing);
    expect(find.text("You don't have access to this."), findsOneWidget);
    // Back where it was, not saved anywhere.
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
    expect(find.byKey(const Key('kanban-pending')), findsNothing);
    await _openColumn(tester, 'completed');
    expect(find.byKey(const Key('kanban-1')), findsNothing);
    expect(server.tasks[1]!['status'], 'in_progress');
  });

  testWidgets('API: a network failure also restores the card', (tester) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    server.refuse = (500, failure('Server Error'));
    await _drag(tester, find.byKey(const Key('kanban-1')), _drop('todo'));
    await tester.pumpAndSettle();
    expect(find.text('Task status updated.'), findsNothing);
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
  });

  testWidgets('API: rapid drags of two cards send one request each', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [
      _task(1, 'in_progress'),
      _task(2, 'in_progress'),
    ]);
    server.gate = Completer<void>();
    await _drag(tester, find.byKey(const Key('kanban-1')), _drop('completed'));
    await _drag(tester, find.byKey(const Key('kanban-2')), _drop('backlog'));
    await tester.pump();
    expect(find.byKey(const Key('kanban-1')), findsNothing);
    expect(find.byKey(const Key('kanban-2')), findsNothing);
    server.gate!.complete();
    await tester.pumpAndSettle();
    expect(server.posts.map((p) => p.data).toList(), [
      {'task_id': 1, 'status': 'completed'},
      {'task_id': 2, 'status': 'backlog'},
    ]);
  });

  testWidgets('API: dropping on the current status sends nothing', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    await _drag(tester, find.byKey(const Key('kanban-1')), _drop('inProgress'));
    await tester.pumpAndSettle();
    expect(server.posts, isEmpty);
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
    expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
  });

  testWidgets('API: a card the server marks read-only cannot be moved', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [
      _task(1, 'in_progress', canUpdate: false),
    ]);
    await _reveal(tester, find.byKey(const Key('kanban-1')));
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('kanban-1'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
    await g.up();
    await tester.tap(find.byKey(const Key('kanban-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('move-completed')), findsNothing);
    expect(server.posts, isEmpty);
  });

  testWidgets('a swipe still scrolls the page and picks nothing up', (
    tester,
  ) async {
    await _pumpApi(tester, [
      for (var i = 1; i <= 4; i++) _task(i, 'in_progress', title: _longTitle),
    ]);
    final list = find.byType(Scrollable).first;
    await _reveal(tester, find.byKey(const Key('kanban-1')));
    final before = tester.state<ScrollableState>(list).position.pixels;
    await tester.drag(find.byKey(const Key('kanban-1')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(list).position.pixels,
      greaterThan(before),
    );
    expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
  });

  testWidgets('a cancelled drag removes the drop bar and changes nothing', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    await _reveal(tester, find.byKey(const Key('kanban-1')));
    final start = tester.getCenter(find.byKey(const Key('kanban-1')));
    final g = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(const Key('kanban-drop-bar')), findsOneWidget);
    await g.moveTo(start + const Offset(0, 40));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-drop-bar')), findsNothing);
    expect(server.posts, isEmpty);
    expect(find.byKey(const Key('kanban-1')), findsOneWidget);
  });

  testWidgets('tap-to-move still works as the accessible fallback', (
    tester,
  ) async {
    final server = await _pumpApi(tester, [_task(1, 'in_progress')]);
    await _reveal(tester, find.byKey(const Key('kanban-1')));
    await tester.tap(find.byKey(const Key('kanban-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-inReview')));
    await tester.pumpAndSettle();
    expect((server.posts.single.data as Map)['status'], 'in_review');
  });

  testWidgets('demo: drag a card into the backlog', (tester) async {
    await _pumpMock(tester, const Size(360, 740));
    await _drag(tester, find.byKey(const Key('kanban-t2')), _drop('backlog'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Backlog').first);
    await tester.tap(find.text('Backlog').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-t2')), findsOneWidget);
  });
}
