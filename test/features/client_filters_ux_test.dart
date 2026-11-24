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
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/preferences/preference_controls.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/finance/presentation/payments_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/overview/presentation/overview_screen.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';
import 'client_api_contract_test.dart' show invoicesExample;

/// Client UX cleanup (after d51d596): the list-filter pattern approved on
/// Employee Tasks — one search in the masthead, every filter in one sheet
/// applied with "Show results", removable active-filter chips, Reset, and
/// Export beside the Filters button using the applied filters — on Client
/// Invoices and Payments; one search on Projects and Meetings; the
/// Preferences row and the numeral policy. Fixtures are test doubles.

Map<String, dynamic> _invoices({int lastPage = 3}) {
  final body = invoicesExample();
  (body['data'] as Map<String, dynamic>)
    ..['last_page'] = lastPage
    ..['total'] = lastPage * 15;
  return body;
}

Map<String, dynamic> _payments() => {
  'success': true,
  'message': 'Payments list',
  'data': {
    'current_page': 1,
    'per_page': 15,
    'total': 45,
    'last_page': 3,
    'data': [
      {
        'id': 31,
        'invoice_id': 5,
        'amount': '300.00',
        'payment_method': 'cash',
        'payment_date': '2026-08-01',
        'direction': 'incoming',
      },
    ],
  },
  'stats': {'total': 1, 'received': 300, 'pending': 0, 'paid_out': 0},
  'totals': [
    {
      'currency_id': 1,
      'code': 'USD',
      'symbol': r'$',
      'received': 300,
      'pending': 0,
      'paid_out': 0,
    },
  ],
};

RawReply _csv(String name) =>
    RawReply(Uint8List.fromList(utf8.encode('Invoice\r\n')), {
      Headers.contentTypeHeader: 'text/csv; charset=UTF-8',
      'content-disposition': 'attachment; filename="$name"',
    });

Map<String, (int, Object?)> get _routes => {
  'GET /api/v1/client/account': (
    200,
    ok({'id': 1, 'email': 'qa@test.dev', 'name': 'QA'}),
  ),
  'GET /api/v1/client/notifications': (
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
  ),
  'GET /api/v1/client/notifications/unread-count': (
    200,
    ok({'unread_count': 0}),
  ),
  'GET /api/v1/client/invoices': (200, _invoices()),
  'GET /api/v1/client/invoices/export': (200, _csv('i.csv')),
  'GET /api/v1/client/payments': (200, _payments()),
  'GET /api/v1/client/payments/export': (200, _csv('p.csv')),
  'GET /api/v1/client/projects': (
    200,
    ok({
      'current_page': 1,
      'per_page': 15,
      'total': 0,
      'last_page': 1,
      'data': <Object>[],
    }),
  ),
  'GET /api/v1/client/meetings': (
    200,
    ok({
      'current_page': 1,
      'per_page': 15,
      'total': 0,
      'last_page': 1,
      'data': <Object>[],
    }),
  ),
};

late RouteHttpAdapter _http;

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 1400),
  double scale = 1,
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  AppColors.use(dark ? Brightness.dark : Brightness.light);
  addTearDown(() => AppColors.use(Brightness.light));
  useWesternDigits();
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
  _http = RouteHttpAdapter(_routes);
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
          adapter: _http,
        ),
      ),
      csvSaverProvider.overrideWithValue((_) async => true),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<RequestOptions> _calls(String path) =>
    _http.requests.where((r) => r.uri.path == path).toList();

Map<String, dynamic> _lastQuery(String path) =>
    _calls(path).last.uri.queryParameters;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The editable text fields on the page (the masthead search included).
int _searchFields(WidgetTester tester) => find
    .byType(EditableText)
    .evaluate()
    .where((e) => (e.renderObject! as RenderBox).attached)
    .length;

void main() {
  group('one search per screen', () {
    for (final (name, screen, key) in [
      ('Invoices', const InvoicesScreen(), 'invoices-search'),
      ('Payments', const PaymentsScreen(), 'payments-search'),
      ('Projects', const ProjectsScreen(), 'projects-search'),
      ('Meetings', const MeetingsScreen(), 'meetings-search'),
    ]) {
      testWidgets('$name has only the masthead search', (tester) async {
        await _pump(tester, screen);
        expect(_searchFields(tester), 1);
        // The masthead field carries the screen's search key.
        expect(
          find.descendant(
            of: find.byType(ModuleMasthead),
            matching: find.byKey(Key(key)),
          ),
          findsOneWidget,
        );
      });
    }
  });

  group('Invoices filters', () {
    const path = '/api/v1/client/invoices';

    testWidgets('chips are in the sheet, not on the screen', (tester) async {
      await _pump(tester, const InvoicesScreen());
      expect(find.byKey(const Key('invoice-filter-overdue')), findsNothing);
      expect(find.byKey(const Key('invoice-project')), findsNothing);
      expect(find.byKey(const Key('invoice-filters')), findsOneWidget);
      // Export sits beside the Filters button.
      final bar = find.byKey(const Key('invoice-filter-bar'));
      expect(
        find.descendant(of: bar, matching: find.byKey(const Key('export-csv'))),
        findsOneWidget,
      );
    });

    testWidgets('three choices send one request from page 1; dismissing '
        'sends none', (tester) async {
      await _pump(tester, const InvoicesScreen());
      // Go to page 2 first.
      await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(_lastQuery(path)['page'], '2');
      final before = _calls(path).length;

      // Dismissed: nothing is sent and nothing changes.
      await _tap(tester, find.byKey(const Key('invoice-filters')));
      await _tap(tester, find.byKey(const Key('invoice-filter-overdue')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_calls(path).length, before);
      expect(find.text('Filters'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('invoice-filters')));
      await _tap(tester, find.byKey(const Key('invoice-filter-overdue')));
      await _tap(tester, find.byKey(const Key('invoice-range-thisYear')));
      await _tap(tester, find.byKey(const Key('invoice-sort-highestAmount')));
      await tester.pumpAndSettle();
      expect(_calls(path).length, before, reason: 'drafted, not sent');
      await _tap(tester, find.byKey(const Key('invoice-filters-apply')));

      expect(_calls(path).length, before + 1, reason: 'one request');
      final q = _lastQuery(path);
      expect(q['status'], 'overdue');
      expect(q['sort'], '-amount');
      expect(q['from'], '${DateTime.now().year}-01-01');
      expect(q['page'], '1');
      expect(find.text('Filters (3)'), findsOneWidget);
      for (final k in ['status', 'range', 'sort']) {
        expect(find.byKey(Key('active-filter-$k')), findsOneWidget);
      }
    });

    testWidgets('removing a chip drops only that filter; Reset clears all', (
      tester,
    ) async {
      await _pump(tester, const InvoicesScreen());
      await _tap(tester, find.byKey(const Key('invoice-filters')));
      await _tap(tester, find.byKey(const Key('invoice-filter-paid')));
      await _tap(tester, find.byKey(const Key('invoice-sort-oldest')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('invoice-filters-apply')));

      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('active-filter-status')),
          matching: find.byType(IconButton),
        ),
      );
      var q = _lastQuery(path);
      expect(q['status'], 'all');
      expect(q['sort'], 'invoice_date');
      expect(find.text('Filters (1)'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('reset-filters')));
      q = _lastQuery(path);
      expect(q['status'], 'all');
      expect(q['sort'], '-invoice_date');
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byKey(const Key('reset-filters')), findsNothing);
    });

    testWidgets('the sheet keeps the applied filters and its Reset only '
        'resets the draft', (tester) async {
      await _pump(tester, const InvoicesScreen());
      await _tap(tester, find.byKey(const Key('invoice-filters')));
      await _tap(tester, find.byKey(const Key('invoice-filter-unpaid')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('invoice-filters-apply')));
      final sent = _calls(path).length;

      await _tap(tester, find.byKey(const Key('invoice-filters')));
      bool selected(String key) =>
          tester.widget<FilterChipBox>(find.byKey(Key(key))).selected;
      // The sheet opens on the applied filters.
      expect(selected('invoice-filter-unpaid'), isTrue);
      expect(selected('invoice-filter-all'), isFalse);
      await _tap(tester, find.byKey(const Key('invoice-filters-reset')));
      await tester.pumpAndSettle();
      expect(_calls(path).length, sent, reason: 'Reset in the sheet drafts');
      await _tap(tester, find.byKey(const Key('invoice-filters-apply')));
      expect(_lastQuery(path)['status'], 'all');
    });

    testWidgets('export sends exactly the applied filters and search', (
      tester,
    ) async {
      await _pump(tester, const InvoicesScreen());
      await _tap(tester, find.byKey(const Key('invoice-filters')));
      await _tap(tester, find.byKey(const Key('invoice-filter-overdue')));
      await tester.tap(find.byKey(const Key('invoice-range-last90')));
      await _tap(tester, find.byKey(const Key('invoice-sort-dueSoonest')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('invoice-filters-apply')));
      await tester.enterText(find.byKey(const Key('invoices-search')), 'acme');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const Key('export-csv')));
      final list = Map.of(_lastQuery(path))
        ..remove('page')
        ..remove('per_page');
      final export = _lastQuery('/api/v1/client/invoices/export');
      expect(export, list);
      expect(export['search'], 'acme');
      expect(export['status'], 'overdue');
    });
  });

  group('Payments filters', () {
    const path = '/api/v1/client/payments';

    testWidgets('status and period in one request; chips; export matches', (
      tester,
    ) async {
      await _pump(tester, const PaymentsScreen());
      expect(find.byKey(const Key('payment-status-pending')), findsNothing);
      await _tap(tester, find.widgetWithText(ChoiceChip, '3'));
      final before = _calls(path).length;

      await _tap(tester, find.byKey(const Key('payment-filters')));
      await _tap(tester, find.byKey(const Key('payment-status-pending')));
      await tester.tap(find.byKey(const Key('payment-range-last30')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('payment-filters-apply')));
      expect(_calls(path).length, before + 1);
      final q = _lastQuery(path);
      expect(q['status'], 'pending');
      expect(q['from'], isNotNull);
      expect(q['page'], '1');
      expect(find.text('Filters (2)'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('export-csv')));
      final list = Map.of(_lastQuery(path))
        ..remove('page')
        ..remove('per_page');
      expect(_lastQuery('/api/v1/client/payments/export'), list);

      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('active-filter-range')),
          matching: find.byType(IconButton),
        ),
      );
      expect(_lastQuery(path).containsKey('from'), isFalse);
      expect(_lastQuery(path)['status'], 'pending');
      await _tap(tester, find.byKey(const Key('reset-filters')));
      expect(_lastQuery(path)['status'], isNull);
    });
  });

  group('layout: English/Arabic, light/dark, 320/360 dp, 1.0/1.3 text', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final dark in [false, true]) {
        for (final width in const [320.0, 360.0]) {
          for (final scale in const [1.0, 1.3]) {
            final tag =
                '${locale.languageCode} ${dark ? 'dark' : 'light'} '
                '${width.toInt()} x$scale';
            for (final (name, screen, id) in [
              ('Invoices', const InvoicesScreen(), 'invoice'),
              ('Payments', const PaymentsScreen(), 'payment'),
            ]) {
              testWidgets('$name bar and sheet fit: $tag', (tester) async {
                await _pump(
                  tester,
                  screen,
                  size: Size(width, 740),
                  scale: scale,
                  locale: locale,
                  dark: dark,
                );
                expect(tester.takeException(), isNull);
                await _tap(tester, find.byKey(Key('$id-filters')));
                expect(tester.takeException(), isNull);
                expect(find.byKey(Key('$id-filter-sheet')), findsOneWidget);
                expect(
                  Directionality.of(
                    tester.element(find.byKey(Key('$id-filter-sheet'))),
                  ),
                  locale.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                );
                // Every choice is reachable by scrolling the sheet.
                final apply = find.byKey(Key('$id-filters-apply'));
                await tester.ensureVisible(apply);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await screenshot(
                  tester,
                  'ux_${id}_sheet_${tag.replaceAll(' ', '_')}',
                );
              });
            }
          }
        }
      }
    }
  });

  group('Preferences row', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets('titles never break inside a word: '
              '${locale.languageCode} ${width.toInt()} x$scale', (
            tester,
          ) async {
            await _pump(
              tester,
              const Padding(
                padding: EdgeInsets.all(20),
                child: PreferencesCard(),
              ),
              size: Size(width, 740),
              scale: scale,
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            for (final k in ['settings-language', 'settings-appearance']) {
              final p = tester.renderObject<RenderParagraph>(
                find.byKey(Key('$k-title')),
              );
              final text = p.text.toPlainText();
              final lines = p
                  .getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: text.length),
                  )
                  .map((b) => b.top.round())
                  .toSet()
                  .length;
              expect(lines, 1, reason: '"$text" wrapped');
            }
          });
        }
      }
    }
  });

  group('numeral policy: Western digits in both languages', () {
    testWidgets('Arabic home date has no Arabic-Indic digits', (tester) async {
      await _pump(tester, const OverviewScreen(), locale: const Locale('ar'));
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' ');
      expect(RegExp('[٠-٩]').hasMatch(texts), isFalse);
      expect(texts, contains('${DateTime.now().day}'));
    });
  });
}
