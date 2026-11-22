import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/config/app_config.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/storage/session_storage.dart';
import 'package:workflow_app/features/categories/presentation/client_categories.dart';
import 'package:workflow_app/features/categories/presentation/employee_categories.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// Regression tests for the Redmi 8 R1–R4 findings
/// (docs/redmi8-r1-r4-qa-report.md): F3 calendar weekday labels, F4
/// dark-mode icon contrast, F5 RTL chevrons in Preferences.

const _locales = [Locale('en'), Locale('ar')];
const _widths = [320.0, 360.0];
const _scales = [1.0, 1.3];

void _setUp(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  bool dark = false,
}) {
  useViewport(tester, Size(width, 760));
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  AppColors.use(dark ? Brightness.dark : Brightness.light);
  addTearDown(() => AppColors.use(Brightness.light));
}

Widget _app(Widget home, {required Locale locale, bool dark = false}) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(mode: AppMode.mock, apiBaseUrl: ''),
        ),
        sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
      ],
      child: MaterialApp(
        locale: locale,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

/// WCAG relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final (hi, lo) = (lum(a), lum(b));
  return (math.max(hi, lo) + 0.05) / (math.min(hi, lo) + 0.05);
}

/// The colour an SVG under [finder] is painted with (`null` = Figma's own).
Color? _paint(WidgetTester tester, Finder finder) {
  final picture = tester.widget<SvgPicture>(
    find.descendant(of: finder, matching: find.byType(SvgPicture)).first,
  );
  final filter = picture.colorFilter;
  if (filter == null) return null;
  // ColorFilter.mode(color, srcIn) — compare through an equal filter.
  for (final c in [
    AppColors.textPrimary,
    AppColors.textSecondary,
    AppColors.white,
    AppColors.primary,
  ]) {
    if (filter == ColorFilter.mode(c, BlendMode.srcIn)) return c;
  }
  fail('Unexpected colour filter $filter');
}

void main() {
  group('F3 meetings calendar weekday labels', () {
    for (final locale in _locales) {
      for (final width in _widths) {
        for (final scale in _scales) {
          for (final dark in [false, true]) {
            final name =
                '${locale.languageCode} ${width.toInt()} dp × $scale'
                '${dark ? ' dark' : ''}';
            testWidgets('labels fit their column on one line: $name', (
              tester,
            ) async {
              _setUp(tester, width: width, scale: scale, dark: dark);
              await loadAppFonts();
              await tester.pumpWidget(
                _app(
                  Scaffold(
                    body: Padding(
                      // The calendar card's 20 px gutter + 16 px padding.
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: MeetingMonthCalendar(
                        month: DateTime(2026, 11),
                        selected: DateTime(2026, 11, 22),
                        marked: const {5, 22},
                        onMonth: (_) {},
                        onDay: (_) {},
                      ),
                    ),
                  ),
                  locale: locale,
                  dark: dark,
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);

              final column = (width - 72) / 7;
              final labels = <String>[];
              for (var i = 0; i < 7; i++) {
                final f = find.byKey(Key('cal-weekday-$i'));
                final text = tester.widget<Text>(f);
                labels.add(text.data!);
                expect(text.maxLines, 1);
                final paragraph = tester.renderObject<RenderParagraph>(f);
                expect(paragraph.didExceedMaxLines, isFalse);
                // Drawn inside its 1/7 column (after any scale-down).
                expect(
                  tester.getRect(f).width,
                  lessThanOrEqualTo(column + 0.01),
                  reason: '"${text.data}" is wider than its column',
                );
              }
              expect(labels.toSet(), hasLength(7));
              if (locale.languageCode == 'ar') {
                // Narrow forms: no clipped "الخمي" / "الجمع".
                for (final l in labels) {
                  expect(l.characters.length, lessThanOrEqualTo(2), reason: l);
                }
                // Short enough to stay at full size (no shrinking).
                for (var i = 0; i < 7; i++) {
                  final f = find.byKey(Key('cal-weekday-$i'));
                  expect(
                    tester.getRect(f).width,
                    closeTo(tester.getSize(f).width, 0.01),
                  );
                }
                // The month heading uses the same Western digits as the days.
                expect(find.textContaining('2026'), findsOneWidget);
                expect(find.textContaining('٢٠٢٦'), findsNothing);
              } else {
                expect(labels.first, 'Sun');
              }
              // Screen readers still hear the full day name.
              expect(
                find.bySemanticsLabel(
                  locale.languageCode == 'ar' ? 'الخميس' : 'Thursday',
                ),
                findsOneWidget,
              );
            });
          }
        }
      }
    }
  });

  group('F4 dark-mode icon contrast', () {
    test('neutral icons keep Figma colours in light mode', () {
      AppColors.use(Brightness.light);
      for (final icon in AppIcon.values) {
        expect(icon.defaultTint, isNull, reason: icon.name);
      }
    });

    test('neutral icons follow the theme in dark mode', () {
      AppColors.use(Brightness.dark);
      addTearDown(() => AppColors.use(Brightness.light));
      for (final icon in [
        AppIcon.notification,
        AppIcon.search,
        AppIcon.profile,
        AppIcon.message,
      ]) {
        expect(icon.defaultTint, AppColors.textPrimary, reason: icon.name);
      }
      expect(AppIcon.lock.defaultTint, AppColors.textSecondary);
      expect(AppIcon.hide.defaultTint, AppColors.textSecondary);
      // Brand-coloured and navigation icons are left alone.
      expect(AppIcon.sliders.defaultTint, isNull);
      expect(AppIcon.navMore.defaultTint, isNull);
      // Legible on every dark surface they sit on (WCAG 3:1 for icons).
      for (final bg in [
        AppColors.surface,
        AppColors.appBackground,
        AppColors.surfaceSubtle,
      ]) {
        expect(_contrast(AppColors.iconStrongTint!, bg), greaterThan(4.5));
        expect(_contrast(AppColors.iconMutedTint!, bg), greaterThan(4.5));
      }
    });

    for (final (portal, screen, grey, blue) in [
      (
        'client',
        const ClientCategoriesScreen(),
        ['cat_item_companies', 'cat_item_invoices', 'cat_item_payments'],
        <String>[],
      ),
      (
        'employee',
        const EmployeeCategoriesScreen(),
        ['cat_item_projects', 'nav_tasks'],
        ['nav_sprints', 'metric_ts_2'],
      ),
    ]) {
      for (final dark in [false, true]) {
        for (final locale in _locales) {
          testWidgets('$portal More: header, search, tiles and account sheet '
              '(${dark ? 'dark' : 'light'}, ${locale.languageCode})', (
            tester,
          ) async {
            _setUp(tester, width: 360, dark: dark);
            await tester.pumpWidget(_app(screen, locale: locale, dark: dark));
            await tester.pumpAndSettle();

            final strong = dark ? AppColors.textPrimary : null;
            final muted = dark ? AppColors.textSecondary : null;
            for (final icon in [AppIcon.notification, AppIcon.search]) {
              final found = find.byWidgetPredicate(
                (w) => w is SvgIcon && w.icon == icon,
              );
              expect(found, findsWidgets, reason: icon.name);
              expect(_paint(tester, found.first), strong, reason: icon.name);
            }
            for (final name in grey) {
              final f = find.byKey(Key('cat-item-icon-$name'));
              await tester.ensureVisible(f);
              expect(_paint(tester, f), muted, reason: name);
            }
            for (final name in blue) {
              final f = find.byKey(Key('cat-item-icon-$name'));
              await tester.ensureVisible(f);
              expect(_paint(tester, f), isNull, reason: name);
            }

            // Account sheet → "Profile Details".
            await tester.tap(find.byKey(const Key('account-menu')).first);
            await tester.pumpAndSettle();
            expect(
              _paint(tester, find.byKey(const Key('account-profile'))),
              strong,
            );
          });
        }
      }
    }
  });

  group('F5 Preferences chevrons', () {
    for (final locale in _locales) {
      for (final width in _widths) {
        for (final scale in _scales) {
          testWidgets('point to the reading end: ${locale.languageCode} '
              '${width.toInt()} dp × $scale', (tester) async {
            _setUp(tester, width: width, scale: scale);
            await tester.pumpWidget(
              _app(const ClientCategoriesScreen(), locale: locale),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final chevrons = find.byKey(const Key('settings-row-chevron'));
            await tester.ensureVisible(chevrons.first);
            expect(chevrons, findsNWidgets(2)); // Language, Appearance.
            final rtl = locale.languageCode == 'ar';
            for (final e in chevrons.evaluate()) {
              final icon = e.widget as Icon;
              // chevron_right mirrors itself in RTL; nothing else may
              // flip it again.
              expect(icon.icon, Icons.chevron_right);
              expect(icon.icon!.matchTextDirection, isTrue);
              expect(
                Directionality.of(e),
                rtl ? TextDirection.rtl : TextDirection.ltr,
              );
            }
            // Drawn mirrored exactly once in RTL (pointing left, like the
            // category rows), never in LTR.
            for (var i = 0; i < 2; i++) {
              expect(
                find.descendant(
                  of: chevrons.at(i),
                  matching: find.byType(Transform),
                ),
                rtl ? findsOneWidget : findsNothing,
              );
            }
          });
        }
      }
    }
  });
}
