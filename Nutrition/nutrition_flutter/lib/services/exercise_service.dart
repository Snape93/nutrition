import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';
import '../config.dart';

class ExerciseService {
  // Cache for exercises to avoid repeated API calls
  static List<Exercise>? _cachedExercises;
  static DateTime? _lastFetchTime;
  static bool _attemptedApiFetch = false;

  // Fetch all exercises from backend (preferred). Fallback to API sample if unreachable.
  static Future<List<Exercise>> fetchAllExercises() async {
    // Use cached if fresh
    if (_cachedExercises != null && _lastFetchTime != null) {
      final timeDifference = DateTime.now().difference(_lastFetchTime!);
      if (timeDifference.inHours < 1) {
        return _cachedExercises!;
      }
    }
    // Try backend first
    try {
      final backendExercises = await _fetchFromBackend();
      if (backendExercises.isNotEmpty) {
        debugPrint(
          'EXERCISE DEBUG: fetched ${backendExercises.length} from backend',
        );
        _cachedExercises = backendExercises;
        _lastFetchTime = DateTime.now();
        return _cachedExercises!;
      } else {
        debugPrint('EXERCISE DEBUG: backend returned 0 exercises');
      }
    } catch (e) {
      debugPrint('EXERCISE DEBUG: backend fetch failed: $e');
    }

    // Optional: Try ExerciseDB if key is set
    if (rapidApiKey.isNotEmpty && !_attemptedApiFetch) {
      try {
        final apiExercises = await _fetchDefaultCatalogFromApi();
        if (apiExercises.isNotEmpty) {
          _cachedExercises = apiExercises;
          _lastFetchTime = DateTime.now();
          _attemptedApiFetch = true;
          return _cachedExercises!;
        }
      } catch (e) {
        debugPrint('EXERCISE DEBUG: ExerciseDB fetch failed: $e');
      } finally {
        _attemptedApiFetch = true;
      }
    }

    // Final fallback
    _cachedExercises = _getSampleExercises();
    _lastFetchTime = DateTime.now();
    debugPrint(
      'EXERCISE DEBUG: using local sample exercises (${_cachedExercises!.length})',
    );
    return _cachedExercises!;
  }

  // Get exercises by category
  static Future<List<Exercise>> getExercisesByCategory(String category) async {
    // Backend supports category filter
    try {
      final fromBackend = await _fetchFromBackend(category: category);
      debugPrint('EXERCISE DEBUG: category=$category -> ${fromBackend.length}');
      if (fromBackend.isNotEmpty) return fromBackend;
    } catch (e) {
      debugPrint('EXERCISE DEBUG: backend category fetch failed: $e');
    }
    // Fallback to cached/all
    final all = await fetchAllExercises();
    final list = all.where((e) => e.category == category).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // Get exercises by body part
  static Future<List<Exercise>> getExercisesByBodyPart(String bodyPart) async {
    if (rapidApiKey.isNotEmpty) {
      try {
        return await _fetchByBodyPart(bodyPart);
      } catch (_) {}
    }
    final allExercises = await fetchAllExercises();
    return allExercises
        .where(
          (exercise) =>
              exercise.bodyPart.toLowerCase() == bodyPart.toLowerCase(),
        )
        .toList();
  }

  // Optional client-side filters
  static List<Exercise> applyFilters(
    List<Exercise> list, {
    List<String>? difficulty,
    List<String>? equipment,
  }) {
    Iterable<Exercise> filtered = list;
    if (difficulty != null && difficulty.isNotEmpty) {
      final allowed = difficulty.map((d) => d.toLowerCase()).toSet();
      filtered = filtered.where(
        (e) => allowed.contains(e.exerciseDifficulty.toLowerCase()),
      );
    }
    if (equipment != null && equipment.isNotEmpty) {
      final allowedEq = equipment.map((e) => e.toLowerCase()).toSet();
      filtered = filtered.where(
        (e) => allowedEq.contains(e.equipment.toLowerCase()),
      );
    }
    final result = filtered.toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  // Get exercises by equipment
  static Future<List<Exercise>> getExercisesByEquipment(
    String equipment,
  ) async {
    final allExercises = await fetchAllExercises();
    return allExercises
        .where(
          (exercise) =>
              exercise.equipment.toLowerCase() == equipment.toLowerCase(),
        )
        .toList();
  }

  // Search exercises by name
  static Future<List<Exercise>> searchExercises(String query) async {
    try {
      final uri = Uri.parse(
        '$apiBase/exercises?search=${Uri.encodeQueryComponent(query)}&limit=200',
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);
        final List<dynamic> list = data['exercises'] ?? [];
        final results = list.map(_mapExerciseFromBackend).toList();
        debugPrint('EXERCISE DEBUG: search "$query" -> ${results.length}');
        return results;
      }
    } catch (e) {
      debugPrint('EXERCISE DEBUG: backend search failed: $e');
    }
    final allExercises = await fetchAllExercises();
    return allExercises
        .where(
          (exercise) =>
              exercise.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Get exercise by ID
  static Future<Exercise?> getExerciseById(String id) async {
    try {
      final uri = Uri.parse('$apiBase/exercises/$id');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);
        final Map<String, dynamic>? ex =
            data['exercise'] as Map<String, dynamic>?;
        if (ex != null) return _mapExerciseFromBackend(ex);
      }
    } catch (e) {
      debugPrint('EXERCISE DEBUG: backend get by id failed: $e');
    }
    final allExercises = await fetchAllExercises();
    try {
      return allExercises.firstWhere((exercise) => exercise.id == id);
    } catch (_) {
      return null;
    }
  }

  // Get available categories
  static Future<List<String>> getAvailableCategories() async {
    // Derived from local data heuristics
    final all = await fetchAllExercises();
    final categories = all.map((e) => e.exerciseCategory).toSet().toList();
    categories.sort();
    return categories;
  }

  // Get available body parts
  static Future<List<String>> getAvailableBodyParts() async {
    final allExercises = await fetchAllExercises();
    final bodyParts = allExercises.map((e) => e.bodyPart).toSet().toList();
    bodyParts.sort();
    return bodyParts;
  }

  // Get available equipment
  static Future<List<String>> getAvailableEquipment() async {
    final allExercises = await fetchAllExercises();
    final equipment = allExercises.map((e) => e.equipment).toSet().toList();
    equipment.sort();
    return equipment;
  }

  // Log exercise session
  static Future<bool> logExerciseSession({
    required String user,
    required String exerciseId,
    required String exerciseName,
    required int durationSeconds,
    double? caloriesBurned,
    int setsCompleted = 1,
    String? notes,
  }) async {
    // Offline stub: no-op success
    return true;
  }

  // Get exercise sessions for a user
  static Future<Map<String, dynamic>> getExerciseSessions({
    required String user,
    String? date,
  }) async {
    // Offline stub: empty sessions
    return {
      'success': true,
      'sessions': [],
      'summary': {
        'total_sessions': 0,
        'total_calories_burned': 0,
        'total_duration_minutes': 0,
      },
    };
  }

  // Sync exercises from ExerciseDB to your backend
  static Future<bool> syncExercises() async {
    // Offline stub: nothing to sync
    return true;
  }

  // ------------------ ExerciseDB integration ------------------

  static Map<String, String> get _headers => {
    'X-RapidAPI-Key': rapidApiKey,
    'X-RapidAPI-Host': exerciseDbHost,
  };

  static Future<List<Exercise>> _fetchByBodyPart(String bodyPart) async {
    final uri = Uri.parse(
      '$exerciseDbBaseUrl/exercises/bodyPart/${Uri.encodeComponent(bodyPart)}',
    );
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('ExerciseDB error ${resp.statusCode}');
    }
    final List<dynamic> jsonList = json.decode(resp.body);
    return jsonList.map(_mapExerciseFromApi).toList();
  }

  static Future<List<Exercise>> _fetchStrengthAggregated() async {
    const parts = ['chest', 'upper legs', 'upper arms', 'back', 'shoulders'];
    final futures = parts.map((p) => _fetchByBodyPart(p));
    final results = await Future.wait(futures);
    // Merge and de-duplicate by id
    final Map<String, Exercise> byId = {};
    for (final list in results) {
      for (final ex in list) {
        byId[ex.id] = ex;
      }
    }
    final merged = byId.values.toList();
    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  static Exercise _mapExerciseFromApi(dynamic jsonObj) {
    final Map<String, dynamic> j = jsonObj as Map<String, dynamic>;
    // ExerciseDB fields: id, name, bodyPart, equipment, target, gifUrl, secondaryMuscles, instructions
    final rawInstructions = j['instructions'];
    final List<String> instructions;
    if (rawInstructions is List) {
      instructions = rawInstructions.map((e) => e.toString()).toList();
    } else if (rawInstructions is String) {
      instructions =
          rawInstructions
              .split('. ')
              .where((s) => s.trim().isNotEmpty)
              .toList();
    } else {
      instructions = [];
    }
    return Exercise(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      bodyPart: (j['bodyPart'] ?? '').toString(),
      equipment: (j['equipment'] ?? '').toString(),
      target: (j['target'] ?? '').toString(),
      gifUrl: (j['gifUrl'] ?? '').toString(),
      instructions: instructions,
    );
  }

  // ------------------ Backend integration ------------------

  static Future<List<Exercise>> _fetchFromBackend({String? category}) async {
    final params = <String, String>{'limit': '10000'};
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    final uri = Uri.parse(
      '$apiBase/exercises',
    ).replace(queryParameters: params);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Backend /exercises ${resp.statusCode}');
    }
    final Map<String, dynamic> data = json.decode(resp.body);
    final List<dynamic> list = data['exercises'] ?? [];
    final mapped = list.map(_mapExerciseFromBackend).toList();
    mapped.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return mapped;
  }

  // Calculate calories from backend given name/id and duration seconds
  static Future<double?> calculateCalories({
    String? id,
    String? name,
    required int durationSeconds,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/exercises/calculate');
      final body = <String, dynamic>{'duration_seconds': durationSeconds};
      if (id != null && id.isNotEmpty) body['exercise_id'] = id;
      if ((name ?? '').isNotEmpty) body['name'] = name;
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);
        if (data['success'] == true) {
          final dynamic cals = data['calories'];
          if (cals is num) return cals.toDouble();
        }
      }
    } catch (e) {
      debugPrint('EXERCISE DEBUG: calculate calories failed: $e');
    }
    return null;
  }

  static Exercise _mapExerciseFromBackend(dynamic jsonObj) {
    final Map<String, dynamic> j = jsonObj as Map<String, dynamic>;
    final List<dynamic>? rawInstr = j['instructions'] as List<dynamic>?;
    final instructions =
        rawInstr?.map((e) => e.toString()).toList() ?? <String>[];
    return Exercise(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      bodyPart: (j['body_part'] ?? '').toString(),
      equipment: (j['equipment'] ?? '').toString(),
      target: (j['target'] ?? '').toString(),
      gifUrl: (j['gif_url'] ?? '').toString(),
      instructions: instructions,
    );
  }

  static Future<List<Exercise>> _fetchDefaultCatalogFromApi() async {
    // Reasonable default: cardio + strength aggregate
    final cardio = await _fetchByBodyPart('cardio');
    final strength = await _fetchStrengthAggregated();
    final list = [...cardio, ...strength];
    // De-duplicate by id
    final Map<String, Exercise> byId = {for (final e in list) e.id: e};
    final merged = byId.values.toList();
    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  // Sample exercises for development/testing when API is not available
  static List<Exercise> _getSampleExercises() {
    return [
      Exercise(
        id: '0001',
        name: 'Push-up',
        bodyPart: 'chest',
        equipment: 'body weight',
        target: 'pectorals',
        gifUrl: 'https://example.com/pushup.gif',
        instructions: [
          'Start in a plank position with your hands slightly wider than shoulder-width apart.',
          'Lower your body until your chest nearly touches the floor.',
          'Push your body back up to the starting position.',
          'Keep your core tight and maintain a straight line from head to heels.',
        ],
      ),
      Exercise(
        id: '0002',
        name: 'Squat',
        bodyPart: 'upper legs',
        equipment: 'body weight',
        target: 'glutes',
        gifUrl: 'https://example.com/squat.gif',
        instructions: [
          'Stand with your feet shoulder-width apart.',
          'Lower your body as if sitting back into a chair.',
          'Keep your chest up and knees behind your toes.',
          'Return to the starting position.',
        ],
      ),
      Exercise(
        id: '0003',
        name: 'Jumping Jack',
        bodyPart: 'cardio',
        equipment: 'body weight',
        target: 'cardiovascular system',
        gifUrl: 'https://example.com/jumpingjack.gif',
        instructions: [
          'Start in a standing position with your feet together.',
          'Jump and spread your legs while raising your arms overhead.',
          'Jump back to the starting position.',
          'Repeat at a quick pace.',
        ],
      ),
      Exercise(
        id: '0004',
        name: 'Downward Dog',
        bodyPart: 'back',
        equipment: 'body weight',
        target: 'hamstrings',
        gifUrl: 'https://example.com/downwarddog.gif',
        instructions: [
          'Start on your hands and knees.',
          'Lift your hips and straighten your legs.',
          'Form an inverted V shape with your body.',
          'Hold the position and breathe deeply.',
        ],
      ),
      Exercise(
        id: '0005',
        name: 'Plank',
        bodyPart: 'waist',
        equipment: 'body weight',
        target: 'abs',
        gifUrl: 'https://example.com/plank.gif',
        instructions: [
          'Start in a push-up position.',
          'Lower your forearms to the ground.',
          'Keep your body in a straight line.',
          'Hold the position for the desired time.',
        ],
      ),
    ];
  }
}
