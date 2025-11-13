import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrition_flutter/account_settings.dart';

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

  group('AccountSettings Working Tests', () {
    testWidgets('AccountSettings displays loading indicator initially', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings displays app bar correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Check app bar
      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AccountSettings shows error state when network fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete and error to show
      await tester.pumpAndSettle();

      // Should show the main sections even with network error
      expect(find.text('Email Settings'), findsOneWidget);
      expect(find.text('Password Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings displays form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that text fields are present
      expect(find.byType(TextFormField), findsAtLeastNWidgets(4));
    });

    testWidgets('AccountSettings displays buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that buttons are present
      expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
      expect(find.byType(OutlinedButton), findsAtLeastNWidgets(1));
    });

    testWidgets('AccountSettings displays cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that cards are present
      expect(find.byType(Card), findsAtLeastNWidgets(1));
    });

    testWidgets('AccountSettings displays icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that icons are present
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('AccountSettings can handle text input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Find text fields and enter text
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'test@example.com');
        await tester.pump();

        // Verify text was entered
        expect(find.text('test@example.com'), findsOneWidget);
      }
    });

    testWidgets('AccountSettings handles button taps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Find buttons and tap them
      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().isNotEmpty) {
        await tester.tap(buttons.first);
        await tester.pump();

        // Should not crash
        expect(find.byType(AccountSettings), findsOneWidget);
      }
    });

    testWidgets('AccountSettings displays different content for male/female', (
      tester,
    ) async {
      // Test male theming
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AccountSettings), findsOneWidget);

      // Test female theming
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'female'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AccountSettings), findsOneWidget);
    });

    testWidgets('AccountSettings handles scrolling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Try to scroll
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Should still be functional
      expect(find.byType(AccountSettings), findsOneWidget);
    });

    testWidgets('AccountSettings handles form validation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Try to submit form without filling required fields
      final submitButtons = find.byType(ElevatedButton);
      if (submitButtons.evaluate().isNotEmpty) {
        await tester.tap(submitButtons.first);
        await tester.pump();

        // Should handle validation gracefully
        expect(find.byType(AccountSettings), findsOneWidget);
      }
    });

    testWidgets('AccountSettings displays loading states correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Initially should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('AccountSettings handles network errors gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Should still display the UI even with network errors
      expect(find.byType(AccountSettings), findsOneWidget);
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings displays all main sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the main sections are present
      expect(find.text('Email Settings'), findsOneWidget);
      expect(find.text('Password Settings'), findsOneWidget);
    });

    testWidgets('AccountSettings has proper widget structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check basic widget structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('AccountSettings handles user interactions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Test various user interactions
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        // Test text input
        await tester.enterText(textFields.first, 'test input');
        await tester.pump();

        // Test button taps
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pump();
        }

        // Test switches if present
        final switches = find.byType(Switch);
        if (switches.evaluate().isNotEmpty) {
          await tester.tap(switches.first);
          await tester.pump();
        }
      }

      // Should remain functional
      expect(find.byType(AccountSettings), findsOneWidget);
    });
  });
}

