// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrition_flutter/my_app.dart';

void main() {
  testWidgets('Login screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle(); // Wait for all navigation/animations

    // If your app starts on a landing page, tap the login button first:
    if (find.text('Log In').evaluate().isNotEmpty) {
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('usernameField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('usernameField')), 'user');
    await tester.enterText(find.byKey(const Key('passwordField')), 'pass');

    // Tap the login button
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    // Verify that login was successful
    expect(find.text('Login successful'), findsOneWidget);

    // Try with wrong credentials
    await tester.enterText(find.byKey(const Key('usernameField')), 'wrong');
    await tester.enterText(find.byKey(const Key('passwordField')), 'wrong');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    // Verify that login failed
    expect(find.text('Login failed'), findsOneWidget);
  });
}
