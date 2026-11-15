import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/viewport.dart';

/// Content height of the statistics-heavy screens at 390 px (demo data),
/// written to `$LAYOUT_REPORT` when set, with full-length screenshots under
/// `$SCREENSHOT_DIR`. Used for the before/after comparison of the compact
/// layouts; in normal runs it only checks that every screen opens.

Future<void> _pump(WidgetTester tester, Portal portal, Size size) async {
  useViewport(tester, size);
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

Future<void> _open(WidgetTester tester, String? tab, String? category) async {
  if (tab != null) await tester.tap(find.text(tab).last);
  if (category != null) {
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    final c = find.byKey(Key('category-$category'));
    await tester.ensureVisible(c);
    await tester.pumpAndSettle();
    // Clear of the floating navigation surface (bottom 130 px).
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final r = tester.getRect(c);
    if (r.bottom > height - 130) {
      await tester.drag(
        find.byType(Scrollable).hitTestable().first,
        Offset(0, height - 130 - r.bottom),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(c);
  }
  await tester.pumpAndSettle();
}

/// Total scrollable content height of the screen's main list.
double _contentHeight(WidgetTester tester) {
  // Only the list on screen: other tabs and the routes underneath keep
  // their own scrollables alive.
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable).hitTestable())
      .where((s) => s.position.axis == Axis.vertical)
      .toList();
  var best = 0.0;
  for (final s in states) {
    final p = s.position;
    if (!p.hasContentDimensions) continue;
    final total = p.maxScrollExtent + p.viewportDimension;
    if (total > best) best = total;
  }
  return best;
}

const _screens = <(String, Portal, String?, String?)>[
  ('client_home', Portal.client, null, null),
  ('client_dashboard', Portal.client, null, 'Dashboard'),
  ('client_projects', Portal.client, null, 'Projects'),
  ('client_invoices', Portal.client, 'Invoices', null),
  ('client_payments', Portal.client, null, 'Payments'),
  ('employee_home', Portal.employee, null, null),
  ('employee_dashboard', Portal.employee, null, 'Dashboard'),
  ('employee_projects', Portal.employee, 'Projects', null),
  ('employee_tasks', Portal.employee, null, 'Tasks'),
  ('employee_timesheets', Portal.employee, null, 'Timesheets'),
];

void main() {
  // A missed tap would measure the wrong screen.
  WidgetController.hitTestWarningShouldBeFatal = true;
  final report = <String>[];

  tearDownAll(() {
    final path = Platform.environment['LAYOUT_REPORT'];
    if (path != null && path.isNotEmpty) {
      File(path).writeAsStringSync('${report.join('\n')}\n');
    }
  });

  for (final (name, portal, tab, category) in _screens) {
    testWidgets('$name opens; content height recorded', (tester) async {
      await _pump(tester, portal, const Size(390, 844));
      await _open(tester, tab, category);
      final h = _contentHeight(tester);
      expect(h, greaterThan(0));
      report.add('$name\t${h.round()}');
      // A full-length shot: the same width, tall enough for everything.
      if ((Platform.environment['SCREENSHOT_DIR'] ?? '').isNotEmpty) {
        useViewport(tester, Size(390, h + 120));
        await tester.pumpAndSettle();
        await screenshot(tester, 'survey_$name');
      }
    });
  }
}
