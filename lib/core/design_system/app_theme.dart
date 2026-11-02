import 'package:flutter/material.dart';

/// Single entry point for theming. Screens read colors, type and spacing from
/// `Theme.of(context)` and [AppSpacing] only — never hardcoded values — so the
/// WorkFlow brand tokens can be dropped in here once they are extracted from
/// the Figma file (currently inaccessible; see the backend/design gap report).
///
/// Until then this is deliberately the neutral Material 3 baseline, not an
/// invented brand.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
  );
}

/// Spacing scale placeholder (4-pt grid) pending Figma tokens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
