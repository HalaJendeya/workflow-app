import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/categories/presentation/employee_categories.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// Redmi 8 run 1 (2026-11-17): U1 — on More the + button covered the end
/// of the Appearance row; U2 — a non-lead's + offered only "Schedule
/// meeting" and "Join by Code", neither usable in API mode; U3 — the
/// Arabic date header used a Latin comma.

/// The shell reports its floating navigation surface (103 px) as bottom
/// padding; the More tab is laid out inside it.
const _shellPadding = EdgeInsets.only(bottom: 103);

void main() {
  Future<void> pumpMore(
    WidgetTester tester, {
    required bool demo,
    Set<int> led = const {},
    Locale locale = const Locale('en'),
    Size size = const Size(360, 740),
  }) async {
    useViewport(tester, size);
    await loadAppFonts();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              mode: demo ? AppMode.mock : AppMode.api,
              apiBaseUrl: demo ? '' : 'https://api.test',
            ),
          ),
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
          ledProjectIdsProvider.overrideWithValue(led),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: _shellPadding),
              child: const EmployeeCategoriesScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> createActions(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('create-fab')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const Key('create-sheet'));
    return [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: sheet, matching: find.byType(Text)),
      ))
        t.data!,
    ];
  }

  group('U2: employee + offers only usable actions', () {
    // Join by Code became usable for employees (GET …/meetings/by-code);
    // scheduling still has no employee route.
    testWidgets('API, not a lead: Join by Code only', (tester) async {
      await pumpMore(tester, demo: false);
      expect(await createActions(tester), ['Join by Code']);
    });

    testWidgets('API, lead: Add task and Join by Code', (tester) async {
      await pumpMore(tester, demo: false, led: {2});
      expect(await createActions(tester), ['Add Task', 'Join by Code']);
    });

    testWidgets('demo: every action, saved on the device', (tester) async {
      await pumpMore(tester, demo: true);
      expect(await createActions(tester), [
        'Add Task',
        'Schedule meeting',
        'Join by Code',
      ]);
    });
  });

  group('U1: the + button clears Preferences and Appearance', () {
    for (final (name, locale) in [
      ('LTR', const Locale('en')),
      ('RTL', const Locale('ar')),
    ]) {
      for (final size in [const Size(360, 740), const Size(320, 640)]) {
        // A regular employee has the + too (Join by Code only).
        for (final (role, led) in [
          ('lead', {2}),
          ('member', <int>{}),
        ]) {
          testWidgets('$name, $role at ${size.width.toInt()} px', (
            tester,
          ) async {
            await pumpMore(
              tester,
              demo: false,
              led: led,
              locale: locale,
              size: size,
            );
            // The page itself, not the horizontal section pills.
            final scrollable = find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.byKey(const Key('settings-appearance')),
              200,
              scrollable: scrollable,
            );
            // At the end of the page, where the last row sits lowest.
            await tester.drag(scrollable, const Offset(0, -2000));
            await tester.pumpAndSettle();
            final fab = tester.getRect(find.byKey(const Key('create-fab')));
            for (final key in ['settings-language', 'settings-appearance']) {
              final row = tester.getRect(find.byKey(Key(key)));
              expect(
                row.overlaps(fab),
                isFalse,
                reason: '$key $row is under the + button $fab',
              );
            }
          });
        }
      }
    }
  });

  testWidgets('U3: the Arabic date header uses the Arabic comma', (
    tester,
  ) async {
    useViewport(tester, const Size(390, 844));
    await loadAppFonts();
    final storage = InMemorySessionStorage();
    await storage.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 20,
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
        child: const WorkFlowApp(locale: Locale('ar')),
      ),
    );
    await tester.pumpAndSettle();
    final date = DateFormat.MMMMEEEEd('ar').format(DateTime.now());
    expect(date, contains('،'));
    expect(date, isNot(contains(',')));
    expect(find.text(date.toUpperCase()), findsOneWidget);
  });
}
