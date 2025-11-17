import 'dart:async';
import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';
import 'services/connectivity_service.dart';
import 'utils/connectivity_notification_helper.dart';
import 'widgets/animated_logo_widget.dart';

class LandingScreen extends StatefulWidget {
  final Function(String?)? onUserSexChanged;
  const LandingScreen({super.key, this.onUserSexChanged});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isCheckingConnectivity = true;
  bool _hasConnection = false;
  bool _isInitialCheck = true; // Track if this is the initial check
  bool _isNavigatingToLogin = false;
  bool _isNavigatingToRegister = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivityOnStart();
    // Listen to connectivity changes (only after initial check)
    _connectivitySubscription = ConnectivityService.instance.connectivityStream.listen(
      (isConnected) {
        if (mounted && !_isInitialCheck) {
          // Only show notifications after initial check is complete
          setState(() {
            _hasConnection = isConnected;
          });
          
          if (isConnected) {
            // Connection restored during app usage
            ConnectivityNotificationHelper.showConnectionRestoredSnackBar(context);
          } else {
            // Connection lost during app usage
            ConnectivityNotificationHelper.showConnectionLostSnackBar(
              context,
              onRetry: () async {
                final connected = await ConnectivityService.instance.hasInternetConnection(forceRefresh: true);
                if (connected && mounted) {
                  ConnectivityNotificationHelper.showConnectionRestoredSnackBar(context);
                }
              },
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivityOnStart() async {
    // Check connectivity IMMEDIATELY when app starts (no delay)
    final isConnected = await ConnectivityService.instance.hasInternetConnection();
    
    if (mounted) {
      setState(() {
        _hasConnection = isConnected;
        _isCheckingConnectivity = false;
        _isInitialCheck = false; // Mark initial check as complete
      });

      // If no connection, show dialog immediately
      if (!isConnected) {
        _showInitialConnectionDialog();
      }
      // If connected, proceed silently (no notification)
    }
  }

  Future<void> _showInitialConnectionDialog() async {
    if (!mounted) return;
    
    final shouldRetry = await ConnectivityNotificationHelper.showNoConnectionDialog(context);
    
    if (shouldRetry && mounted) {
      // Retry connectivity check with force refresh
      setState(() {
        _isCheckingConnectivity = true;
      });
      
      // Force a fresh check when user clicks retry
      final isConnected = await ConnectivityService.instance.hasInternetConnection(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _hasConnection = isConnected;
          _isCheckingConnectivity = false;
        });

        if (!isConnected) {
          // Still no connection, show dialog again
          _showInitialConnectionDialog();
        }
        // If connected, transition silently (no notification on retry)
      }
    } else if (!shouldRetry && mounted) {
      // User dismissed, but we should still check periodically
      // Keep the dialog available but allow them to see the screen
      setState(() {
        _hasConnection = false;
      });
    }
  }

  bool get _isNavigating => _isNavigatingToLogin || _isNavigatingToRegister;

  Future<void> _navigateToLogin() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigatingToLogin = true;
    });

    // Allow UI to rebuild before running potentially expensive checks
    await Future<void>.delayed(Duration.zero);

    // Check connectivity before navigating (still blocking, but spinner is visible)
    final isConnected = await ConnectivityNotificationHelper.checkAndNotifyIfDisconnected(context);
    if (!isConnected || !mounted) {
      if (mounted) {
        setState(() {
          _isNavigatingToLogin = false;
        });
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onUserSexChanged: widget.onUserSexChanged,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isNavigatingToLogin = false;
      });
    }
  }

  Future<void> _navigateToRegister() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigatingToRegister = true;
    });

    // Allow UI to rebuild before running potentially expensive checks
    await Future<void>.delayed(Duration.zero);

    // Check connectivity before navigating (still blocking, but spinner is visible)
    final isConnected = await ConnectivityNotificationHelper.checkAndNotifyIfDisconnected(context);
    if (!isConnected || !mounted) {
      if (mounted) {
        setState(() {
          _isNavigatingToRegister = false;
        });
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(
          onUserSexChanged: widget.onUserSexChanged,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isNavigatingToRegister = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show animated logo while checking connectivity
    if (_isCheckingConnectivity) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6FFF7),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedLogoWidget(
                size: 120,
              ),
              const SizedBox(height: 24),
              const Text(
                'Nutritionist App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C), // Dark green
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6FFF7), // Light greenish background
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'design/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome to Nutritionist App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF388E3C), // Dark green
                  ),
                ),
                const SizedBox(height: 40),
                // Connection status indicator
                if (!_hasConnection)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasConnection && !_isNavigating
                        ? _navigateToLogin
                        : () {
                            if (!_hasConnection) {
                              ConnectivityNotificationHelper.showNoConnectionDialog(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 2,
                    ),
                    child: _isNavigatingToLogin
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasConnection && !_isNavigating
                        ? _navigateToRegister
                        : () {
                            if (!_hasConnection) {
                              ConnectivityNotificationHelper.showNoConnectionDialog(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 0,
                    ),
                    child: _isNavigatingToRegister
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            ),
                          )
                        : const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
