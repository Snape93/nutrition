import 'package:flutter/material.dart';
import 'widgets/sex_specific_theme.dart';

class OnboardingWelcome extends StatelessWidget {
  final String usernameOrEmail;
  const OnboardingWelcome({super.key, required this.usernameOrEmail});

  void _startOnboarding(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/onboarding/goals',
      arguments: {'usernameOrEmail': usernameOrEmail},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get gender from arguments or user profile
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? gender = args != null ? args['gender'] as String? : null;
    final theme = SexSpecificTheme.getThemeFromString(gender);
    final Color primaryColor = theme.primaryColor;
    final Color lightBackground = theme.backgroundColor;
    final Color blue = Color(0xFF2196F3);
    final Color orange = Color(0xFFFFA726);
    final Color purple = Color(0xFF9C27B0);
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(child: _AppleBadge(primaryColor: primaryColor)),
                const SizedBox(height: 24),
                // Welcome text
                Text(
                  'Welcome to Your\nNutrition Journey!',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle in rounded rectangle
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    "Let's create your personalized nutrition plan in just 2 minutes",
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                // What we'll cover
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.04),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.explore, color: primaryColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "Here's what we'll cover:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Step 1
                      _StepCard(
                        number: 1,
                        color: primaryColor,
                        icon: Icons.flag,
                        title: 'Goals & Motivation',
                        subtitle: 'What you want to achieve and why',
                        bgColor: primaryColor.withValues(alpha: 0.07),
                      ),
                      const SizedBox(height: 12),
                      // Step 2
                      _StepCard(
                        number: 2,
                        color: blue,
                        icon: Icons.person,
                        title: 'Physical Profile',
                        subtitle: 'Your current stats and experience',
                        bgColor: blue.withValues(alpha: 0.07),
                      ),
                      const SizedBox(height: 12),
                      // Step 3
                      _StepCard(
                        number: 3,
                        color: orange,
                        icon: Icons.directions_run,
                        title: 'Lifestyle & Activity',
                        subtitle: 'How active you are and your schedule',
                        bgColor: orange.withValues(alpha: 0.07),
                      ),
                      const SizedBox(height: 12),
                      // Step 4
                      _StepCard(
                        number: 4,
                        color: purple,
                        icon: Icons.restaurant,
                        title: 'Food Preferences',
                        subtitle: 'Your dietary needs and cooking habits',
                        bgColor: purple.withValues(alpha: 0.07),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Feature highlights
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FeatureHighlight(
                      icon: Icons.calculate,
                      color: primaryColor,
                      label: 'Personalized\nCalories',
                    ),
                    _FeatureHighlight(
                      icon: Icons.auto_graph,
                      color: blue,
                      label: 'Smart\nRecommendations',
                    ),
                    _FeatureHighlight(
                      icon: Icons.track_changes,
                      color: orange,
                      label: 'Goal\nTracking',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () => _startOnboarding(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 2,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Get Started'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 26),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Small note with clock icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      color: primaryColor.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Takes less than 2 minutes • Complete your profile',
                        style: TextStyle(
                          color: primaryColor.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleBadge extends StatelessWidget {
  final Color primaryColor;
  const _AppleBadge({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseSize = (screenWidth * 0.26).clamp(96.0, 168.0).toDouble();
    final double appleSize = baseSize * 0.56;
    final double borderWidth = baseSize * 0.035;

    return Container(
      width: baseSize,
      height: baseSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: baseSize * 0.16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: appleSize,
          height: appleSize,
          child: Image.asset(
            'design/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  const _StepCard({
    required this.number,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.black87, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _FeatureHighlight({
    required this.icon,
    required this.color,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
