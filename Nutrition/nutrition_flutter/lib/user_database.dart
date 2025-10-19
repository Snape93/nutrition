import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart' as config;

// Use centralized API base from config.dart

class UserDatabase {
  static final UserDatabase _instance = UserDatabase._internal();
  factory UserDatabase() => _instance;
  UserDatabase._internal();

  // Remove keys that have null values from a Map for cleaner consumers/logs
  static Map<String, dynamic> _stripNulls(Map<String, dynamic> source) {
    final cleaned = <String, dynamic>{};
    source.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned;
  }

  // API-based authentication methods
  Future<bool> login(String usernameOrEmail, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username_or_email': usernameOrEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
              'full_name': fullName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  Future<bool> usernameExists(String username) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${config.apiBase}/user/check-username?username=$username',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Username check error: $e');
      return false;
    }
  }

  Future<bool> emailExists(String email) async {
    try {
      final response = await http
          .get(
            Uri.parse('${config.apiBase}/user/check-email?email=$email'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Email check error: $e');
      return false;
    }
  }

  Future<bool> hasSeenTutorial(String usernameOrEmail) async {
    try {
      final userData = await getUserData(usernameOrEmail);
      return userData?['has_seen_tutorial'] == true;
    } catch (e) {
      debugPrint('Tutorial check error: $e');
      return false;
    }
  }

  Future<void> markTutorialAsSeen(String usernameOrEmail) async {
    try {
      await http
          .put(
            Uri.parse('${config.apiBase}/user/$usernameOrEmail'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'has_seen_tutorial': true}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Mark tutorial seen error: $e');
    }
  }

  /// Get user data from backend API
  Future<Map<String, dynamic>?> getUserData(String usernameOrEmail) async {
    try {
      final response = await http
          .get(
            Uri.parse('${config.apiBase}/user/$usernameOrEmail'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return _stripNulls(Map<String, dynamic>.from(data['user']));
        }
      }
    } catch (e) {
      debugPrint('Get user data error: $e');
    }

    return null;
  }

  /// Check if user profile is complete by checking backend
  Future<bool> isProfileComplete(String usernameOrEmail) async {
    try {
      final userData = await getUserData(usernameOrEmail);
      if (userData == null) return false;

      // Check if all required fields are filled
      final requiredFields = [
        'age',
        'sex',
        'weight_kg',
        'height_cm',
        'activity_level',
        'goal',
      ];
      for (final field in requiredFields) {
        if (userData[field] == null || userData[field].toString().isEmpty) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Profile complete check error: $e');
      return false;
    }
  }

  Future<void> updateThemeMode(String usernameOrEmail, String themeMode) async {
    try {
      await http
          .put(
            Uri.parse('${config.apiBase}/user/$usernameOrEmail'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'theme_mode': themeMode}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Update theme mode error: $e');
    }
  }

  Future<String> getThemeMode(String usernameOrEmail) async {
    try {
      final userData = await getUserData(usernameOrEmail);
      return userData?['theme_mode'] ?? 'system';
    } catch (e) {
      debugPrint('Get theme mode error: $e');
      return 'system';
    }
  }

  // Food logging methods using API
  Future<bool> logFood({
    required String usernameOrEmail,
    required String foodName,
    required double calories,
    String? mealType,
    String? servingSize,
    double quantity = 1.0,
    double protein = 0.0,
    double carbs = 0.0,
    double fat = 0.0,
    double fiber = 0.0,
    double sodium = 0.0,
    DateTime? date,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/log/food'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user': usernameOrEmail,
              'food_name': foodName,
              'calories': calories,
              'meal_type': mealType,
              'serving_size': servingSize,
              'quantity': quantity,
              'protein': protein,
              'carbs': carbs,
              'fat': fat,
              'fiber': fiber,
              'sodium': sodium,
              'date':
                  date?.toIso8601String().split('T')[0] ??
                  DateTime.now().toIso8601String().split('T')[0],
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Log food error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFoodLogs(
    String usernameOrEmail, {
    DateTime? date,
  }) async {
    try {
      final dateStr =
          date?.toIso8601String().split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0];
      final response = await http
          .get(
            Uri.parse(
              '${config.apiBase}/log/food?user=$usernameOrEmail&date=$dateStr',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['logs'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Get food logs error: $e');
      return [];
    }
  }

  // Exercise logging methods using API
  Future<bool> logExercise({
    required String usernameOrEmail,
    required String exerciseName,
    required int duration,
    String? category,
    String? intensity,
    int? calories,
    DateTime? date,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/log/exercise'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user': usernameOrEmail,
              'exercise_name': exerciseName,
              'duration': duration,
              'category': category,
              'intensity': intensity,
              'calories': calories,
              'date':
                  date?.toIso8601String().split('T')[0] ??
                  DateTime.now().toIso8601String().split('T')[0],
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Log exercise error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getExerciseLogs(
    String usernameOrEmail, {
    DateTime? date,
  }) async {
    try {
      final dateStr =
          date?.toIso8601String().split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0];
      final response = await http
          .get(
            Uri.parse(
              '${config.apiBase}/log/exercise?user=$usernameOrEmail&date=$dateStr',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['logs'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Get exercise logs error: $e');
      return [];
    }
  }

  // Weight logging methods using API
  Future<bool> logWeight({
    required String usernameOrEmail,
    required double weight,
    DateTime? date,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/log/weight'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user': usernameOrEmail,
              'weight': weight,
              'date':
                  date?.toIso8601String().split('T')[0] ??
                  DateTime.now().toIso8601String().split('T')[0],
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Log weight error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getWeightLogs(
    String usernameOrEmail, {
    int? limit,
  }) async {
    try {
      final url =
          '${config.apiBase}/log/weight?user=$usernameOrEmail${limit != null ? '&limit=$limit' : ''}';
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['logs'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Get weight logs error: $e');
      return [];
    }
  }

  // Additional methods for compatibility
  Future<String?> getUserSex(String usernameOrEmail) async {
    try {
      final userData = await getUserData(usernameOrEmail);
      return userData?['sex'];
    } catch (e) {
      debugPrint('Get user sex error: $e');
      return null;
    }
  }

  Future<int> getDailyCalorieGoal(String usernameOrEmail) async {
    try {
      final userData = await getUserData(usernameOrEmail);
      return userData?['daily_calorie_goal'] ?? 2000;
    } catch (e) {
      debugPrint('Get daily calorie goal error: $e');
      return 2000;
    }
  }

  Future<int> getDailyCalorieGoalLocal(String usernameOrEmail) async {
    return await getDailyCalorieGoal(usernameOrEmail);
  }

  Future<int> getTodayFoodCaloriesLocal(String usernameOrEmail) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${config.apiBase}/log/food?user=$usernameOrEmail&date=${DateTime.now().toIso8601String().split('T')[0]}',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final totals = data['totals'] ?? {};
        return (totals['calories'] ?? 0).toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('Get today food calories error: $e');
      return 0;
    }
  }

  Future<void> setDailyCalorieGoal(String usernameOrEmail, int goal) async {
    try {
      await http
          .put(
            Uri.parse('${config.apiBase}/user/$usernameOrEmail'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'daily_calorie_goal': goal}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Set daily calorie goal error: $e');
    }
  }

  Future<bool> saveFoodLog({
    required String usernameOrEmail,
    required String foodName,
    required dynamic calories, // Can be double or int
    String? mealType,
    String? servingSize,
    double quantity = 1.0,
    double protein = 0.0,
    double carbs = 0.0,
    double fat = 0.0,
    double fiber = 0.0,
    double sodium = 0.0,
    DateTime? date,
    dynamic timestamp, // Added for compatibility (can be DateTime or int)
  }) async {
    return await logFood(
      usernameOrEmail: usernameOrEmail,
      foodName: foodName,
      calories: calories.toDouble(),
      mealType: mealType,
      servingSize: servingSize,
      quantity: quantity,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      date: date,
    );
  }

  Future<bool> deleteFoodLogById(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${config.apiBase}/log/food/$id'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete food log error: $e');
      return false;
    }
  }

  Future<bool> saveCustomExercise({
    required String usernameOrEmail,
    required String name,
    String? category,
    String? intensity,
    int? duration,
    int? reps,
    int? sets,
    String? notes,
    int? calories,
    int? durationMin, // Added for compatibility
    int? estCalories, // Added for compatibility
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/exercises/custom'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user': usernameOrEmail,
              'name': name,
              'category': category,
              'intensity': intensity,
              'duration': duration ?? durationMin,
              'reps': reps,
              'sets': sets,
              'notes': notes,
              'calories': calories ?? estCalories,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Save custom exercise error: $e');
      return false;
    }
  }

  // Database getter for compatibility (returns null since we use API)
  dynamic get database => null;
}
