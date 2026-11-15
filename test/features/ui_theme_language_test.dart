import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/app.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/preferences/app_preferences.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/shell/app_shell.dart';

import '../helpers/viewport.dart';

/// The main Client and Employee screens in dark mode, in Arabic (RTL) and
/// in both, at 320×640 with 130 % text and at 390×844: no overflow (a
/// layout overflow fails the test), the right brightness and direction.
/// With `SCREENSHOT_DIR` set it writes one PNG per screen and mode.

enum _Mode { dark, arabic, darkArabic }

AppPreferences _prefs(_Mode m) => switch (m) {
  _Mode.dark => const AppPreferences(appearance: AppearancePreference.dark),
  _Mode.arabic => const AppPreferences(language: LanguagePreference.arabic),
  _Mode.darkArabic => const AppPreferences(
    language: LanguagePreference.arabic,
    appearance: AppearancePreference.dark,
  ),
};

Future<void> _pump(
  WidgetTester tester, {
  required _Mode mode,
  Portal? portal,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  useViewport(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await loadAppFonts();
  final storage = InMemorySessionStorage();
  if (portal != null) {
    await storage.writeAll(
      Session(
        token: 't',
        tokenType: 'Bearer',
        userId: 10,
        portal: portal,
      ).toStorage(),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        initialPreferencesProvider.overrideWithValue(_prefs(mode)),
      ],
      child: const WorkFlowApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens a tab by its position (labels differ per language), or a More
/// category by its index in the More list.
Future<void> _tab(WidgetTester tester, int index) async {
  final nav = find.byType(WfNavigationSurface);
  final items = find.descendant(of: nav, matching: find.byType(InkResponse));
  await tester.tap(items.at(index));
  await tester.pumpAndSettle();
}

void _expectMode(WidgetTester tester, _Mode mode) {
  final ctx = tester.element(find.byType(Scaffold).first);
  final dark = mode != _Mode.arabic;
  expect(Theme.of(ctx).brightness, dark ? Brightness.dark : Brightness.light);
  expect(AppColors.isDark, dark);
  expect(
    Directionality.of(ctx),
    mode == _Mode.dark ? TextDirection.ltr : TextDirection.rtl,
  );
}

void main() {
  for (final mode in _Mode.values) {
    group(mode.name, () {
      testWidgets('account type and login', (tester) async {
        await _pump(tester, mode: mode);
        _expectMode(tester, mode);
        await screenshot(tester, '${mode.name}_account_type');
        await tester.tap(find.byKey(const Key('portal-client')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(WfPrimaryButton));
        await tester.pumpAndSettle();
        await screenshot(tester, '${mode.name}_login');
      });

      for (final portal in Portal.values) {
        testWidgets('${portal.name} tabs', (tester) async {
          await _pump(tester, mode: mode, portal: portal);
          _expectMode(tester, mode);
          for (var i = 0; i < 5; i++) {
            await _tab(tester, i);
            await screenshot(tester, '${mode.name}_${portal.name}_tab$i');
          }
        });
      }

      // Every tab of both portals at each size: an overflow fails here.
      for (final (size, scale) in const [
        (Size(320, 640), 1.3),
        (Size(360, 800), 1.0),
        (Size(390, 844), 1.3),
        (Size(768, 1024), 1.0),
      ]) {
        for (final portal in Portal.values) {
          testWidgets(
            '${portal.name} at ${size.width.toInt()}x${size.height.toInt()} '
            'text x$scale',
            (tester) async {
              await _pump(
                tester,
                mode: mode,
                portal: portal,
                size: size,
                scale: scale,
              );
              for (var i = 0; i < 5; i++) {
                await _tab(tester, i);
              }
            },
          );
        }
      }
    });
  }
}
