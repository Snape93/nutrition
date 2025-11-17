import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/foundation.dart';

/// Service for checking internet connectivity status
/// Combines connectivity_plus (network interface) with internet_connection_checker (actual internet access)
class ConnectivityService {
  ConnectivityService._();
  
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  // InternetConnectionChecker instance - create once and reuse
  late final InternetConnectionChecker _connectionChecker;
  
  // Stream controller for connectivity changes
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  bool _lastKnownStatus = true; // Assume connected by default
  Timer? _debounceTimer;

  /// Initialize connectivity monitoring
  void initialize() {
    // Initialize InternetConnectionChecker
    _connectionChecker = InternetConnectionChecker.createInstance(
      checkInterval: const Duration(seconds: 10),
      checkTimeout: const Duration(seconds: 3),
    );
    
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _debounceConnectivityCheck();
    });
    
    // Initial check
    _checkConnectivity();
  }

  /// Debounce connectivity checks to avoid rapid notifications
  void _debounceConnectivityCheck() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _checkConnectivity();
    });
  }

  /// Check connectivity status (both network interface and actual internet)
  Future<bool> _checkConnectivity() async {
    try {
      // First check if any network interface is available
      final connectivityResults = await _connectivity.checkConnectivity();
      
      // If no network interface, definitely no internet
      if (connectivityResults.contains(ConnectivityResult.none)) {
        _updateStatus(false);
        return false;
      }

      // Network interface exists, check actual internet access
      final status = await _connectionChecker.connectionStatus;
      final hasInternet = status == InternetConnectionStatus.connected;
      _updateStatus(hasInternet);
      return hasInternet;
    } catch (e) {
      debugPrint('ConnectivityService: Error checking connectivity: $e');
      // On error, assume no connection to be safe
      _updateStatus(false);
      return false;
    }
  }

  /// Update connectivity status and notify listeners
  void _updateStatus(bool isConnected) {
    if (_lastKnownStatus != isConnected) {
      _lastKnownStatus = isConnected;
      _connectivityController.add(isConnected);
      debugPrint('ConnectivityService: Status changed to ${isConnected ? "connected" : "disconnected"}');
    }
  }

  /// Quick check if device is currently connected
  /// Returns true if both network interface exists AND internet is accessible
  Future<bool> isConnected() async {
    return await _checkConnectivity();
  }

  /// Check if device has internet connection (more accurate than isConnected)
  /// This verifies actual internet access, not just network interface
  /// [forceRefresh] - if true, forces a fresh check instead of using cached status
  Future<bool> hasInternetConnection({bool forceRefresh = false}) async {
    try {
      // Check network interface first (faster)
      final connectivityResults = await _connectivity.checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none)) {
        debugPrint('ConnectivityService: No network interface available');
        return false;
      }

      // Then verify actual internet access
      bool hasInternet;
      if (forceRefresh) {
        // Force a fresh check using hasConnection which performs an actual check
        debugPrint('ConnectivityService: Forcing fresh internet connection check...');
        hasInternet = await _connectionChecker.hasConnection;
        debugPrint('ConnectivityService: Fresh check result: $hasInternet');
      } else {
        // Use cached status for faster response
        final status = await _connectionChecker.connectionStatus;
        hasInternet = status == InternetConnectionStatus.connected;
      }
      
      // Update internal status
      _updateStatus(hasInternet);
      
      return hasInternet;
    } catch (e) {
      debugPrint('ConnectivityService: Error checking internet connection: $e');
      return false;
    }
  }

  /// Get current connectivity result (network interface type)
  Future<List<ConnectivityResult>> getConnectivityResult() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('ConnectivityService: Error getting connectivity result: $e');
      return [ConnectivityResult.none];
    }
  }

  /// Get connection type as string (WiFi, Mobile, None, etc.)
  Future<String> getConnectionType() async {
    final results = await getConnectivityResult();
    
    if (results.contains(ConnectivityResult.none)) {
      return 'None';
    } else if (results.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else {
      return 'Unknown';
    }
  }

  /// Get last known connectivity status (synchronous, no network call)
  bool get lastKnownStatus => _lastKnownStatus;

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _connectivityController.close();
  }
}

