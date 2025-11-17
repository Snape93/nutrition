import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/connectivity_service.dart';
import 'connectivity_notification_helper.dart';

/// Helper class for making HTTP requests with automatic connectivity checking
/// Wraps http calls and handles connectivity errors gracefully
class ApiHelper {
  ApiHelper._();

  /// Make a GET request with connectivity check
  /// Returns the response if successful, null if connectivity check fails
  /// Throws exception for other errors
  static Future<http.Response?> get(
    BuildContext? context,
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
    bool checkConnectivity = true,
  }) async {
    if (checkConnectivity && context != null) {
      final isConnected = await ConnectivityService.instance.hasInternetConnection();
      if (!isConnected) {
        final shouldRetry = await ConnectivityNotificationHelper.showNoConnectionDialog(context);
        if (shouldRetry) {
          // Retry connectivity check
          final retryConnected = await ConnectivityService.instance.hasInternetConnection();
          if (!retryConnected) {
            return null;
          }
        } else {
          return null;
        }
      }
    }

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(timeout ?? const Duration(seconds: 30));
      return response;
    } on SocketException catch (e) {
      // Network error
      if (context != null && context.mounted) {
        ConnectivityNotificationHelper.showConnectionLostSnackBar(context);
      }
      throw Exception('Network error: ${e.message}');
    } on HttpException catch (e) {
      // HTTP error
      throw Exception('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      // Format error
      throw Exception('Format error: ${e.message}');
    } catch (e) {
      // Other errors (including timeout)
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        if (context != null && context.mounted) {
          ConnectivityNotificationHelper.showSlowConnectionSnackBar(context);
        }
        throw Exception('Request timeout. Please check your connection and try again.');
      }
      rethrow;
    }
  }

  /// Make a POST request with connectivity check
  static Future<http.Response?> post(
    BuildContext? context,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    bool checkConnectivity = true,
  }) async {
    if (checkConnectivity && context != null) {
      final isConnected = await ConnectivityService.instance.hasInternetConnection();
      if (!isConnected) {
        final shouldRetry = await ConnectivityNotificationHelper.showNoConnectionDialog(context);
        if (shouldRetry) {
          final retryConnected = await ConnectivityService.instance.hasInternetConnection();
          if (!retryConnected) {
            return null;
          }
        } else {
          return null;
        }
      }
    }

    try {
      final response = await http
          .post(url, headers: headers, body: body, encoding: encoding)
          .timeout(timeout ?? const Duration(seconds: 30));
      return response;
    } on SocketException catch (e) {
      if (context != null && context.mounted) {
        ConnectivityNotificationHelper.showConnectionLostSnackBar(context);
      }
      throw Exception('Network error: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Format error: ${e.message}');
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        if (context != null && context.mounted) {
          ConnectivityNotificationHelper.showSlowConnectionSnackBar(context);
        }
        throw Exception('Request timeout. Please check your connection and try again.');
      }
      rethrow;
    }
  }

  /// Make a PUT request with connectivity check
  static Future<http.Response?> put(
    BuildContext? context,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    bool checkConnectivity = true,
  }) async {
    if (checkConnectivity && context != null) {
      final isConnected = await ConnectivityService.instance.hasInternetConnection();
      if (!isConnected) {
        final shouldRetry = await ConnectivityNotificationHelper.showNoConnectionDialog(context);
        if (shouldRetry) {
          final retryConnected = await ConnectivityService.instance.hasInternetConnection();
          if (!retryConnected) {
            return null;
          }
        } else {
          return null;
        }
      }
    }

    try {
      final response = await http
          .put(url, headers: headers, body: body, encoding: encoding)
          .timeout(timeout ?? const Duration(seconds: 30));
      return response;
    } on SocketException catch (e) {
      if (context != null && context.mounted) {
        ConnectivityNotificationHelper.showConnectionLostSnackBar(context);
      }
      throw Exception('Network error: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Format error: ${e.message}');
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        if (context != null && context.mounted) {
          ConnectivityNotificationHelper.showSlowConnectionSnackBar(context);
        }
        throw Exception('Request timeout. Please check your connection and try again.');
      }
      rethrow;
    }
  }

  /// Make a DELETE request with connectivity check
  static Future<http.Response?> delete(
    BuildContext? context,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    bool checkConnectivity = true,
  }) async {
    if (checkConnectivity && context != null) {
      final isConnected = await ConnectivityService.instance.hasInternetConnection();
      if (!isConnected) {
        final shouldRetry = await ConnectivityNotificationHelper.showNoConnectionDialog(context);
        if (shouldRetry) {
          final retryConnected = await ConnectivityService.instance.hasInternetConnection();
          if (!retryConnected) {
            return null;
          }
        } else {
          return null;
        }
      }
    }

    try {
      final response = await http
          .delete(url, headers: headers, body: body, encoding: encoding)
          .timeout(timeout ?? const Duration(seconds: 30));
      return response;
    } on SocketException catch (e) {
      if (context != null && context.mounted) {
        ConnectivityNotificationHelper.showConnectionLostSnackBar(context);
      }
      throw Exception('Network error: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Format error: ${e.message}');
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        if (context != null && context.mounted) {
          ConnectivityNotificationHelper.showSlowConnectionSnackBar(context);
        }
        throw Exception('Request timeout. Please check your connection and try again.');
      }
      rethrow;
    }
  }

  /// Check connectivity before making a request (without making the request)
  /// Useful for pre-flight checks
  static Future<bool> checkConnectivityBeforeRequest(BuildContext? context) async {
    if (context == null) {
      return await ConnectivityService.instance.hasInternetConnection();
    }

    final isConnected = await ConnectivityService.instance.hasInternetConnection();
    if (!isConnected) {
      await ConnectivityNotificationHelper.showNoConnectionDialog(context);
      return await ConnectivityService.instance.hasInternetConnection();
    }
    return true;
  }
}

