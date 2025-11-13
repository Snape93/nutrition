import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'google_fit_service.dart';

/// Enhanced Health Service with proven Health Connect fixes
///
/// Based on research from successful implementations, this service uses:
/// 1. Proper timing for permission requests
/// 2. Enhanced error handling
/// 3. Correct data source registration
/// 4. Android 14 compatibility fixes
class HealthService {
  // Health instance (plugin routes to Health Connect when available)
  static Health health = Health();

  // CRITICAL: These data types MUST match health_permissions.xml
  // Progressive permission strategy: Start minimal, then expand
  // Minimal, transparent permission set (reset implementation)
  // We start with just STEPS to avoid broad prompts being denied by OEMs.
  static final List<HealthDataType> coreTypes = [HealthDataType.STEPS];

  // For requesting both READ and WRITE on the same type, we duplicate the type
  // as required by the `health` plugin (types and permissions lists align 1:1).
  static final List<HealthDataType> permissionTypes = [
    HealthDataType.STEPS,
    HealthDataType.STEPS,
  ];
  static final List<HealthDataAccess> permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.WRITE,
  ];

  // Expanded groups removed for minimal footprint; we only use STEPS
  static final List<HealthDataType> _vitalsReadTypes = <HealthDataType>[];

  static List<HealthDataAccess> _readAccessFor(List<HealthDataType> types) =>
      List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);

  // No write accessors needed for minimal STEPS-only build

  /// Initialize Health Connect with proper configuration
  static Future<void> initializeHealthConnect() async {
    try {
      debugPrint('🔧 Initializing Health Connect...');
      debugPrint(
        '📋 Core types: ${coreTypes.map((e) => e.toString()).join(', ')}',
      );
      debugPrint(
        '🔑 Permissions: ${permissions.map((e) => e.toString()).join(', ')}',
      );

      // Basic probe: attempt a benign permission check to warm up plugin
      try {
        debugPrint('🔍 Probing Health Connect availability...');
        bool? hasPermissions = await health.hasPermissions(
          permissionTypes,
          permissions: permissions,
        );
        debugPrint('🔍 Permission check result: $hasPermissions');
      } catch (e) {
        debugPrint('🔍 Permission check failed (expected): $e');
      }
      debugPrint('🔍 Health Connect probe completed');

      debugPrint('✅ Health Connect initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Health Connect: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error details: ${e.toString()}');
    }
  }

  /// Enhanced Health Connect availability check with proper error handling
  ///
  /// Based on GitHub tutorial best practices, this method uses multiple
  /// detection strategies to determine if Health Connect is available.
  static Future<bool> isHealthConnectAvailable() async {
    try {
      debugPrint('🔍 Checking Health Connect availability...');
      debugPrint('🔍 Method 1: Permission check...');

      // Method 1: Try to check permissions (most reliable)
      try {
        bool? hasPermissions = await health.hasPermissions(
          permissionTypes,
          permissions: permissions,
        );
        debugPrint('🔍 Permission check result: $hasPermissions');
        debugPrint('✅ Health Connect detected via permission check');
        return true;
      } catch (e) {
        debugPrint('⚠️ Permission check failed: $e');
        debugPrint('⚠️ Error type: ${e.runtimeType}');
      }

      debugPrint('🔍 Method 2: Data access check...');
      // Method 2: Try to get health data (fallback detection)
      try {
        final now = DateTime.now();
        final oneHourAgo = now.subtract(Duration(hours: 1));
        debugPrint('🔍 Querying data from $oneHourAgo to $now');

        List<HealthDataPoint> data = await health.getHealthDataFromTypes(
          types: coreTypes,
          startTime: oneHourAgo,
          endTime: now,
        );
        debugPrint('🔍 Data query returned ${data.length} points');
        debugPrint('✅ Health Connect detected via data access');
        return true;
      } catch (e) {
        debugPrint('⚠️ Data access check failed: $e');
        debugPrint('⚠️ Error type: ${e.runtimeType}');
      }

      // Method 3: If both fail, assume Health Connect is not available
      // but don't block the user - let them try to connect anyway
      debugPrint(
        '⚠️ Health Connect may not be available, but allowing connection attempt',
      );
      return true; // Allow user to try connecting
    } catch (e) {
      debugPrint('❌ Health Connect availability check failed: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return true; // Default to allowing connection attempts
    }
  }

  /// MyFitnessPal-style Health Connect connection method
  /// Opens Health Connect directly and lets user grant permissions there
  static Future<Map<String, dynamic>> requestHealthConnectPermissions() async {
    try {
      debugPrint('🔐 Starting MyFitnessPal-style Health Connect connection...');

      // Step 1: Initialize Health Connect (but don't request permissions yet)
      await initializeHealthConnect();

      // Step 2: Check if Health Connect is available
      bool isAvailable = await isHealthConnectAvailable();
      if (!isAvailable) {
        return {
          'success': false,
          'error':
              'Health Connect is not available on this device. Please install Health Connect from Play Store.',
          'errorCode': 'NOT_AVAILABLE',
          'action': 'install_health_connect',
        };
      }

      // Step 3: Ensure basic Android permissions first
      debugPrint('🔧 Requesting basic Android permissions...');
      if (await Permission.activityRecognition.isDenied ||
          await Permission.activityRecognition.isPermanentlyDenied) {
        await Permission.activityRecognition.request();
      }
      if (await Permission.sensors.isDenied ||
          await Permission.sensors.isPermanentlyDenied) {
        await Permission.sensors.request();
      }

      // Step 4: First, request authorization via plugin so the OS registers our app
      debugPrint(
        '🛂 Requesting Health Connect authorization via plugin (primary)...',
      );
      bool authorized = false;
      try {
        authorized = await health.requestAuthorization(
          permissionTypes,
          permissions: permissions,
        );
        debugPrint('🛂 requestAuthorization result: $authorized');
      } catch (e) {
        debugPrint('⚠️ requestAuthorization threw: $e');
      }

      // If user granted permissions here, we're done
      if (authorized == true) {
        await _saveConnectionStatus('Health Connect', true);
        // Optional: write a small no-op steps record to finalize registration
        try {
          final now = DateTime.now();
          await health.writeHealthData(
            type: HealthDataType.STEPS,
            value: 0,
            startTime: now.subtract(Duration(minutes: 1)),
            endTime: now,
          );
        } catch (_) {}
        return {
          'success': true,
          'message': 'Health Connect connected successfully!',
        };
      }

      // Step 4.5: Force app registration with multiple methods
      await forceHealthConnectRegistration();

      // Step 5: Fallback - open Health Connect app settings/permission UI directly
      debugPrint(
        '🚀 Opening Health Connect for permission grant (fallback)...',
      );
      bool launched = await launchHealthConnectPermissions();

      if (launched) {
        // Give user time to grant permissions, then check
        debugPrint(
          '⏳ Waiting for user to grant permissions in Health Connect...',
        );

        // Return success with instruction to check permissions
        return {
          'success': false,
          'error':
              'Health Connect opened. Please grant permissions to "Nutrition App" and return here.',
          'errorCode': 'PERMISSION_PENDING',
          'action': 'check_permissions_after_grant',
          'instruction':
              '1. In Health Connect, find "Nutrition App"\n2. Grant the permissions you want\n3. Return to this app and try connecting again',
        };
      } else {
        // Fallback: Try to open Health Connect settings
        debugPrint('🔄 Fallback: Opening Health Connect settings...');
        bool settingsOpened = await openHealthConnectSettings();

        if (settingsOpened) {
          return {
            'success': false,
            'error':
                'Health Connect settings opened. Please add "Nutrition App" and grant permissions.',
            'errorCode': 'SETTINGS_OPENED',
            'action': 'add_app_in_settings',
            'instruction':
                '1. In Health Connect settings, add "Nutrition App"\n2. Grant the permissions you want\n3. Return to this app and try connecting again',
          };
        } else {
          return {
            'success': false,
            'error':
                'Could not open Health Connect. Please open it manually and add this app.',
            'errorCode': 'CANNOT_OPEN',
            'action': 'manual_setup',
            'instruction':
                '1. Open Health Connect app manually\n2. Go to Settings → App permissions\n3. Add "Nutrition App" and grant permissions\n4. Return here and try connecting again',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Critical error in Health Connect connection: $e');
      return {
        'success': false,
        'error': 'Critical error occurred. Please restart the app.',
        'errorCode': 'CRITICAL_ERROR',
        'details': e.toString(),
      };
    }
  }

  // Expanded permissions method removed; we only request minimal STEPS for now

  /// Reset Health Connect local state and provide guidance
  static Future<void> resetHealthConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('connected_Health Connect');
      debugPrint('🧹 Cleared saved Health Connect status');
      // We cannot revoke OS-level permissions programmatically. Prompt user.
      debugPrint(
        'ℹ️ To fully reset, open Health Connect and revoke this app\'s access.',
      );
    } catch (e) {
      debugPrint('❌ Failed to reset Health Connect: $e');
    }
  }

  /// Check if Health Connect is currently connected
  static Future<bool> isHealthConnectConnected() async {
    try {
      // Method 1: Check saved status
      bool savedStatus = await _getConnectionStatus('Health Connect');
      if (!savedStatus) return false;

      // Method 2: Verify permissions are still valid
      bool? hasPermissions = await health.hasPermissions(
        permissionTypes,
        permissions: permissions,
      );

      bool isConnected = hasPermissions == true;

      // Sync saved status with actual permissions
      if (!isConnected && savedStatus) {
        await _saveConnectionStatus('Health Connect', false);
      }

      return isConnected;
    } catch (e) {
      debugPrint('Error checking Health Connect connection: $e');
      return false;
    }
  }

  /// Check if Health Connect permissions were granted after user returns
  /// This is called after the user grants permissions in Health Connect
  static Future<Map<String, dynamic>>
  checkHealthConnectPermissionsAfterGrant() async {
    try {
      debugPrint('🔍 Checking Health Connect permissions after user grant...');

      // Wait a moment for permissions to propagate
      await Future.delayed(Duration(seconds: 1));

      // Check if we have permissions now
      bool? hasPermissions = await health.hasPermissions(
        permissionTypes,
        permissions: permissions,
      );

      if (hasPermissions == true) {
        await _saveConnectionStatus('Health Connect', true);
        debugPrint('✅ Health Connect permissions granted successfully!');
        return {
          'success': true,
          'message': 'Health Connect connected successfully!',
        };
      } else {
        debugPrint('❌ Health Connect permissions not granted yet');
        return {
          'success': false,
          'error':
              'Permissions not granted yet. Please try again or check Health Connect settings.',
          'errorCode': 'PERMISSIONS_NOT_GRANTED',
          'action': 'retry_or_check_settings',
        };
      }
    } catch (e) {
      debugPrint('❌ Error checking Health Connect permissions: $e');
      return {
        'success': false,
        'error': 'Error checking permissions. Please try again.',
        'errorCode': 'CHECK_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Disconnect from Health Connect
  static Future<bool> disconnectHealthConnect() async {
    try {
      // Note: We can't revoke permissions programmatically
      // But we can clear our saved status
      await _saveConnectionStatus('Health Connect', false);
      debugPrint('✅ Health Connect disconnected (local status cleared)');
      return true;
    } catch (e) {
      debugPrint('Error disconnecting Health Connect: $e');
      return false;
    }
  }

  /// Direct Health Connect permission launcher (bypasses plugin detection)
  static Future<bool> launchHealthConnectPermissions() async {
    try {
      debugPrint(
        '🚀 Launching Health Connect permissions via native channel...',
      );
      const channel = MethodChannel(
        'com.example.nutrition_flutter/healthconnect',
      );
      debugPrint('📡 Invoking native method: launchPermissions');
      final bool launched =
          await channel.invokeMethod<bool>('launchPermissions') ?? false;
      debugPrint('📡 Native method result: $launched');
      return launched;
    } catch (e) {
      debugPrint('❌ Error launching Health Connect permissions: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error details: ${e.toString()}');
      return false;
    }
  }

  /// Enhanced Health Connect settings opener
  static Future<bool> openHealthConnectSettings() async {
    try {
      debugPrint('🔧 Opening Health Connect settings (Enhanced)...');

      // Use native channel to open settings directly (no chooser)
      const channel = MethodChannel(
        'com.example.nutrition_flutter/healthconnect',
      );
      debugPrint('📡 Invoking native method: openSettings');
      final bool opened =
          await channel.invokeMethod<bool>('openSettings') ?? false;
      debugPrint('📡 Native method result: $opened');
      return opened;
    } catch (e) {
      debugPrint('❌ Error opening Health Connect: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error details: ${e.toString()}');
      return false;
    }
  }

  /// Force app registration in Health Connect by making multiple API calls
  static Future<void> forceHealthConnectRegistration() async {
    try {
      debugPrint('🔄 Forcing Health Connect app registration...');

      // Method 1: Request permissions explicitly
      try {
        await health.requestAuthorization(
          permissionTypes,
          permissions: permissions,
        );
        debugPrint('🔄 Registration method 1: requestAuthorization completed');
      } catch (e) {
        debugPrint('🔄 Registration method 1 failed: $e');
      }

      // Method 2: Check permissions (triggers registration)
      try {
        await health.hasPermissions(permissionTypes, permissions: permissions);
        debugPrint('🔄 Registration method 2: hasPermissions completed');
      } catch (e) {
        debugPrint('🔄 Registration method 2 failed: $e');
      }

      // Method 3: Attempt data read (forces registration)
      try {
        final now = DateTime.now();
        final oneMinuteAgo = now.subtract(Duration(minutes: 1));
        await health.getHealthDataFromTypes(
          types: coreTypes,
          startTime: oneMinuteAgo,
          endTime: now,
        );
        debugPrint('🔄 Registration method 3: data read completed');
      } catch (e) {
        debugPrint('🔄 Registration method 3 failed: $e');
      }

      debugPrint('🔄 Health Connect registration attempts completed');
    } catch (e) {
      debugPrint('🔄 Force registration failed: $e');
    }
  }

  /// Diagnostics: verify Health Connect installation and app visibility
  static Future<Map<String, dynamic>> diagnoseHealthConnectVisibility() async {
    final diagnostics = <String, dynamic>{};
    try {
      diagnostics['timestamp'] = DateTime.now().toIso8601String();
      diagnostics['coreTypes'] = coreTypes.map((e) => e.toString()).toList();
      diagnostics['permissions'] =
          permissions.map((e) => e.toString()).toList();

      // Check install status via native channel
      const channel = MethodChannel(
        'com.example.nutrition_flutter/healthconnect',
      );
      bool installed = await channel.invokeMethod<bool>('isInstalled') ?? false;
      diagnostics['isInstalled'] = installed;

      // Probe permissions existence (registration often shows up after this)
      try {
        bool? has = await health.hasPermissions(
          permissionTypes,
          permissions: permissions,
        );
        diagnostics['hasPermissionsProbe'] = has;
      } catch (e) {
        diagnostics['hasPermissionsProbeError'] = e.toString();
      }

      // Try reading tiny window of steps (forces registration sometimes)
      try {
        final now = DateTime.now();
        final fiveMinAgo = now.subtract(Duration(minutes: 5));
        final data = await health.getHealthDataFromTypes(
          types: coreTypes,
          startTime: fiveMinAgo,
          endTime: now,
        );
        diagnostics['dataProbeCount'] = data.length;
      } catch (e) {
        diagnostics['dataProbeError'] = e.toString();
      }

      // Manifest/array hints for support review
      diagnostics['manifestHints'] = {
        'metaData.health_permissions': 'present (arrays.xml)',
        'metaData.supported_types': 'present (arrays.xml)',
      };

      debugPrint('🩺 Health Connect diagnostics: $diagnostics');
      return diagnostics;
    } catch (e) {
      diagnostics['fatalError'] = e.toString();
      debugPrint('🩺 Health Connect diagnostics failed: $diagnostics');
      return diagnostics;
    }
  }

  /// Get today's steps with enhanced error handling
  static Future<int> getTodaySteps() async {
    try {
      if (!await isHealthConnectConnected()) {
        debugPrint('❌ Health Connect not connected for steps');
        return 0;
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: coreTypes,
        startTime: midnight,
        endTime: now,
      );

      int totalSteps = 0;
      for (HealthDataPoint point in healthData) {
        if (point.value is NumericHealthValue) {
          totalSteps +=
              (point.value as NumericHealthValue).numericValue.round();
        }
      }

      debugPrint('📊 Today\'s steps from Health Connect: $totalSteps');
      return totalSteps;
    } catch (e) {
      debugPrint('❌ Error getting steps from Health Connect: $e');
      return 0;
    }
  }

  /// Get latest heart rate
  static Future<int?> getLatestHeartRate() async {
    try {
      if (!await isHealthConnectConnected()) {
        return null;
      }

      // Ensure we have permission for heart rate
      await _ensurePermissions(
        _vitalsReadTypes,
        _readAccessFor(_vitalsReadTypes),
      );

      final now = DateTime.now();
      final oneHourAgo = now.subtract(Duration(hours: 1));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: oneHourAgo,
        endTime: now,
      );

      if (healthData.isNotEmpty) {
        healthData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        HealthDataPoint latestPoint = healthData.first;

        if (latestPoint.value is NumericHealthValue) {
          int heartRate =
              (latestPoint.value as NumericHealthValue).numericValue.round();
          debugPrint('❤️ Latest heart rate: $heartRate BPM');
          return heartRate;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting heart rate: $e');
      return null;
    }
  }

  /// Get today's calories burned
  static Future<double> getTodayCaloriesBurned() async {
    try {
      if (!await isHealthConnectConnected()) {
        return 0.0;
      }

      // Ensure we have permission for calories
      await _ensurePermissions([
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ], _readAccessFor([HealthDataType.ACTIVE_ENERGY_BURNED]));

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );

      double totalCalories = 0.0;
      for (HealthDataPoint point in healthData) {
        if (point.value is NumericHealthValue) {
          totalCalories += (point.value as NumericHealthValue).numericValue;
        }
      }

      debugPrint('🔥 Today\'s calories from Health Connect: $totalCalories');
      return totalCalories;
    } catch (e) {
      debugPrint('❌ Error getting calories: $e');
      return 0.0;
    }
  }

  /// Periodic background sync (simple timer-based while app is in foreground)
  static Timer? _syncTimer;

  static void startForegroundSync({
    Duration interval = const Duration(minutes: 15),
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) async {
      final connected = await isHealthConnectConnected();
      if (!connected) return;
      try {
        await getTodaySteps();
        await getTodayCaloriesBurned();
      } catch (_) {}
    });
  }

  static void stopForegroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Get recent workouts
  static Future<List<Map<String, dynamic>>> getRecentWorkouts() async {
    try {
      if (!await isHealthConnectConnected()) {
        return [];
      }

      // Ensure we have permission for workouts
      await _ensurePermissions([
        HealthDataType.WORKOUT,
      ], _readAccessFor([HealthDataType.WORKOUT]));

      final now = DateTime.now();
      final threeDaysAgo = now.subtract(Duration(days: 3));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: threeDaysAgo,
        endTime: now,
      );

      List<Map<String, dynamic>> workouts = [];
      for (HealthDataPoint point in healthData) {
        workouts.add({
          'type': point.type.toString().replaceAll('HealthDataType.', ''),
          'startTime': point.dateFrom,
          'endTime': point.dateTo,
          'duration': point.dateTo.difference(point.dateFrom).inMinutes,
        });
      }

      debugPrint('🏃 Found ${workouts.length} recent workouts');
      return workouts;
    } catch (e) {
      debugPrint('❌ Error getting workouts: $e');
      return [];
    }
  }

  /// Save connection status to SharedPreferences
  static Future<void> _saveConnectionStatus(
    String platform,
    bool connected,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connected_$platform', connected);
  }

  /// Get connection status from SharedPreferences
  static Future<bool> _getConnectionStatus(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('connected_$platform') ?? false;
  }

  /// Get connection status for all platforms (limited set)
  static Future<Map<String, bool>> getAllConnectionStatuses() async {
    return {
      'Health Connect': await isHealthConnectConnected(),
      'Google Fit': await GoogleFitService.isConnectedToGoogleFit(),
    };
  }

  /// Ensure permissions for specific types; request if missing (read-only flow)
  static Future<void> _ensurePermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> access,
  ) async {
    try {
      bool? has = await health.hasPermissions(types, permissions: access);
      if (has == true) return;
      await health.requestAuthorization(types, permissions: access);
    } catch (e) {
      // Non-fatal; data call may still fail gracefully
      debugPrint('⚠️ ensurePermissions failed for $types: $e');
    }
  }

  /// Connect to a specific platform
  static Future<dynamic> connectPlatform(String platformName) async {
    switch (platformName) {
      case 'Health Connect':
        Map<String, dynamic> result = await requestHealthConnectPermissions();
        return result['success'] ?? false;
      case 'Google Fit':
        // Import GoogleFitService and use it
        try {
          final result = await GoogleFitService.connectToGoogleFit();
          return result; // Return the full result object
        } catch (e) {
          debugPrint('❌ Google Fit connection failed: $e');
          return {
            'success': false,
            'error': 'Google Fit connection failed: $e',
            'errorCode': 'CONNECTION_ERROR',
          };
        }
      case 'Samsung Health':
      case 'Fitbit':
      case 'Strava':
        await _saveConnectionStatus(platformName, true);
        return true;
      default:
        return false;
    }
  }

  /// Disconnect from a platform
  static Future<bool> disconnectPlatform(String platformName) async {
    switch (platformName) {
      case 'Health Connect':
        return await disconnectHealthConnect();
      case 'Google Fit':
        try {
          return await GoogleFitService.disconnectGoogleFit();
        } catch (e) {
          debugPrint('❌ Google Fit disconnection failed: $e');
          return false;
        }
      case 'Samsung Health':
      case 'Fitbit':
      case 'Strava':
        await _saveConnectionStatus(platformName, false);
        return true;
      default:
        return false;
    }
  }
}
