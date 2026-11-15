import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/tokens.dart';
import 'package:workflow_app/core/design_system/typography.dart';

export 'tokens.dart';
export 'typography.dart';

/// Material themes built from the two [AppPalette]s, so stock widgets
/// (dialogs, sheets, menus, fields, snack bars, date pickers) match the
/// custom ones in either brightness.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final dark = p.brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: AppColors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.surfaceSubtle,
      surfaceContainerHigh: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerLow: p.surface,
      outline: p.borderDefault,
      outlineVariant: p.borderSubtle,
      error: p.dangerFg,
    );
    const sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.navSurface),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: AppTextStyles.family,
      scaffoldBackgroundColor: p.appBackground,
      canvasColor: p.surface,
      cardColor: p.surface,
      dividerColor: p.borderSubtle,
      splashFactory: InkRipple.splashFactory,
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // A light bar on dark pages: the default inverse surface.
        backgroundColor: dark ? p.textPrimary : null,
        contentTextStyle: dark
            ? TextStyle(
                color: p.appBackground,
                fontFamily: AppTextStyles.family,
              )
            : null,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.borderDefault,
        shape: sheetShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.mobileLgSemiBold.copyWith(
          color: p.neutral900,
        ),
        contentTextStyle: AppTextStyles.mobileBaseRegular.copyWith(
          color: p.textPrimary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBackground,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }
}
