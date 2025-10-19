import 'package:flutter/material.dart';
import 'user_database.dart';
import 'login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String _message = '';
  bool _emailVerified = false;

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = 'Please enter your email.';
      });
      return;
    }
    final exists = await UserDatabase().emailExists(email);
    if (!mounted) return;
    setState(() {
      if (exists) {
        _emailVerified = true;
        _message = 'Email verified. Please enter your new password.';
      } else {
        _message = 'Email not found.';
      }
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _message = 'Please enter and confirm your new password.';
      });
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() {
        _message = 'Passwords do not match.';
      });
      return;
    }
    final db = await UserDatabase().database;
    final user = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (user.isNotEmpty && user.first['password'] == newPassword) {
      setState(() {
        _message =
            'You are already using this password. Please choose a new one.';
      });
      return;
    }
    final updated = await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
    if (!mounted) return;
    if (updated > 0) {
      if (!mounted) return;
      setState(() {
        _emailVerified = false;
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Password Changed'),
              content: const Text(
                'Your password has been changed successfully! Please log in with your new password.',
              ),
              actions: [
                TextButton(
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
              ],
            ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _message = 'Failed to reset password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: !_emailVerified,
            ),
            if (!_emailVerified)
              ElevatedButton(
                onPressed: _verifyEmail,
                child: const Text('Verify Email'),
              ),
            if (_emailVerified) ...[
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                obscureText: true,
              ),
              ElevatedButton(
                onPressed: _resetPassword,
                child: const Text('Reset Password'),
              ),
            ],
            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
