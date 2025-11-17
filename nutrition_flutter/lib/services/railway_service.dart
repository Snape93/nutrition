import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'dart:async';

/// Service to handle Railway-specific issues (sleep/wake, retries)
class RailwayService {
  RailwayService._();
  static final RailwayService _instance = RailwayService._();
  static RailwayService get instance => _instance;

  /// Wake up Railway server by making a quick health check
  /// This helps with free tier apps that sleep after inactivity
  static Future<bool> wakeUpServer({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      debugPrint('🔄 Waking up Railway server...');
      final response = await http
          .get(Uri.parse('$apiBase/health'))
          .timeout(timeout);
      
      if (response.statusCode == 200) {
        debugPrint('✅ Railway server is awake');
        return true;
      } else {
        debugPrint('⚠️ Railway server responded with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Railway wake-up check failed (server may be sleeping): $e');
      // Don't fail - server might wake up during main request
      return false;
    }
  }

  /// Execute HTTP request with Railway-specific retry logic
  /// Handles Railway free tier sleep/wake behavior
  static Future<http.Response> executeWithRetry({
    required Future<http.Response> Function() request,
    int maxRetries = 2,
    Duration initialTimeout = const Duration(seconds: 30),
    bool wakeUpFirst = true,
  }) async {
    // Step 1: Wake up server first (if enabled)
    if (wakeUpFirst) {
      await wakeUpServer();
      // Give server a moment to fully wake up
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Step 2: Try request with retries
    Exception? lastException;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 Retry attempt $attempt/$maxRetries...');
          // Exponential backoff: 1s, 2s, 4s
          final delay = Duration(seconds: 1 << (attempt - 1));
          await Future.delayed(delay);
          
          // Wake up server again before retry
          await wakeUpServer();
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final response = await request().timeout(initialTimeout);
        debugPrint('✅ Request successful on attempt ${attempt + 1}');
        return response;
        
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint('⏱️ Timeout on attempt ${attempt + 1}: $e');
        
        if (attempt < maxRetries) {
          debugPrint('🔄 Will retry...');
          continue;
        } else {
          debugPrint('❌ All retry attempts exhausted');
          rethrow;
        }
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint('🌐 Network error on attempt ${attempt + 1}: $e');
        
        // Network errors might be temporary, retry
        if (attempt < maxRetries) {
          continue;
        } else {
          rethrow;
        }
      } catch (e) {
        // Other errors (like HTTP error codes) - don't retry
        debugPrint('❌ Request failed with error: $e');
        rethrow;
      }
    }

    // Should never reach here, but just in case
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('Request failed after $maxRetries retries');
  }

  /// Check if Railway server is reachable
  static Future<bool> isServerReachable({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Server not reachable: $e');
      return false;
    }
  }
}

