import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/route_http_adapter.dart';
import '../helpers/viewport.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Portal portal, {
  AppMode mode = AppMode.mock,
  Size size = const Size(360, 740),
  RouteHttpAdapter? adapter,
}) async {
  useViewport(tester, size);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
      companyId: 3,
      portal: portal,
    ).toStorage(),
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(mode: mode, apiBaseUrl: 'https://api.test'),
      ),
      sessionStorageProvider.overrideWithValue(storage),
      if (adapter != null)
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
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WorkFlowApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, h - 130 - r.bottom),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _openCategory(WidgetTester tester, String label) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.byKey(Key('category-$label')));
  await tester.tap(find.byKey(Key('category-$label')));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String field, String option) async {
  final select = find.ancestor(
    of: find.text(field),
    matching: find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() ==
          'SelectField<${option == 'Pending' ? 'InvoiceStatus' : 'String'}>',
    ),
  );
  await _scrollTo(tester, select.first);
  await tester.tap(
    find.descendant(
      of: select.first,
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Fills every required invoice field with valid values.
Future<void> _fillInvoice(WidgetTester tester, {String amount = '250'}) async {
  await _pick(tester, 'Company', FinanceOptions.companies.first);
  await _pick(tester, 'Client', FinanceOptions.clients.first);
  await _pick(tester, 'Project', FinanceOptions.projects.first);
  await _scrollTo(tester, find.byKey(const Key('invoice-amount')));
  await tester.enterText(find.byKey(const Key('invoice-amount')), amount);
  await _pick(tester, 'Status', 'Pending');
}

void main() {
  testWidgets('a fast double tap on Save creates one invoice', (tester) async {
    final c = await _pump(tester, Portal.client);
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();
    final before = c.read(invoicesProvider).length;
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    await _fillInvoice(tester);
    await _scrollTo(tester, find.byKey(const Key('form-save')));
    final save = tester.getCenter(find.byKey(const Key('form-save')));
    await tester.tapAt(save);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(save);
    await tester.pumpAndSettle();
    expect(c.read(invoicesProvider).length, before + 1);
    expect(find.byKey(const Key('form-save')), findsNothing);
  });

  testWidgets('a zero amount is refused with a visible message', (
    tester,
  ) async {
    final c = await _pump(tester, Portal.client);
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();
    final before = c.read(invoicesProvider).length;
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    await _fillInvoice(tester, amount: '0');
    await _scrollTo(tester, find.byKey(const Key('form-save')));
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
    expect(c.read(invoicesProvider).length, before);
  });

  testWidgets('a due date before the invoice date is refused', (tester) async {
    final c = await _pump(tester, Portal.client);
    await tester.tap(find.text('Invoices').last);
    await tester.pumpAndSettle();
    final before = c.read(invoicesProvider).length;
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    await _fillInvoice(tester);
    // Move the due date back before the invoice date (today).
    final due = find.byKey(const Key('date-Due Date'));
    await _scrollTo(tester, due);
    await tester.tap(due);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '01/01/2021');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('form-save')));
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('The due date can’t be before the invoice date'),
      findsOneWidget,
    );
    expect(c.read(invoicesProvider).length, before);
  });

  testWidgets('story points must be a whole number', (tester) async {
    await _pump(tester, Portal.employee);
    await _openCategory(tester, 'Tasks');
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    final points = find.byKey(const Key('task-points'));
    await _scrollTo(tester, points);
    await tester.enterText(points, '1.5');
    await _scrollTo(tester, find.byKey(const Key('form-save')));
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number'), findsOneWidget);
  });

  testWidgets('a date field outside the picker range still opens', (
    tester,
  ) async {
    useViewport(tester, const Size(360, 740));
    var value = DateTime(2016, 3, 4);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => DateField(
              label: 'Date',
              value: value,
              onChanged: (d) => set(() => value = d),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('04-03-2016'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('long record details scroll inside the sheet', (tester) async {
    useViewport(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showRecordDetails(
                  context,
                  title: 'Customer Portal Revamp and Billing Migration',
                  status: 'In progress',
                  tone: BadgeTone.info,
                  fields: [
                    for (var i = 0; i < 12; i++)
                      DetailField(
                        'Field $i',
                        'A long value that wraps over several lines on a '
                            'small phone to test the sheet height $i',
                      ),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'record_details_long_320x640_x1.3');
    await tester.scrollUntilVisible(
      find.text('Field 11'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Field 11').hitTestable(), findsOneWidget);
  });

  testWidgets('project actions open above the navigation surface', (
    tester,
  ) async {
    await _pump(tester, Portal.employee);
    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    final more = find.descendant(
      of: find.byKey(const Key('project-p1')),
      matching: find.byTooltip('More actions'),
    );
    await _scrollTo(tester, more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Delete').last.hitTestable(), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-delete')), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
  });

  group('API mode never opens a form that cannot be saved', () {
    final routes = <String, (int, Object?)>{
      'GET /api/v1/client/account': (200, ok({'id': 10, 'name': 'Me'})),
      'GET /api/v1/employee/account': (200, ok({'id': 10, 'name': 'Me'})),
    };

    testWidgets('create invoice', (tester) async {
      await _pump(
        tester,
        Portal.client,
        mode: AppMode.api,
        adapter: RouteHttpAdapter(routes),
      );
      await tester.tap(find.text('Invoices').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-save')), findsNothing);
      expect(find.textContaining('no invoice create route'), findsOneWidget);
    });

    testWidgets('add payment', (tester) async {
      await _pump(
        tester,
        Portal.client,
        mode: AppMode.api,
        adapter: RouteHttpAdapter(routes),
      );
      await _openCategory(tester, 'Payments');
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-save')), findsNothing);
      expect(find.textContaining('no payment create route'), findsOneWidget);
    });

    testWidgets('add project', (tester) async {
      await _pump(
        tester,
        Portal.employee,
        mode: AppMode.api,
        adapter: RouteHttpAdapter(routes),
      );
      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-save')), findsNothing);
      expect(find.textContaining('no project create route'), findsOneWidget);
    });

    testWidgets('add task', (tester) async {
      await _pump(
        tester,
        Portal.employee,
        mode: AppMode.api,
        adapter: RouteHttpAdapter(routes),
      );
      await _openCategory(tester, 'Tasks');
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-save')), findsNothing);
      expect(find.textContaining('project leader'), findsOneWidget);
    });

    testWidgets('the More create menu says the same', (tester) async {
      await _pump(
        tester,
        Portal.client,
        mode: AppMode.api,
        adapter: RouteHttpAdapter(routes),
      );
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Invoice'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-save')), findsNothing);
      expect(find.textContaining('no invoice create route'), findsOneWidget);
    });
  });
}
