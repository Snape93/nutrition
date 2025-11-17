import 'dart:async';
import 'package:flutter/material.dart';
import 'landing.dart';
import 'theme_service.dart';
import 'home.dart';
import 'onboarding/enhanced_onboarding_goals.dart';
import 'onboarding/enhanced_onboarding_physical.dart';
import 'onboarding/enhanced_onboarding_lifestyle.dart';
import 'onboarding/enhanced_onboarding_nutrition.dart';
import 'onboarding/onboarding_complete.dart';
import 'test_health_widget.dart';
import 'services/connectivity_service.dart';
import 'utils/connectivity_notification_helper.dart';

// Add RouteObserver for navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? userSex;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _wasConnected = true;
  bool _isInitialLoad = true; // Track initial app load

  @override
  void initState() {
    super.initState();
    // Wait a bit before starting to listen (to avoid initial check notifications)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    });
    
    // Listen to connectivity changes
    _connectivitySubscription = ConnectivityService.instance.connectivityStream.listen(
      (isConnected) {
        if (mounted && !_isInitialLoad) {
          // Only show notifications after initial load period
          // Only show notification if status changed
          if (!_wasConnected && isConnected) {
            // Connection restored during app usage
            final context = navigatorKey.currentContext;
            if (context != null) {
              ConnectivityNotificationHelper.showConnectionRestoredSnackBar(context);
            }
          } else if (_wasConnected && !isConnected) {
            // Connection lost during app usage
            final context = navigatorKey.currentContext;
            if (context != null) {
              ConnectivityNotificationHelper.showConnectionLostSnackBar(
                context,
                onRetry: () async {
                  final connected = await ConnectivityService.instance.hasInternetConnection(forceRefresh: true);
                  if (connected && context.mounted) {
                    ConnectivityNotificationHelper.showConnectionRestoredSnackBar(context);
                  }
                },
              );
            }
          }
          _wasConnected = isConnected;
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void updateUserSex(String? sex) {
    setState(() {
      userSex = sex;
    });
  }

  // Global navigator key for showing notifications from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Nutrition App',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.getThemeForSex(userSex),
      home: LandingScreen(onUserSexChanged: updateUserSex),
      navigatorObservers: [routeObserver],
      routes: {
        '/home': (context) => const HomePage(usernameOrEmail: ''),
        '/onboarding/goals': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EnhancedOnboardingGoals(
            usernameOrEmail: args?['usernameOrEmail'] ?? '',
          );
        },
        '/onboarding/physical': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EnhancedOnboardingPhysical(
            usernameOrEmail: args?['usernameOrEmail'] ?? '',
          );
        },
        '/onboarding/lifestyle': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EnhancedOnboardingLifestyle(
            usernameOrEmail: args?['usernameOrEmail'] ?? '',
          );
        },
        '/onboarding/enhanced_nutrition': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return EnhancedOnboardingNutrition(
            usernameOrEmail: args?['usernameOrEmail'] ?? '',
            goal: args?['goal'],
            gender: args?['gender'],
            age: args?['age'],
            height: args?['height'],
            weight: args?['weight'],
            targetWeight: args?['targetWeight'],
            activityLevel: args?['activityLevel'],
            currentMood: args?['currentMood'],
            energyLevel: args?['energyLevel'],
          );
        },
        '/onboarding/complete': (context) => const OnboardingCompleteScreen(),
        '/test/health': (context) => const HealthConnectTestWidget(),
      },
    );
  }
}
