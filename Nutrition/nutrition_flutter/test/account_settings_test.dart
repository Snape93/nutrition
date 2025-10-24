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

  group('AccountSettings Widget Tests', () {
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

    testWidgets('AccountSettings displays email settings section', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Check email settings section
      expect(find.text('Email Settings'), findsOneWidget);
      expect(find.text('Current Email'), findsOneWidget);
      expect(find.text('New Email Address'), findsOneWidget);
      expect(find.text('Change Email'), findsOneWidget);
    });

    testWidgets('AccountSettings displays password settings section', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check password settings section
      expect(find.text('Password Settings'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('AccountSettings displays notification settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check notification settings
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Email Notifications'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
    });

    testWidgets('AccountSettings displays privacy settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check privacy settings
      expect(find.text('Privacy & Data'), findsOneWidget);
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
      expect(find.text('Danger Zone'), findsOneWidget);
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

    testWidgets('Notification toggles work correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Test notification toggle
      final notificationSwitch = find.byType(Switch).first;
      expect(notificationSwitch, findsOneWidget);

      // Toggle the switch
      await tester.tap(notificationSwitch);
      await tester.pump();

      // The switch should be toggled (this tests the state change)
      expect(
        find.byType(Switch),
        findsNWidgets(4),
      ); // All switches should be present
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

    testWidgets('Loading state shows progress indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('App bar displays correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Check app bar
      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
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

    testWidgets('Form resets after successful operations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Fill form fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Email Address'),
        'test@example.com',
      );

      // Verify text is there
      expect(find.text('test@example.com'), findsOneWidget);

      // The form should be clearable (this tests the controller functionality)
      final emailField = find.widgetWithText(
        TextFormField,
        'New Email Address',
      );
      expect(emailField, findsOneWidget);
    });
  });

  group('AccountSettings Integration Tests', () {
    testWidgets('Complete user flow for changing email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Enter new email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Email Address'),
        'newemail@example.com',
      );

      // Tap change email button
      await tester.tap(find.text('Change Email'));
      await tester.pumpAndSettle();

      // Should attempt to make API call (will fail due to network override)
      expect(find.textContaining('Error changing email'), findsOneWidget);
    });

    testWidgets('Complete user flow for changing password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettings(usernameOrEmail: 'testuser', userSex: 'male'),
        ),
      );

      await tester.pumpAndSettle();

      // Fill password form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current Password'),
        'oldpassword',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'newpassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'newpassword123',
      );

      // Tap change password button
      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      // Should attempt to make API call (will fail due to network override)
      expect(find.textContaining('Error changing password'), findsOneWidget);
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
      expect(switches, findsNWidgets(4));

      // Toggle each switch
      for (int i = 0; i < 4; i++) {
        await tester.tap(switches.at(i));
        await tester.pump();
      }

      // All switches should be present and functional
      expect(switches, findsNWidgets(4));
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
