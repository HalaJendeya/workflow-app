import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/tokens.dart';
import 'package:workflow_app/core/design_system/typography.dart';

export 'tokens.dart';
export 'typography.dart';

/// Light theme built from the Figma tokens. The Figma file defines a dark
/// mode only for desktop auth frames, so the app ships light-only for now.
abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.textPrimary,
      outline: AppColors.borderDefault,
      outlineVariant: AppColors.borderSubtle,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTextStyles.family,
      scaffoldBackgroundColor: AppColors.appBackground,
      splashFactory: InkRipple.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.navSurface),
          ),
        ),
      ),
    );
  }
}
