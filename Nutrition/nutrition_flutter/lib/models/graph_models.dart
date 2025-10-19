import 'package:flutter/material.dart';

/// Professional color scheme for the graph system with gender-based theming
class ProfessionalColors {
  // Gender-based color schemes
  static const Map<String, Color> _maleColors = {
    'waterIntake': Color(0xFF4CAF50), // Green
    'weight': Color(0xFF4CAF50), // Green
    'calories': Color(0xFF4CAF50), // Green
    'steps': Color(0xFF4CAF50), // Green
    'exercise': Color(0xFF4CAF50), // Green
    'sleep': Color(0xFF4CAF50), // Green
    'heartRate': Color(0xFF4CAF50), // Green
  };

  static const Map<String, Color> _femaleColors = {
    'waterIntake': Color(0xFFB76E79), // Rose Gold
    'weight': Color(0xFFB76E79), // Rose Gold
    'calories': Color(0xFFB76E79), // Rose Gold
    'steps': Color(0xFFB76E79), // Rose Gold
    'exercise': Color(0xFFB76E79), // Rose Gold
    'sleep': Color(0xFFB76E79), // Rose Gold
    'heartRate': Color(0xFFB76E79), // Rose Gold
  };

  // Neutral colors (same for all genders)
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color outline = Color(0xFFE1E1E1);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  // Status colors (same for all genders)
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Get color based on gender and metric type
  static Color getColorForMetric(String metric, String? gender) {
    final colorMap = gender == 'male' ? _maleColors : _femaleColors;
    return colorMap[metric] ?? _femaleColors[metric]!;
  }

  // Get gradient colors based on gender and metric type
  static List<Color> getGradientForMetric(String metric, String? gender) {
    final baseColor = getColorForMetric(metric, gender);
    return [baseColor, baseColor.withOpacity(0.6)];
  }
}

/// Available graph types for tracking
enum GraphType {
  waterIntake,
  weight,
  calories,
  steps,
  exercise,
  sleep,
  heartRate,
}

/// Time range options for graphs
enum TimeRange { daily, weekly, monthly, custom }

/// Chart style options
enum ChartStyle { line, bar, area, combined }

/// Graph configuration model
class GraphConfig {
  final GraphType type;
  final TimeRange timeRange;
  final ChartStyle style;
  final Color primaryColor;
  final Color secondaryColor;
  final bool showGoalLine;
  final double? goalValue;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const GraphConfig({
    required this.type,
    required this.timeRange,
    required this.style,
    required this.primaryColor,
    required this.secondaryColor,
    this.showGoalLine = false,
    this.goalValue,
    this.customStartDate,
    this.customEndDate,
  });

  /// Get the appropriate color for a graph type based on gender
  static Color getColorForType(GraphType type, String? gender) {
    final metricName = _getMetricName(type);
    return ProfessionalColors.getColorForMetric(metricName, gender);
  }

  /// Get the appropriate gradient for a graph type based on gender
  static List<Color> getGradientForType(GraphType type, String? gender) {
    final metricName = _getMetricName(type);
    return ProfessionalColors.getGradientForMetric(metricName, gender);
  }

  /// Convert GraphType to metric name string
  static String _getMetricName(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return 'waterIntake';
      case GraphType.weight:
        return 'weight';
      case GraphType.calories:
        return 'calories';
      case GraphType.steps:
        return 'steps';
      case GraphType.exercise:
        return 'exercise';
      case GraphType.sleep:
        return 'sleep';
      case GraphType.heartRate:
        return 'heartRate';
    }
  }

  /// Get the display name for a graph type
  static String getDisplayName(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return 'Water Intake';
      case GraphType.weight:
        return 'Weight';
      case GraphType.calories:
        return 'Calories';
      case GraphType.steps:
        return 'Steps';
      case GraphType.exercise:
        return 'Exercise';
      case GraphType.sleep:
        return 'Sleep';
      case GraphType.heartRate:
        return 'Heart Rate';
    }
  }

  /// Get the icon for a graph type
  static IconData getIconForType(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return Icons.water_drop;
      case GraphType.weight:
        return Icons.monitor_weight;
      case GraphType.calories:
        return Icons.local_fire_department;
      case GraphType.steps:
        return Icons.directions_walk;
      case GraphType.exercise:
        return Icons.fitness_center;
      case GraphType.sleep:
        return Icons.bedtime;
      case GraphType.heartRate:
        return Icons.favorite;
    }
  }

  /// Get the unit for a graph type
  static String getUnitForType(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return 'ml';
      case GraphType.weight:
        return 'kg';
      case GraphType.calories:
        return 'cal';
      case GraphType.steps:
        return 'steps';
      case GraphType.exercise:
        return 'min';
      case GraphType.sleep:
        return 'hrs';
      case GraphType.heartRate:
        return 'bpm';
    }
  }
}

/// Data point for graphs
class GraphDataPoint {
  final DateTime date;
  final double value;
  final String? label;
  final Map<String, dynamic>? metadata;

  const GraphDataPoint({
    required this.date,
    required this.value,
    this.label,
    this.metadata,
  });

  /// Create a copy with updated values
  GraphDataPoint copyWith({
    DateTime? date,
    double? value,
    String? label,
    Map<String, dynamic>? metadata,
  }) {
    return GraphDataPoint(
      date: date ?? this.date,
      value: value ?? this.value,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Graph statistics model
class GraphStatistics {
  final double currentValue;
  final double averageValue;
  final double minValue;
  final double maxValue;
  final double? goalValue;
  final double? changePercentage;
  final String? trendDirection;
  final int totalDataPoints;

  const GraphStatistics({
    required this.currentValue,
    required this.averageValue,
    required this.minValue,
    required this.maxValue,
    this.goalValue,
    this.changePercentage,
    this.trendDirection,
    required this.totalDataPoints,
  });

  /// Calculate trend direction based on change percentage
  String get trendIcon {
    if (changePercentage == null) return '';
    if (changePercentage! > 0) return '↗️';
    if (changePercentage! < 0) return '↘️';
    return '→';
  }

  /// Get trend color based on change percentage
  Color get trendColor {
    if (changePercentage == null) return ProfessionalColors.outline;
    if (changePercentage! > 0) return ProfessionalColors.success;
    if (changePercentage! < 0) return ProfessionalColors.error;
    return ProfessionalColors.outline;
  }
}

/// Graph metadata for display
class GraphMetadata {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String unit;
  final String description;

  const GraphMetadata({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unit,
    required this.description,
  });

  /// Create metadata from graph type with gender-based colors
  factory GraphMetadata.fromType(GraphType type, String? gender) {
    return GraphMetadata(
      title: GraphConfig.getDisplayName(type),
      subtitle: _getSubtitleForType(type),
      icon: GraphConfig.getIconForType(type),
      color: GraphConfig.getColorForType(type, gender),
      unit: GraphConfig.getUnitForType(type),
      description: _getDescriptionForType(type),
    );
  }

  static String _getSubtitleForType(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return 'Track your daily hydration';
      case GraphType.weight:
        return 'Monitor your weight changes';
      case GraphType.calories:
        return 'Calories consumed vs burned';
      case GraphType.steps:
        return 'Daily step count tracking';
      case GraphType.exercise:
        return 'Exercise minutes and activities';
      case GraphType.sleep:
        return 'Sleep duration and quality';
      case GraphType.heartRate:
        return 'Heart rate monitoring';
    }
  }

  static String _getDescriptionForType(GraphType type) {
    switch (type) {
      case GraphType.waterIntake:
        return 'Stay hydrated by tracking your daily water intake';
      case GraphType.weight:
        return 'Monitor your weight progress over time';
      case GraphType.calories:
        return 'Balance your calorie intake and expenditure';
      case GraphType.steps:
        return 'Track your daily activity and movement';
      case GraphType.exercise:
        return 'Log your workouts and exercise sessions';
      case GraphType.sleep:
        return 'Monitor your sleep patterns and duration';
      case GraphType.heartRate:
        return 'Track your heart rate during activities';
    }
  }
}
