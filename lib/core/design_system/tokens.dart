import 'package:flutter/painting.dart';

/// WorkFlow design tokens, taken from the Figma file's variables
/// (`saas-project-managment`, page "mobile ui client" 534:30389 and the
/// mobile auth frames). Names mirror the Figma variable names.
abstract final class AppColors {
  /// `action/primary`
  static const primary = Color(0xFF0170FD);

  /// `background cat` — filled choice cards and some primary actions.
  static const primaryStrong = Color(0xFF086FE8);

  /// `color/primary/50` — success symbol background.
  static const primary50 = Color(0xFFE6F1FF);

  /// `Foundation/primary/primary-50` — checkbox fill.
  static const checkboxFill = Color(0xFFE9F9FB);

  /// `text/primary`
  static const textPrimary = Color(0xFF424242);

  /// `text/secondary` and `text/placeholder`
  static const textSecondary = Color(0xFF707070);

  /// `text/inverse`, `white`, `surface/default`
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  /// `color/neutral/900` — card titles.
  static const neutral900 = Color(0xFF18232F);

  /// `surface/subtle` and `Foundation/gradescale/gradescale-50`
  static const surfaceSubtle = Color(0xFFF5F5F5);

  /// `text/border/subtle` (#E1E1E1, 70 % in the variable).
  static const borderSubtle = Color(0xFFE1E1E1);

  /// `text/border/default`
  static const borderDefault = Color(0xFFD2D2D2);

  /// Auth card stroke: rgba(225, 225, 225, 0.5).
  static const authCardBorder = Color(0x80E1E1E1);

  /// `Color/backgrondlogin` as used by auth frames.
  static const authBackground = Color(0xFFFBFBFB);

  /// `Color/backgrondlogin` as used by app frames.
  static const appBackground = Color(0xFFF7F7F7);

  /// Page content area under the masthead.
  static const pageContent = Color(0xFFFAFAFA);

  /// `status/info`, `status/info-background`
  static const statusInfo = Color(0xFF0278AD);
  static const statusInfoBackground = Color(0xFFE6F6FE);

  static const navShadow = Color(0x0A18232F);
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
