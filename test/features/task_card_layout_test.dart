import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// Task cards (Tasks list, Kanban, dashboard focus tasks): density at
/// 390×844, written to `$TASK_REPORT` when set, and layout checks in light,
/// dark, English and Arabic at the phone sizes — no overflow (fails the
/// test), every card's actions reachable, badges inside their card.

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
      final first = _cards('task-').first;
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      list.position.jumpTo(
        list.position.pixels + tester.getRect(first).top - 20,
      );
      await tester.pumpAndSettle();
      final (avg, whole) = _density(tester, 'task-');
      report.add('tasks_list\t${avg.round()}\t$whole');
      await screenshot(tester, 'task_list');
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

      testWidgets('Tasks list: $tag', (tester) async {
        await _pump(tester, size: size, scale: scale, prefs: prefs);
        await _openCategory(tester, 2);
        final cards = _cards('task-');
        expect(cards, findsWidgets);
        for (var i = 0; i < 2; i++) {
          final card = cards.at(i);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final box = tester.getRect(card);
          expect(box.width, lessThanOrEqualTo(size.width));
          for (final key in const ['action-edit', 'action-delete']) {
            final action = find.descendant(
              of: card,
              matching: find.byKey(Key(key)),
            );
            expect(
              action.hitTestable(),
              findsOneWidget,
              reason: '$key reachable',
            );
            final r = tester.getRect(action);
            expect(r.width, greaterThanOrEqualTo(40));
            expect(box.contains(r.center), isTrue);
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
      bool actions = true,
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
                  subtitle: 'P01-T04 · Sprint 3 · Customer Portal Revamp',
                  badge: const StatusBadge(
                    label: 'In Progress',
                    tone: BadgeTone.warning,
                  ),
                  meta: const [
                    TaskMeta(Icons.person_outline, 'Assignee', 'Lina Daoud'),
                    TaskMeta(
                      Icons.event_outlined,
                      'Schedule',
                      '2026/11/15 09:00–11:30',
                    ),
                    TaskMeta(Icons.timer_outlined, 'Duration', '2.5h'),
                    TaskMeta(Icons.flag_outlined, 'Priority', 'Urgent'),
                    TaskMeta(
                      Icons.payments_outlined,
                      'Amount',
                      r'$1,250.00',
                      strong: true,
                    ),
                  ],
                  onView: () => taps.add('view'),
                  onEdit: actions ? () => taps.add('edit') : null,
                  onDelete: actions ? () => taps.add('delete') : null,
                ),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('tap opens details; edit and delete keep their own actions', (
      tester,
    ) async {
      final taps = await pumpCard(tester);
      await tester.tap(
        find.text('P01-T04 · Sprint 3 · Customer Portal Revamp'),
      );
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.tap(find.byKey(const Key('action-delete')));
      expect(taps, ['view', 'edit', 'delete']);
    });

    testWidgets(
      'long content at 320 px and 130 % text: no overflow, all meta',
      (tester) async {
        await pumpCard(tester);
        for (final v in const ['Lina Daoud', '2.5h', 'Urgent', r'$1,250.00']) {
          expect(find.text(v), findsOneWidget);
        }
        // Metadata wraps instead of clipping; nothing is cut off to the side.
        final card = tester.getRect(find.byKey(const Key('card')));
        for (final e in find.byType(Text).evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          expect(r.right, lessThanOrEqualTo(card.right + 0.5));
          expect(r.left, greaterThanOrEqualTo(card.left - 0.5));
        }
      },
    );

    testWidgets('metadata is announced with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, scale: 1);
      // The card is one button; its announcement names every value.
      final label = tester
          .getSemantics(find.byKey(const Key('action-view')))
          .getSemanticsData()
          .label;
      expect(label, contains('Assignee: Lina Daoud'));
      expect(label, contains('Priority: Urgent'));
      handle.dispose();
    });

    testWidgets('without permissions no edit/delete is shown', (tester) async {
      await pumpCard(tester, actions: false);
      expect(find.byKey(const Key('action-edit')), findsNothing);
      expect(find.byKey(const Key('action-delete')), findsNothing);
    });

    testWidgets('Arabic: badge on the left, actions at the left end', (
      tester,
    ) async {
      await pumpCard(tester, locale: const Locale('ar'), width: 390, scale: 1);
      final card = tester.getRect(find.byKey(const Key('card')));
      final badge = tester.getRect(find.byType(StatusBadge));
      final delete = tester.getRect(find.byKey(const Key('action-delete')));
      expect(badge.left, lessThan(card.center.dx));
      expect(delete.left, lessThan(card.center.dx));
    });

    testWidgets('a card is about a third of the old stacked height', (
      tester,
    ) async {
      await pumpCard(tester, width: 390, scale: 1);
      expect(
        tester.getSize(find.byKey(const Key('card'))).height,
        lessThan(160),
      );
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
