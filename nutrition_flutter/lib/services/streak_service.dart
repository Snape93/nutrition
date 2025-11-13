import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/streak_model.dart';

/// Service for managing streak data and API interactions
class StreakService {
  /// Get user's streak data
  /// 
  /// [usernameOrEmail] - User identifier
  /// [streakType] - Optional filter by streak type ('calories' or 'exercise')
  /// [forceRefresh] - Force refresh from server, bypass cache
  static Future<List<StreakData>> getStreaks({
    required String usernameOrEmail,
    String? streakType,
    bool forceRefresh = false,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/api/streaks').replace(
        queryParameters: {
          'user': usernameOrEmail,
          if (streakType != null) 'type': streakType,
        },
      );

      debugPrint('🔥 Fetching streaks for $usernameOrEmail');
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        
        if (body['success'] == true) {
          final streaksList = body['streaks'] as List<dynamic>? ?? [];
          final streaks = streaksList
              .map((json) => StreakData.fromJson(json as Map<String, dynamic>))
              .toList();
          
          debugPrint('✅ Loaded ${streaks.length} streak(s)');
          return streaks;
        } else {
          debugPrint('❌ API returned success=false: ${body['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch streaks: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching streaks: $e');
      return [];
    }
  }

  /// Get a specific streak by type
  /// 
  /// Returns the first streak matching the type, or null if not found
  static Future<StreakData?> getStreakByType({
    required String usernameOrEmail,
    required String streakType,
  }) async {
    final streaks = await getStreaks(
      usernameOrEmail: usernameOrEmail,
      streakType: streakType,
    );
    
    if (streaks.isEmpty) {
      return null;
    }
    
    return streaks.firstWhere(
      (s) => s.streakType.toLowerCase() == streakType.toLowerCase(),
      orElse: () => streaks.first,
    );
  }

  /// Update streak when user logs activity
  /// 
  /// [request] - Streak update request with user, type, and goal status
  static Future<StreakUpdateResponse?> updateStreak(
    StreakUpdateRequest request,
  ) async {
    try {
      final uri = Uri.parse('$apiBase/api/streaks/update');
      
      debugPrint('🔥 Updating streak: ${request.streakType} for ${request.user}');
      
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        
        if (body['success'] == true) {
          final updateResponse = StreakUpdateResponse.fromJson(body);
          debugPrint('✅ Streak updated: ${updateResponse.currentStreak} days');
          return updateResponse;
        } else {
          debugPrint('❌ API returned success=false: ${body['error']}');
          return null;
        }
      } else {
        debugPrint('❌ Failed to update streak: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error updating streak: $e');
      return null;
    }
  }

  /// Check if streak needs updating
  /// 
  /// Returns information about whether streak should be updated
  static Future<Map<String, dynamic>?> checkStreak({
    required String usernameOrEmail,
    String? streakType,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/api/streaks/check').replace(
        queryParameters: {
          'user': usernameOrEmail,
          if (streakType != null) 'type': streakType,
        },
      );

      debugPrint('🔥 Checking streak status for $usernameOrEmail');
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        
        if (body['success'] == true) {
          return body['results'] as Map<String, dynamic>?;
        } else {
          debugPrint('❌ API returned success=false: ${body['error']}');
          return null;
        }
      } else {
        debugPrint('❌ Failed to check streak: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error checking streak: $e');
      return null;
    }
  }

  /// Update calories streak automatically
  /// 
  /// Checks if goal is met and updates streak accordingly
  static Future<StreakUpdateResponse?> updateCaloriesStreak({
    required String usernameOrEmail,
    DateTime? date,
  }) async {
    final request = StreakUpdateRequest(
      user: usernameOrEmail,
      streakType: 'calories',
      date: date,
      // met_goal will be calculated by backend
    );
    
    return updateStreak(request);
  }

  /// Update exercise streak automatically
  /// 
  /// Checks if goal is met and updates streak accordingly
  static Future<StreakUpdateResponse?> updateExerciseStreak({
    required String usernameOrEmail,
    DateTime? date,
    int? exerciseMinutes,
    int? minimumExerciseMinutes,
  }) async {
    final request = StreakUpdateRequest(
      user: usernameOrEmail,
      streakType: 'exercise',
      date: date,
      exerciseMinutes: exerciseMinutes,
      minimumExerciseMinutes: minimumExerciseMinutes,
      // met_goal will be calculated by backend
    );
    
    return updateStreak(request);
  }
}


