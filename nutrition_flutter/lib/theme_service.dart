import 'package:flutter/material.dart';
import 'design_system/app_design_system.dart';

/// Professional theme service using the centralized design system
class ThemeService {
  // Legacy color constants for backward compatibility
  static const Color kGreen = AppDesignSystem.primaryGreen;
  static const Color kLightGreen = AppDesignSystem.background;
  static const Color kRoseGold = AppDesignSystem.primaryRoseGold;
  static const Color kLightRoseGold = AppDesignSystem.background;

  /// Get theme data based on gender with professional styling
  static ThemeData getThemeForSex(String? sex) {
    final primaryColor = AppDesignSystem.getPrimaryColor(sex);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: AppDesignSystem.surface,
        onSurface: AppDesignSystem.onSurface,
        // background property is deprecated, using surface instead
        error: AppDesignSystem.error,
      ),
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppDesignSystem.primaryButtonStyle(primaryColor: primaryColor),
      ),
      cardTheme: CardThemeData(
        elevation: AppDesignSystem.elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(color: AppDesignSystem.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(color: AppDesignSystem.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  /// Build consistent text theme
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: AppDesignSystem.displayLarge,
      displayMedium: AppDesignSystem.displayMedium,
      displaySmall: AppDesignSystem.displaySmall,
      headlineLarge: AppDesignSystem.headlineLarge,
      headlineMedium: AppDesignSystem.headlineMedium,
      headlineSmall: AppDesignSystem.headlineSmall,
      titleLarge: AppDesignSystem.titleLarge,
      titleMedium: AppDesignSystem.titleMedium,
      titleSmall: AppDesignSystem.titleSmall,
      bodyLarge: AppDesignSystem.bodyLarge,
      bodyMedium: AppDesignSystem.bodyMedium,
      bodySmall: AppDesignSystem.bodySmall,
      labelLarge: AppDesignSystem.labelLarge,
      labelMedium: AppDesignSystem.labelMedium,
      labelSmall: AppDesignSystem.labelSmall,
    );
  }

  /// Get primary color based on gender
  static Color getPrimaryColor(String? sex) {
    return AppDesignSystem.getPrimaryColor(sex);
  }

  /// Get background color based on gender
  static Color getBackgroundColor(String? sex) {
    return AppDesignSystem.getBackgroundColor(sex);
  }

  /// Get color scheme based on gender
  static ColorScheme getColorScheme(String? sex) {
    final primaryColor = AppDesignSystem.getPrimaryColor(sex);
    return ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );
  }
}
