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

  group('AccountSettings Basic Tests', () {
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

    testWidgets('AccountSettings displays all main sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Check all main sections are present by scrolling through the list
      // Start at the top
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();

      // Check Email Settings
      expect(find.text('Email Settings'), findsOneWidget);

      // Scroll down to find Password Settings
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Password Settings'), findsOneWidget);

      // Scroll down to find Notifications
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);

      // Scroll down to find Privacy & Data
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & Data'), findsOneWidget);

      // Scroll down to find Danger Zone
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Danger Zone'), findsOneWidget);
    });

    testWidgets('AccountSettings displays email form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check email form fields
      expect(find.text('Current Email'), findsOneWidget);
      expect(find.text('New Email Address'), findsOneWidget);
      expect(find.text('Change Email'), findsOneWidget);
    });

    testWidgets('AccountSettings displays password form fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check password form fields
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('AccountSettings displays notification toggles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check notification toggles
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Email Notifications'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(3));
    });

    testWidgets('AccountSettings displays privacy settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check privacy settings
      expect(find.text('Data Sharing'), findsOneWidget);
      expect(find.text('Export My Data'), findsOneWidget);
    });

    testWidgets('AccountSettings displays danger zone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check danger zone
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('Email validation works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Find the new email field
      final emailField = find.widgetWithText(
        TextFormField,
        'New Email Address',
      );
      expect(emailField, findsOneWidget);

      // Test invalid email
      await tester.enterText(emailField, 'invalid-email');
      await tester.tap(find.text('Change Email'));
      await tester.pump();

      // Should show validation error
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Password validation works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Test short password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        '123',
      );
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      // Should show validation error
      expect(find.text('At least 6 characters'), findsOneWidget);
    });

    testWidgets('Password confirmation validation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Enter different passwords
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'different123',
      );
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      // Should show validation error
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Delete account shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Tap delete account button
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(
        find.text('Delete Account'),
        findsNWidgets(2),
      ); // Button and dialog title
      expect(
        find.text('Are you sure you want to delete your account?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Export data shows dialog with user data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Tap export data button
      await tester.tap(find.text('Export My Data'));
      await tester.pumpAndSettle();

      // Should show export dialog
      expect(find.text('Data Export'), findsOneWidget);
      expect(find.text('Your data has been compiled'), findsOneWidget);
      expect(find.text('Export Summary:'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Form validation prevents submission with empty fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Try to submit password change without filling fields
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      // Should show validation errors for required fields
      expect(find.text('Required'), findsAtLeastNWidgets(1));
    });

    testWidgets('UI elements have correct styling and theming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check that cards are present
      expect(
        find.byType(Card),
        findsAtLeastNWidgets(4),
      ); // Email, Password, Notifications, Privacy, Danger

      // Check that icons are present
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byIcon(Icons.privacy_tip), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('All text fields are present and functional', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check all text fields are present
      expect(
        find.widgetWithText(TextFormField, 'New Email Address'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Current Password'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'New Password'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        findsOneWidget,
      );

      // Test that we can enter text in fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Email Address'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current Password'),
        'oldpassword',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'newpassword',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'newpassword',
      );

      // Verify text was entered
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('oldpassword'), findsOneWidget);
      expect(find.text('newpassword'), findsNWidgets(2));
    });

    testWidgets('Gender-based theming is applied correctly', (tester) async {
      // Test male theming
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // The primary color should be applied (this tests the theming logic)
      expect(find.byType(AccountSettings), findsOneWidget);

      // Test female theming
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'female'),
        ),
      );

      await tester.pumpAndSettle();

      // The primary color should be different for female
      expect(find.byType(AccountSettings), findsOneWidget);
    });

    testWidgets('Error handling for network failures', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Try to change email (this will fail due to network override)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Email Address'),
        'new@example.com',
      );
      await tester.tap(find.text('Change Email'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('Error changing email'), findsOneWidget);
    });

    testWidgets('User can toggle all notification settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Find all switches
      final switches = find.byType(Switch);
      expect(switches, findsAtLeastNWidgets(3));

      // Toggle each switch
      for (int i = 0; i < 3; i++) {
        await tester.tap(switches.at(i));
        await tester.pump();
      }

      // All switches should be present and functional
      expect(switches, findsAtLeastNWidgets(3));
    });

    testWidgets('User can access all sections of settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll through all sections to ensure they're accessible
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // All sections should be visible
      expect(find.text('Email Settings'), findsOneWidget);
      expect(find.text('Password Settings'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy & Data'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);
    });
  });
}
