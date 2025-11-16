import 'package:flutter/material.dart';

import 'app_design_system.dart';

extension ResponsiveContext on BuildContext {
  /// Screen dimensions
  double get screenWidth => AppDesignSystem.getScreenWidth(this);
  double get screenHeight => AppDesignSystem.getScreenHeight(this);

  /// Screen category helpers
  ScreenCategory get screenCategory => AppDesignSystem.getScreenCategory(this);
  bool get isSmallPhone =>
      screenCategory == ScreenCategory.smallPhone;
  bool get isPhone =>
      screenCategory == ScreenCategory.smallPhone ||
      screenCategory == ScreenCategory.phone;
  bool get isTablet => screenCategory == ScreenCategory.tablet;
  bool get isDesktop => screenCategory == ScreenCategory.desktop;

  /// Orientation helpers
  bool get isLandscape => AppDesignSystem.isLandscape(this);
  bool get isPortrait => !isLandscape;

  /// Responsive spacing & padding
  EdgeInsets get screenPadding => AppDesignSystem.getScreenPadding(this);
  EdgeInsets get cardPadding => AppDesignSystem.getCardPadding(this);
  EdgeInsets get inputPadding => AppDesignSystem.getInputPadding(this);
  EdgeInsets get numericInputPadding =>
      AppDesignSystem.getNumericInputPadding(this);
  BoxConstraints get numericInputConstraints =>
      AppDesignSystem.getNumericInputConstraints(this);

  double get sectionSpacing => AppDesignSystem.getSectionSpacing(this);
  double get elementSpacing => AppDesignSystem.getElementSpacing(this);

  /// Convenience wrappers for custom responsive values
  double responsiveFontSize({
    double xs = 12,
    double sm = 14,
    double md = 16,
    double lg = 18,
  }) {
    return AppDesignSystem.getResponsiveFontSize(
      this,
      xs: xs,
      sm: sm,
      md: md,
      lg: lg,
    );
  }

  double responsiveSpacing({
    double xs = AppDesignSystem.spaceSM,
    double sm = AppDesignSystem.spaceMD,
    double md = AppDesignSystem.spaceLG,
    double lg = AppDesignSystem.spaceXL,
  }) {
    return AppDesignSystem.getResponsiveSpacing(
      this,
      xs: xs,
      sm: sm,
      md: md,
      lg: lg,
    );
  }

  EdgeInsets responsivePadding({
    double horizontal = AppDesignSystem.spaceMD,
    double vertical = AppDesignSystem.spaceMD,
    double? xs,
    double? sm,
    double? md,
    double? lg,
  }) {
    return AppDesignSystem.getResponsivePaddingExact(
      this,
      horizontal: horizontal,
      vertical: vertical,
      xs: xs,
      sm: sm,
      md: md,
      lg: lg,
    );
  }
}

