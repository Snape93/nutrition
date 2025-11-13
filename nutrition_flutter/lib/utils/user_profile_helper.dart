import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart' as config;

/// Helper class to fetch user profile data from backend
class UserProfileHelper {
  static Map<String, dynamic>? _cachedProfile;
  static String? _cachedUsername;

  /// Fetch complete user profile data from backend
  static Future<Map<String, dynamic>?> fetchUserProfileData(
    String usernameOrEmail,
  ) async {
    // Return cached data if available
    if (_cachedProfile != null && _cachedUsername == usernameOrEmail) {
      return _cachedProfile;
    }

    try {
      final response = await http.get(
        Uri.parse('${config.apiBase}/user/$usernameOrEmail'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          // Extract 'user' object from response if it exists
          final userData = data['user'] ?? data;
          _cachedProfile = userData is Map<String, dynamic> ? userData : data;
          _cachedUsername = usernameOrEmail;
          return _cachedProfile;
        }
      } else {
        debugPrint(
          'Failed to fetch user profile: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }

    return null;
  }

  /// Fetch user age from backend
  static Future<int?> fetchUserAge(String usernameOrEmail) async {
    final profile = await fetchUserProfileData(usernameOrEmail);
    if (profile != null) {
      final age = profile['age'];
      if (age != null) {
        if (age is int) {
          return age;
        } else if (age is String) {
          return int.tryParse(age);
        } else if (age is double) {
          return age.toInt();
        }
      }
    }
    return null;
  }

  /// Clear cached profile data
  static void clearCache() {
    _cachedProfile = null;
    _cachedUsername = null;
  }
}

