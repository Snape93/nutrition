import 'package:flutter/material.dart';
import 'config.dart';
import 'login.dart';
import 'verify_code_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utils/connectivity_notification_helper.dart';
import 'widgets/password_strength_widget.dart';
import 'widgets/animated_logo_widget.dart';

// Use centralized apiBase from config.dart

class RegisterScreen extends StatefulWidget {
  final Function(String?)? onUserSexChanged;
  const RegisterScreen({super.key, this.onUserSexChanged});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final TextEditingController _birthdayController = TextEditingController();
  final String _message = '';
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  DateTime? _selectedBirthday;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _onUsernameChanged(String username) async {
    if (username.isEmpty) {
      return;
    }
  }

  void _register() async {
    // Check for empty required fields
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorDialog('Please fill in all required fields.');
      return;
    }
    // Check password confirmation
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_formKey.currentState?.validate() ?? false) {
        // Validate birthday and calculate age
        if (_selectedBirthday == null) {
          _showErrorDialog('Please select your date of birth');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final today = DateTime.now();
        int age = today.year - _selectedBirthday!.year;
        if (today.month < _selectedBirthday!.month ||
            (today.month == _selectedBirthday!.month &&
                today.day < _selectedBirthday!.day)) {
          age--;
        }

        if (age < 21) {
          _showAgeLimitDialog();
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Check connectivity before attempting registration
        final isConnected =
            await ConnectivityNotificationHelper.checkAndNotifyIfDisconnected(
              context,
            );
        if (!isConnected) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Register using backend API only
        final backendData = {
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'age': age,
        };

        debugPrint('DEBUG: Attempting registration to: $apiBase/register');
        debugPrint('DEBUG: Registration data: $backendData');

        final backendResponse = await http
            .post(
              Uri.parse('$apiBase/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(backendData),
            )
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'DEBUG: Registration response status: ${backendResponse.statusCode}',
        );
        debugPrint(
          'DEBUG: Registration response body: ${backendResponse.body}',
        );

        if (backendResponse.statusCode == 201 ||
            backendResponse.statusCode == 200) {
          // Registration successful
          setState(() {
            _isLoading = false;
          });
          if (!mounted) return;

          // Parse response to get email and expiration
          String email = _emailController.text.trim();
          DateTime? expiresAt;
          try {
            final responseData = json.decode(backendResponse.body);
            if (responseData is Map && responseData['email'] != null) {
              email = responseData['email'] as String;
            }
            if (responseData is Map && responseData['expires_at'] != null) {
              expiresAt = DateTime.parse(responseData['expires_at']);
            }
          } catch (e) {
            debugPrint('Error parsing registration response: $e');
          }

          // Navigate to verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => VerifyCodeScreen(
                    email: email,
                    username: _usernameController.text.trim(),
                    expiresAt: expiresAt?.toIso8601String(),
                  ),
            ),
          );
        } else {
          // Registration failed
          String msg = 'Registration failed';
          try {
            final responseData = json.decode(backendResponse.body);
            if (responseData is Map) {
              // Try 'message' field first (backend standard)
              if (responseData['message'] is String &&
                  (responseData['message'] as String).isNotEmpty) {
                msg = responseData['message'] as String;
              }
              // Fallback to 'error' field if 'message' not available
              else if (responseData['error'] is String &&
                  (responseData['error'] as String).isNotEmpty) {
                msg = responseData['error'] as String;
              }
            }
          } catch (e) {
            debugPrint('Error parsing response: $e');
          }

          // Provide more specific default messages based on status code
          if (msg == 'Registration failed') {
            if (backendResponse.statusCode == 409) {
              msg = 'Username or email already exists';
            } else if (backendResponse.statusCode == 400) {
              msg = 'Invalid registration data';
            } else {
              msg = 'Registration failed. Please try again.';
            }
          }

          setState(() {
            _isLoading = false;
          });
          _showErrorDialog('Registration failed: $msg');
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('DEBUG: Registration timeout - server not responding');
      _showErrorDialog(
        'Server is not responding. Please check if Flask server is running on $apiBase',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('DEBUG: Registration error: $e');
      debugPrint('DEBUG: Error type: ${e.runtimeType}');
      _showErrorDialog(
        'Network error: $e\n\nMake sure Flask server is running on $apiBase',
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showAgeLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Age Requirement',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF388E3C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You must be at least 21 years old to use this application. Please verify your date of birth and try again.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedBirthday = null;
                          _birthdayController.clear();
                        });
                      },
                      child: const Text('I Understand'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _birthdayController.dispose();
    super.dispose();
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
                  child: Form(
                    key: _formKey,
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
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF388E3C),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Join us and start your healthy journey',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  key: const Key('registerUsernameField'),
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Username *',
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
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Username is required';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    _onUsernameChanged(value);
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('registerEmailField'),
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email *',
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
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    final emailRegex = RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$',
                                    );
                                    if (!emailRegex.hasMatch(value.trim())) {
                                      return 'Invalid email address';
                                    }
                                    return null;
                                  },
                                  onChanged: (_) {
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('registerPasswordField'),
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Password *',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: const Color(0xFF4CAF50),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  obscureText: !_showPassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (value.length < 8) {
                                      return 'Password must be at least 8 characters';
                                    }
                                    final strength = calculatePasswordStrength(
                                      value,
                                    );
                                    if (!strength.isValid) {
                                      return 'Password is too weak. Please use at least 8 characters, 1 uppercase letter, and 1 number.';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                ),
                                if (_passwordFocusNode.hasFocus &&
                                    _passwordController.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  PasswordStrengthMeter(
                                    password: _passwordController.text,
                                    primaryColor: const Color(0xFF4CAF50),
                                  ),
                                ],
                                if (_passwordFocusNode.hasFocus) ...[
                                  const SizedBox(height: 8),
                                  PasswordRequirementsChecklist(
                                    password: _passwordController.text,
                                    primaryColor: const Color(0xFF4CAF50),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key(
                                    'registerConfirmPasswordField',
                                  ),
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password *',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: const Color(0xFF4CAF50),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  obscureText: !_showConfirmPassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('registerBirthdayField'),
                                  controller: _birthdayController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth *',
                                    hintText: 'Select your date of birth',
                                    helperText: 'Must be 21 years or older',
                                    prefixIcon: const Icon(
                                      Icons.cake_outlined,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (value) {
                                    if (_selectedBirthday == null) {
                                      return 'Date of birth is required';
                                    }
                                    final today = DateTime.now();
                                    int age =
                                        today.year - _selectedBirthday!.year;
                                    if (today.month <
                                            _selectedBirthday!.month ||
                                        (today.month ==
                                                _selectedBirthday!.month &&
                                            today.day <
                                                _selectedBirthday!.day)) {
                                      age--;
                                    }
                                    if (age < 21) {
                                      _showAgeLimitDialog();
                                      return 'You must be at least 21 years old';
                                    }
                                    if (age > 120) {
                                      return 'Please enter a valid date of birth';
                                    }
                                    return null;
                                  },
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now().subtract(
                                            const Duration(days: 365 * 25),
                                          ),
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365 * 120),
                                          ),
                                          lastDate: DateTime.now(),
                                          helpText: 'Select Date of Birth',
                                          cancelText: 'Cancel',
                                          confirmText: 'Select',
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme:
                                                    const ColorScheme.light(
                                                      primary: Color(
                                                        0xFF4CAF50,
                                                      ),
                                                      onPrimary: Colors.white,
                                                      onSurface: Colors.black87,
                                                    ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedBirthday = picked;
                                        _birthdayController.text =
                                            '${picked.day}/${picked.month}/${picked.year}';
                                      });
                                      _formKey.currentState?.validate();
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    key: const Key('registerButton'),
                                    onPressed: _isLoading ? null : _register,
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
                                    child: const Text('Register'),
                                  ),
                                ),
                                if (_isLoading) ...[
                                  const SizedBox(height: 20),
                                  const AnimatedLogoWidget(
                                    size: 90,
                                  ),
                                ],
                                if (_message.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    _message,
                                    key: const Key('registerMessage'),
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Already have an account? '),
                                    TextButton(
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : () {
                                                Navigator.of(
                                                  context,
                                                ).pushReplacement(
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            const LoginScreen(),
                                                  ),
                                                );
                                              },
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                      ),
                                      child: const Text('Log in'),
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
          ),
        ],
      ),
    );
  }
}
