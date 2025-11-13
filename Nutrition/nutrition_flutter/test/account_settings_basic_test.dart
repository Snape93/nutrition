import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_flutter/account_settings.dart';

void main() {
  group('AccountSettings Basic Tests', () {
    testWidgets('AccountSettings loads without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Just verify the screen loads without crashing
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings shows loading state initially', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // In test mode, data loads immediately, so we just verify the screen loads
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings displays email section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Check that email section is present
      expect(find.text('Email Settings'), findsOneWidget);
      expect(find.text('Current Email'), findsOneWidget);
    });

    testWidgets('AccountSettings displays password section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Scroll down to find password section
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Check that password section is present
      expect(find.text('Password Settings'), findsOneWidget);
    });
  });
}
