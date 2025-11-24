import 'package:flutter/material.dart';
import 'config.dart' as config;
import 'login.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'theme_service.dart';
import 'user_database.dart';
import 'design_system/app_design_system.dart';

class AccountDeletionVerificationScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String email;
  final String? userSex;
  final String? expiresAt; // ISO format string from backend

  const AccountDeletionVerificationScreen({
    super.key,
    required this.usernameOrEmail,
    required this.email,
    this.userSex,
    this.expiresAt,
  });

  @override
  State<AccountDeletionVerificationScreen> createState() =>
      _AccountDeletionVerificationScreenState();
}

class _AccountDeletionVerificationScreenState
    extends State<AccountDeletionVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';
  String _message = '';
  int _resendCountdown = 0;
  int _expirationCountdown = 0;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Timer? _expirationTimer;

  Color get primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(widget.userSex);
  
  // Design system colors - using error color for destructive action
  Color get errorColor => AppDesignSystem.error;
  Color get successColor => AppDesignSystem.success;
  Color get warningColor => AppDesignSystem.warning;
  Color get infoColor => AppDesignSystem.info;
  Color get onSurfaceVariant => AppDesignSystem.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _startExpirationCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _expirationTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 60; // 60 seconds
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpirationCountdown() {
    // Use expires_at from backend if available, otherwise default to 15 minutes
    if (widget.expiresAt != null) {
      try {
        _expiresAt = DateTime.parse(widget.expiresAt!);
      } catch (e) {
        debugPrint('Error parsing expires_at: $e');
        _expiresAt = DateTime.now().add(const Duration(minutes: 15));
      }
    } else {
      _expiresAt = DateTime.now().add(const Duration(minutes: 15));
    }
    _updateExpirationCountdown();
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateExpirationCountdown();
      if (_expirationCountdown <= 0) {
        timer.cancel();
        setState(() {
          _errorMessage =
              'Verification code has expired. Please request a new one.';
        });
      }
    });
  }

  void _updateExpirationCountdown() {
    if (_expiresAt != null) {
      final now = DateTime.now();
      final difference = _expiresAt!.difference(now);
      setState(() {
        _expirationCountdown = difference.inSeconds;
      });
    }
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Verification code must be 6 digits';
      });
      return;
    }

    // Final confirmation before deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Final Confirmation',
          style: TextStyle(color: AppDesignSystem.error),
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted:\n\n'
          '• Food logs\n'
          '• Exercise logs\n'
          '• Weight logs\n'
          '• Workout logs\n'
          '• Custom recipes\n'
          '• All personal data\n\n'
          'Are you absolutely sure you want to delete your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.error),
            child: const Text('Yes, Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                '${config.apiBase}/user/${widget.usernameOrEmail}/delete/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'verification_code': code,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Clear local database
        try {
          final db = await UserDatabase().database;
          await db.delete(
            'users',
            where: 'username = ? OR email = ?',
            whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
          );
        } catch (e) {
          debugPrint('Error clearing local database: $e');
        }

        if (!mounted) return;

        // Show success dialog
        await _showSuccessDialog('Account deleted successfully');

        if (!mounted) return;

        // Navigate to login and clear all routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        final errorMsg =
            responseData['error'] ?? 'Verification failed. Please try again.';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });

        // If expired, stop timers
        if (errorMsg.contains('expired')) {
          _expirationTimer?.cancel();
          _countdownTimer?.cancel();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _showSuccessDialog(String message, {String title = 'Success'}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            boxShadow: [
              BoxShadow(
                color: errorColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: errorColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: AppDesignSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: errorColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: AppDesignSystem.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                    ),
                    elevation: AppDesignSystem.elevationLow,
                  ),
                  child: Text(
                    'OK',
                    style: AppDesignSystem.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                '${config.apiBase}/user/${widget.usernameOrEmail}/delete/resend-code'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isResending = false;
          _message = 'Verification code sent! Check your email.';
        });

        // Update expiration time if provided
        if (responseData['expires_at'] != null) {
          try {
            _expiresAt = DateTime.parse(responseData['expires_at']);
            _startExpirationCountdown(); // Restart countdown with new expiration
          } catch (e) {
            debugPrint('Error parsing expires_at: $e');
          }
        }

        _startResendCountdown();
      } else {
        final errorMsg =
            responseData['error'] ?? 'Failed to resend code. Please try again.';
        setState(() {
          _isResending = false;
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _isResending = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _cancelDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Account Deletion'),
        content: const Text(
          'Are you sure you want to cancel the account deletion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Continue Deletion'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse(
              '${config.apiBase}/user/${widget.usernameOrEmail}/delete/cancel'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          if (mounted) {
            Navigator.of(context).pop(); // Go back to account settings
          }
        } else {
          // Even if cancel fails, allow navigation back
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        // Even if cancel fails, allow navigation back
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: AppDesignSystem.elevationMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppDesignSystem.spaceLG),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: errorColor,
                      ),
                    ),
                    SizedBox(height: AppDesignSystem.spaceMD),
                    Text(
                      'Verify Account Deletion',
                      style: AppDesignSystem.displaySmall.copyWith(
                        color: errorColor,
                      ),
                    ),
                    SizedBox(height: AppDesignSystem.spaceSM),
                    Container(
                      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        border: Border.all(
                          color: errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '⚠️ WARNING: This action is permanent!',
                            style: AppDesignSystem.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: errorColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppDesignSystem.spaceSM),
                          Text(
                            'All your data will be permanently deleted:',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppDesignSystem.spaceSM),
                          Text(
                            '• Food logs\n'
                            '• Exercise logs\n'
                            '• Weight logs\n'
                            '• Workout logs\n'
                            '• Custom recipes\n'
                            '• All personal data',
                            style: AppDesignSystem.bodySmall,
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppDesignSystem.spaceMD),
                    Text(
                      'We sent a 6-digit verification code to',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDesignSystem.spaceSM),
                    Container(
                      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                        border: Border.all(color: AppDesignSystem.outline),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.email,
                          style: AppDesignSystem.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Expiration countdown
                    if (_expirationCountdown > 0) ...[
                      SizedBox(height: AppDesignSystem.spaceSM),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDesignSystem.spaceSM,
                          vertical: AppDesignSystem.spaceSM,
                        ),
                        decoration: BoxDecoration(
                          color: (_expirationCountdown < 300
                                  ? warningColor
                                  : infoColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                          border: Border.all(
                            color: (_expirationCountdown < 300
                                    ? warningColor
                                    : infoColor)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: _expirationCountdown < 300
                                  ? warningColor
                                  : infoColor,
                            ),
                            SizedBox(width: AppDesignSystem.spaceXS),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Code expires in: ${_formatCountdown(_expirationCountdown)}',
                                  style: AppDesignSystem.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _expirationCountdown < 300
                                        ? warningColor
                                        : infoColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: AppDesignSystem.spaceLG),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: AppDesignSystem.displaySmall.copyWith(
                        color: Colors.black,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        labelStyle: TextStyle(color: Colors.black),
                        hintText: '000000',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: errorColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                          borderSide: BorderSide(color: errorColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: '',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _errorMessage = '';
                          _message = '';
                        });
                      },
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      SizedBox(height: AppDesignSystem.spaceSM),
                      Container(
                        padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                        decoration: BoxDecoration(
                          color: errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                          border: Border.all(
                            color: errorColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: errorColor, size: 20),
                            SizedBox(width: AppDesignSystem.spaceSM),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: AppDesignSystem.bodyMedium.copyWith(
                                  color: errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_message.isNotEmpty) ...[
                      SizedBox(height: AppDesignSystem.spaceSM),
                      Container(
                        padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                        decoration: BoxDecoration(
                          color: successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                          border: Border.all(
                            color: successColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: successColor, size: 20),
                            SizedBox(width: AppDesignSystem.spaceSM),
                            Expanded(
                              child: Text(
                                _message,
                                style: AppDesignSystem.bodyMedium.copyWith(
                                  color: successColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: AppDesignSystem.spaceLG),
                    _isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(errorColor),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: errorColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                padding: EdgeInsets.symmetric(
                                  vertical: AppDesignSystem.spaceMD,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                                ),
                                textStyle: AppDesignSystem.titleMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              child: const Text('Verify & Delete Account'),
                            ),
                          ),
                    SizedBox(height: AppDesignSystem.spaceMD),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Flexible(
                          child: Text(
                            "Didn't receive the code?",
                            style: AppDesignSystem.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: _resendCountdown > 0 || _isResending
                              ? null
                              : _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: errorColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDesignSystem.spaceXS,
                              vertical: AppDesignSystem.spaceXS,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _isResending
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(errorColor),
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _resendCountdown > 0
                                        ? 'Resend in ${_resendCountdown}s'
                                        : 'Resend Code',
                                    style: AppDesignSystem.labelLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: errorColor,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppDesignSystem.spaceMD),
                    TextButton(
                      onPressed: _isLoading ? null : _cancelDeletion,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
                      child: Text(
                        'Cancel Deletion',
                        style: AppDesignSystem.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

