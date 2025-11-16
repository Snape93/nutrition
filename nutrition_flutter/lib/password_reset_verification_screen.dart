import 'package:flutter/material.dart';
import 'config.dart' as config;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'theme_service.dart';
import 'design_system/app_design_system.dart';
import 'user_database.dart';
import 'login.dart';
import 'widgets/password_strength_widget.dart';

class PasswordResetVerificationScreen extends StatefulWidget {
  final String email;
  final String? userSex;
  final String? expiresAt; // ISO format string from backend

  const PasswordResetVerificationScreen({
    super.key,
    required this.email,
    this.userSex,
    this.expiresAt,
  });

  @override
  State<PasswordResetVerificationScreen> createState() =>
      _PasswordResetVerificationScreenState();
}

class _PasswordResetVerificationScreenState
    extends State<PasswordResetVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isResending = false;
  bool _isVerifyingCode = false;
  bool _isResettingPassword = false;
  bool _codeVerified = false; // Track if code has been verified
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  String _message = '';
  int _resendCountdown = 0;
  int _expirationCountdown = 0;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Timer? _expirationTimer;

  String? _userSex;

  Color get primaryColor =>
      ThemeService.getPrimaryColor(_userSex ?? widget.userSex);
  Color get backgroundColor =>
      ThemeService.getBackgroundColor(_userSex ?? widget.userSex);

  // Design system colors
  Color get errorColor => AppDesignSystem.error;
  Color get successColor => AppDesignSystem.success;
  Color get warningColor => AppDesignSystem.warning;
  Color get infoColor => AppDesignSystem.info;
  Color get onSurfaceVariant => AppDesignSystem.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    _userSex = widget.userSex;
    _loadUserSex();
    _startResendCountdown();
    _startExpirationCountdown();
  }

  Future<void> _loadUserSex() async {
    // Try to load user sex from email if not provided
    if (_userSex == null) {
      try {
        final userData = await UserDatabase().getUserData(widget.email);
        if (userData != null && mounted) {
          setState(() {
            _userSex = userData['sex'] as String?;
          });
        }
      } catch (e) {
        // Ignore errors - use default colors
        debugPrint('Could not load user sex: $e');
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _expirationTimer?.cancel();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
      _isVerifyingCode = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('${config.apiBase}/auth/password-reset/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': widget.email, 'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isVerifyingCode = false;
          _codeVerified = true;
          _message =
              'Verification code is correct! Please enter your new password.';
        });

        // Update expiration time if provided
        if (responseData['expires_at'] != null) {
          try {
            _expiresAt = DateTime.parse(responseData['expires_at']);
            _updateExpirationCountdown();
          } catch (e) {
            debugPrint('Error parsing expires_at: $e');
          }
        }
      } else {
        final errorMsg =
            responseData['error'] ?? 'Verification failed. Please try again.';
        setState(() {
          _isVerifyingCode = false;
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
        _isVerifyingCode = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    // Check password strength
    final strengthResult = calculatePasswordStrength(newPassword);
    if (!strengthResult.isValid) {
      setState(() {
        _errorMessage =
            'Password is too weak. Please ensure all requirements are met.';
      });
      return;
    }

    setState(() {
      _isResettingPassword = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '${config.apiBase}/auth/password-reset/verify-and-complete',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': widget.email,
              'code': code,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isResettingPassword = false;
        });

        if (!mounted) return;

        // Clear local storage (force re-login)
        try {
          final db = await UserDatabase().database;
          await db.delete('users');
        } catch (e) {
          debugPrint('Error clearing local database: $e');
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password reset successfully! Please log in with your new password.',
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

        // Navigate to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        final errorMsg =
            responseData['error'] ?? 'Password reset failed. Please try again.';
        setState(() {
          _isResettingPassword = false;
          _errorMessage = errorMsg;
        });

        // If code is invalid, reset verification state
        if (errorMsg.contains('Invalid verification code') ||
            errorMsg.contains('expired')) {
          setState(() {
            _codeVerified = false;
          });
          _expirationTimer?.cancel();
          _countdownTimer?.cancel();
        }
      }
    } catch (e) {
      setState(() {
        _isResettingPassword = false;
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
            Uri.parse('${config.apiBase}/auth/password-reset/resend-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': widget.email}),
          )
          .timeout(const Duration(seconds: 10));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.surface,
        foregroundColor: primaryColor,
        elevation: AppDesignSystem.elevationLow,
        title: Text(
          'Reset Password',
          style: AppDesignSystem.titleMedium.copyWith(color: primaryColor),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDesignSystem.getResponsivePadding(context),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: AppDesignSystem.elevationMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppDesignSystem.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Icon(Icons.lock_reset, size: 64, color: primaryColor),
                    SizedBox(height: AppDesignSystem.spaceMD),

                    // Title
                    Text(
                      'Reset Your Password',
                      style: AppDesignSystem.displaySmall.copyWith(
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDesignSystem.spaceSM),

                    // Description
                    Text(
                      _codeVerified
                          ? 'Verification code verified! Please enter your new password below.'
                          : 'We sent a verification code to your email address. Enter the code to verify.',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: AppDesignSystem.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDesignSystem.spaceSM),

                    // Expiration countdown (only show when code is not verified)
                    if (_expirationCountdown > 0 && !_codeVerified)
                      Container(
                        padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                        decoration: BoxDecoration(
                          color: infoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusSM,
                          ),
                          border: Border.all(
                            color: infoColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, size: 16, color: infoColor),
                            SizedBox(width: AppDesignSystem.spaceXS),
                            Text(
                              'Code expires in: ${_formatCountdown(_expirationCountdown)}',
                              style: AppDesignSystem.labelSmall.copyWith(
                                color: infoColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: AppDesignSystem.spaceLG),

                    // Code input field (only show if not verified)
                    if (!_codeVerified) ...[
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        cursorColor: primaryColor,
                        style: AppDesignSystem.displaySmall.copyWith(
                          color: primaryColor,
                          letterSpacing: 8,
                        ),
                        maxLength: 6,
                        enabled: !_isVerifyingCode,
                        decoration: InputDecoration(
                          labelText: 'Verification Code',
                          labelStyle: TextStyle(
                            color: AppDesignSystem.onSurfaceVariant,
                          ),
                          hintText: '000000',
                          hintStyle: TextStyle(
                            letterSpacing: 8,
                            color: AppDesignSystem.outlineVariant,
                          ),
                          counterText: '',
                          prefixIcon: Icon(Icons.vpn_key, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor, width: 2),
                          ),
                          filled: true,
                          fillColor: AppDesignSystem.surface,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = '';
                            _message = '';
                          });
                        },
                      ),

                      SizedBox(height: AppDesignSystem.spaceLG),

                      // Verify Code button
                      if (_isVerifyingCode)
                        Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
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
                              borderRadius: BorderRadius.circular(
                                AppDesignSystem.radiusMD,
                              ),
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

                      // Resend code button (only show if not verified)
                      TextButton(
                        onPressed:
                            _resendCountdown > 0 || _isResending
                                ? null
                                : _resendCode,
                        child:
                            _isResending
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                  ),
                                )
                                : Text(
                                  _resendCountdown > 0
                                      ? 'Resend code (${_resendCountdown}s)'
                                      : 'Resend Code',
                                  style: AppDesignSystem.labelLarge.copyWith(
                                    color: primaryColor,
                                  ),
                                ),
                      ),
                    ],

                    // Password fields (only show after code is verified)
                    if (_codeVerified) ...[
                      SizedBox(height: AppDesignSystem.spaceLG),

                      // Success indicator for verified code
                      Container(
                        padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                        decoration: BoxDecoration(
                          color: successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusSM,
                          ),
                          border: Border.all(
                            color: successColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: successColor,
                              size: 20,
                            ),
                            SizedBox(width: AppDesignSystem.spaceSM),
                            Text(
                              'Code verified successfully',
                              style: AppDesignSystem.bodyMedium.copyWith(
                                color: successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppDesignSystem.spaceLG),

                      // New password field
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        cursorColor: primaryColor,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(
                            color: AppDesignSystem.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(Icons.lock, color: primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppDesignSystem.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor, width: 2),
                          ),
                          filled: true,
                          fillColor: AppDesignSystem.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'New password is required';
                          }
                          final strength = calculatePasswordStrength(value);
                          if (!strength.isValid) {
                            return 'Password is too weak';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = '';
                          });
                        },
                      ),

                      SizedBox(height: AppDesignSystem.spaceSM),

                      // Password strength meter (show when typing)
                      if (_newPasswordController.text.isNotEmpty)
                        PasswordStrengthMeter(
                          password: _newPasswordController.text,
                          primaryColor: primaryColor,
                        ),

                      SizedBox(height: AppDesignSystem.spaceSM),

                      // Password requirements checklist (always visible to guide user)
                      PasswordRequirementsChecklist(
                        password: _newPasswordController.text,
                        primaryColor: primaryColor,
                      ),

                      SizedBox(height: AppDesignSystem.spaceMD),

                      // Confirm password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        cursorColor: primaryColor,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: TextStyle(
                            color: AppDesignSystem.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_clock,
                            color: primaryColor,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppDesignSystem.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppDesignSystem.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMD,
                            ),
                            borderSide: BorderSide(color: errorColor, width: 2),
                          ),
                          filled: true,
                          fillColor: AppDesignSystem.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = '';
                          });
                        },
                      ),

                      SizedBox(height: AppDesignSystem.spaceLG),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                          decoration: BoxDecoration(
                            color: errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusSM,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: errorColor,
                              ),
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

                      // Success message (for resend code)
                      if (_message.isNotEmpty && !_codeVerified)
                        Container(
                          padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                          decoration: BoxDecoration(
                            color: successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusSM,
                            ),
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

                      // Reset password button (only show after code is verified)
                      if (_isResettingPassword)
                        Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppDesignSystem.spaceMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDesignSystem.radiusMD,
                              ),
                            ),
                            elevation: AppDesignSystem.elevationLow,
                          ),
                          child: Text(
                            'Reset Password',
                            style: AppDesignSystem.titleMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],

                    SizedBox(height: AppDesignSystem.spaceMD),

                    // Back to login button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppDesignSystem.onSurfaceVariant,
                      ),
                      child: Text(
                        'Back to Login',
                        style: AppDesignSystem.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
