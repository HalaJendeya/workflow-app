import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../helpers/viewport.dart';

const List<double> _scales = [1.0, 1.3];

const _longProject =
    'Customer Portal Revamp and Billing Migration for the Regional Office';

enum _State { populated, empty, error, rateLimited }

/// The client API as the screens use it, in one of four states. Every
/// request is recorded with its X-Company header; [gate] holds responses
/// open to observe loading states.
class _Server implements HttpClientAdapter {
  _State state = _State.populated;
  Completer<void>? gate;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    if (!o.uri.path.contains('/account') &&
        !o.uri.path.contains('/notifications')) {
      await gate?.future;
    }
    final (status, body) = _reply(o.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (status == 429) 'retry-after': ['120'],
      },
    );
  }

  (int, Object?) _reply(String path) {
    if (path == '/api/v1/client/account') {
      return (200, ok({'id': 1, 'name': 'Client', 'email': 'c@test.dev'}));
    }
    if (path == '/api/v1/client/notifications') {
      return (
        200,
        ok({
          'notifications': <Object>[],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 20,
            'total': 0,
            'unread_count': 0,
          },
        }),
      );
    }
    if (path == '/api/v1/client/notifications/unread-count') {
      return (200, ok({'unread_count': 0}));
    }
    switch (state) {
      case _State.error:
        return (500, failure('Server Error'));
      case _State.rateLimited:
        return (429, failure('Too Many Attempts.'));
      case _State.empty:
      case _State.populated:
        final full = state == _State.populated;
        return switch (path) {
          '/api/v1/client/dashboard' => (
            200,
            ok({
              'projectsCount': full ? 1234567 : 0,
              'projectsCompleted': full ? 987654 : 0,
              'projectsInProgress': full ? 246913 : 0,
            }),
          ),
          '/api/v1/client/projects' => (200, _projects(full)),
          '/api/v1/client/invoices' => (200, _invoices(full)),
          '/api/v1/client/payments' => (200, _payments(full)),
          _ => (404, failure('Not found')),
        };
    }
  }

  static Map<String, dynamic> _page(List<Object> rows) => {
    'current_page': 1,
    'data': rows,
    'last_page': rows.isEmpty ? 1 : 3,
    'per_page': 10,
    'total': rows.isEmpty ? 0 : 27,
  };

  static Map<String, dynamic> _projects(bool full) => {
    ...ok(
      _page([
        if (full)
          for (var i = 1; i <= 3; i++)
            {
              'id': i,
              'title': i == 1 ? _longProject : 'Project $i',
              'status': 'in_progress',
              'budget': '98765432.10',
              'currency': {'id': 1, 'code': 'USD', 'symbol': r'$'},
              'completion_percentage': 40 * i % 100,
            },
      ]),
    ),
    'stats': {
      'total': full ? 1234567 : 0,
      'pending': full ? 400000 : 0,
      'in_progress': full ? 734567 : 0,
      'completed': full ? 100000 : 0,
    },
  };

  static Map<String, dynamic> _invoices(bool full) =>
      ok({
        ..._page([
          if (full)
            for (var i = 1; i <= 3; i++)
              {
                'id': 100 + i,
                'invoice_date': '2026-10-12',
                'due_date': '2026-10-01',
                'amount': '987654321.50',
                'status': 'partially_paid',
                'paid_amount': 123456789.25,
                'remaining_amount': 864197532.25,
                'payment_status': 'partially_paid',
                'is_overdue': i == 1,
                'currency': {'id': 1, 'code': 'USD', 'symbol': r'$'},
              },
        ]),
        'stats': {
          'total': full ? 1234567 : 0,
          'paid': full ? 345678 : 0,
          'unpaid': full ? 456789 : 0,
          'partially_paid': full ? 432100 : 0,
          'overdue': full ? 98765 : 0,
        },
      })..addAll({
        'totals': [
          if (full)
            {
              'currency_id': 1,
              'code': 'USD',
              'symbol': r'$',
              'amount': 9876543210.75,
              'paid': 1234567890.5,
              'remaining': 8641975320.25,
              'overdue_amount': 987654321,
            },
        ],
      });

  static Map<String, dynamic> _payments(bool full) => {
    ...ok(_page(const [])),
    'totals': [
      if (full)
        {
          'currency_id': 1,
          'code': 'USD',
          'symbol': r'$',
          'received': 9876543210.75,
          'pending': 123456789.5,
          'paid_out': 0,
        },
    ],
    'stats': {
      'total': full ? 1234567 : 0,
      'received': 0,
      'pending': 0,
      'paid_out': 0,
    },
  };

  @override
  void close({bool force = false}) {}
}

Future<_Server?> _pump(
  WidgetTester tester,
  Size size,
  double scale, {
  AppMode mode = AppMode.api,
  _State state = _State.populated,
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
      userId: 1,
      companyId: 2,
      portal: Portal.client,
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

/// Top edge of the floating navigation surface (or the screen bottom on a
/// page pushed above the shell).
double _navTop(WidgetTester tester) {
  final home = find.text('Home').hitTestable();
  if (home.evaluate().isEmpty) return _height(tester);
  return tester.getRect(home.last).top - 46;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final limit = _navTop(tester) - 8;
  final r = tester.getRect(target);
  if (r.bottom > limit) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, limit - r.bottom),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _open(
  WidgetTester tester,
  String screen, {
  bool settle = true,
}) async {
  if (screen == 'Companies' || screen == 'Invoices') {
    await tester.tap(find.text(screen).last);
  } else {
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(Key('category-$screen')));
    await tester.tap(find.byKey(Key('category-$screen')));
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Let the page transition finish (it outlasts a single short pump).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// The masthead title wraps between words, never inside one.
void _expectTitleWordsWhole(WidgetTester tester, String title) {
  final p = tester.renderObject<RenderParagraph>(find.text(title).first);
  final lines = p
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: title.length),
      )
      .map((b) => b.top.round())
      .toSet()
      .length;
  expect(
    lines,
    lessThanOrEqualTo(title.split(' ').length),
    reason: '"$title" broke inside a word',
  );
}

const _titles = {
  'Dashboard': 'Dashboard',
  'Companies': 'Available Companies',
  'Projects': 'Projects Management',
  'Invoices': 'Invoices Management',
  'Payments': 'Payment Records',
};

/// Scrolls to the end and checks that no card is left under the floating
/// navigation surface, then that every visible text is drawn whole.
Future<void> _checkEnd(WidgetTester tester, String shot) async {
  // Lazily built lists grow as they scroll: jump to the end until it
  // stops moving.
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

/// Fails when a single-line text that should be whole is ellipsized.
void _expectWhole(WidgetTester tester, Finder texts) {
  for (final e in texts.evaluate()) {
    final p = e.renderObject;
    if (p is RenderParagraph) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: '"${p.text.toPlainText()}" is cut off',
      );
    }
  }
}

/// No text inside a card wraps in the middle of a word or a number
/// ("\$98,765,432 / .10" was split at its decimal point).
void _expectNoBrokenWords(WidgetTester tester) {
  final cards = find.byWidgetPredicate(
    (w) => w is ModuleCard || w is MetricCard || w is RecordCard,
  );
  for (final e
      in find
          .descendant(of: cards, matching: find.byType(RichText))
          .evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.attached || !p.hasSize) continue;
    final text = p.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final lines = p
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map((b) => b.top.round())
        .toSet()
        .length;
    final words = text.trim().split(RegExp(r'\s+')).length;
    expect(lines, lessThanOrEqualTo(words), reason: '"$text" broke mid-word');
  }
}

const _screens = ['Dashboard', 'Companies', 'Projects', 'Invoices', 'Payments'];

void main() {
  for (final MapEntry(key: name, value: size) in phoneViewports.entries) {
    for (final scale in _scales) {
      final tag = '${name}_x$scale';
      group('$name text x$scale', () {
        for (final screen in _screens) {
          testWidgets('$screen demo mode fits and scrolls', (tester) async {
            await _pump(tester, size, scale, mode: AppMode.mock);
            await _open(tester, screen);
            await screenshot(tester, 'client_${screen}_mock_top_$tag');
            _expectTitleWordsWhole(tester, _titles[screen]!);
            await _checkEnd(tester, 'client_${screen}_mock_end_$tag');
          });

          testWidgets('$screen API data with long names and large sums', (
            tester,
          ) async {
            await _pump(tester, size, scale);
            await _open(tester, screen);
            await screenshot(tester, 'client_${screen}_api_top_$tag');
            _expectTitleWordsWhole(tester, _titles[screen]!);
            // Large sums and counts are shown whole, never "1,234,5…",
            // and never split across lines.
            _expectWhole(tester, find.textContaining(RegExp(r'\d{1,3},\d{3}')));
            _expectNoBrokenWords(tester);
            await _checkEnd(tester, 'client_${screen}_api_end_$tag');
            _expectNoBrokenWords(tester);
          });
        }
      });
    }
  }

  group('API states at 320x640, text x1.3', () {
    const size = Size(320, 640);
    for (final screen in ['Dashboard', 'Projects', 'Invoices', 'Payments']) {
      testWidgets('$screen empty', (tester) async {
        await _pump(tester, size, 1.3, state: _State.empty);
        await _open(tester, screen);
        expect(find.byKey(const Key('api-error')), findsNothing);
        await _checkEnd(tester, 'client_${screen}_empty');
      });

      testWidgets('$screen error, retry and long message', (tester) async {
        final server = await _pump(
          tester,
          size,
          1.3,
          state: _State.rateLimited,
        );
        await _open(tester, screen);
        // The error cards sit below the summary cards (one per section).
        final scroll = find.byType(Scrollable).first;
        for (var i = 0; i < 20; i++) {
          if (find.byKey(const Key('api-error')).evaluate().isNotEmpty) break;
          await tester.drag(scroll, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('api-error')), findsWidgets);
        expect(find.textContaining('Too many attempts'), findsWidgets);
        await screenshot(tester, 'client_${screen}_error');
        // Retry with the server back: data replaces the error.
        server!.state = _State.populated;
        final retry = find.byKey(const Key('api-retry'));
        // Bounded: a Retry that never clears its error must fail the test,
        // not hang it.
        for (var i = 0; i < 5 && retry.evaluate().isNotEmpty; i++) {
          await _reveal(tester, retry.first);
          await tester.tap(retry.first);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('api-error')), findsNothing);
        await _checkEnd(tester, 'client_${screen}_retried');
      });

      testWidgets('$screen loading shows progress, not sample data', (
        tester,
      ) async {
        final server = await _pump(tester, size, 1);
        server!.gate = Completer<void>();
        await _open(tester, screen, settle: false);
        // Spinners may sit below the fold of a lazily built page.
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 100));
        // Either the request is in flight (spinner), or the list was
        // already loaded by the Home tab and is shown from the cache.
        final cached = find.byKey(const Key('api-project-1'));
        expect(
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
              cached.evaluate().isNotEmpty,
          isTrue,
        );
        expect(find.byKey(const Key('api-error')), findsNothing);
        expect(find.text('#INV-2026-0234'), findsNothing);
        expect(find.text('Gaza'), findsNothing);
        server.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    }

    testWidgets('Payments shows no demo-only search or filters', (
      tester,
    ) async {
      await _pump(tester, size, 1.3);
      await _open(tester, 'Payments');
      expect(find.text('Searching....'), findsNothing);
      expect(find.textContaining('ready for the new WorkFlow API'), findsOne);
      await _checkEnd(tester, 'client_Payments_api_controls');
      expect(find.byKey(const Key('payments-search')), findsNothing);
      expect(find.textContaining('Incoming'), findsNothing);
      expect(find.text('No records match these filters'), findsNothing);
    });

    testWidgets('Companies explains it has no API data yet', (tester) async {
      await _pump(tester, size, 1.3);
      await _open(tester, 'Companies');
      expect(find.textContaining('ready for the new WorkFlow API'), findsOne);
      expect(find.text('Gaza'), findsNothing);
      expect(find.text('Searching....'), findsNothing);
      await _checkEnd(tester, 'client_Companies_api_pending');
    });
  });

  testWidgets('rapid tab switching settles on the last tab without errors', (
    tester,
  ) async {
    final server = await _pump(tester, const Size(360, 740), 1);
    for (var round = 0; round < 3; round++) {
      for (final tab in ['Companies', 'Invoices', 'Home', 'Chat', 'More']) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 30));
      }
    }
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();
    expect(find.text('Invoices Management'), findsOneWidget);
    expect(find.byKey(const Key('api-error')), findsNothing);
    // Every request carried the session's company.
    expect(
      server!.requests
          .where((r) => r.uri.path.startsWith('/api/v1/client/'))
          .every((r) => r.headers['X-Company'] == '2'),
      isTrue,
    );
  });

  testWidgets('back from a pushed client screen returns to More', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 740), 1);
    for (final screen in ['Dashboard', 'Projects', 'Payments']) {
      await _open(tester, screen);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('masthead-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category-$screen')), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
    }
  });
}
