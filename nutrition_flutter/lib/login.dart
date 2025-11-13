import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'forgot_password.dart';
import 'home.dart';
import 'onboarding/onboarding_welcome.dart';
import 'register.dart';
import 'verify_code_screen.dart';
import 'config.dart';

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

  Future<void> _login() async {
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
          .timeout(const Duration(seconds: 10));

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
        String msg = backendResponse.statusCode >= 500
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
            (responseData['message'] is String && (responseData['message'] as String).isNotEmpty)
                ? responseData['message'] as String
                : 'Invalid username or password';
        
        // Check if email verification is required
        final bool emailVerificationRequired = responseData['email_verification_required'] == true;
        final String? email = responseData['email'] as String?;
        
        if (!mounted) return;
        
        // If email verification required, navigate to verification screen
        if (emailVerificationRequired && email != null) {
          setState(() {
            _isLoading = false;
            _message = '';
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyCodeScreen(
                email: email,
                username: _usernameController.text.trim(),
              ),
            ),
          );
          return;
        }
        
        setState(() {
          _isLoading = false;
          _message = 'Login failed: $serverMessage';
        });
        return;
      }

      // Check if user has completed onboarding/tutorial from backend
      final dynamic userDataDyn = responseData['user'];
      final Map? userData = userDataDyn is Map ? userDataDyn : null;
      final bool hasSeenTutorial = (userData?['has_seen_tutorial'] == true);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = '';
      });
      
      // Navigate to appropriate screen
      try {
        if (hasSeenTutorial) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      HomePage(usernameOrEmail: _usernameController.text),
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
      body: Container(
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
                  Image.asset(
                    'design/logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF388E3C),
                            ),
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
                                          (context) => const ForgotPasswordScreen(),
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
                          const SizedBox(height: 8),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
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
                                    child: const Text('Sign In'),
                                  ),
                                ),
                          if (_message.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              _message,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
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
    );
  }
}
