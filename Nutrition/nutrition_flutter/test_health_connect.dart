import 'package:flutter/material.dart';
import 'lib/services/health_service.dart';

/// Simple test script to verify Health Connect integration
/// Run this to test the connection flow
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🧪 Testing Health Connect Integration...');

  // Test 1: Check availability
  debugPrint('\n1. Testing Health Connect availability...');
  bool isAvailable = await HealthService.isHealthConnectAvailable();
  debugPrint('Health Connect available: $isAvailable');

  // Test 2: Check current connection status
  debugPrint('\n2. Testing current connection status...');
  bool isConnected = await HealthService.isHealthConnectConnected();
  debugPrint('Health Connect connected: $isConnected');

  // Test 3: Try to connect (if not already connected)
  if (!isConnected) {
    debugPrint('\n3. Testing permission request...');
    Map<String, dynamic> result =
        await HealthService.requestHealthConnectPermissions();
    debugPrint('Connection result: $result');

    if (result['success']) {
      debugPrint('✅ Health Connect connected successfully!');

      // Test 4: Try to get some data
      debugPrint('\n4. Testing data retrieval...');
      int steps = await HealthService.getTodaySteps();
      debugPrint('Today\'s steps: $steps');

      int? heartRate = await HealthService.getLatestHeartRate();
      debugPrint('Latest heart rate: ${heartRate ?? 'No data'}');

      double calories = await HealthService.getTodayCaloriesBurned();
      debugPrint('Today\'s calories: $calories');
    } else {
      debugPrint('❌ Health Connect connection failed: ${result['error']}');
      if (result['action'] != null) {
        debugPrint('Suggested action: ${result['action']}');
      }
    }
  } else {
    debugPrint('✅ Health Connect already connected!');

    // Test data retrieval
    debugPrint('\n4. Testing data retrieval...');
    int steps = await HealthService.getTodaySteps();
    debugPrint('Today\'s steps: $steps');
  }

  debugPrint('\n🏁 Test completed!');
}
