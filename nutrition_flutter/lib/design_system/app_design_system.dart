import 'package:flutter/material.dart';

/// Screen category enum for device classification
enum ScreenCategory {
  smallPhone, // < 360px width
  phone,      // 360-600px width
  tablet,     // 600-900px width
  desktop,    // > 900px width
}

/// Professional design system for the nutrition app
/// This centralizes all design decisions to prevent overfitting and ensure consistency
class AppDesignSystem {
  // Private constructor to prevent instantiation
  AppDesignSystem._();

  // ============================================================================
  // COLOR SYSTEM
  // ============================================================================

  /// Primary brand colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryRoseGold = Color(0xFFB76E79);

  /// Neutral colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFFE1E1E1);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  /// Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  /// Get primary color based on gender
  static Color getPrimaryColor(String? gender) {
    return gender?.toLowerCase() == 'female' ? primaryRoseGold : primaryGreen;
  }

  /// Get background color based on gender
  static Color getBackgroundColor(String? gender) {
    return gender?.toLowerCase() == 'female'
        ? const Color(0xFFFDF2F4)
        : const Color(0xFFE8F5E8);
  }

  // ============================================================================
  // TYPOGRAPHY SYSTEM
  // ============================================================================

  /// Text styles with consistent scaling
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ============================================================================
  // SPACING SYSTEM
  // ============================================================================

  /// Consistent spacing scale (based on 8px grid)
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  /// Responsive spacing based on screen size
  static double getResponsiveSpacing(
    BuildContext context, {
    double xs = spaceSM,
    double sm = spaceMD,
    double md = spaceLG,
    double lg = spaceXL,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return xs;
    if (screenWidth < 600) return sm;
    if (screenWidth < 900) return md;
    return lg;
  }

  // ============================================================================
  // BORDER RADIUS SYSTEM
  // ============================================================================

  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;

  // ============================================================================
  // ELEVATION SYSTEM
  // ============================================================================

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationMax = 16.0;

  // ============================================================================
  // ANIMATION SYSTEM
  // ============================================================================

  /// Consistent animation durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  /// Consistent animation curves
  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerated = Curves.easeOut;

  // ============================================================================
  // COMPONENT STYLES
  // ============================================================================

  /// Card style
  static BoxDecoration cardDecoration({
    Color? color,
    double? elevation,
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(borderRadius ?? radiusLG),
      boxShadow:
          elevation != null
              ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
              : null,
    );
  }

  /// Button style
  static ButtonStyle primaryButtonStyle({
    required Color primaryColor,
    Color? backgroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? primaryColor,
      foregroundColor: Colors.white,
      elevation: elevationLow,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spaceLG,
        vertical: spaceMD,
      ),
    );
  }

  /// Input decoration
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Color? primaryColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null 
          ? Icon(prefixIcon, color: primaryColor ?? primaryGreen)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: primaryColor ?? primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: surface,
    );
  }

  // ============================================================================
  // RESPONSIVE HELPERS
  // ============================================================================

  /// Get screen category for debugging and conditional logic
  static ScreenCategory getScreenCategory(BuildContext context) {
    try {
      final width = MediaQuery.of(context).size.width;
      if (width < 360) return ScreenCategory.smallPhone;
      if (width < 600) return ScreenCategory.phone;
      if (width < 900) return ScreenCategory.tablet;
      return ScreenCategory.desktop;
    } catch (e) {
      // Fallback to phone if MediaQuery fails
      return ScreenCategory.phone;
    }
  }

  /// Get screen category as string (for debugging)
  static String getScreenCategoryString(BuildContext context) {
    final category = getScreenCategory(context);
    switch (category) {
      case ScreenCategory.smallPhone:
        return 'smallPhone';
      case ScreenCategory.phone:
        return 'phone';
      case ScreenCategory.tablet:
        return 'tablet';
      case ScreenCategory.desktop:
        return 'desktop';
    }
  }

  /// Check if device is a phone
  static bool isPhone(BuildContext context) {
    final category = getScreenCategory(context);
    return category == ScreenCategory.smallPhone || category == ScreenCategory.phone;
  }

  /// Check if device is a tablet or larger
  static bool isTablet(BuildContext context) {
    final category = getScreenCategory(context);
    return category == ScreenCategory.tablet || category == ScreenCategory.desktop;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    try {
      final orientation = MediaQuery.of(context).orientation;
      return orientation == Orientation.landscape;
    } catch (e) {
      return false;
    }
  }

  /// Get screen width (safe access)
  static double getScreenWidth(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width;
    } catch (e) {
      return 360.0; // Default fallback
    }
  }

  /// Get screen height (safe access)
  static double getScreenHeight(BuildContext context) {
    try {
      return MediaQuery.of(context).size.height;
    } catch (e) {
      return 640.0; // Default fallback
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    double xs = 12.0,
    double sm = 14.0,
    double md = 16.0,
    double lg = 18.0,
  }) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth < 360) return xs;
      if (screenWidth < 600) return sm;
      if (screenWidth < 900) return md;
      return lg;
    } catch (e) {
      // Fallback to medium size
      return sm;
    }
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double horizontal = spaceMD,
    double vertical = spaceLG,
  }) {
    try {
      final responsiveHorizontal = getResponsiveSpacing(
        context,
        xs: horizontal * 0.75,
        sm: horizontal,
        md: horizontal * 1.25,
        lg: horizontal * 1.5,
      );

      final responsiveVertical = getResponsiveSpacing(
        context,
        xs: vertical * 0.75,
        sm: vertical,
        md: vertical * 1.25,
        lg: vertical * 1.5,
      );

      return EdgeInsets.symmetric(
        horizontal: responsiveHorizontal,
        vertical: responsiveVertical,
      );
    } catch (e) {
      // Fallback to default values
      return EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      );
    }
  }

  /// Get responsive padding with exact value matching
  /// Use this when you need to match specific values from old hard-coded logic
  /// 
  /// Example:
  /// ```dart
  /// // Old: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)
  /// // New:
  /// padding: AppDesignSystem.getResponsivePaddingExact(
  ///   context,
  ///   xs: 8,   // < 360px (matches isNarrowScreen ? 8)
  ///   sm: 12,  // 360-600px (matches isSmallScreen ? 12)
  ///   md: 16,  // 600-900px (matches default 16)
  ///   lg: 20,  // > 900px (optional, for tablets)
  /// )
  /// ```
  static EdgeInsets getResponsivePaddingExact(
    BuildContext context, {
    double? xs,  // < 360px
    double? sm,  // 360-600px
    double? md,  // 600-900px
    double? lg,  // > 900px
    double horizontal = spaceMD,
    double vertical = spaceLG,
  }) {
    try {
      final width = MediaQuery.of(context).size.width;
      double h, v;

      if (width < 360) {
        h = xs ?? (horizontal * 0.75);
        v = xs ?? (vertical * 0.75);
      } else if (width < 600) {
        h = sm ?? horizontal;
        v = sm ?? vertical;
      } else if (width < 900) {
        h = md ?? (horizontal * 1.25);
        v = md ?? (vertical * 1.25);
      } else {
        h = lg ?? (horizontal * 1.5);
        v = lg ?? (vertical * 1.5);
      }

      return EdgeInsets.symmetric(horizontal: h, vertical: v);
    } catch (e) {
      // Fallback to defaults
      return EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      );
    }
  }

  /// Get responsive spacing with exact value matching
  /// Use this when you need to match specific spacing values from old hard-coded logic
  /// 
  /// Example:
  /// ```dart
  /// // Old: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24)
  /// // New:
  /// SizedBox(
  ///   height: AppDesignSystem.getResponsiveSpacingExact(
  ///     context,
  ///     xs: 16,  // < 600px (matches isVerySmallScreen ? 16)
  ///     sm: 20,  // 600-700px (matches isSmallScreen ? 20)
  ///     md: 24,  // > 700px (matches default 24)
  ///   ),
  /// )
  /// ```
  static double getResponsiveSpacingExact(
    BuildContext context, {
    double? xs,  // < 360px
    double? sm,  // 360-600px
    double? md,  // 600-900px
    double? lg,  // > 900px
    double defaultValue = spaceMD,
  }) {
    try {
      final width = MediaQuery.of(context).size.width;
      if (width < 360) return xs ?? (defaultValue * 0.75);
      if (width < 600) return sm ?? defaultValue;
      if (width < 900) return md ?? (defaultValue * 1.25);
      return lg ?? (defaultValue * 1.5);
    } catch (e) {
      // Fallback to default value
      return defaultValue;
    }
  }

  /// Get responsive padding for screen edges (common use case)
  static EdgeInsets getScreenPadding(BuildContext context) {
    return getResponsivePadding(
      context,
      horizontal: spaceMD,
      vertical: spaceMD,
    );
  }

  /// Standardized padding for compact numeric inputs (height/weight fields)
  static EdgeInsets getNumericInputPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getResponsiveSpacingExact(
        context,
        xs: spaceSM + 2,
        sm: spaceMD,
        md: spaceMD + 2,
        lg: spaceLG,
      ),
      vertical: getResponsiveSpacingExact(
        context,
        xs: 12,
        sm: 14,
        md: 16,
        lg: 18,
      ),
    );
  }

  /// Minimum constraints to keep numeric inputs legible on very small devices
  static BoxConstraints getNumericInputConstraints(BuildContext context) {
    return BoxConstraints(
      minHeight: getResponsiveSpacingExact(
        context,
        xs: 44,
        sm: 48,
        md: 52,
        lg: 56,
      ),
    );
  }

  /// Get responsive padding for cards/containers (common use case)
  static EdgeInsets getCardPadding(BuildContext context) {
    return getResponsivePadding(
      context,
      horizontal: spaceMD,
      vertical: spaceMD,
    );
  }

  /// Get responsive padding for input fields (common use case)
  static EdgeInsets getInputPadding(BuildContext context) {
    return getResponsivePadding(
      context,
      horizontal: spaceMD,
      vertical: spaceSM,
    );
  }

  /// Get responsive spacing between sections (common use case)
  static double getSectionSpacing(BuildContext context) {
    return getResponsiveSpacing(
      context,
      xs: spaceMD,
      sm: spaceLG,
      md: spaceXL,
      lg: spaceXXL,
    );
  }

  /// Get responsive spacing between elements (common use case)
  static double getElementSpacing(BuildContext context) {
    return getResponsiveSpacing(
      context,
      xs: spaceSM,
      sm: spaceMD,
      md: spaceLG,
      lg: spaceXL,
    );
  }

  // ============================================================================
  // RESPONSIVE TEXT STYLES
  // ============================================================================

  /// Get responsive text style for display large
  static TextStyle getResponsiveDisplayLarge(BuildContext context) {
    return displayLarge.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 24,
        sm: 28,
        md: 32,
        lg: 36,
      ),
    );
  }

  /// Get responsive text style for display medium
  static TextStyle getResponsiveDisplayMedium(BuildContext context) {
    return displayMedium.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 20,
        sm: 24,
        md: 28,
        lg: 32,
      ),
    );
  }

  /// Get responsive text style for display small
  static TextStyle getResponsiveDisplaySmall(BuildContext context) {
    return displaySmall.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 18,
        sm: 20,
        md: 24,
        lg: 28,
      ),
    );
  }

  /// Get responsive text style for headline large
  static TextStyle getResponsiveHeadlineLarge(BuildContext context) {
    return headlineLarge.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 18,
        sm: 20,
        md: 22,
        lg: 24,
      ),
    );
  }

  /// Get responsive text style for headline medium
  static TextStyle getResponsiveHeadlineMedium(BuildContext context) {
    return headlineMedium.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 16,
        sm: 18,
        md: 20,
        lg: 22,
      ),
    );
  }

  /// Get responsive text style for headline small
  static TextStyle getResponsiveHeadlineSmall(BuildContext context) {
    return headlineSmall.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 14,
        sm: 16,
        md: 18,
        lg: 20,
      ),
    );
  }

  /// Get responsive text style for title large
  static TextStyle getResponsiveTitleLarge(BuildContext context) {
    return titleLarge.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 14,
        sm: 15,
        md: 16,
        lg: 18,
      ),
    );
  }

  /// Get responsive text style for body large
  static TextStyle getResponsiveBodyLarge(BuildContext context) {
    return bodyLarge.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 14,
        sm: 15,
        md: 16,
        lg: 18,
      ),
    );
  }

  /// Get responsive text style for body medium
  static TextStyle getResponsiveBodyMedium(BuildContext context) {
    return bodyMedium.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 12,
        sm: 13,
        md: 14,
        lg: 16,
      ),
    );
  }

  /// Get responsive text style for body small
  static TextStyle getResponsiveBodySmall(BuildContext context) {
    return bodySmall.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        xs: 10,
        sm: 11,
        md: 12,
        lg: 14,
      ),
    );
  }

  // ============================================================================
  // RESPONSIVE DIMENSIONS
  // ============================================================================

  /// Get responsive icon size
  static double getResponsiveIconSize(
    BuildContext context, {
    double xs = 16.0,
    double sm = 20.0,
    double md = 24.0,
    double lg = 28.0,
  }) {
    return getResponsiveFontSize(context, xs: xs, sm: sm, md: md, lg: lg);
  }

  /// Get responsive image height
  static double getResponsiveImageHeight(
    BuildContext context, {
    double xs = 80.0,
    double sm = 100.0,
    double md = 120.0,
    double lg = 140.0,
  }) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      // Use smaller of width/height for very small screens
      if (screenHeight < 600 || screenWidth < 360) return xs;
      if (screenWidth < 600) return sm;
      if (screenWidth < 900) return md;
      return lg;
    } catch (e) {
      return sm;
    }
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(
    BuildContext context, {
    double xs = 44.0,
    double sm = 48.0,
    double md = 52.0,
    double lg = 56.0,
  }) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth < 360) return xs;
      if (screenWidth < 600) return sm;
      if (screenWidth < 900) return md;
      return lg;
    } catch (e) {
      return sm;
    }
  }

  /// Get responsive container width (as percentage of screen)
  static double getResponsiveContainerWidth(
    BuildContext context, {
    double percentage = 0.9,
    double? maxWidth,
    double? minWidth,
  }) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      double width = screenWidth * percentage;
      if (maxWidth != null && width > maxWidth) width = maxWidth;
      if (minWidth != null && width < minWidth) width = minWidth;
      return width;
    } catch (e) {
      return 360.0 * percentage;
    }
  }

  /// Get responsive button width with max constraint
  /// Buttons should not stretch too wide on large screens
  static double? getResponsiveButtonWidth(BuildContext context) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      // On very small screens, use full width
      if (screenWidth < 360) return double.infinity;
      // On small-medium screens, use full width
      if (screenWidth < 600) return double.infinity;
      // On tablets and larger, constrain to max 500px and center
      if (screenWidth < 900) return 500.0;
      // On desktop, max 400px
      return 400.0;
    } catch (e) {
      return double.infinity;
    }
  }

  /// Check if button should be centered (for larger screens)
  static bool shouldCenterButton(BuildContext context) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      return screenWidth >= 600; // Center on tablets and larger
    } catch (e) {
      return false;
    }
  }

  /// Get responsive container height (as percentage of screen)
  static double getResponsiveContainerHeight(
    BuildContext context, {
    double percentage = 0.5,
    double? maxHeight,
    double? minHeight,
  }) {
    try {
      final screenHeight = MediaQuery.of(context).size.height;
      double height = screenHeight * percentage;
      if (maxHeight != null && height > maxHeight) height = maxHeight;
      if (minHeight != null && height < minHeight) height = minHeight;
      return height;
    } catch (e) {
      return 640.0 * percentage;
    }
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(
    BuildContext context, {
    double xs = radiusSM,
    double sm = radiusMD,
    double md = radiusLG,
    double lg = radiusXL,
  }) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth < 360) return xs;
      if (screenWidth < 600) return sm;
      if (screenWidth < 900) return md;
      return lg;
    } catch (e) {
      return sm;
    }
  }

  /// Check if screen is very small (height < 600)
  static bool isVerySmallScreen(BuildContext context) {
    try {
      return MediaQuery.of(context).size.height < 600;
    } catch (e) {
      return false;
    }
  }

  /// Check if screen is narrow (width < 360)
  static bool isNarrowScreen(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width < 360;
    } catch (e) {
      return false;
    }
  }
}
