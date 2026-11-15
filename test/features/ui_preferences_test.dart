import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';

import '../helpers/viewport.dart';

/// Language and appearance preferences: defaults, following the device,
/// manual overrides from sign-in and from More, persistence across a
/// restart and a sign-out, and the compact statistics layout.

Future<InMemoryPreferencesStore> _pump(
  WidgetTester tester, {
  InMemoryPreferencesStore? store,
  bool signedIn = false,
  Size size = const Size(390, 844),
}) async {
  useViewport(tester, size);
  await loadAppFonts();
  final prefs = store ?? InMemoryPreferencesStore();
  final session = InMemorySessionStorage();
  if (signedIn) {
    await session.writeAll(
      const Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 10,
        portal: Portal.client,
      ).toStorage(),
    );
  }
  // As main() does: what was stored is read before the first frame.
  final initial = await loadPreferences(prefs);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
        ),
        sessionStorageProvider.overrideWithValue(session),
        preferencesStoreProvider.overrideWithValue(prefs),
        initialPreferencesProvider.overrideWithValue(initial),
      ],
      child: const WorkFlowApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void _device(WidgetTester tester, List<Locale> locales) {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Future<void> _pick(WidgetTester tester, String chip, String option) async {
  await tester.tap(find.byKey(Key(chip)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('option-$option')));
  await tester.pumpAndSettle();
}

void main() {
  group('preferences model', () {
    test('defaults follow the device', () {
      const p = AppPreferences();
      expect(p.language, LanguagePreference.system);
      expect(p.appearance, AppearancePreference.system);
      expect(p.locale, isNull);
      expect(p.themeMode, ThemeMode.system);
      expect(p.brightness(Brightness.dark), Brightness.dark);
    });

    test('stored values are read back; unknown values fall back', () {
      final p = AppPreferences.fromStorage(const {
        'language': 'arabic',
        'appearance': 'dark',
      });
      expect(p.locale, const Locale('ar'));
      expect(p.brightness(Brightness.light), Brightness.dark);
      expect(
        AppPreferences.fromStorage(const {'language': 'klingon'}),
        const AppPreferences(),
      );
    });

    test('unsupported device languages fall back to English', () {
      const supported = [Locale('ar'), Locale('en')];
      expect(
        resolveLocale([const Locale('fr')], supported),
        const Locale('en'),
      );
      expect(resolveLocale(null, supported), const Locale('en'));
      expect(
        resolveLocale([
          const Locale('fr'),
          const Locale('ar', 'EG'),
        ], supported),
        const Locale('ar'),
      );
    });

    test('a broken store never blocks launch', () async {
      expect(await loadPreferences(_BrokenStore()), const AppPreferences());
    });
  });

  group('following the device', () {
    testWidgets('first launch uses the device language (RTL for Arabic)', (
      tester,
    ) async {
      _device(tester, const [Locale('ar', 'SA')]);
      await _pump(tester);
      expect(_direction(tester), TextDirection.rtl);
    });

    testWidgets('an unsupported device language shows English', (tester) async {
      _device(tester, const [Locale('fr', 'FR')]);
      await _pump(tester);
      expect(_direction(tester), TextDirection.ltr);
      expect(find.text('Account Type'), findsOneWidget);
    });

    testWidgets('System appearance tracks the device switching dark', (
      tester,
    ) async {
      await _pump(tester);
      expect(_brightness(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(_brightness(tester), Brightness.dark);
      expect(AppColors.isDark, isTrue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(AppColors.isDark, isFalse);
    });

    testWidgets('a device language change applies while System', (
      tester,
    ) async {
      _device(tester, const [Locale('en')]);
      await _pump(tester);
      expect(_direction(tester), TextDirection.ltr);
      tester.platformDispatcher.localesTestValue = const [Locale('ar')];
      await tester.pumpAndSettle();
      expect(_direction(tester), TextDirection.rtl);
    });
  });

  group('overrides before sign-in', () {
    testWidgets('Arabic applies at once, keeps typed input, persists', (
      tester,
    ) async {
      _device(tester, const [Locale('en')]);
      final store = await _pump(tester);
      await tester.tap(find.byKey(const Key('portal-client')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'qa@example.test',
      );
      await _pick(tester, 'pref-language', 'arabic');
      expect(_direction(tester), TextDirection.rtl);
      // Still on the login form, with what was typed.
      expect(find.text('qa@example.test'), findsOneWidget);
      expect(store.values['language'], 'arabic');

      // Restart: the choice is read back before the first frame.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, store: store);
      expect(_direction(tester), TextDirection.rtl);
    });

    testWidgets('Dark applies at once and overrides a light device', (
      tester,
    ) async {
      final store = await _pump(tester);
      await _pick(tester, 'pref-appearance', 'dark');
      expect(_brightness(tester), Brightness.dark);
      expect(store.values['appearance'], 'dark');
      // The device changing does not undo an explicit choice.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(_brightness(tester), Brightness.dark);
      await _pick(tester, 'pref-appearance', 'system');
      expect(_brightness(tester), Brightness.light);
    });
  });

  group('Settings in More', () {
    testWidgets('appearance and language from More; kept after sign-out', (
      tester,
    ) async {
      _device(tester, const [Locale('en')]);
      final store = await _pump(tester, signedIn: true);
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('preferences-card'));
      // The card ends the page: at the end it sits clear of the navigation.
      final list = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((s) => s.position.axis == Axis.vertical);
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('option-dark')));
      await tester.pumpAndSettle();
      expect(_brightness(tester), Brightness.dark);
      // Still on More: the change rebuilt the screen without leaving it.
      expect(card, findsOneWidget);

      list.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-menu')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      // Signed out, still dark: preferences are not part of the session.
      expect(find.byKey(const Key('portal-client')), findsOneWidget);
      expect(_brightness(tester), Brightness.dark);
      expect(store.values['appearance'], 'dark');
    });
  });

  group('compact statistics', () {
    Future<void> pumpGroup(
      WidgetTester tester,
      List<Metric> metrics, {
      double width = 390,
      double scale = 1,
    }) async {
      useViewport(tester, Size(width, 400));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: MetricGroup(metrics: metrics),
            ),
          ),
        ),
      );
    }

    int rows(WidgetTester tester) =>
        tester.widgetList<Table>(find.byType(Table)).length;
    int cellsIn(WidgetTester tester, int row) => tester
        .widgetList<Table>(find.byType(Table))
        .elementAt(row)
        .children
        .single
        .children
        .length;

    testWidgets('three short figures share one row', (tester) async {
      await pumpGroup(tester, const [
        Metric(label: 'Total', value: '12'),
        Metric(label: 'Paid', value: '8'),
        Metric(label: 'Overdue', value: '1'),
      ]);
      expect(rows(tester), 1);
      expect(cellsIn(tester, 0), 3);
    });

    testWidgets('long sums get half the width each', (tester) async {
      await pumpGroup(tester, const [
        Metric(label: 'Received', value: r'$9,876,543,210.75'),
        Metric(label: 'Pending', value: r'$1,234.00'),
        Metric(label: 'Count', value: '42'),
      ]);
      expect(rows(tester), 2);
      expect(cellsIn(tester, 0), 2);
      expect(cellsIn(tester, 1), 1, reason: 'odd last cell spans the row');
    });

    testWidgets('narrow phone with large text drops to two per row', (
      tester,
    ) async {
      await pumpGroup(
        tester,
        const [
          Metric(label: 'Total', value: '12'),
          Metric(label: 'Paid', value: '8'),
          Metric(label: 'Overdue', value: '1'),
        ],
        width: 320,
        scale: 1.3,
      );
      expect(cellsIn(tester, 0), 2);
    });

    testWidgets('no comparison badge without data; loading shows a dash', (
      tester,
    ) async {
      await pumpGroup(tester, const [
        Metric(label: 'Total', value: '—', delta: '—'),
        Metric(label: 'Paid', value: '3', delta: '+8% vs last month'),
      ]);
      expect(find.text('—'), findsOneWidget, reason: 'the value only');
      expect(find.text('0'), findsNothing);
      expect(find.text('+8% vs last month'), findsOneWidget);
    });
  });
}

class _BrokenStore implements PreferencesStore {
  @override
  Future<Map<String, String>> read() => Future.error(StateError('locked'));

  @override
  Future<void> write(String key, String value) async {}
}
