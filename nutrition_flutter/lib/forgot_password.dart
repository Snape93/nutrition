import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'password_reset_verification_screen.dart';
import 'theme_service.dart';
import 'design_system/app_design_system.dart';
import 'user_database.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _message = '';
  String _errorMessage = '';
  bool _isLoading = false;
  String? _userSex;

  Color get primaryColor => ThemeService.getPrimaryColor(_userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(_userSex);
  Color get errorColor => AppDesignSystem.error;
  Color get successColor => AppDesignSystem.success;

  @override
  void initState() {
    super.initState();
    _loadUserSex();
  }

  Future<void> _loadUserSex() async {
    // Try to load user sex from email if user exists
    try {
      final email = _emailController.text.trim();
      if (email.isNotEmpty) {
        final userData = await UserDatabase().getUserData(email);
        if (userData != null && mounted) {
          setState(() {
            _userSex = userData['sex'] as String?;
          });
        }
      }
    } catch (e) {
      // Ignore errors - use default colors
      debugPrint('Could not load user sex: $e');
    }
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) {
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
            Uri.parse('$apiBase/auth/password-reset/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _emailController.text.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      // Parse response body
      Map<String, dynamic> responseData = {};
      try {
        if (response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        }
      } catch (e) {
        // If JSON parsing fails, use empty map
        print('JSON parsing error: $e');
        responseData = {};
      }

      // Only navigate if success is true AND expires_at is present (email was actually sent)
      if (response.statusCode == 200 &&
          responseData['success'] == true &&
          responseData['expires_at'] != null) {
        if (!mounted) return;

        // Navigate to verification screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => PasswordResetVerificationScreen(
                  email: _emailController.text.trim(),
                  expiresAt: responseData['expires_at'],
                ),
          ),
        );
      } else {
        // Handle error response (email not found or other errors)
        String errorMsg;

        // Debug: Print response for troubleshooting
        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');
        print('Response Data: $responseData');

        // Check status code first for specific errors
        if (response.statusCode == 404) {
          // Email not found - use error from response or default message
          errorMsg =
              (responseData['error']?.toString().trim().isNotEmpty == true)
                  ? responseData['error'].toString().trim()
                  : 'No account found with this email address';
        } else if (response.statusCode == 429) {
          // Rate limited
          errorMsg =
              (responseData['error']?.toString().trim().isNotEmpty == true)
                  ? responseData['error'].toString().trim()
                  : 'Too many requests. Please try again later.';
        } else if (response.statusCode == 400) {
          // Validation errors
          errorMsg =
              (responseData['error']?.toString().trim().isNotEmpty == true)
                  ? responseData['error'].toString().trim()
                  : 'Invalid email address';
        }
        // Try to get error from response data
        else if (responseData.containsKey('error') &&
            responseData['error'] != null &&
            responseData['error'].toString().trim().isNotEmpty) {
          errorMsg = responseData['error'].toString().trim();
        }
        // Fallback to generic error
        else {
          errorMsg = 'Failed to request password reset. Please try again.';
        }

        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        // Do not navigate to verification screen when there's an error
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
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
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Image.asset(
                              'design/logo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reset Your Password',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF388E3C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your email address and we\'ll send you a verification code to reset your password.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              cursorColor: const Color(0xFF4CAF50),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF4CAF50),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email address is required';
                                }
                                // Validate email format
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                              onChanged: (value) async {
                                setState(() {
                                  _errorMessage = '';
                                });
                                // Try to load user sex when email changes
                                await _loadUserSex();
                              },
                            ),
                            if (_errorMessage.isNotEmpty) ...[
                              SizedBox(height: AppDesignSystem.spaceMD),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(
                                  AppDesignSystem.spaceSM,
                                ),
                                decoration: BoxDecoration(
                                  color: errorColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppDesignSystem.radiusSM,
                                  ),
                                  border: Border.all(
                                    color: errorColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: errorColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: AppDesignSystem.spaceSM),
                                    Flexible(
                                      child: Text(
                                        _errorMessage,
                                        textAlign: TextAlign.center,
                                        style: AppDesignSystem.bodyMedium
                                            .copyWith(color: errorColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_message.isNotEmpty) ...[
                              SizedBox(height: AppDesignSystem.spaceMD),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(
                                  AppDesignSystem.spaceSM,
                                ),
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
                                      Icons.check_circle_outline,
                                      color: successColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: AppDesignSystem.spaceSM),
                                    Flexible(
                                      child: Text(
                                        _message,
                                        textAlign: TextAlign.center,
                                        style: AppDesignSystem.bodyMedium
                                            .copyWith(color: successColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF4CAF50),
                                    ),
                                  ),
                                )
                                : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _requestPasswordReset,
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
                                    child: const Text('Send Verification Code'),
                                  ),
                                ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Remember your password? '),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF4CAF50),
                                  ),
                                  child: const Text('Back to Login'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
