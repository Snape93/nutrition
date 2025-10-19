import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrition_flutter/screens/your_exercise_screen.dart';

class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Block any outbound HTTP during widget tests
    throw const SocketException('Network disabled in tests');
  }
}

void main() {
  setUp(() {
    HttpOverrides.global = _NoNetworkHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  testWidgets('YourExerciseScreen validates and shows success snackbar', (
    tester,
  ) async {
    Future<int> fakeSaver({
      required String usernameOrEmail,
      required String name,
      String? category,
      String? intensity,
      int? durationMin,
      int? reps,
      int? sets,
      String? notes,
      int? estCalories,
    }) async => 1;

    await tester.pumpWidget(
      MaterialApp(
        home: YourExerciseScreen(
          usernameOrEmail: 'tester',
          onSaveCustomExercise: fakeSaver,
          closeOnSubmit: false,
        ),
      ),
    );

    // Enter a valid name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Exercise name *'),
      'Test Exercise',
    );

    // Enter a duration (so validation passes without reps/sets)
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration (min)'),
      '10',
    );

    // Tap submit (ensure it's visible inside scroll view)
    final submitText = find.text('Submit');
    expect(submitText, findsOneWidget);
    await tester.tap(submitText);
    await tester.pumpAndSettle();

    // Expect a SnackBar indicating save success
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
  });
}
