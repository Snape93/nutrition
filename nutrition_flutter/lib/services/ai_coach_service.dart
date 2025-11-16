import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Service for calling backend AI Coach endpoints.
///
/// For now these hit Flask endpoints which in turn call Groq / LLaMA 3.
class AiCoachService {
  static const String _baseUrl = apiBase;

  /// Get a daily AI summary for the given user.
  ///
  /// Returns a map with at least:
  ///  - summaryText: String
  ///  - tips: List<String>
  static Future<Map<String, dynamic>> getDailySummary({
    required String usernameOrEmail,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final ds =
        '${targetDate.year.toString().padLeft(4, '0')}-'
        '${targetDate.month.toString().padLeft(2, '0')}-'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$_baseUrl/ai/summary/daily');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user': usernameOrEmail,
              'date': ds,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint(
          'AI Coach summary failed: ${response.statusCode} ${response.body}',
        );
        throw Exception('AI summary request failed');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('AI Coach summary error: $e');
      rethrow;
    }
  }

  /// Get "what to eat next" suggestions for the user.
  ///
  /// Returns a map with at least:
  ///  - headline: String
  ///  - suggestions: List<String>
  ///  - explanation: String
  static Future<Map<String, dynamic>> getWhatToEatNext({
    required String usernameOrEmail,
    String? nextMealType,
  }) async {
    final uri = Uri.parse('$_baseUrl/ai/what-to-eat-next');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user': usernameOrEmail,
              if (nextMealType != null && nextMealType.isNotEmpty)
                'next_meal_type': nextMealType,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint(
          'AI Coach what-to-eat-next failed: ${response.statusCode} ${response.body}',
        );
        throw Exception('AI what-to-eat-next request failed');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('AI Coach what-to-eat-next error: $e');
      rethrow;
    }
  }

  /// Send a chat message to the AI Coach and get a reply.
  ///
  /// [messages] should be a list of maps with 'role' ('user' or 'assistant')
  /// and 'content' (String). The last message should be from the user.
  ///
  /// Returns a map with:
  ///  - success: bool
  ///  - reply: String (AI coach's response)
  ///  - used_context: Map (optional, for debugging)
  static Future<Map<String, dynamic>> sendChatMessage({
    required String usernameOrEmail,
    required List<Map<String, String>> messages,
  }) async {
    final uri = Uri.parse('$_baseUrl/ai/coach/chat');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user': usernameOrEmail,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
          'AI Coach chat failed: ${response.statusCode} ${response.body}',
        );
        throw Exception('AI chat request failed');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('AI Coach chat error: $e');
      rethrow;
    }
  }
}


