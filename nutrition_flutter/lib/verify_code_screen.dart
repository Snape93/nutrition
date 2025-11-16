import 'package:flutter/material.dart';
import 'config.dart';
import 'login.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final String? username;
  final String? expiresAt; // ISO format string from backend
  
  const VerifyCodeScreen({
    super.key,
    required this.email,
    this.username,
    this.expiresAt,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  bool _isChangingEmail = false;
  bool _showEmailEdit = false;
  String _message = '';
  String _errorMessage = '';
  int _resendCountdown = 0;
  int _expirationCountdown = 0; // Countdown until code expires (15 minutes)
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Timer? _expirationTimer;
  int _resendCount = 0;
  int _maxResends = 5;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _startResendCountdown();
    // Start expiration countdown - will be updated when we get expires_at from backend
    _startExpirationCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _expirationTimer?.cancel();
    _codeController.dispose();
    _emailController.dispose();
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
          _errorMessage = 'Verification code has expired. Please register again.';
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
      final response = await http.post(
        Uri.parse('$apiBase/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          setState(() {
            _isLoading = false;
            _message = 'Email verified successfully!';
          });

          if (!mounted) return;
          
          // Show success dialog and navigate to login
          _showSuccessDialog();
      } else {
        final errorMsg = responseData['error'] ?? 'Verification failed. Please try again.';
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
      final response = await http.post(
        Uri.parse('$apiBase/auth/resend-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isResending = false;
          _message = 'Verification code sent! Check your email.';
          _resendCount = responseData['resend_count'] ?? 0;
          _maxResends = responseData['max_resends'] ?? 5;
        });
        if (responseData['expires_at'] != null) {
          try {
            _expiresAt = DateTime.parse(responseData['expires_at']);
            _startExpirationCountdown();
          } catch (e) {
            debugPrint('Error parsing expires_at: $e');
          }
        }
        _startResendCountdown();
      } else {
        final errorMsg = responseData['error'] ?? 'Failed to resend code. Please try again.';
        setState(() {
          _isResending = false;
          _errorMessage = errorMsg;
        });
        
        // Check if rate limit reached
        if (response.statusCode == 429) {
          _resendCount = responseData['resend_count'] ?? 5;
          _maxResends = responseData['max_resends'] ?? 5;
        }
      }
    } catch (e) {
      setState(() {
        _isResending = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = _emailController.text.trim();
    
    if (newEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an email address';
      });
      return;
    }
    
    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(newEmail)) {
      setState(() {
        _errorMessage = 'Invalid email format';
      });
      return;
    }
    
    if (newEmail.toLowerCase() == widget.email.toLowerCase()) {
      setState(() {
        _errorMessage = 'This is already your email address';
      });
      return;
    }

    setState(() {
      _isChangingEmail = true;
      _errorMessage = '';
      _message = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBase/auth/change-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'old_email': widget.email,
          'new_email': newEmail,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _isChangingEmail = false;
          _showEmailEdit = false;
          _message = 'Email changed! Verification code sent to new email.';
          _resendCount = 0; // Reset resend count
        });
        
        if (responseData['expires_at'] != null) {
          try {
            _expiresAt = DateTime.parse(responseData['expires_at']);
            _startExpirationCountdown();
          } catch (e) {
            debugPrint('Error parsing expires_at: $e');
          }
        }
        _startResendCountdown();
      } else {
        final errorMsg = responseData['error'] ?? 'Failed to change email. Please try again.';
        setState(() {
          _isChangingEmail = false;
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _isChangingEmail = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(18),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Email Verified!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your email has been verified successfully. You can now log in to your account.',
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
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                          const Icon(
                            Icons.email_outlined,
                            size: 64,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Verify Your Email',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF388E3C),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We sent a 6-digit verification code to',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Email display with edit option
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _showEmailEdit
                                    ? TextField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: const Icon(
                                            Icons.email_outlined,
                                            color: Color(0xFF4CAF50),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _emailController.text,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4CAF50),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                              if (!_showEmailEdit)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF4CAF50), size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _showEmailEdit = true;
                                      _errorMessage = '';
                                      _message = '';
                                    });
                                  },
                                ),
                            ],
                          ),
                          if (_showEmailEdit) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isChangingEmail ? null : _changeEmail,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isChangingEmail
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Update Email'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showEmailEdit = false;
                                      _emailController.text = widget.email;
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                          // Expiration countdown
                          if (_expirationCountdown > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _expirationCountdown < 300
                                    ? Colors.orange[50]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _expirationCountdown < 300
                                      ? Colors.orange[200]!
                                      : Colors.blue[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: _expirationCountdown < 300
                                        ? Colors.orange[700]
                                        : Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Code expires in: ${_formatCountdown(_expirationCountdown)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _expirationCountdown < 300
                                          ? Colors.orange[700]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Verification Code',
                              labelStyle: const TextStyle(color: Colors.black),
                              hintText: '000000',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF4CAF50),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_message.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message,
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _verifyCode,
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
                                    child: const Text('Verify'),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Didn't receive the code? ",
                                style: TextStyle(fontSize: 14),
                              ),
                              TextButton(
                                onPressed: _resendCountdown > 0 || _isResending || _resendCount >= _maxResends
                                    ? null
                                    : _resendCode,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF4CAF50),
                                ),
                                child: _isResending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _resendCountdown > 0
                                            ? 'Resend in ${_resendCountdown}s'
                                            : _resendCount >= _maxResends
                                                ? 'Max resends reached'
                                                : 'Resend Code',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _resendCount >= _maxResends
                                              ? Colors.grey
                                              : const Color(0xFF4CAF50),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          if (_resendCount > 0 && _resendCount < _maxResends) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Resend attempts: $_resendCount/$_maxResends',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                            child: const Text('Back to Login'),
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

