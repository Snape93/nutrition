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
}










