import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class CustomExerciseService {
  static Future<bool> submitCustomExercise({
    required String user,
    required String name,
    String? category,
    String? intensity,
    int? durationMin,
    int? reps,
    int? sets,
    String? notes,
    int? estCalories,
    int timeoutSeconds = 6,
  }) async {
    final uri = Uri.parse('$apiBase/api/exercises/custom');
    final body = jsonEncode({
      'user': user,
      'name': name,
      'category': category,
      'intensity': intensity,
      'duration_min': durationMin,
      'reps': reps,
      'sets': sets,
      'notes': notes,
      'est_calories': estCalories,
    });
    try {
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(Duration(seconds: timeoutSeconds));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false; // offline or server down; caller may retry later
    }
  }

  /// Get custom exercises submitted by a user
  static Future<List<String>> getCustomExerciseNames({
    required String user,
    int timeoutSeconds = 10,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/api/exercises/custom');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(Duration(seconds: timeoutSeconds));
      
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        // Filter by user and extract unique exercise names
        final Set<String> names = {};
        for (final item in items) {
          final itemUser = item['user'] as String?;
          final name = item['name'] as String?;
          // Only include items that belong to this user
          if (itemUser == user && name != null && name.isNotEmpty) {
            names.add(name);
          }
        }
        return names.toList();
      }
      return [];
    } catch (_) {
      return []; // Return empty list on error
    }
  }
}
























