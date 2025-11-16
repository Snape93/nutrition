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

      // Aggregate exercise data first (needed for calories calculation)
      final exerciseData = _aggregateExerciseData(
        backendData,
        healthData,
        googleFitData,
      );

      // Aggregate all data
      final caloriesData = _aggregateCaloriesData(backendData, userGoals, exerciseData, dateRange);
      
      // Generate breakdowns based on time range
      final dailyBreakdown = timeRange == TimeRange.weekly 
          ? _generateDailyBreakdown(backendData, dateRange)
          : null;
      final weeklyBreakdown = timeRange == TimeRange.monthly
          ? _generateWeeklyBreakdown(backendData, dateRange)
          : null;
      
      final progressData = ProgressData(
        username: usernameOrEmail,
        timeRange: timeRange,
        dateRange: dateRange,
        calories: caloriesData,
        weight: _aggregateWeightData(backendData),
        exercise: exerciseData,
        steps: _aggregateStepsData(healthData, googleFitData),
        waterIntake: _aggregateWaterData(backendData, userGoals),
        sleep: _aggregateSleepData(healthData),
        heartRate: _aggregateHeartRateData(healthData),
        goals: userGoals,
        dailyBreakdown: dailyBreakdown,
        weeklyBreakdown: weeklyBreakdown,
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

  /// Get user's first food log date (when they started tracking)
  static Future<DateTime?> getUserStartDate({
    required String usernameOrEmail,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/progress/start-date?user=$usernameOrEmail');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['has_data'] == true) {
          final startDateStr = body['start_date'] as String?;
          if (startDateStr != null) {
            return DateTime.parse(startDateStr);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user start date: $e');
      return null;
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

  /// Public method to clear cache (useful after adding data)
  static void clearCache() {
    _clearCache();
  }

  static DateRange _calculateDateRange(
    TimeRange timeRange,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final now = DateTime.now();
    // Normalize to start of day (00:00:00) for accurate date comparisons
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (timeRange) {
      case TimeRange.daily:
        // Use start and end of today to capture all exercises for today
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateRange(todayStart, todayEnd);
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

  /// Fetch raw backend data for bar graph (public method)
  static Future<Map<String, dynamic>> fetchRawBackendData(
    String username,
    DateRange dateRange,
  ) async {
    return await _fetchBackendData(username, dateRange);
  }

  static Future<Map<String, dynamic>> _fetchBackendData(
    String username,
    DateRange dateRange,
  ) async {
    try {
      // Try aggregated endpoint first
      final aggUri = Uri.parse(
        '$apiBase/progress/all?user=$username&start=${dateRange.start.toIso8601String()}&end=${dateRange.end.toIso8601String()}',
      );
      try {
        final aggResp = await http
            .get(aggUri)
            .timeout(const Duration(seconds: 6));
        if (aggResp.statusCode == 200) {
          final body = json.decode(aggResp.body) as Map<String, dynamic>;
          final calories = body['calories'] ?? [];
          final weight = body['weight'] ?? [];
          final workouts = body['workouts'] ?? [];
          debugPrint('📊 Backend data received via /progress/all');
          return {
            'calories': calories,
            'weight': weight,
            'workouts': workouts,
          };
        }
      } catch (_) {
        // fall through to legacy multi-call path
      }

      // Fallback: perform three parallel requests
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

  static Future<Map<String, dynamic>> _fetchUserGoals(
    String username, {
    DateTime? targetDate,
  }) async {
    try {
      String url = '$apiBase/progress/goals?user=$username';
      
      // Add date parameter if provided (for historical goals)
      if (targetDate != null) {
        final dateStr = targetDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
        url += '&date=$dateStr';
      }
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Convert all numeric values to double to avoid type errors
        return {
          'calories': _safeToDouble(data['calories'] ?? 2000),
          'steps': _safeToDouble(data['steps'] ?? 10000),
          'water': _safeToDouble(data['water'] ?? 2000),
          'exercise': _safeToDouble(data['exercise'] ?? 30),
          'sleep': _safeToDouble(data['sleep'] ?? 8),
        };
      }
      return _getDefaultGoals();
    } catch (e) {
      debugPrint('❌ Error fetching user goals: $e');
      return _getDefaultGoals();
    }
  }

  /// Fetch user goal for a specific date (for historical goals)
  static Future<double> fetchGoalForDate(
    String usernameOrEmail,
    DateTime targetDate,
  ) async {
    try {
      final goals = await _fetchUserGoals(usernameOrEmail, targetDate: targetDate);
      return _safeToDouble(goals['calories'] ?? 2000);
    } catch (e) {
      debugPrint('❌ Error fetching goal for date: $e');
      return 2000.0;
    }
  }

  /// Safely convert a value to double, handling both int and double types
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
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
    ExerciseData exerciseData,
    DateRange dateRange,
  ) {
    final calories = backendData['calories'] as List<dynamic>;
    final totalCalories = calories.fold<double>(
      0,
      (sum, entry) {
        final value = entry['calories'];
        return sum + _safeToDouble(value);
      },
    );
    
    // Get daily goal and multiply by number of days in the range
    final dailyGoal = _safeToDouble(goals['calories'] ?? 2000);
    final daysInRange = dateRange.end.difference(dateRange.start).inDays + 1;
    final goal = dailyGoal * daysInRange;
    
    // Calculate remaining: goal - food + exercise (MyFitnessPal style)
    // This allows negative values when user exceeds goal
    final remaining = goal - totalCalories + exerciseData.caloriesBurned;
    
    // Percentage can exceed 1.0 when goal is exceeded
    final percentage = goal > 0 ? (totalCalories / goal) : 0;

    return CaloriesData(
      current: totalCalories,
      goal: goal,
      remaining: remaining, // Allow negative values
      percentage: percentage.toDouble(), // Allow > 1.0 when exceeded
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
      current: _safeToDouble(latest['weight'] ?? 0),
      previous: previous != null ? _safeToDouble(previous['weight']) : null,
      change: previous != null 
          ? (_safeToDouble(latest['weight']) - _safeToDouble(previous['weight']))
          : 0,
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
      (sum, workout) {
        final value = workout['calories_burned'] ?? 0;
        return sum + _safeToDouble(value);
      },
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
    final goal = _safeToDouble(goals['water'] ?? 2000);

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
      duration: _safeToDouble(sleepData['duration'] ?? 0),
      quality: _safeToDouble(sleepData['quality'] ?? 0),
      bedtime: sleepData['bedtime'],
      wakeTime: sleepData['wakeTime'],
    );
  }

  static HeartRateData _aggregateHeartRateData(
    Map<String, dynamic> healthData,
  ) {
    final heartRateData = healthData['heartRate'] ?? {};

    return HeartRateData(
      average: _safeToDouble(heartRateData['average'] ?? 0),
      resting: _safeToDouble(heartRateData['resting'] ?? 0),
      max: _safeToDouble(heartRateData['max'] ?? 0),
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

  // Breakdown generation methods

  /// Generate daily breakdown for weekly view (7 days)
  static List<DailyBreakdownData>? _generateDailyBreakdown(
    Map<String, dynamic> backendData,
    DateRange dateRange,
  ) {
    final calories = backendData['calories'] as List<dynamic>;
    if (calories.isEmpty) return null;

    // Group calories by date
    // FIXED: Parse dates as date-only to prevent timezone conversion issues
    final Map<String, double> dailyTotals = {};
    for (final entry in calories) {
      final dateStr = entry['date'] as String;
      
      // Parse date string and extract date components without timezone conversion
      // This prevents dates from shifting when converted to local timezone
      DateTime parsedDate;
      try {
        // Try parsing as ISO date string (YYYY-MM-DD)
        if (dateStr.contains('T')) {
          // Has time component, extract date part only
          parsedDate = DateTime.parse(dateStr.split('T')[0]);
        } else {
          // Date-only string, parse directly
          parsedDate = DateTime.parse(dateStr);
        }
        // Use UTC to avoid timezone shifts, then extract date components
        // This ensures consistent date grouping regardless of device timezone
        final date = DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final calValue = _safeToDouble(entry['calories'] ?? 0);
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + calValue;
      } catch (e) {
        // If parsing fails, skip this entry and log warning
        debugPrint('⚠️ Failed to parse date: $dateStr, error: $e');
        continue;
      }
    }

    // Generate breakdown for all 7 days of the week
    final List<DailyBreakdownData> breakdown = [];
    final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 7; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (currentDate.isAfter(todayDate)) {
        break;
      }
      final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      final dayName = _getDayName(currentDate.weekday);
      
      breakdown.add(DailyBreakdownData(
        date: currentDate,
        calories: dailyTotals[dateKey] ?? 0.0,
        dayName: dayName,
      ));
    }

    return breakdown;
  }

  /// Generate weekly breakdown for monthly view (4-5 weeks)
  static List<WeeklyBreakdownData>? _generateWeeklyBreakdown(
    Map<String, dynamic> backendData,
    DateRange dateRange,
  ) {
    final calories = backendData['calories'] as List<dynamic>;
    if (calories.isEmpty) return null;

    // Group calories by week
    // FIXED: Parse dates as date-only to prevent timezone conversion issues
    final Map<String, double> weeklyTotals = {};
    for (final entry in calories) {
      final dateStr = entry['date'] as String;
      
      // Parse date string and extract date components without timezone conversion
      DateTime parsedDate;
      try {
        // Try parsing as ISO date string (YYYY-MM-DD)
        if (dateStr.contains('T')) {
          // Has time component, extract date part only
          parsedDate = DateTime.parse(dateStr.split('T')[0]);
        } else {
          // Date-only string, parse directly
          parsedDate = DateTime.parse(dateStr);
        }
        // Use UTC to avoid timezone shifts, then extract date components
        final date = DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day);
        final weekStart = _getWeekStart(date);
        final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
        final calValue = _safeToDouble(entry['calories'] ?? 0);
        weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) + calValue;
      } catch (e) {
        // If parsing fails, skip this entry and log warning
        debugPrint('⚠️ Failed to parse date: $dateStr, error: $e');
        continue;
      }
    }

    // Generate breakdown for all weeks in the month
    final List<WeeklyBreakdownData> breakdown = [];
    final monthStart = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final monthEnd = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
    
    var currentWeekStart = _getWeekStart(monthStart);
    int weekNumber = 1;
    
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    while (currentWeekStart.isBefore(monthEnd) || currentWeekStart.isAtSameMomentAs(monthEnd)) {
      if (currentWeekStart.isAfter(todayDate)) {
        break;
      }
      final weekEnd = currentWeekStart.add(const Duration(days: 6));
      final weekKey = '${currentWeekStart.year}-${currentWeekStart.month}-${currentWeekStart.day}';
      
      breakdown.add(WeeklyBreakdownData(
        weekStart: currentWeekStart,
        weekEnd: weekEnd,
        calories: weeklyTotals[weekKey] ?? 0.0,
        weekLabel: 'Week $weekNumber',
      ));
      
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
      weekNumber++;
      
      // Limit to 5 weeks max
      if (weekNumber > 5) break;
    }

    return breakdown;
  }

  static String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  // Bar graph aggregation methods

  /// Aggregate data for bar graph - Daily view
  static List<GraphDataPoint> aggregateDailyDataForBarGraph(
    List<Map<String, dynamic>> rawData,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Group by date
    final Map<String, double> dailyTotals = {};
    for (final entry in rawData) {
      try {
        final dateStr = entry['date'] as String? ?? '';
        if (dateStr.isEmpty) continue;
        
        DateTime parsedDate;
        if (dateStr.contains('T')) {
          parsedDate = DateTime.parse(dateStr.split('T')[0]);
        } else {
          parsedDate = DateTime.parse(dateStr);
        }
        final dateKey = '${parsedDate.year}-${parsedDate.month}-${parsedDate.day}';
        final value = _safeToDouble(entry['calories'] ?? 0);
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + value;
      } catch (e) {
        debugPrint('⚠️ Failed to parse date in daily aggregation: $e');
        continue;
      }
    }

    // Fill missing dates with 0
    final List<GraphDataPoint> result = [];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      final dateKey = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
      final value = dailyTotals[dateKey] ?? 0.0;
      final dayName = _getDayName(currentDate.weekday);
      
      result.add(GraphDataPoint(
        date: currentDate,
        value: value,
        label: dayName,
      ));
      
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return result;
  }

  /// Aggregate data for bar graph - Weekly view
  /// Returns average daily calories per week (not total)
  static List<GraphDataPoint> aggregateWeeklyDataForBarGraph(
    List<Map<String, dynamic>> rawData,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Group by week - track totals and day counts
    final Map<String, double> weeklyTotals = {};
    final Map<String, int> weeklyDayCounts = {};
    
    for (final entry in rawData) {
      try {
        final dateStr = entry['date'] as String? ?? '';
        if (dateStr.isEmpty) continue;
        
        DateTime parsedDate;
        if (dateStr.contains('T')) {
          parsedDate = DateTime.parse(dateStr.split('T')[0]);
        } else {
          parsedDate = DateTime.parse(dateStr);
        }
        final weekStart = _getWeekStart(parsedDate);
        final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
        final value = _safeToDouble(entry['calories'] ?? 0);
        
        // Sum calories and count days
        weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) + value;
        weeklyDayCounts[weekKey] = (weeklyDayCounts[weekKey] ?? 0) + 1;
      } catch (e) {
        debugPrint('⚠️ Failed to parse date in weekly aggregation: $e');
        continue;
      }
    }

    // Generate weeks in range
    final List<GraphDataPoint> result = [];
    var currentWeekStart = _getWeekStart(startDate);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    int weekNumber = 1;
    
    while (currentWeekStart.isBefore(end) || currentWeekStart.isAtSameMomentAs(end)) {
      final weekKey = '${currentWeekStart.year}-${currentWeekStart.month}-${currentWeekStart.day}';
      final weekEnd = currentWeekStart.add(const Duration(days: 6));
      
      // Calculate actual days in this week (handle partial weeks)
      final actualWeekEnd = weekEnd.isAfter(end) ? end : weekEnd;
      final daysInWeek = actualWeekEnd.difference(currentWeekStart).inDays + 1;
      
      // Get total and day count for this week
      final total = weeklyTotals[weekKey] ?? 0.0;
      final dayCount = weeklyDayCounts[weekKey] ?? 0;
      
      // Calculate average daily calories (use actual days in week, not just days with data)
      // If no data, return 0.0; otherwise divide total by actual days in week
      final averageValue = (dayCount > 0 && daysInWeek > 0) 
          ? total / daysInWeek 
          : 0.0;
      
      result.add(GraphDataPoint(
        date: currentWeekStart,
        value: averageValue,
        label: 'Week $weekNumber',
        metadata: {
          'weekStart': currentWeekStart.toIso8601String(),
          'weekEnd': weekEnd.toIso8601String(),
          'daysInWeek': daysInWeek,
          'totalCalories': total,
        },
      ));
      
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
      weekNumber++;
      
      // Limit to 5 weeks max
      if (weekNumber > 5) break;
    }

    return result;
  }

  /// Aggregate data for bar graph - Monthly view
  /// Returns average daily calories per month (not total)
  static List<GraphDataPoint> aggregateMonthlyDataForBarGraph(
    List<Map<String, dynamic>> rawData,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Group by month - track totals and day counts
    final Map<String, double> monthlyTotals = {};
    final Map<String, int> monthlyDayCounts = {};
    
    for (final entry in rawData) {
      try {
        final dateStr = entry['date'] as String? ?? '';
        if (dateStr.isEmpty) continue;
        
        DateTime parsedDate;
        if (dateStr.contains('T')) {
          parsedDate = DateTime.parse(dateStr.split('T')[0]);
        } else {
          parsedDate = DateTime.parse(dateStr);
        }
        final monthKey = '${parsedDate.year}-${parsedDate.month}';
        final value = _safeToDouble(entry['calories'] ?? 0);
        
        // Sum calories and count days
        monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + value;
        monthlyDayCounts[monthKey] = (monthlyDayCounts[monthKey] ?? 0) + 1;
      } catch (e) {
        debugPrint('⚠️ Failed to parse date in monthly aggregation: $e');
        continue;
      }
    }

    // Generate months in range
    final List<GraphDataPoint> result = [];
    var currentMonth = DateTime(startDate.year, startDate.month, 1);
    final end = DateTime(endDate.year, endDate.month, 1);
    
    while (currentMonth.isBefore(end) || currentMonth.isAtSameMomentAs(end)) {
      final monthKey = '${currentMonth.year}-${currentMonth.month}';
      final monthName = _getMonthName(currentMonth.month);
      
      // Calculate actual days in this month (handle partial months)
      DateTime monthEnd;
      if (currentMonth.month == 12) {
        monthEnd = DateTime(currentMonth.year + 1, 1, 0); // Last day of December
      } else {
        monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0); // Last day of month
      }
      
      // Handle partial months at start/end of range
      final actualMonthStart = currentMonth.isBefore(startDate) ? startDate : currentMonth;
      final actualMonthEnd = monthEnd.isAfter(endDate) ? endDate : monthEnd;
      final daysInMonth = actualMonthEnd.difference(actualMonthStart).inDays + 1;
      
      // Get total and day count for this month
      final total = monthlyTotals[monthKey] ?? 0.0;
      final dayCount = monthlyDayCounts[monthKey] ?? 0;
      
      // Calculate average daily calories (use actual days in month, not just days with data)
      // If no data, return 0.0; otherwise divide total by actual days in month
      final averageValue = (dayCount > 0 && daysInMonth > 0) 
          ? total / daysInMonth 
          : 0.0;
      
      result.add(GraphDataPoint(
        date: currentMonth,
        value: averageValue,
        label: monthName,
        metadata: {
          'monthStart': currentMonth.toIso8601String(),
          'monthEnd': monthEnd.toIso8601String(),
          'daysInMonth': daysInMonth,
          'totalCalories': total,
        },
      ));
      
      // Move to next month
      if (currentMonth.month == 12) {
        currentMonth = DateTime(currentMonth.year + 1, 1, 1);
      } else {
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      }
      
      // Limit to 12 months max
      if (result.length >= 12) break;
    }

    return result;
  }

  /// Aggregate data for bar graph - Custom view (same as daily)
  static List<GraphDataPoint> aggregateCustomDataForBarGraph(
    List<Map<String, dynamic>> rawData,
    DateTime startDate,
    DateTime endDate,
  ) {
    return aggregateDailyDataForBarGraph(rawData, startDate, endDate);
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  static String _formatDateRange(DateTime start, DateTime end) {
    return '${start.day}/${end.day}';
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

/// Daily breakdown data for weekly view
class DailyBreakdownData {
  final DateTime date;
  final double calories;
  final String dayName;

  const DailyBreakdownData({
    required this.date,
    required this.calories,
    required this.dayName,
  });
}

/// Weekly breakdown data for monthly view
class WeeklyBreakdownData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double calories;
  final String weekLabel;

  const WeeklyBreakdownData({
    required this.weekStart,
    required this.weekEnd,
    required this.calories,
    required this.weekLabel,
  });
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
  final List<DailyBreakdownData>? dailyBreakdown;
  final List<WeeklyBreakdownData>? weeklyBreakdown;
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
    this.dailyBreakdown,
    this.weeklyBreakdown,
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
      dailyBreakdown: null,
      weeklyBreakdown: null,
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
    // Use ProgressDataService helper for safe conversion
    // Note: We can't call static methods from here, so we'll inline the logic
    double safeToDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }
    
    return CaloriesData(
      current: safeToDouble(json['current'], 0),
      goal: safeToDouble(json['goal'], 2000),
      remaining: safeToDouble(json['remaining'], 2000),
      percentage: safeToDouble(json['percentage'], 0),
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
