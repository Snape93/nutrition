import 'package:flutter/material.dart';
import 'config.dart' as config;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'theme_service.dart';
import 'design_system/app_design_system.dart';

class PasswordChangeVerificationScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;
  final String? expiresAt; // ISO format string from backend

  const PasswordChangeVerificationScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
    this.expiresAt,
  });

  @override
  State<PasswordChangeVerificationScreen> createState() =>
      _PasswordChangeVerificationScreenState();
}

class _PasswordChangeVerificationScreenState
    extends State<PasswordChangeVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  bool _isCancelling = false;
  bool _hasVerified = false;
  String _errorMessage = '';
  String _message = '';
  int _resendCountdown = 0;
  int _expirationCountdown = 0;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Timer? _expirationTimer;

  Color get primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(widget.userSex);
  
  // Design system colors
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

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                '${config.apiBase}/user/${widget.usernameOrEmail}/password/verify-change'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isLoading = false;
          _hasVerified = true; // Mark as verified to prevent cancellation
        });

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password changed successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
            ),
            margin: EdgeInsets.all(AppDesignSystem.spaceMD),
          ),
        );

        // Navigate back to previous screen (Account Settings) - user stays logged in
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        final errorMsg = responseData['error'] ??
            'Verification failed. Please try again.';
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
                '${config.apiBase}/user/${widget.usernameOrEmail}/password/resend-code'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Update expiration time if provided
        if (responseData['expires_at'] != null) {
          try {
            _expiresAt = DateTime.parse(responseData['expires_at']);
            _updateExpirationCountdown();
          } catch (e) {
            debugPrint('Error parsing expires_at: $e');
          }
        }

        setState(() {
          _isResending = false;
          _message = 'Verification code resent successfully';
        });

        _startResendCountdown();
      } else {
        final errorMsg = responseData['error'] ??
            'Failed to resend code. Please try again.';
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

  Future<void> _cancelChange({bool showConfirmation = true}) async {
    // Don't cancel if already verified
    if (_hasVerified) {
      Navigator.of(context).pop();
      return;
    }

    // Show confirmation dialog if requested
    if (showConfirmation && mounted) {
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Cancel Password Change?',
            style: AppDesignSystem.titleLarge.copyWith(
              color: primaryColor,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel? You will need to request a new password change.',
            style: AppDesignSystem.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'No, Continue',
                style: TextStyle(color: primaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppDesignSystem.error,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        ),
      );

      if (shouldCancel != true) {
        return; // User chose not to cancel
      }
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                '${config.apiBase}/user/${widget.usernameOrEmail}/password/cancel-change'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (!mounted) return;
        debugPrint('[CANCEL] Password change cancelled successfully');
        Navigator.of(context).pop();
      } else {
        debugPrint('[CANCEL] Failed to cancel password change: ${response.statusCode}');
        // Still navigate back even if cancel fails
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[CANCEL] Error cancelling password change: $e');
      // Still navigate back even if cancel fails
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _hasVerified, // Only allow back if verified
      onPopInvoked: (didPop) async {
        if (!didPop && !_hasVerified) {
          // Intercept back button - cancel password change
          await _cancelChange(showConfirmation: true);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: AppDesignSystem.getResponsivePadding(context),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: Center(
                    child: Card(
                      elevation: AppDesignSystem.elevationMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppDesignSystem.spaceLG),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: primaryColor,
                            ),
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Title
                  Text(
                    'Verify Password Change',
                    style: AppDesignSystem.displaySmall.copyWith(
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDesignSystem.spaceSM),

                  // Description
                  Text(
                    'We sent a verification code to your email address. Please enter the code below to complete your password change.',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      color: AppDesignSystem.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDesignSystem.spaceSM),

                  // Expiration countdown
                  if (_expirationCountdown > 0)
                    Container(
                      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                      decoration: BoxDecoration(
                        color: infoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                        border: Border.all(
                          color: infoColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: infoColor,
                          ),
                          SizedBox(width: AppDesignSystem.spaceXS),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Code expires in: ${_formatCountdown(_expirationCountdown)}',
                                style: AppDesignSystem.labelSmall.copyWith(
                                  color: infoColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: AppDesignSystem.spaceLG),

                  // Code input field
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: AppDesignSystem.displaySmall.copyWith(
                      color: primaryColor,
                      letterSpacing: 8,
                    ),
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: TextStyle(color: AppDesignSystem.onSurface),
                      hintText: '000000',
                      hintStyle: TextStyle(
                        letterSpacing: 8,
                        color: AppDesignSystem.outlineVariant,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        borderSide: BorderSide(
                          color: AppDesignSystem.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        borderSide: BorderSide(
                          color: errorColor,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        borderSide: BorderSide(
                          color: errorColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppDesignSystem.surface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _errorMessage = '';
                      });
                    },
                  ),

                  SizedBox(height: AppDesignSystem.spaceSM),

                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                        border: Border.all(
                          color: errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: errorColor,
                          ),
                          SizedBox(width: AppDesignSystem.spaceSM),
                          Flexible(
                            child: Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: AppDesignSystem.bodyMedium.copyWith(
                                color: errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Success message
                  if (_message.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: successColor,
                          ),
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

                  SizedBox(height: AppDesignSystem.spaceLG),

                  // Verify button
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppDesignSystem.spaceMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                        ),
                        elevation: AppDesignSystem.elevationLow,
                      ),
                      child: Text(
                        'Verify Code',
                        style: AppDesignSystem.titleMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),

                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Resend code button
                  TextButton(
                    onPressed: _resendCountdown > 0 || _isResending
                        ? null
                        : _resendCode,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.spaceXS,
                        vertical: AppDesignSystem.spaceXS,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _isResending
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _resendCountdown > 0
                                  ? 'Resend code (${_resendCountdown}s)'
                                  : 'Resend Code',
                              style: AppDesignSystem.labelLarge.copyWith(
                                color: primaryColor,
                              ),
                            ),
                          ),
                  ),

                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Cancel button
                  TextButton(
                    onPressed: (_isCancelling || _hasVerified) ? null : () => _cancelChange(showConfirmation: true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignSystem.onSurfaceVariant,
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.onSurfaceVariant),
                            ),
                          )
                        : Text(
                            'Cancel',
                            style: AppDesignSystem.labelLarge,
                          ),
                  ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

