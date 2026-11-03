import 'package:flutter/painting.dart';
import 'package:workflow_app/core/design_system/tokens.dart';

/// Text styles from the Figma file. `Mobile/*` styles are used inside the app,
/// `Desktop/*` styles by the auth frames (the file reuses them on mobile).
/// Line heights are expressed as ratios of the font size.
abstract final class AppTextStyles {
  static const family = 'Inter';

  static TextStyle _s(double size, FontWeight weight, double lineHeight) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: 0,
      );

  // Mobile scale.
  static final TextStyle mobile5xlBold = _s(28, FontWeight.w700, 39.2);
  static final TextStyle mobile2xlSemiBold = _s(20, FontWeight.w600, 28);
  static final TextStyle mobileXlSemiBold = _s(18, FontWeight.w600, 25.2);
  static final TextStyle mobileLgSemiBold = _s(16, FontWeight.w600, 22.4);
  static final TextStyle mobileBaseRegular = _s(14, FontWeight.w400, 19.6);
  static final TextStyle mobileBaseSemiBold = _s(14, FontWeight.w600, 19.6);
  static final TextStyle mobileXsRegular = _s(12, FontWeight.w400, 16.8);
  static final TextStyle mobileXsMedium = _s(12, FontWeight.w500, 16.8);
  static final TextStyle mobileXsSemiBold = _s(12, FontWeight.w600, 16.8);

  // Desktop scale reused by auth frames.
  static final TextStyle authTitle = _s(28, FontWeight.w700, 36);
  static final TextStyle accountTypeTitle = _s(31, FontWeight.w700, 46.5);
  static final TextStyle choiceTitle = _s(22, FontWeight.w700, 33);
  static final TextStyle desktopLgBold = _s(20, FontWeight.w700, 30);
  static final TextStyle desktopBaseBold = _s(16, FontWeight.w700, 24);
  static final TextStyle desktopBaseMedium = _s(16, FontWeight.w500, 24);
  static final TextStyle desktopBaseRegular = _s(16, FontWeight.w400, 24);
  static final TextStyle desktopXsMedium = _s(13, FontWeight.w500, 19.5);
  static final TextStyle desktopXsRegular = _s(13, FontWeight.w400, 19.5);
  static final TextStyle desktopXsSemiBold = _s(13, FontWeight.w600, 19.5);

  static final TextStyle link = desktopXsMedium.copyWith(
    color: AppColors.primary,
  );
}
