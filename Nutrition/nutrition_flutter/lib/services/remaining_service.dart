import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class RemainingService {
  // Centralized baseUrl via config.dart
  static const String baseUrl = apiBase;

  static Future<Map<String, dynamic>> fetchRemaining({
    required String user,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final ds =
        '${d.year.toString().padLeft(4, '0')}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$baseUrl/remaining?user=$user&date=$ds');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) {
      throw Exception('Remaining request failed: ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      // Some error responses may not include success
      return data;
    }
    return data;
  }
}
