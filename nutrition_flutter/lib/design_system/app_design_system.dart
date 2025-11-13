import 'package:flutter/material.dart';

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

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    double xs = 12.0,
    double sm = 14.0,
    double md = 16.0,
    double lg = 18.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return xs;
    if (screenWidth < 600) return sm;
    if (screenWidth < 900) return md;
    return lg;
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double horizontal = spaceMD,
    double vertical = spaceLG,
  }) {
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
  }
}
