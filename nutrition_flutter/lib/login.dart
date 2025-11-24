import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'forgot_password.dart';
import 'home.dart';
import 'onboarding/onboarding_welcome.dart';
import 'register.dart';
import 'theme_service.dart';
import 'verify_code_screen.dart';
import 'config.dart';
import 'utils/connectivity_notification_helper.dart';
import 'design_system/app_design_system.dart';

// Use centralized apiBase from config.dart

class LoginScreen extends StatefulWidget {
  final Function(String?)? onUserSexChanged;
  const LoginScreen({super.key, this.onUserSexChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isNavigatingToRegister = false;

  // Security lockout variables
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isLockedOut = false;

  static const int _maxFailedAttempts = 5;
  static const int _lockoutDurationMinutes = 5;
  static const String _failedAttemptsKey = 'login_failed_attempts';
  static const String _lockoutUntilKey = 'login_lockout_until';

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntilString = prefs.getString(_lockoutUntilKey);

    if (lockoutUntilString != null) {
      final lockoutUntil = DateTime.parse(lockoutUntilString);
      final now = DateTime.now();

      if (lockoutUntil.isAfter(now)) {
        // Still locked out
        setState(() {
          _isLockedOut = true;
          _lockoutUntil = lockoutUntil;
        });
        _startCountdown();
      } else {
        // Lockout expired, reset
        await _resetFailedAttempts();
      }
    } else {
      // Load failed attempts count
      final attempts = prefs.getInt(_failedAttemptsKey) ?? 0;
      setState(() {
        _failedAttempts = attempts;
      });
    }
  }

  Future<void> _resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
    setState(() {
      _failedAttempts = 0;
      _isLockedOut = false;
      _lockoutUntil = null;
      _remainingSeconds = 0;
    });
    _countdownTimer?.cancel();
  }

  Future<void> _incrementFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final newAttempts = _failedAttempts + 1;
    await prefs.setInt(_failedAttemptsKey, newAttempts);

    setState(() {
      _failedAttempts = newAttempts;
    });

    if (newAttempts >= _maxFailedAttempts) {
      // Lock out for 5 minutes
      final lockoutUntil = DateTime.now().add(
        Duration(minutes: _lockoutDurationMinutes),
      );
      await prefs.setString(_lockoutUntilKey, lockoutUntil.toIso8601String());

      setState(() {
        _isLockedOut = true;
        _lockoutUntil = lockoutUntil;
      });

      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutUntil == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = _lockoutUntil!.difference(now);

      if (remaining.isNegative || remaining.inSeconds <= 0) {
        // Lockout expired
        timer.cancel();
        _resetFailedAttempts();
      } else {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }
    });
  }

  String _formatCountdown(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _login() async {
    // Check if locked out
    if (_isLockedOut) {
      setState(() {
        _message =
            'Too many failed login attempts. Please try again in ${_formatCountdown(_remainingSeconds)}.';
      });
      return;
    }

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _message = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    // Let the UI rebuild before heavy checks
    await Future<void>.delayed(Duration.zero);

    // Check connectivity before attempting login
    final isConnected =
        await ConnectivityNotificationHelper.checkAndNotifyIfDisconnected(
          context,
        );
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final backendResponse = await http
          .post(
            Uri.parse('$apiBase/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username_or_email': _usernameController.text.trim(),
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      // Debug logging
      debugPrint('Login response status: ${backendResponse.statusCode}');
      debugPrint('Login response body: ${backendResponse.body}');

      if (backendResponse.statusCode != 200) {
        if (!mounted) return;

        // Increment failed attempts for non-server errors
        if (backendResponse.statusCode < 500) {
          await _incrementFailedAttempts();
        }

        String msg =
            backendResponse.statusCode >= 500
                ? 'Server error. Please try again.'
                : 'Invalid username or password';
        try {
          final body = json.decode(backendResponse.body);
          if (body is Map &&
              body['message'] is String &&
              (body['message'] as String).isNotEmpty) {
            msg = body['message'];
          }
        } catch (_) {}

        // Add warning about remaining attempts
        if (!_isLockedOut &&
            _failedAttempts > 0 &&
            _failedAttempts < _maxFailedAttempts) {
          final remaining = _maxFailedAttempts - _failedAttempts;
          msg += '\n${remaining} attempt${remaining > 1 ? 's' : ''} remaining.';
        }

        setState(() {
          _isLoading = false;
          _message = msg;
        });
        return;
      }

      // Check if response body is empty
      if (backendResponse.body.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _message = 'Empty response from server';
        });
        return;
      }

      // Parse response to get user data with defensive checks
      final dynamic decoded;
      try {
        decoded = json.decode(backendResponse.body);
      } catch (e) {
        debugPrint('JSON decode error: $e');
        debugPrint('Response body: ${backendResponse.body}');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _message = 'Invalid response from server';
        });
        return;
      }

      if (decoded is! Map) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _message = 'Unexpected response from server';
        });
        return;
      }

      final Map responseData = decoded;
      final bool success = responseData['success'] == true;

      if (!success) {
        final String serverMessage =
            (responseData['message'] is String &&
                    (responseData['message'] as String).isNotEmpty)
                ? responseData['message'] as String
                : 'Invalid username or password';

        // Check if email verification is required
        final bool emailVerificationRequired =
            responseData['email_verification_required'] == true;
        final String? email = responseData['email'] as String?;

        if (!mounted) return;

        // Increment failed attempts (only if not already incremented for status code != 200)
        // Note: This handles the case where status code is 200 but success is false
        if (backendResponse.statusCode == 200) {
          await _incrementFailedAttempts();
        }

        // If email verification required, navigate to verification screen
        if (emailVerificationRequired && email != null) {
          setState(() {
            _isLoading = false;
            _message = '';
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => VerifyCodeScreen(
                    email: email,
                    username: _usernameController.text.trim(),
                  ),
            ),
          );
          return;
        }

        String errorMsg = 'Login failed: $serverMessage';
        // Add warning about remaining attempts
        if (!_isLockedOut &&
            _failedAttempts > 0 &&
            _failedAttempts < _maxFailedAttempts) {
          final remaining = _maxFailedAttempts - _failedAttempts;
          errorMsg +=
              '\n${remaining} attempt${remaining > 1 ? 's' : ''} remaining.';
        }

        setState(() {
          _isLoading = false;
          _message = errorMsg;
        });
        return;
      }

      // Reset failed attempts on successful login
      await _resetFailedAttempts();

      // Check if user has completed onboarding/tutorial from backend
      final dynamic userDataDyn = responseData['user'];
      final Map? userData = userDataDyn is Map ? userDataDyn : null;
      final bool hasSeenTutorial = (userData?['has_seen_tutorial'] == true);
      final String? userSex =
          userData?['sex'] as String?; // Get user sex from login response
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = '';
      });

      // Navigate to appropriate screen
      try {
        if (hasSeenTutorial) {
          // Get background color for transition
          final backgroundColor = ThemeService.getBackgroundColor(userSex);

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => HomePage(
                    usernameOrEmail: _usernameController.text,
                    initialUserSex:
                        userSex, // Pass userSex to avoid green flash
                  ),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                // Use SlideTransition to cover old screen completely
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0), // Slide from right
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color:
                        backgroundColor, // Use correct background color, not green
                    child: child,
                  ),
                );
              },
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OnboardingWelcome(
                    usernameOrEmail: _usernameController.text,
                  ),
            ),
          );
        }
      } catch (navError) {
        debugPrint('Navigation error: $navError');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _message = 'Navigation error. Please try again.';
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('Login timeout: $e');
      final isReachable = await _isServerReachable();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = isReachable
            ? 'Server is taking too long to respond. Please try again.'
            : 'Cannot connect to server. Please check your internet connection and try again.';
      });
    } catch (e, stackTrace) {
      // Log the error for debugging
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = AppDesignSystem.isNarrowScreen(context);
    
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9), // light mint
                  Color(0xFFB2DFDB), // soft teal
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: AppDesignSystem.getResponsivePadding(
                    context,
                    horizontal: isNarrowScreen ? 20.0 : 24.0,
                    vertical: AppDesignSystem.spaceLG,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.getResponsiveBorderRadius(
                              context,
                              xs: 20,
                              sm: 22,
                              md: 24,
                              lg: 28,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: AppDesignSystem.getResponsivePadding(
                            context,
                            horizontal: AppDesignSystem.spaceLG,
                            vertical: AppDesignSystem.spaceLG,
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                'design/logo.png',
                                height: AppDesignSystem.getResponsiveImageHeight(
                                  context,
                                  xs: 80,
                                  sm: 90,
                                  md: 100,
                                  lg: 110,
                                ),
                                fit: BoxFit.contain,
                              ),
                              SizedBox(height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 12,
                                sm: 14,
                                md: 16,
                                lg: 20,
                              )),
                              Text(
                                'Welcome Back',
                                style: AppDesignSystem.getResponsiveDisplaySmall(context).copyWith(
                                  color: const Color(0xFF388E3C),
                                ),
                              ),
                              SizedBox(height: AppDesignSystem.spaceSM),
                              Text(
                                'Sign in to continue your nutrition journey',
                                style: AppDesignSystem.getResponsiveBodyMedium(context).copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 20,
                                sm: 22,
                                md: 24,
                                lg: 28,
                              )),
                              TextField(
                                key: const Key('usernameField'),
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username or Email',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: const Color(0xFF4CAF50),
                                    size: AppDesignSystem.getResponsiveIconSize(context),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDesignSystem.getResponsiveBorderRadius(
                                        context,
                                        xs: AppDesignSystem.radiusSM,
                                        sm: AppDesignSystem.radiusMD,
                                      ),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              SizedBox(height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 12,
                                sm: 14,
                                md: 16,
                                lg: 18,
                              )),
                              TextField(
                                key: const Key('passwordField'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: const Color(0xFF4CAF50),
                                    size: AppDesignSystem.getResponsiveIconSize(context),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: const Color(0xFF4CAF50),
                                      size: AppDesignSystem.getResponsiveIconSize(context),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDesignSystem.getResponsiveBorderRadius(
                                        context,
                                        xs: AppDesignSystem.radiusSM,
                                        sm: AppDesignSystem.radiusMD,
                                      ),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              SizedBox(height: AppDesignSystem.spaceSM),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4CAF50),
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: AppDesignSystem.getResponsiveBodySmall(context),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLockedOut) ...[
                                SizedBox(height: AppDesignSystem.spaceSM),
                                Text(
                                  'Locked. Retry in ${_formatCountdown(_remainingSeconds)}.',
                                  style: AppDesignSystem.getResponsiveBodySmall(context).copyWith(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              SizedBox(height: AppDesignSystem.spaceSM),
                              SizedBox(
                                width: double.infinity,
                                height: AppDesignSystem.getResponsiveButtonHeight(context),
                                child: ElevatedButton(
                                  onPressed:
                                      (!_isLoading && !_isLockedOut)
                                          ? _login
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppDesignSystem.getResponsiveSpacingExact(
                                        context,
                                        xs: 12,
                                        sm: 14,
                                        md: 16,
                                        lg: 18,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDesignSystem.getResponsiveBorderRadius(
                                          context,
                                          xs: AppDesignSystem.radiusSM,
                                          sm: AppDesignSystem.radiusMD,
                                        ),
                                      ),
                                    ),
                                    textStyle: AppDesignSystem.getResponsiveHeadlineSmall(context).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: AppDesignSystem.getResponsiveIconSize(
                                            context,
                                            xs: 20,
                                            sm: 24,
                                            md: 28,
                                          ),
                                          height: AppDesignSystem.getResponsiveIconSize(
                                            context,
                                            xs: 20,
                                            sm: 24,
                                            md: 28,
                                          ),
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text('Sign In'),
                                ),
                              ),
                              if (_message.isNotEmpty && !_isLockedOut) ...[
                                SizedBox(height: AppDesignSystem.getResponsiveSpacingExact(
                                  context,
                                  xs: 12,
                                  sm: 14,
                                  md: 16,
                                  lg: 18,
                                )),
                                Text(
                                  _message,
                                  style: AppDesignSystem.getResponsiveBodyMedium(context).copyWith(
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              SizedBox(height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 12,
                                sm: 14,
                                md: 16,
                                lg: 18,
                              )),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: AppDesignSystem.getResponsiveBodyMedium(context),
                                  ),
                                  TextButton(
                                    onPressed:
                                        (_isLoading || _isNavigatingToRegister)
                                            ? null
                                            : () async {
                                                setState(() {
                                                  _isNavigatingToRegister = true;
                                                });

                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const RegisterScreen(),
                                                  ),
                                                );

                                                if (mounted) {
                                                  setState(() {
                                                    _isNavigatingToRegister =
                                                        false;
                                                  });
                                                }
                                              },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4CAF50),
                                    ),
                                    child: const Text('Sign Up'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<bool> _isServerReachable({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
