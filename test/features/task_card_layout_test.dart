import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// Task cards (Tasks list, Kanban, dashboard focus tasks) and the task
/// details: density at 390×844 (`$TASK_REPORT`), layout in light, dark,
/// English and Arabic at the phone sizes — no overflow (fails the test),
/// badges inside their card, the details' menu and status control
/// reachable — plus My Tasks, details, actions and back navigation.

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  AppPreferences prefs = const AppPreferences(
    language: LanguagePreference.english,
  ),
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
        initialPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WorkFlowApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens a More category by its position in the More list (labels differ
/// per language): 0 Dashboard, 1 Projects, 2 Tasks, 3 Sprints, 4 Timesheets.
Future<void> _openCategory(WidgetTester tester, int index) async {
  await tester.tap(_navItem(4));
  await tester.pumpAndSettle();
  final items = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('category-'),
  );
  final target = items.at(index);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final r = tester.getRect(target);
  if (r.bottom > h - 130) {
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      Offset(0, h - 130 - r.bottom),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _navItem(int i) => find
    .descendant(
      of: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'WfNavigationSurface',
      ),
      matching: find.byType(InkResponse),
    )
    .at(i);

Future<void> _tapIn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _cards(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      RegExp('^$prefix[^-]+\$').hasMatch((w.key! as ValueKey<String>).value),
);

/// Average height of the cards on screen and how many fit whole between
/// the masthead and the navigation bar.
(double, int) _density(WidgetTester tester, String prefix) {
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rects = [
    for (final e in _cards(prefix).evaluate())
      if (e.renderObject case final RenderBox b when b.attached && b.hasSize)
        b.localToGlobal(Offset.zero) & b.size,
  ];
  if (rects.isEmpty) return (0, 0);
  final avg = rects.map((r) => r.height).reduce((a, b) => a + b) / rects.length;
  final whole = rects.where((r) => r.top >= 0 && r.bottom <= h - 104).length;
  return (avg, whole);
}

void main() {
  final report = <String>[];
  tearDownAll(() {
    final path = Platform.environment['TASK_REPORT'];
    if (path != null && path.isNotEmpty) {
      File(path).writeAsStringSync('${report.join('\n')}\n');
    }
  });

  group('density at 390x844', () {
    testWidgets('Tasks list', (tester) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      final list = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((s) => s.position.axis == Axis.vertical);
      // Scroll so the first card is at the top of the screen.
      final first = _cards('task-t').first;
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      list.position.jumpTo(
        list.position.pixels + tester.getRect(first).top - 20,
      );
      await tester.pumpAndSettle();
      final (avg, whole) = _density(tester, 'task-t');
      report.add('tasks_list\t${avg.round()}\t$whole');
      for (final e in _cards('task-t').evaluate()) {
        final key = (e.widget.key! as ValueKey<String>).value;
        final h = tester.getSize(find.byKey(Key(key))).height.round();
        report.add('  $key\t$h');
      }
      await screenshot(tester, 'task_list');
      final scope = find.byKey(const Key('task-scope'));
      list.position.jumpTo(
        list.position.pixels + tester.getRect(scope).top - 120,
      );
      await tester.pumpAndSettle();
      await screenshot(tester, 'task_list_top');
      expect(avg, greaterThan(0));
    });

    testWidgets('Kanban', (tester) async {
      await _pump(tester);
      await tester.tap(_navItem(1));
      await tester.pumpAndSettle();
      final (avg, whole) = _density(tester, 'kanban-');
      report.add('kanban\t${avg.round()}\t$whole');
      await screenshot(tester, 'task_kanban');
      expect(avg, greaterThan(0));
    });

    testWidgets('Dashboard focus tasks', (tester) async {
      await _pump(tester);
      await _openCategory(tester, 0);
      final first = _cards('focus-').first;
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      final (avg, whole) = _density(tester, 'focus-');
      report.add('dashboard_focus\t${avg.round()}\t$whole');
      await screenshot(tester, 'task_focus');
      expect(avg, greaterThan(0));
    });
  });

  // Light/dark × English/Arabic at the phone sizes. A layout overflow fails
  // the test; every card on screen keeps its badge and actions inside it.
  for (final (name, prefs) in const [
    ('en light', AppPreferences(language: LanguagePreference.english)),
    (
      'ar dark',
      AppPreferences(
        language: LanguagePreference.arabic,
        appearance: AppearancePreference.dark,
      ),
    ),
    (
      'en dark',
      AppPreferences(
        language: LanguagePreference.english,
        appearance: AppearancePreference.dark,
      ),
    ),
    ('ar light', AppPreferences(language: LanguagePreference.arabic)),
  ]) {
    for (final (size, scale) in const [
      (Size(320, 640), 1.3),
      (Size(360, 800), 1.0),
      (Size(390, 844), 1.0),
    ]) {
      final tag = '$name ${size.width.toInt()}x${size.height.toInt()} x$scale';
      final rtl = name.startsWith('ar');

      testWidgets('Tasks list and details: $tag', (tester) async {
        await _pump(tester, size: size, scale: scale, prefs: prefs);
        await _openCategory(tester, 2);
        final cards = _cards('task-t');
        // My Tasks: the demo account's three tasks.
        expect(cards, findsNWidgets(3));
        for (var i = 0; i < 2; i++) {
          final card = cards.at(i);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final box = tester.getRect(card);
          expect(box.width, lessThanOrEqualTo(size.width));
          // No actions on the card.
          for (final key in const ['action-edit', 'action-delete']) {
            expect(
              find.descendant(of: card, matching: find.byKey(Key(key))),
              findsNothing,
            );
          }
          final badge = tester.getRect(
            find.descendant(of: card, matching: find.byType(StatusBadge)),
          );
          expect(
            box.contains(badge.topLeft) && box.contains(badge.bottomRight),
            isTrue,
          );
          // The badge sits at the top end: right in English, left in Arabic.
          expect(
            rtl ? badge.left < box.center.dx : badge.right > box.center.dx,
            isTrue,
            reason: 'badge at the end side',
          );
        }
        if (size.width == 320) {
          await screenshot(
            tester,
            'task_list_${name.replaceAll(' ', '_')}_320',
          );
        }
        // Details: reachable menu and back, in this mode and size.
        final first = cards.first;
        await tester.ensureVisible(first);
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('task-details')), findsOneWidget);
        expect(
          find.byKey(const Key('task-actions')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('task-change-status')).hitTestable(),
          findsOneWidget,
        );
        if (size.width == 320) {
          await screenshot(
            tester,
            'task_details_${name.replaceAll(' ', '_')}_320',
          );
        }
        final list = tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('task-details')),
                matching: find.byType(Scrollable),
              ),
            )
            .first;
        list.position.jumpTo(list.position.maxScrollExtent);
        await tester.pumpAndSettle();
        // Scrolled to the end: back and the menu are still in reach.
        expect(
          find.byKey(const Key('task-actions')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('task-details-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('task-details')), findsNothing);
      });

      testWidgets('Kanban: $tag', (tester) async {
        await _pump(tester, size: size, scale: scale, prefs: prefs);
        await tester.tap(_navItem(1));
        await tester.pumpAndSettle();
        final card = _cards('kanban-').first;
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final box = tester.getRect(card);
        final parent = tester.getRect(find.byType(Scaffold).first);
        expect(box.left, greaterThanOrEqualTo(parent.left));
        expect(box.right, lessThanOrEqualTo(parent.right));
        if (size.width == 320) {
          await screenshot(
            tester,
            'task_kanban_${name.replaceAll(' ', '_')}_320',
          );
        }
      });

      testWidgets('Dashboard focus tasks: $tag', (tester) async {
        await _pump(tester, size: size, scale: scale, prefs: prefs);
        await _openCategory(tester, 0);
        final card = _cards('focus-').first;
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(tester.getRect(card).right, lessThanOrEqualTo(size.width));
      });
    }
  }

  group('TaskCard', () {
    Future<List<String>> pumpCard(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      double width = 320,
      double scale = 1.3,
      String? description =
          'Invalidate cached project and invoice pages whenever the '
          'underlying records change, including bulk imports, and add a '
          'dashboard showing the hit rate per cache key.',
      String? due = '2026/11/20',
    }) async {
      useViewport(tester, Size(width, 400));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: TaskCard(
                  key: const Key('card'),
                  title:
                      'Create executive dashboard widgets and a realtime '
                      'stream for every regional office',
                  description: description,
                  due: due,
                  status: const StatusBadge(
                    label: 'In Progress',
                    tone: BadgeTone.warning,
                  ),
                  onOpen: () => taps.add('open'),
                ),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('a tap anywhere on the card opens the task', (tester) async {
      final taps = await pumpCard(tester);
      await tester.tap(find.byKey(const Key('task-description')));
      await tester.tap(find.byKey(const Key('task-due')));
      expect(taps, ['open', 'open']);
    });

    testWidgets('long text at 320 px and 130 %: two description lines', (
      tester,
    ) async {
      await pumpCard(tester);
      final d = tester.widget<ContentText>(
        find.byKey(const Key('task-description')),
      );
      expect(d.maxLines, 2);
      expect(d.overflow, TextOverflow.ellipsis);
      final card = tester.getRect(find.byKey(const Key('card')));
      for (final e in find.byType(Text).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(r.right, lessThanOrEqualTo(card.right + 0.5));
        expect(r.left, greaterThanOrEqualTo(card.left - 0.5));
      }
      expect(find.text('Due 2026/11/20'), findsOneWidget);
    });

    testWidgets('no description and no due date: nothing invented', (
      tester,
    ) async {
      await pumpCard(tester, description: null, due: null, scale: 1);
      expect(find.byKey(const Key('task-description')), findsNothing);
      expect(find.byKey(const Key('task-due')), findsNothing);
      // Title and status only: a short card.
      expect(
        tester.getSize(find.byKey(const Key('card'))).height,
        lessThan(110),
      );
    });

    testWidgets('announced as a button that opens the details', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, scale: 1);
      final data = tester
          .getSemantics(find.byKey(const Key('action-view')))
          .getSemanticsData();
      expect(data.hint, 'Opens the task details');
      expect(data.label, contains('Create executive dashboard'));
      expect(data.label, contains('In Progress'));
      // Touch target: the whole card.
      expect(
        tester.getSize(find.byKey(const Key('action-view'))).height,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });

    testWidgets('Arabic: the status badge is on the left', (tester) async {
      await pumpCard(tester, locale: const Locale('ar'), width: 390, scale: 1);
      final card = tester.getRect(find.byKey(const Key('card')));
      final badge = tester.getRect(find.byType(StatusBadge));
      expect(badge.left, lessThan(card.center.dx));
    });
  });

  group('demo My Tasks and details', () {
    testWidgets('My Tasks by default; Team tasks shows everyone', (
      tester,
    ) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      expect(find.byKey(const Key('task-t1')), findsOneWidget);
      expect(find.byKey(const Key('task-t2')), findsNothing);
      await _tapIn(tester, find.byKey(const Key('task-scope-team')));
      expect(find.byKey(const Key('task-t2')), findsOneWidget);
      await _tapIn(tester, find.byKey(const Key('task-scope-mine')));
      expect(find.byKey(const Key('task-t2')), findsNothing);
    });

    testWidgets('the card shows title, description, status and due only', (
      tester,
    ) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      final card = find.byKey(const Key('task-t1'));
      await tester.ensureVisible(card);
      for (final hidden in ['P01-T04', 'Sprint 4', 'Urgent', r'$133.58']) {
        expect(
          find.descendant(of: card, matching: find.textContaining(hidden)),
          findsNothing,
          reason: hidden,
        );
      }
      expect(
        find.descendant(of: card, matching: find.byKey(const Key('task-due'))),
        findsOneWidget,
      );
      // t4 has neither a description nor a due date.
      final bare = find.byKey(const Key('task-t4'));
      await tester.ensureVisible(bare);
      expect(
        find.descendant(
          of: bare,
          matching: find.byKey(const Key('task-description')),
        ),
        findsNothing,
      );
    });

    testWidgets('details: every section, no cost; back to the list', (
      tester,
    ) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      await _tapIn(tester, find.byKey(const Key('task-t3')));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
      for (final text in [
        'Configure Redis cache invalidation hooks',
        'P01-T12',
        'Demo Project 01 — Customer Portal Revamp',
        'Sprint 4',
        'Medium',
        'Demo User',
        '2 pts',
        '2h 0m',
        'Due date',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // The full description, not two lines.
      final d = tester.widget<ContentText>(
        find.byKey(const Key('task-details-description')),
      );
      expect(d.maxLines, isNull);
      expect(d.data, contains('stale entries before customers do'));
      expect(find.textContaining(r'$95'), findsNothing);
      await _tapIn(tester, find.byKey(const Key('task-details-back')));
      expect(find.byKey(const Key('task-details')), findsNothing);
      expect(find.byKey(const Key('task-t3')), findsOneWidget);
    });

    testWidgets('change status from the details', (tester) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      await _tapIn(tester, find.byKey(const Key('task-t4')));
      await _tapIn(tester, find.byKey(const Key('task-change-status')));
      await _tapIn(tester, find.byKey(const Key('status-completed')));
      expect(
        find.descendant(
          of: find.byKey(const Key('task-details-status')),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      expect(find.text('Task status updated.'), findsOneWidget);
    });

    testWidgets('edit and delete live in the menu; delete asks first', (
      tester,
    ) async {
      await _pump(tester);
      await _openCategory(tester, 2);
      await _tapIn(tester, find.byKey(const Key('task-t3')));
      await _tapIn(tester, find.byKey(const Key('task-actions')));
      expect(find.byKey(const Key('action-edit')), findsOneWidget);
      await _tapIn(tester, find.byKey(const Key('action-edit')));
      expect(find.byKey(const Key('task-title')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapIn(tester, find.byKey(const Key('task-actions')));
      await _tapIn(tester, find.byKey(const Key('action-delete')));
      // Cancel keeps it.
      await _tapIn(tester, find.text('Cancel'));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
      await _tapIn(tester, find.byKey(const Key('task-actions')));
      await _tapIn(tester, find.byKey(const Key('action-delete')));
      await _tapIn(tester, find.text('Delete').last);
      expect(find.byKey(const Key('task-details')), findsNothing);
      expect(find.byKey(const Key('task-t3')), findsNothing);
    });

    testWidgets('Kanban and dashboard open the same details', (tester) async {
      await _pump(tester);
      await tester.tap(_navItem(1));
      await tester.pumpAndSettle();
      await _tapIn(tester, _cards('kanban-').first);
      await _tapIn(tester, find.text('View Details'));
      expect(find.byKey(const Key('task-details')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openCategory(tester, 0);
      final focus = _cards('focus-');
      // The dashboard lists the employee's own tasks.
      expect(focus, findsNWidgets(3));
      await _tapIn(tester, focus.first);
      expect(find.byKey(const Key('task-details')), findsOneWidget);
    });
  });

  test('schedule keeps its figures in order and the time range together', () {
    final label = scheduleLabel(
      DateTime(2026, 11, 13, 7, 40),
      DateTime(2026, 11, 13, 12, 10),
    );
    expect(label, '\u20662026/11/13 07:40\u2060–\u206012:10\u2069');
    expect(
      scheduleLabel(DateTime(2026, 11, 13, 22), DateTime(2026, 11, 14, 1)),
      '\u20662026/11/13 22:00 – 2026/11/14 01:00\u2069',
    );
  });
}
