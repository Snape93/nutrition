import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_flutter/services/processed_exercise_service.dart';

void main() {
  group('ProcessedExerciseService Tests', () {
    testWidgets('Load cardio exercises', (tester) async {
      final exercises = await ProcessedExerciseService.getCardioExercises();

      expect(exercises, isNotEmpty);
      expect(exercises.every((e) => e.exerciseCategory == 'Cardio'), isTrue);

      // Check that exercises are sorted alphabetically
      for (int i = 1; i < exercises.length; i++) {
        expect(
          exercises[i - 1].name.toLowerCase().compareTo(
            exercises[i].name.toLowerCase(),
          ),
          lessThanOrEqualTo(0),
        );
      }
    });

    testWidgets('Load strength exercises', (tester) async {
      final exercises = await ProcessedExerciseService.getStrengthExercises();

      expect(exercises, isNotEmpty);
      expect(exercises.every((e) => e.exerciseCategory == 'Strength'), isTrue);

      // Check that exercises are sorted alphabetically
      for (int i = 1; i < exercises.length; i++) {
        expect(
          exercises[i - 1].name.toLowerCase().compareTo(
            exercises[i].name.toLowerCase(),
          ),
          lessThanOrEqualTo(0),
        );
      }
    });

    testWidgets('Get exercises by category', (tester) async {
      final cardioExercises =
          await ProcessedExerciseService.getExercisesByCategory('Cardio');
      final strengthExercises =
          await ProcessedExerciseService.getExercisesByCategory('Strength');

      expect(cardioExercises, isNotEmpty);
      expect(strengthExercises, isNotEmpty);
      expect(
        cardioExercises.every((e) => e.exerciseCategory == 'Cardio'),
        isTrue,
      );
      expect(
        strengthExercises.every((e) => e.exerciseCategory == 'Strength'),
        isTrue,
      );
    });

    testWidgets('Search exercises in category', (tester) async {
      final cardioResults =
          await ProcessedExerciseService.searchExercisesInCategory(
            'Cardio',
            'run',
          );
      final strengthResults =
          await ProcessedExerciseService.searchExercisesInCategory(
            'Strength',
            'squat',
          );

      expect(cardioResults, isNotEmpty);
      expect(strengthResults, isNotEmpty);

      // Check that search results contain the search term
      expect(
        cardioResults.any((e) => e.name.toLowerCase().contains('run')),
        isTrue,
      );
      expect(
        strengthResults.any((e) => e.name.toLowerCase().contains('squat')),
        isTrue,
      );
    });

    testWidgets('Get exercise statistics', (tester) async {
      final stats = await ProcessedExerciseService.getExerciseStats();

      expect(stats['cardio'], greaterThan(0));
      expect(stats['strength'], greaterThan(0));
      expect(stats['total'], greaterThan(0));
      expect(stats['total'], equals(stats['cardio']! + stats['strength']!));
    });

    testWidgets('Exercise model has correct fields', (tester) async {
      final exercises = await ProcessedExerciseService.getCardioExercises();
      final exercise = exercises.first;

      expect(exercise.id, isNotEmpty);
      expect(exercise.name, isNotEmpty);
      expect(exercise.bodyPart, isNotEmpty);
      expect(exercise.equipment, isNotEmpty);
      expect(exercise.target, isNotEmpty);
      expect(exercise.instructions, isNotEmpty);
      expect(exercise.exerciseCategory, equals('Cardio'));
      expect(exercise.exerciseDifficulty, isNotEmpty);
      expect(exercise.exerciseCaloriesPerMinute, greaterThan(0));
    });
  });
}
