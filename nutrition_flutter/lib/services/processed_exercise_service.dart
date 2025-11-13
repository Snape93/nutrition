import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

/// Service to load processed exercises from local JSON files
class ProcessedExerciseService {
  static List<Exercise>? _cachedCardioExercises;
  static List<Exercise>? _cachedStrengthExercises;
  static Map<String, dynamic>? _cachedDataset;

  /// Load cardio exercises from local JSON file
  static Future<List<Exercise>> getCardioExercises() async {
    if (_cachedCardioExercises != null) {
      return _cachedCardioExercises!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'lib/data/cardio_exercises.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      _cachedCardioExercises =
          jsonList.map((json) => _mapExerciseFromJson(json)).toList();
      return _cachedCardioExercises!;
    } catch (e) {
      debugPrint('Error loading cardio exercises: $e');
      return [];
    }
  }

  /// Load strength exercises from local JSON file
  static Future<List<Exercise>> getStrengthExercises() async {
    if (_cachedStrengthExercises != null) {
      return _cachedStrengthExercises!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'lib/data/strength_exercises.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      _cachedStrengthExercises =
          jsonList.map((json) => _mapExerciseFromJson(json)).toList();
      return _cachedStrengthExercises!;
    } catch (e) {
      debugPrint('Error loading strength exercises: $e');
      return [];
    }
  }

  /// Load all exercises from the combined dataset
  static Future<Map<String, dynamic>> getFullDataset() async {
    if (_cachedDataset != null) {
      return _cachedDataset!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'lib/data/exercises_dataset.json',
      );
      _cachedDataset = json.decode(jsonString);
      return _cachedDataset!;
    } catch (e) {
      debugPrint('Error loading full dataset: $e');
      return {};
    }
  }

  /// Get exercises by category (Cardio or Strength)
  static Future<List<Exercise>> getExercisesByCategory(String category) async {
    switch (category.toLowerCase()) {
      case 'cardio':
        return await getCardioExercises();
      case 'strength':
        return await getStrengthExercises();
      default:
        return [];
    }
  }

  /// Search exercises by name within a category
  static Future<List<Exercise>> searchExercisesInCategory(
    String category,
    String query,
  ) async {
    final exercises = await getExercisesByCategory(category);
    if (query.isEmpty) return exercises;

    final lowercaseQuery = query.toLowerCase();
    return exercises.where((exercise) {
      return exercise.name.toLowerCase().contains(lowercaseQuery) ||
          exercise.target.toLowerCase().contains(lowercaseQuery) ||
          exercise.equipment.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Get exercise by ID from any category
  static Future<Exercise?> getExerciseById(String id) async {
    // Search in cardio exercises first
    final cardioExercises = await getCardioExercises();
    for (final exercise in cardioExercises) {
      if (exercise.id == id) return exercise;
    }

    // Search in strength exercises
    final strengthExercises = await getStrengthExercises();
    for (final exercise in strengthExercises) {
      if (exercise.id == id) return exercise;
    }

    return null;
  }

  /// Get available categories
  static Future<List<String>> getAvailableCategories() async {
    return ['Cardio', 'Strength'];
  }

  /// Get exercise statistics
  static Future<Map<String, int>> getExerciseStats() async {
    final cardioCount = (await getCardioExercises()).length;
    final strengthCount = (await getStrengthExercises()).length;

    return {
      'cardio': cardioCount,
      'strength': strengthCount,
      'total': cardioCount + strengthCount,
    };
  }

  /// Map JSON data to Exercise model
  static Exercise _mapExerciseFromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      bodyPart: json['bodyPart']?.toString() ?? '',
      equipment: json['equipment']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      gifUrl: json['gifUrl']?.toString() ?? '',
      instructions: List<String>.from(json['instructions'] ?? []),
      category: json['category']?.toString(),
      difficulty: json['difficulty']?.toString(),
      estimatedCaloriesPerMinute:
          json['estimatedCaloriesPerMinute']?.toDouble(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }

  /// Clear cache (useful for testing or memory management)
  static void clearCache() {
    _cachedCardioExercises = null;
    _cachedStrengthExercises = null;
    _cachedDataset = null;
  }
}
