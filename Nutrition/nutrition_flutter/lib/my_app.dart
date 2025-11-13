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

// Add RouteObserver for navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? userSex;

  void updateUserSex(String? sex) {
    setState(() {
      userSex = sex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
