import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/graph_models.dart';
import 'health_service.dart';
import 'google_fit_service.dart';

/// Comprehensive Progress Data Service
///
/// This service provides unified access to all progress tracking data from:
/// - Backend APIs (calories, weight, workouts)
/// - Health Connect (steps, heart rate, sleep)
/// - Google Fit (activity data)
/// - Local storage (goals, preferences)
class ProgressDataService {
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Cache for progress data
  static Map<String, dynamic>? _cachedData;
  static DateTime? _lastCacheTime;

  /// Get comprehensive progress data for a specific time range
  static Future<ProgressData> getProgressData({
    required String usernameOrEmail,
    required TimeRange timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh && _isCacheValid()) {
        final cachedData = _cachedData?['${usernameOrEmail}_${timeRange.name}'];
        if (cachedData != null) {
          return ProgressData.fromJson(cachedData);
        }
      }

      // Calculate date range
      final dateRange = _calculateDateRange(
        timeRange,
        customStartDate,
        customEndDate,
      );

      debugPrint(
        '🔄 Fetching progress data for $usernameOrEmail - ${timeRange.name}',
      );
      debugPrint('📅 Date range: ${dateRange.start} to ${dateRange.end}');

      // Fetch data from all sources in parallel
      final results = await Future.wait([
        _fetchBackendData(usernameOrEmail, dateRange),
        _fetchHealthConnectData(dateRange),
        _fetchGoogleFitData(dateRange),
        _fetchUserGoals(usernameOrEmail),
      ]);

      final backendData = results[0];
      final healthData = results[1];
      final googleFitData = results[2];
      final userGoals = results[3];

      // Aggregate all data
      final progressData = ProgressData(
        username: usernameOrEmail,
        timeRange: timeRange,
        dateRange: dateRange,
        calories: _aggregateCaloriesData(backendData, userGoals),
        weight: _aggregateWeightData(backendData),
        exercise: _aggregateExerciseData(
          backendData,
          healthData,
          googleFitData,
        ),
        steps: _aggregateStepsData(healthData, googleFitData),
        waterIntake: _aggregateWaterData(backendData, userGoals),
        sleep: _aggregateSleepData(healthData),
        heartRate: _aggregateHeartRateData(healthData),
        goals: userGoals,
        lastUpdated: DateTime.now(),
      );

      // Cache the result
      _cacheData(usernameOrEmail, timeRange, progressData.toJson());

      debugPrint('✅ Progress data fetched successfully');
      return progressData;
    } catch (e) {
      debugPrint('❌ Error fetching progress data: $e');
      return ProgressData.empty(usernameOrEmail, timeRange);
    }
  }

  /// Get daily progress summary
  static Future<DailyProgressSummary> getDailySummary({
    required String usernameOrEmail,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final progressData = await getProgressData(
      usernameOrEmail: usernameOrEmail,
      timeRange: TimeRange.daily,
      customStartDate: targetDate,
      customEndDate: targetDate,
    );

    return DailyProgressSummary.fromProgressData(progressData, targetDate);
  }

  /// Get weekly progress summary
  static Future<WeeklyProgressSummary> getWeeklySummary({
    required String usernameOrEmail,
    DateTime? weekStart,
  }) async {
    final startDate = weekStart ?? _getWeekStart(DateTime.now());
    final endDate = startDate.add(const Duration(days: 6));

    final progressData = await getProgressData(
      usernameOrEmail: usernameOrEmail,
      timeRange: TimeRange.weekly,
      customStartDate: startDate,
      customEndDate: endDate,
    );

    return WeeklyProgressSummary.fromProgressData(progressData, startDate);
  }

  /// Get monthly progress summary
  static Future<MonthlyProgressSummary> getMonthlySummary({
    required String usernameOrEmail,
    DateTime? monthStart,
  }) async {
    final startDate = monthStart ?? _getMonthStart(DateTime.now());
    final endDate = _getMonthEnd(startDate);

    final progressData = await getProgressData(
      usernameOrEmail: usernameOrEmail,
      timeRange: TimeRange.monthly,
      customStartDate: startDate,
      customEndDate: endDate,
    );

    return MonthlyProgressSummary.fromProgressData(progressData, startDate);
  }

  /// Update user goals
  static Future<bool> updateUserGoals({
    required String usernameOrEmail,
    required Map<String, dynamic> goals,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/progress/goals'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user': usernameOrEmail, 'goals': goals}),
      );

      if (response.statusCode == 200) {
        // Clear cache to force refresh
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error updating goals: $e');
      return false;
    }
  }

  /// Sync data with health platforms
  static Future<bool> syncWithHealthPlatforms({
    required String usernameOrEmail,
  }) async {
    try {
      // Sync with Health Connect
      final healthConnected = await HealthService.isHealthConnectConnected();
      if (healthConnected) {
        await _syncHealthConnectData(usernameOrEmail);
      }

      // Sync with Google Fit
      final googleFitConnected =
          await GoogleFitService.isConnectedToGoogleFit();
      if (googleFitConnected) {
        await _syncGoogleFitData(usernameOrEmail);
      }

      // Clear cache to force refresh
      _clearCache();

      return true;
    } catch (e) {
      debugPrint('❌ Error syncing with health platforms: $e');
      return false;
    }
  }

  // Private helper methods

  static bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;
  }

  static void _cacheData(
    String username,
    TimeRange timeRange,
    Map<String, dynamic> data,
  ) {
    _cachedData ??= {};
    _cachedData!['${username}_${timeRange.name}'] = data;
    _lastCacheTime = DateTime.now();
  }

  static void _clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
  }

  static DateRange _calculateDateRange(
    TimeRange timeRange,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final now = DateTime.now();

    switch (timeRange) {
      case TimeRange.daily:
        return DateRange(now, now);
      case TimeRange.weekly:
        final weekStart = _getWeekStart(now);
        return DateRange(weekStart, weekStart.add(const Duration(days: 6)));
      case TimeRange.monthly:
        final monthStart = _getMonthStart(now);
        return DateRange(monthStart, _getMonthEnd(monthStart));
      case TimeRange.custom:
        return DateRange(customStart ?? now, customEnd ?? now);
    }
  }

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  static DateTime _getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime _getMonthEnd(DateTime monthStart) {
    return DateTime(monthStart.year, monthStart.month + 1, 0);
  }

  // Data fetching methods

  static Future<Map<String, dynamic>> _fetchBackendData(
    String username,
    DateRange dateRange,
  ) async {
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '$apiBase/progress/calories?user=$username&start=${dateRange.start.toIso8601String()}&end=${dateRange.end.toIso8601String()}',
          ),
        ),
        http.get(
          Uri.parse(
            '$apiBase/progress/weight?user=$username&start=${dateRange.start.toIso8601String()}&end=${dateRange.end.toIso8601String()}',
          ),
        ),
        http.get(
          Uri.parse(
            '$apiBase/progress/workouts?user=$username&start=${dateRange.start.toIso8601String()}&end=${dateRange.end.toIso8601String()}',
          ),
        ),
      ]);

      final calories =
          results[0].statusCode == 200 ? json.decode(results[0].body) : [];
      final weight =
          results[1].statusCode == 200 ? json.decode(results[1].body) : [];
      final workouts =
          results[2].statusCode == 200 ? json.decode(results[2].body) : [];

      debugPrint('📊 Backend data received:');
      debugPrint('   Calories: ${calories.length} entries');
      debugPrint('   Weight: ${weight.length} entries');
      debugPrint('   Workouts: ${workouts.length} entries');

      return {'calories': calories, 'weight': weight, 'workouts': workouts};
    } catch (e) {
      debugPrint('❌ Error fetching backend data: $e');
      return {'calories': [], 'weight': [], 'workouts': []};
    }
  }

  static Future<Map<String, dynamic>> _fetchHealthConnectData(
    DateRange dateRange,
  ) async {
    try {
      if (!await HealthService.isHealthConnectConnected()) {
        return {};
      }

      // For now, return empty data as these methods need to be implemented
      final results = [
        <String, dynamic>{},
        <String, dynamic>{},
        <String, dynamic>{},
      ];

      return {
        'steps': results[0],
        'heartRate': results[1],
        'sleep': results[2],
      };
    } catch (e) {
      debugPrint('❌ Error fetching Health Connect data: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _fetchGoogleFitData(
    DateRange dateRange,
  ) async {
    try {
      if (!await GoogleFitService.isConnectedToGoogleFit()) {
        return {};
      }

      // For now, return empty data as these methods need to be implemented
      final results = [<String, dynamic>{}, <String, dynamic>{}];

      return {'steps': results[0], 'activities': results[1]};
    } catch (e) {
      debugPrint('❌ Error fetching Google Fit data: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _fetchUserGoals(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/progress/goals?user=$username'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return _getDefaultGoals();
    } catch (e) {
      debugPrint('❌ Error fetching user goals: $e');
      return _getDefaultGoals();
    }
  }

  static Map<String, dynamic> _getDefaultGoals() {
    return {
      'calories': 2000,
      'steps': 10000,
      'water': 2000,
      'exercise': 30,
      'sleep': 8,
    };
  }

  // Data aggregation methods

  static CaloriesData _aggregateCaloriesData(
    Map<String, dynamic> backendData,
    Map<String, dynamic> goals,
  ) {
    final calories = backendData['calories'] as List<dynamic>;
    final totalCalories = calories.fold<double>(
      0,
      (sum, entry) => sum + ((entry['calories'] ?? 0).toDouble()),
    );
    final goal = goals['calories']?.toDouble() ?? 2000.0;

    return CaloriesData(
      current: totalCalories,
      goal: goal,
      remaining: (goal - totalCalories).clamp(0, double.infinity),
      percentage: goal > 0 ? (totalCalories / goal).clamp(0, 1) : 0,
    );
  }

  static WeightData _aggregateWeightData(Map<String, dynamic> backendData) {
    final weights = backendData['weight'] as List<dynamic>;
    if (weights.isEmpty) {
      return WeightData.empty();
    }

    final latest = weights.last;
    final previous = weights.length > 1 ? weights[weights.length - 2] : null;

    return WeightData(
      current: latest['weight']?.toDouble() ?? 0,
      previous: previous?['weight']?.toDouble(),
      change: previous != null ? (latest['weight'] - previous['weight']) : 0,
      trend: _calculateWeightTrend(weights),
    );
  }

  static ExerciseData _aggregateExerciseData(
    Map<String, dynamic> backendData,
    Map<String, dynamic> healthData,
    Map<String, dynamic> googleFitData,
  ) {
    final workouts = backendData['workouts'] as List<dynamic>;
    final totalDuration = workouts.fold<int>(
      0,
      (sum, workout) => sum + (workout['duration'] as int? ?? 0),
    );
    final totalCaloriesBurned = workouts.fold<double>(
      0,
      (sum, workout) => sum + ((workout['calories_burned'] ?? 0).toDouble()),
    );

    return ExerciseData(
      duration: totalDuration,
      caloriesBurned: totalCaloriesBurned,
      sessions: workouts.length,
      averageIntensity:
          workouts.isNotEmpty ? totalCaloriesBurned / totalDuration : 0,
    );
  }

  static StepsData _aggregateStepsData(
    Map<String, dynamic> healthData,
    Map<String, dynamic> googleFitData,
  ) {
    final healthSteps = healthData['steps'] as int? ?? 0;
    final googleFitSteps = googleFitData['steps'] as int? ?? 0;

    // Use the higher value or combine if both sources are available
    final totalSteps =
        healthSteps > googleFitSteps ? healthSteps : googleFitSteps;

    return StepsData(
      current: totalSteps,
      goal: 10000, // Default goal
      remaining: (10000 - totalSteps).clamp(0, 10000),
      percentage: totalSteps / 10000,
    );
  }

  static WaterIntakeData _aggregateWaterData(
    Map<String, dynamic> backendData,
    Map<String, dynamic> goals,
  ) {
    // This would need to be implemented based on your water tracking system
    final goal = goals['water']?.toDouble() ?? 2000.0;

    return WaterIntakeData(
      current: 0, // Placeholder - implement based on your water tracking
      goal: goal,
      remaining: goal,
      percentage: 0,
    );
  }

  static SleepData _aggregateSleepData(Map<String, dynamic> healthData) {
    final sleepData = healthData['sleep'] ?? {};

    return SleepData(
      duration: sleepData['duration']?.toDouble() ?? 0,
      quality: sleepData['quality']?.toDouble() ?? 0,
      bedtime: sleepData['bedtime'],
      wakeTime: sleepData['wakeTime'],
    );
  }

  static HeartRateData _aggregateHeartRateData(
    Map<String, dynamic> healthData,
  ) {
    final heartRateData = healthData['heartRate'] ?? {};

    return HeartRateData(
      average: heartRateData['average']?.toDouble() ?? 0,
      resting: heartRateData['resting']?.toDouble() ?? 0,
      max: heartRateData['max']?.toDouble() ?? 0,
      zones: heartRateData['zones'] ?? {},
    );
  }

  static String _calculateWeightTrend(List<dynamic> weights) {
    if (weights.length < 2) return 'stable';

    final recent = weights.take(7).map((w) => w['weight'] as double).toList();
    final older =
        weights.skip(7).take(7).map((w) => w['weight'] as double).toList();

    if (recent.isEmpty || older.isEmpty) return 'stable';

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;

    if (recentAvg > olderAvg + 0.5) return 'increasing';
    if (recentAvg < olderAvg - 0.5) return 'decreasing';
    return 'stable';
  }

  // Sync methods

  static Future<void> _syncHealthConnectData(String username) async {
    // Implementation for syncing Health Connect data to backend
    debugPrint('🔄 Syncing Health Connect data for $username');
  }

  static Future<void> _syncGoogleFitData(String username) async {
    // Implementation for syncing Google Fit data to backend
    debugPrint('🔄 Syncing Google Fit data for $username');
  }
}

/// Date range helper class
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);
}

/// Comprehensive progress data model
class ProgressData {
  final String username;
  final TimeRange timeRange;
  final DateRange dateRange;
  final CaloriesData calories;
  final WeightData weight;
  final ExerciseData exercise;
  final StepsData steps;
  final WaterIntakeData waterIntake;
  final SleepData sleep;
  final HeartRateData heartRate;
  final Map<String, dynamic> goals;
  final DateTime lastUpdated;

  const ProgressData({
    required this.username,
    required this.timeRange,
    required this.dateRange,
    required this.calories,
    required this.weight,
    required this.exercise,
    required this.steps,
    required this.waterIntake,
    required this.sleep,
    required this.heartRate,
    required this.goals,
    required this.lastUpdated,
  });

  factory ProgressData.empty(String username, TimeRange timeRange) {
    return ProgressData(
      username: username,
      timeRange: timeRange,
      dateRange: DateRange(DateTime.now(), DateTime.now()),
      calories: CaloriesData.empty(),
      weight: WeightData.empty(),
      exercise: ExerciseData.empty(),
      steps: StepsData.empty(),
      waterIntake: WaterIntakeData.empty(),
      sleep: SleepData.empty(),
      heartRate: HeartRateData.empty(),
      goals: {},
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'timeRange': timeRange.name,
      'dateRange': {
        'start': dateRange.start.toIso8601String(),
        'end': dateRange.end.toIso8601String(),
      },
      'calories': calories.toJson(),
      'weight': weight.toJson(),
      'exercise': exercise.toJson(),
      'steps': steps.toJson(),
      'waterIntake': waterIntake.toJson(),
      'sleep': sleep.toJson(),
      'heartRate': heartRate.toJson(),
      'goals': goals,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      username: json['username'] ?? '',
      timeRange: TimeRange.values.firstWhere(
        (e) => e.name == json['timeRange'],
        orElse: () => TimeRange.daily,
      ),
      dateRange: DateRange(
        DateTime.parse(json['dateRange']['start']),
        DateTime.parse(json['dateRange']['end']),
      ),
      calories: CaloriesData.fromJson(json['calories'] ?? {}),
      weight: WeightData.fromJson(json['weight'] ?? {}),
      exercise: ExerciseData.fromJson(json['exercise'] ?? {}),
      steps: StepsData.fromJson(json['steps'] ?? {}),
      waterIntake: WaterIntakeData.fromJson(json['waterIntake'] ?? {}),
      sleep: SleepData.fromJson(json['sleep'] ?? {}),
      heartRate: HeartRateData.fromJson(json['heartRate'] ?? {}),
      goals: json['goals'] ?? {},
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

/// Individual data models for each metric
class CaloriesData {
  final double current;
  final double goal;
  final double remaining;
  final double percentage;

  const CaloriesData({
    required this.current,
    required this.goal,
    required this.remaining,
    required this.percentage,
  });

  factory CaloriesData.empty() {
    return const CaloriesData(
      current: 0,
      goal: 2000,
      remaining: 2000,
      percentage: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'current': current,
    'goal': goal,
    'remaining': remaining,
    'percentage': percentage,
  };

  factory CaloriesData.fromJson(Map<String, dynamic> json) {
    return CaloriesData(
      current: json['current']?.toDouble() ?? 0,
      goal: json['goal']?.toDouble() ?? 2000,
      remaining: json['remaining']?.toDouble() ?? 2000,
      percentage: json['percentage']?.toDouble() ?? 0,
    );
  }
}

class WeightData {
  final double current;
  final double? previous;
  final double change;
  final String trend;

  const WeightData({
    required this.current,
    this.previous,
    required this.change,
    required this.trend,
  });

  factory WeightData.empty() {
    return const WeightData(current: 0, change: 0, trend: 'stable');
  }

  Map<String, dynamic> toJson() => {
    'current': current,
    'previous': previous,
    'change': change,
    'trend': trend,
  };

  factory WeightData.fromJson(Map<String, dynamic> json) {
    return WeightData(
      current: json['current']?.toDouble() ?? 0,
      previous: json['previous']?.toDouble(),
      change: json['change']?.toDouble() ?? 0,
      trend: json['trend'] ?? 'stable',
    );
  }
}

class ExerciseData {
  final int duration; // in minutes
  final double caloriesBurned;
  final int sessions;
  final double averageIntensity;

  const ExerciseData({
    required this.duration,
    required this.caloriesBurned,
    required this.sessions,
    required this.averageIntensity,
  });

  factory ExerciseData.empty() {
    return const ExerciseData(
      duration: 0,
      caloriesBurned: 0,
      sessions: 0,
      averageIntensity: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'duration': duration,
    'caloriesBurned': caloriesBurned,
    'sessions': sessions,
    'averageIntensity': averageIntensity,
  };

  factory ExerciseData.fromJson(Map<String, dynamic> json) {
    return ExerciseData(
      duration: json['duration']?.toInt() ?? 0,
      caloriesBurned: json['caloriesBurned']?.toDouble() ?? 0,
      sessions: json['sessions']?.toInt() ?? 0,
      averageIntensity: json['averageIntensity']?.toDouble() ?? 0,
    );
  }
}

class StepsData {
  final int current;
  final int goal;
  final int remaining;
  final double percentage;

  const StepsData({
    required this.current,
    required this.goal,
    required this.remaining,
    required this.percentage,
  });

  factory StepsData.empty() {
    return const StepsData(
      current: 0,
      goal: 10000,
      remaining: 10000,
      percentage: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'current': current,
    'goal': goal,
    'remaining': remaining,
    'percentage': percentage,
  };

  factory StepsData.fromJson(Map<String, dynamic> json) {
    return StepsData(
      current: json['current']?.toInt() ?? 0,
      goal: json['goal']?.toInt() ?? 10000,
      remaining: json['remaining']?.toInt() ?? 10000,
      percentage: json['percentage']?.toDouble() ?? 0,
    );
  }
}

class WaterIntakeData {
  final double current; // in ml
  final double goal;
  final double remaining;
  final double percentage;

  const WaterIntakeData({
    required this.current,
    required this.goal,
    required this.remaining,
    required this.percentage,
  });

  factory WaterIntakeData.empty() {
    return const WaterIntakeData(
      current: 0,
      goal: 2000,
      remaining: 2000,
      percentage: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'current': current,
    'goal': goal,
    'remaining': remaining,
    'percentage': percentage,
  };

  factory WaterIntakeData.fromJson(Map<String, dynamic> json) {
    return WaterIntakeData(
      current: json['current']?.toDouble() ?? 0,
      goal: json['goal']?.toDouble() ?? 2000,
      remaining: json['remaining']?.toDouble() ?? 2000,
      percentage: json['percentage']?.toDouble() ?? 0,
    );
  }
}

class SleepData {
  final double duration; // in hours
  final double quality; // 0-10 scale
  final DateTime? bedtime;
  final DateTime? wakeTime;

  const SleepData({
    required this.duration,
    required this.quality,
    this.bedtime,
    this.wakeTime,
  });

  factory SleepData.empty() {
    return const SleepData(duration: 0, quality: 0);
  }

  Map<String, dynamic> toJson() => {
    'duration': duration,
    'quality': quality,
    'bedtime': bedtime?.toIso8601String(),
    'wakeTime': wakeTime?.toIso8601String(),
  };

  factory SleepData.fromJson(Map<String, dynamic> json) {
    return SleepData(
      duration: json['duration']?.toDouble() ?? 0,
      quality: json['quality']?.toDouble() ?? 0,
      bedtime: json['bedtime'] != null ? DateTime.parse(json['bedtime']) : null,
      wakeTime:
          json['wakeTime'] != null ? DateTime.parse(json['wakeTime']) : null,
    );
  }
}

class HeartRateData {
  final double average;
  final double resting;
  final double max;
  final Map<String, dynamic> zones;

  const HeartRateData({
    required this.average,
    required this.resting,
    required this.max,
    required this.zones,
  });

  factory HeartRateData.empty() {
    return const HeartRateData(average: 0, resting: 0, max: 0, zones: {});
  }

  Map<String, dynamic> toJson() => {
    'average': average,
    'resting': resting,
    'max': max,
    'zones': zones,
  };

  factory HeartRateData.fromJson(Map<String, dynamic> json) {
    return HeartRateData(
      average: json['average']?.toDouble() ?? 0,
      resting: json['resting']?.toDouble() ?? 0,
      max: json['max']?.toDouble() ?? 0,
      zones: json['zones'] ?? {},
    );
  }
}

/// Summary classes for different time ranges
class DailyProgressSummary {
  final DateTime date;
  final ProgressData progressData;
  final List<String> achievements;
  final List<String> recommendations;

  const DailyProgressSummary({
    required this.date,
    required this.progressData,
    required this.achievements,
    required this.recommendations,
  });

  factory DailyProgressSummary.fromProgressData(
    ProgressData data,
    DateTime date,
  ) {
    return DailyProgressSummary(
      date: date,
      progressData: data,
      achievements: _generateAchievements(data),
      recommendations: _generateRecommendations(data),
    );
  }

  static List<String> _generateAchievements(ProgressData data) {
    final achievements = <String>[];

    if (data.calories.percentage >= 1.0) {
      achievements.add('🎯 Calorie goal achieved!');
    }
    if (data.steps.percentage >= 1.0) {
      achievements.add('🚶 Step goal achieved!');
    }
    if (data.waterIntake.percentage >= 1.0) {
      achievements.add('💧 Hydration goal achieved!');
    }
    if (data.exercise.duration >= 30) {
      achievements.add('💪 Exercise goal achieved!');
    }

    return achievements;
  }

  static List<String> _generateRecommendations(ProgressData data) {
    final recommendations = <String>[];

    if (data.calories.percentage < 0.5) {
      recommendations.add(
        'Consider adding a healthy snack to reach your calorie goal',
      );
    }
    if (data.steps.percentage < 0.5) {
      recommendations.add(
        'Try taking a short walk to increase your step count',
      );
    }
    if (data.waterIntake.percentage < 0.5) {
      recommendations.add('Remember to stay hydrated throughout the day');
    }
    if (data.exercise.duration < 15) {
      recommendations.add('Even 15 minutes of exercise can make a difference');
    }

    return recommendations;
  }
}

class WeeklyProgressSummary {
  final DateTime weekStart;
  final ProgressData progressData;
  final Map<String, double> weeklyAverages;
  final List<String> weeklyAchievements;

  const WeeklyProgressSummary({
    required this.weekStart,
    required this.progressData,
    required this.weeklyAverages,
    required this.weeklyAchievements,
  });

  factory WeeklyProgressSummary.fromProgressData(
    ProgressData data,
    DateTime weekStart,
  ) {
    return WeeklyProgressSummary(
      weekStart: weekStart,
      progressData: data,
      weeklyAverages: _calculateWeeklyAverages(data),
      weeklyAchievements: _generateWeeklyAchievements(data),
    );
  }

  static Map<String, double> _calculateWeeklyAverages(ProgressData data) {
    return {
      'calories': data.calories.current,
      'steps': data.steps.current.toDouble(),
      'exercise': data.exercise.duration.toDouble(),
      'water': data.waterIntake.current,
    };
  }

  static List<String> _generateWeeklyAchievements(ProgressData data) {
    final achievements = <String>[];

    if (data.exercise.sessions >= 5) {
      achievements.add('🏆 Consistent exercise week!');
    }
    if (data.steps.current >= 70000) {
      achievements.add('🚶 Great step count this week!');
    }

    return achievements;
  }
}

class MonthlyProgressSummary {
  final DateTime monthStart;
  final ProgressData progressData;
  final Map<String, double> monthlyTrends;
  final List<String> monthlyAchievements;

  const MonthlyProgressSummary({
    required this.monthStart,
    required this.progressData,
    required this.monthlyTrends,
    required this.monthlyAchievements,
  });

  factory MonthlyProgressSummary.fromProgressData(
    ProgressData data,
    DateTime monthStart,
  ) {
    return MonthlyProgressSummary(
      monthStart: monthStart,
      progressData: data,
      monthlyTrends: _calculateMonthlyTrends(data),
      monthlyAchievements: _generateMonthlyAchievements(data),
    );
  }

  static Map<String, double> _calculateMonthlyTrends(ProgressData data) {
    return {
      'calories': data.calories.current,
      'steps': data.steps.current.toDouble(),
      'exercise': data.exercise.duration.toDouble(),
      'water': data.waterIntake.current,
    };
  }

  static List<String> _generateMonthlyAchievements(ProgressData data) {
    final achievements = <String>[];

    if (data.exercise.sessions >= 20) {
      achievements.add('🏆 Excellent exercise consistency this month!');
    }
    if (data.steps.current >= 300000) {
      achievements.add('🚶 Outstanding step count this month!');
    }

    return achievements;
  }
}
