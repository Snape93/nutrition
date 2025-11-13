/// Streak data model for tracking consecutive days of meeting goals
class StreakData {
  final int id;
  final String user;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final DateTime? streakStartDate;
  final String streakType; // 'calories' or 'exercise'
  final int minimumExerciseMinutes;
  final int? daysSinceStart;
  final int? daysSinceBreak;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StreakData({
    required this.id,
    required this.user,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
    this.streakStartDate,
    required this.streakType,
    required this.minimumExerciseMinutes,
    this.daysSinceStart,
    this.daysSinceBreak,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Create StreakData from JSON response
  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      id: json['id'] as int,
      user: json['user'] as String,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      streakStartDate: json['streak_start_date'] != null
          ? DateTime.parse(json['streak_start_date'] as String)
          : null,
      streakType: json['streak_type'] as String? ?? 'calories',
      minimumExerciseMinutes: json['minimum_exercise_minutes'] as int? ?? 15,
      daysSinceStart: json['days_since_start'] as int?,
      daysSinceBreak: json['days_since_break'] as int?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert StreakData to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'streak_start_date': streakStartDate?.toIso8601String(),
      'streak_type': streakType,
      'minimum_exercise_minutes': minimumExerciseMinutes,
      'days_since_start': daysSinceStart,
      'days_since_break': daysSinceBreak,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Get display name for streak type
  String get streakTypeDisplayName {
    switch (streakType.toLowerCase()) {
      case 'calories':
        return 'Calories';
      case 'exercise':
        return 'Exercise';
      default:
        return streakType;
    }
  }

  /// Get motivational message based on streak length
  String get motivationalMessage {
    if (currentStreak == 0) {
      if (longestStreak > 0) {
        return 'Start a new streak today and beat your record of $longestStreak days!';
      }
      return 'Start your streak today!';
    }

    if (currentStreak >= 100) {
      return '👑 100+ days! You\'re a streak master! This is legendary!';
    } else if (currentStreak >= 50) {
      return '⭐ $currentStreak days! Incredible dedication! You\'re inspiring!';
    } else if (currentStreak >= 30) {
      return '🏆 $currentStreak-day milestone! You\'re a streak legend! Keep it up!';
    } else if (currentStreak >= 14) {
      return '💪 Two weeks! You\'re unstoppable! $currentStreak days and counting!';
    } else if (currentStreak >= 7) {
      return '🔥 One week strong! You\'ve maintained your streak for $currentStreak days!';
    } else if (currentStreak >= 4) {
      return 'You\'re building momentum!';
    } else {
      return 'Great start! Keep it up!';
    }
  }

  /// Check if streak is at a milestone
  bool isMilestone(int days) {
    return currentStreak == days;
  }

  /// Get next milestone
  int? get nextMilestone {
    if (currentStreak < 7) return 7;
    if (currentStreak < 14) return 14;
    if (currentStreak < 30) return 30;
    if (currentStreak < 50) return 50;
    if (currentStreak < 100) return 100;
    return null;
  }

  /// Get days until next milestone
  int? get daysUntilNextMilestone {
    final next = nextMilestone;
    if (next == null) return null;
    return next - currentStreak;
  }
}

/// Streak update request model
class StreakUpdateRequest {
  final String user;
  final String streakType;
  final DateTime? date;
  final bool? metGoal;
  final int? exerciseMinutes;
  final int? minimumExerciseMinutes;

  StreakUpdateRequest({
    required this.user,
    required this.streakType,
    this.date,
    this.metGoal,
    this.exerciseMinutes,
    this.minimumExerciseMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'streak_type': streakType,
      if (date != null) 'date': date!.toIso8601String().split('T')[0],
      if (metGoal != null) 'met_goal': metGoal,
      if (exerciseMinutes != null) 'exercise_minutes': exerciseMinutes,
      if (minimumExerciseMinutes != null)
        'minimum_exercise_minutes': minimumExerciseMinutes,
    };
  }
}

/// Streak update response model
class StreakUpdateResponse {
  final bool success;
  final bool streakUpdated;
  final int currentStreak;
  final int longestStreak;
  final String message;

  StreakUpdateResponse({
    required this.success,
    required this.streakUpdated,
    required this.currentStreak,
    required this.longestStreak,
    required this.message,
  });

  factory StreakUpdateResponse.fromJson(Map<String, dynamic> json) {
    return StreakUpdateResponse(
      success: json['success'] as bool? ?? false,
      streakUpdated: json['streak_updated'] as bool? ?? false,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}


