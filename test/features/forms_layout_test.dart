import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';

import '../helpers/viewport.dart';

const Map<String, Size> _sizes = phoneViewports;
const List<double> _scales = [1.0, 1.3];

Future<void> _pumpMock(
  WidgetTester tester,
  Portal portal,
  Size size,
  double scale,
) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  await storage.writeAll(
    Session(
      token: 't',
      tokenType: 'Bearer',
      userId: 10,
      portal: portal,
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

Future<void> _openCategory(WidgetTester tester, String label) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  final item = find.byKey(Key('category-$label'));
  await tester.scrollUntilVisible(
    item,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _reveal(tester, item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

/// Brings [target] into the area a finger can reach: below the top of the
/// screen and above the floating navigation surface, when there is one.
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

/// Scrolls the form (built lazily) until [target] exists and is shown.
Future<void> _scrollFormTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tapCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-fab')));
  await tester.pumpAndSettle();
}

Finder get _selects =>
    find.byWidgetPredicate((w) => w is DropdownButtonFormField);

Finder get _dateFields =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'DateField');

/// Runs the checks every form must pass at the current size and text
/// scale: empty submit shows errors, the focused input stays above the
/// keyboard, the first dropdown's last option and the date picker are
/// reachable, and Cancel closes the form.
Future<void> _exerciseForm(
  WidgetTester tester, {
  required String shot,
  required String title,
  required Key textField,
  required String lastOption,
  bool hasDate = true,
}) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(find.text(title), findsWidgets);
  await screenshot(tester, '${shot}_top');

  // 1. Required-field validation on an empty submit.
  await _scrollFormTo(tester, find.byKey(const Key('form-save')));
  await tester.tap(find.byKey(const Key('form-save')));
  await tester.pumpAndSettle();
  expect(find.text('This field is required'), findsWidgets);
  expect(
    find.byKey(const Key('form-save')),
    findsOneWidget,
    reason: 'an invalid form stays open',
  );
  await screenshot(tester, '${shot}_errors');

  // 2. The keyboard never hides the focused input.
  await _scrollFormTo(tester, find.byKey(textField));
  await tester.tap(find.byKey(textField));
  showKeyboard(tester, size.height * 0.42);
  await tester.pumpAndSettle();
  final field = tester.getRect(find.byKey(textField));
  expect(field.bottom, lessThanOrEqualTo(size.height * 0.58 + 1));
  expect(field.top, greaterThanOrEqualTo(0));
  await screenshot(tester, '${shot}_keyboard');
  tester.view.resetViewInsets();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  // 3. The first dropdown opens and its last option can be chosen.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  await _scrollFormTo(tester, _selects.first);
  await tester.tap(_selects.first);
  await tester.pumpAndSettle();
  await screenshot(tester, '${shot}_dropdown');
  final option = find.text(lastOption).last;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  expect(option.hitTestable(), findsOneWidget);
  await tester.tap(option);
  await tester.pumpAndSettle();
  expect(
    find.descendant(of: _selects.first, matching: find.text(lastOption)),
    findsWidgets,
  );

  // 4. The date picker opens with reachable actions.
  if (hasDate) {
    await _scrollFormTo(tester, _dateFields.first);
    await tester.tap(_dateFields.first);
    await tester.pumpAndSettle();
    await screenshot(tester, '${shot}_date');
    expect(find.text('OK').hitTestable(), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  // 5. Cancel leaves the form.
  final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
  await _scrollFormTo(tester, cancel);
  await tester.tap(cancel);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('form-save')), findsNothing);
}

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final scale in _scales) {
      final tag = '${name}_x$scale';
      group('$name text x$scale', () {
        testWidgets('invoice form', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await tester.tap(find.text('Invoices').last);
          await tester.pumpAndSettle();
          await _tapCreate(tester);
          await _exerciseForm(
            tester,
            shot: 'invoice_form_$tag',
            title: 'Create Invoice',
            textField: const Key('invoice-amount'),
            lastOption: FinanceOptions.companies.last,
          );
        });

        testWidgets('payment form', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await _openCategory(tester, 'Payments');
          await _tapCreate(tester);
          await _exerciseForm(
            tester,
            shot: 'payment_form_$tag',
            title: 'Add Payment',
            textField: const Key('payment-amount'),
            lastOption: FinanceOptions.companies.last,
          );
        });

        testWidgets('project form', (tester) async {
          await _pumpMock(tester, Portal.client, size, scale);
          await _openCategory(tester, 'Projects');
          await _tapCreate(tester);
          await _exerciseForm(
            tester,
            shot: 'project_form_$tag',
            title: 'Add Project',
            textField: const Key('project-budget'),
            lastOption: FinanceOptions.companies.last,
            hasDate: false,
          );
        });

        testWidgets('task form', (tester) async {
          await _pumpMock(tester, Portal.employee, size, scale);
          await _openCategory(tester, 'Tasks');
          await _tapCreate(tester);
          await _exerciseForm(
            tester,
            shot: 'task_form_$tag',
            title: 'Add Task',
            textField: const Key('task-title'),
            lastOption: workProjects.last,
          );
        });

        testWidgets('timesheet details sheet and view-only actions', (
          tester,
        ) async {
          await _pumpMock(tester, Portal.employee, size, scale);
          await _openCategory(tester, 'Timesheets');
          final card = find.byKey(const Key('timesheet-ts0'));
          final view = find.descendant(
            of: card,
            matching: find.byKey(const Key('action-view')),
          );
          await _reveal(tester, view);
          // Employees may not approve, reject or delete timesheets (403 in
          // the collection), so a card offers View only.
          for (final action in ['action-edit', 'action-delete']) {
            expect(
              find.descendant(of: card, matching: find.byKey(Key(action))),
              findsNothing,
            );
          }
          await tester.tap(view);
          await tester.pumpAndSettle();
          await screenshot(tester, 'timesheet_details_$tag');
          // Every detail row can be scrolled to and the sheet closes.
          await tester.ensureVisible(find.text('Amount').last);
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
        });
      });
    }
  }
}
