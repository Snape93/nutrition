import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'account_settings_test.dart' as account_settings_tests;

/// Test runner for Account Settings functionality
/// This script runs all account settings related tests
void main() {
  debugPrint('🧪 Running Account Settings Tests');
  debugPrint('=' * 50);

  // Run Flutter widget tests
  debugPrint('\n📱 Running Flutter Widget Tests...');
  try {
    testWidgets('Account Settings Widget Tests', (tester) async {
      // This will run all the widget tests defined in account_settings_test.dart
      account_settings_tests.main();
    });
    debugPrint('✅ Flutter widget tests completed');
  } catch (e) {
    debugPrint('❌ Flutter widget tests failed: $e');
  }

  debugPrint('\n🎉 All Account Settings tests completed!');
  debugPrint('=' * 50);
}
