import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// One complete set of WorkFlow colours. [light] holds the Figma variables
/// (`saas-project-managment`, page "mobile ui client" 534:30389 and the
/// mobile auth frames); [dark] is the same roles on dark surfaces with the
/// brand blue kept recognisable and text contrast ≥ 4.5:1.
class AppPalette {
  const new({
    required this.brightness,
    required this.primary,
    required this.primaryStrong,
    required this.primary50,
    required this.checkboxFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.ink,
    required this.neutral900,
    required this.surface,
    required this.surfaceSubtle,
    required this.borderSubtle,
    required this.borderDefault,
    required this.authCardBorder,
    required this.authBackground,
    required this.appBackground,
    required this.pageContent,
    required this.statusInfo,
    required this.statusInfoBackground,
    required this.navShadow,
    required this.successBg,
    required this.successFg,
    required this.warningBg,
    required this.warningFg,
    required this.dangerBg,
    required this.dangerFg,
    required this.selectedChipBorder,
    required this.chipBorder,
    required this.muted,
    required this.sectionDivider,
    required this.pillBorder,
    required this.activePill,
    required this.activePillCount,
    required this.tintTeal,
    required this.tintPurple,
    required this.chartMuted,
    required this.chartTrack,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryStrong;
  final Color primary50;
  final Color checkboxFill;
  final Color textPrimary;
  final Color textSecondary;
  final Color ink;
  final Color neutral900;
  final Color surface;
  final Color surfaceSubtle;
  final Color borderSubtle;
  final Color borderDefault;
  final Color authCardBorder;
  final Color authBackground;
  final Color appBackground;
  final Color pageContent;
  final Color statusInfo;
  final Color statusInfoBackground;
  final Color navShadow;
  final Color successBg;
  final Color successFg;
  final Color warningBg;
  final Color warningFg;
  final Color dangerBg;
  final Color dangerFg;
  final Color selectedChipBorder;
  final Color chipBorder;
  final Color muted;
  final Color sectionDivider;
  final Color pillBorder;
  final Color activePill;
  final Color activePillCount;
  final Color tintTeal;
  final Color tintPurple;
  final Color chartMuted;
  final Color chartTrack;

  static const light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF0170FD),
    primaryStrong: Color(0xFF086FE8),
    primary50: Color(0xFFE6F1FF),
    checkboxFill: Color(0xFFE9F9FB),
    textPrimary: Color(0xFF424242),
    textSecondary: Color(0xFF707070),
    ink: Color(0xFF000000),
    neutral900: Color(0xFF18232F),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF5F5F5),
    borderSubtle: Color(0xFFE1E1E1),
    borderDefault: Color(0xFFD2D2D2),
    authCardBorder: Color(0x80E1E1E1),
    authBackground: Color(0xFFFBFBFB),
    appBackground: Color(0xFFF7F7F7),
    pageContent: Color(0xFFFAFAFA),
    statusInfo: Color(0xFF0278AD),
    statusInfoBackground: Color(0xFFE6F6FE),
    navShadow: Color(0x0A18232F),
    successBg: Color(0xFFEDF7EE),
    successFg: Color(0xFF367C39),
    warningBg: Color(0xFFFFFDEB),
    warningFg: Color(0xFF8C8120),
    dangerBg: Color(0xFFFEECEB),
    dangerFg: Color(0xFFAD3026),
    selectedChipBorder: Color(0xFFB0D3FE),
    chipBorder: Color(0xB3E1E1E1),
    muted: Color(0xFF9E9E9E),
    sectionDivider: Color(0xFFF1F5F9),
    pillBorder: Color(0xCCE2E8F0),
    activePill: Color(0xFF0166E6),
    activePillCount: Color(0xFF559FFE),
    tintTeal: Color(0xFFF0FDFA),
    tintPurple: Color(0xFFFAF5FF),
    chartMuted: Color(0xFFCBD5E1),
    chartTrack: Color(0xFFE2E8F0),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF2F7DF2),
    primaryStrong: Color(0xFF2870DC),
    primary50: Color(0xFF14273F),
    checkboxFill: Color(0xFF13302E),
    textPrimary: Color(0xFFE4E7EB),
    textSecondary: Color(0xFFA0A8B3),
    ink: Color(0xFFF4F6F8),
    neutral900: Color(0xFFF1F4F7),
    surface: Color(0xFF181D24),
    surfaceSubtle: Color(0xFF20262E),
    borderSubtle: Color(0xFF2C333C),
    borderDefault: Color(0xFF3A424C),
    authCardBorder: Color(0xFF2C333C),
    authBackground: Color(0xFF0F1318),
    appBackground: Color(0xFF0F1318),
    pageContent: Color(0xFF12161C),
    statusInfo: Color(0xFF6CC3EE),
    statusInfoBackground: Color(0xFF102C3A),
    navShadow: Color(0x66000000),
    successBg: Color(0xFF143220),
    successFg: Color(0xFF7BD389),
    warningBg: Color(0xFF332F12),
    warningFg: Color(0xFFE6D66A),
    dangerBg: Color(0xFF3B1916),
    dangerFg: Color(0xFFFF8F84),
    selectedChipBorder: Color(0xFF2E5C9C),
    chipBorder: Color(0xFF2C333C),
    muted: Color(0xFF8C949E),
    sectionDivider: Color(0xFF252C35),
    pillBorder: Color(0xFF323A44),
    activePill: Color(0xFF2870DC),
    activePillCount: Color(0xFF7DB3FF),
    tintTeal: Color(0xFF10302C),
    tintPurple: Color(0xFF261C36),
    chartMuted: Color(0xFF4A5462),
    chartTrack: Color(0xFF2C333C),
  );
}

/// WorkFlow colour roles, read from the active [AppPalette]. Names mirror
/// the Figma variables. The app switches the palette with [use] and then
/// rebuilds every widget (see `ThemeSwitch`), so widgets read these as
/// they always have — but no longer as compile-time constants.
abstract final class AppColors {
  static AppPalette _p = AppPalette.light;

  static AppPalette get palette => _p;
  static Brightness get brightness => _p.brightness;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Makes [brightness] the active palette. Returns whether it changed.
  static bool use(Brightness brightness) {
    final next = brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    if (identical(next, _p)) return false;
    _p = next;
    return true;
  }

  /// `action/primary`
  static Color get primary => _p.primary;

  /// `background cat` — filled choice cards and some primary actions.
  static Color get primaryStrong => _p.primaryStrong;

  /// `color/primary/50` — tinted backgrounds.
  static Color get primary50 => _p.primary50;

  /// `Foundation/primary/primary-50` — checkbox fill.
  static Color get checkboxFill => _p.checkboxFill;

  /// `text/primary`
  static Color get textPrimary => _p.textPrimary;

  /// `text/secondary` and `text/placeholder`
  static Color get textSecondary => _p.textSecondary;

  /// Strongest text (Figma's pure black titles).
  static Color get ink => _p.ink;

  /// `color/neutral/900` — card titles.
  static Color get neutral900 => _p.neutral900;

  /// `surface/default`: cards, fields, sheets, navigation.
  static Color get surface => _p.surface;

  /// `text/inverse`: text and icons on the brand blue or a dark room. Never
  /// a background — use [surface].
  static const white = Color(0xFFFFFFFF);

  /// `surface/subtle` and `Foundation/gradescale/gradescale-50`
  static Color get surfaceSubtle => _p.surfaceSubtle;

  /// `text/border/subtle`
  static Color get borderSubtle => _p.borderSubtle;

  /// `text/border/default`
  static Color get borderDefault => _p.borderDefault;

  /// Auth card stroke.
  static Color get authCardBorder => _p.authCardBorder;

  /// `Color/backgrondlogin` as used by auth frames.
  static Color get authBackground => _p.authBackground;

  /// `Color/backgrondlogin` as used by app frames.
  static Color get appBackground => _p.appBackground;

  /// Page content area under the masthead.
  static Color get pageContent => _p.pageContent;

  /// `status/info`, `status/info-background`
  static Color get statusInfo => _p.statusInfo;
  static Color get statusInfoBackground => _p.statusInfoBackground;

  static Color get navShadow => _p.navShadow;
}

abstract final class AppRadii {
  static const pill = 100.0;

  /// `12 RC` — buttons, choice cards, nav touch targets.
  static const button = 12.0;
  static const input = 16.0;
  static const authCard = 16.0;
  static const card = 20.0;
  static const masthead = 28.0;
  static const navSurface = 28.0;
}

/// 4-pt spacing scale (`grid 16` = [md]).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page gutter used by mobile app frames.
  static const double page = 20;
}
