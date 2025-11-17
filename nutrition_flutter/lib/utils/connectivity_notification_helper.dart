import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';
import '../services/connectivity_service.dart';

/// Helper class for displaying connectivity-related notifications
/// Provides consistent, user-friendly notifications for connectivity issues
class ConnectivityNotificationHelper {
  ConnectivityNotificationHelper._();

  /// Show a dialog when user tries to perform action without internet connection
  /// Returns true if user wants to retry, false if they dismiss
  static Future<bool> showNoConnectionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NoConnectionDialog(),
    );
    return result ?? false;
  }

  /// Show a SnackBar when connection is lost during app usage
  static void showConnectionLostSnackBar(BuildContext context, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Expanded(
              child: Text(
                'Connection lost. Please check your internet connection.',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppDesignSystem.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Connection restored – we simply remove any lingering error SnackBars
  /// so the UI returns to its normal (no-notification) state.
  static void showConnectionRestoredSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Show a warning SnackBar for slow/unstable connection
  static void showSlowConnectionSnackBar(BuildContext context, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.signal_wifi_statusbar_connected_no_internet_4,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Expanded(
              child: Text(
                'Your connection seems slow. Please check your network or try again.',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppDesignSystem.warning,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show a dialog with retry option when connection check fails multiple times
  static Future<bool> showRetryFailedDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RetryFailedDialog(),
    );
    return result ?? false;
  }

  /// Check connectivity and show appropriate notification if needed
  /// Returns true if connected, false if not connected (and shows notification)
  static Future<bool> checkAndNotifyIfDisconnected(
    BuildContext context, {
    bool showDialog = true,
  }) async {
    final isConnected = await ConnectivityService.instance.hasInternetConnection();
    
    if (!isConnected && showDialog) {
      final shouldRetry = await showNoConnectionDialog(context);
      if (shouldRetry) {
        // Retry connectivity check with force refresh
        return await ConnectivityService.instance.hasInternetConnection(forceRefresh: true);
      }
    }
    
    return isConnected;
  }
}

/// Dialog widget for no internet connection
class _NoConnectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          boxShadow: [
            BoxShadow(
              color: AppDesignSystem.error.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
              decoration: BoxDecoration(
                color: AppDesignSystem.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off,
                color: AppDesignSystem.error,
                size: 48,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            
            // Title
            Text(
              'No Internet Connection',
              style: AppDesignSystem.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppDesignSystem.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            
            // Message
            Text(
              'Please check your connection and try again. Make sure you\'re connected to WiFi or mobile data.',
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            
            // Buttons
            Row(
              children: [
                // Retry button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesignSystem.error,
                      side: BorderSide(color: AppDesignSystem.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDesignSystem.spaceMD,
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: AppDesignSystem.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spaceMD),
                
                // OK button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDesignSystem.spaceMD,
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: AppDesignSystem.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog widget for retry failed after multiple attempts
class _RetryFailedDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          boxShadow: [
            BoxShadow(
              color: AppDesignSystem.warning.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
              decoration: BoxDecoration(
                color: AppDesignSystem.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                color: AppDesignSystem.warning,
                size: 48,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            
            // Title
            Text(
              'Connection Issues',
              style: AppDesignSystem.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppDesignSystem.warning,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            
            // Message
            Text(
              'Still having connection issues? Please check your network settings or try again later.',
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            
            // OK button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDesignSystem.spaceMD,
                  ),
                ),
                child: Text(
                  'OK',
                  style: AppDesignSystem.labelLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

