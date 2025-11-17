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
      // Use backend API for authentication
      Future<http.Response> doRequest() => http
          .post(
            Uri.parse('$apiBase/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username_or_email': _usernameController.text.trim(),
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      http.Response backendResponse = await doRequest();

      // Auto-retry once on 5xx or network hiccup
      if (backendResponse.statusCode >= 500) {
        backendResponse = await doRequest();
      }

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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Image.asset(
                                'design/logo.png',
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF388E3C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to continue your nutrition journey',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                key: const Key('usernameField'),
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username or Email',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF4CAF50),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const Key('passwordField'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFF4CAF50),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: const Color(0xFF4CAF50),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                    child: const Text('Forgot Password?'),
                                  ),
                                ],
                              ),
                              if (_isLockedOut) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Locked. Retry in ${_formatCountdown(_remainingSeconds)}.',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      (!_isLoading && !_isLockedOut)
                                          ? _login
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text('Sign In'),
                                ),
                              ),
                              if (_message.isNotEmpty && !_isLockedOut) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _message,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? "),
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
}
