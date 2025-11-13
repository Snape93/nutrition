import 'package:flutter/material.dart';

enum UserSex { male, female, other }

class SexSpecificTheme {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final LinearGradient backgroundGradient;
  final List<Color> cardGradientColors;
  final IconData genderIcon;
  final String welcomeMessage;
  final String motivationalMessage;
  final List<String> healthTips;
  final Map<String, String> goalMessages;
  final Map<String, List<String>> nutritionInsights;

  const SexSpecificTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.cardGradientColors,
    required this.genderIcon,
    required this.welcomeMessage,
    required this.motivationalMessage,
    required this.healthTips,
    required this.goalMessages,
    required this.nutritionInsights,
  });

  static SexSpecificTheme getTheme(UserSex sex) {
    switch (sex) {
      case UserSex.female:
        return _femaleTheme;
      case UserSex.male:
        return _maleTheme;
      case UserSex.other:
        return _neutralTheme;
    }
  }

  static SexSpecificTheme getThemeFromString(String? gender) {
    if (gender == null) return _neutralTheme;

    switch (gender.toLowerCase()) {
      case 'female':
        return _femaleTheme;
      case 'male':
        return _maleTheme;
      default:
        return _neutralTheme;
    }
  }

  static const SexSpecificTheme _femaleTheme = SexSpecificTheme(
    primaryColor: Color(0xFFB76E79), // Rose Gold
    secondaryColor: Color(0xFFE8C1C5),
    accentColor: Color(0xFF8B5A65),
    backgroundColor: Color(0xFFFDF2F4),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFFDF2F4), Color(0xFFF8E8EC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientColors: [Color(0xFFFDF2F4), Color(0xFFE8C1C5)],
    genderIcon: Icons.female,
    welcomeMessage: "Welcome to your personalized nutrition journey! 💕",
    motivationalMessage:
        "Designed specifically for women's unique nutritional needs",
    healthTips: [
      "Your iron needs are 18mg/day - higher than most apps recommend",
      "We'll adjust your nutrition based on your menstrual cycle",
      "Calcium intake optimized for bone health and hormonal balance",
      "Folate requirements considered for reproductive health",
    ],
    goalMessages: {
      'lose_weight':
          "We'll create a sustainable plan that honors your body's natural rhythms and hormonal changes.",
      'gain_muscle':
          "Our approach considers women's unique muscle-building potential and recovery needs.",
      'maintain_weight':
          "We'll help you maintain balance while supporting your energy and mood throughout your cycle.",
      'improve_health':
          "Focus on nutrients that support hormonal health, energy, and overall wellness.",
    },
    nutritionInsights: {
      'cycle_support': [
        'Adjusted iron during menstruation',
        'Increased magnesium for PMS relief',
        'Complex carbs for mood stability',
      ],
      'bone_health': [
        'Calcium: 1000-1200mg daily',
        'Vitamin D for absorption',
        'Magnesium for bone formation',
      ],
      'hormonal_balance': [
        'Omega-3s for hormone production',
        'Fiber for estrogen metabolism',
        'Antioxidants for cellular health',
      ],
    },
  );

  static const SexSpecificTheme _maleTheme = SexSpecificTheme(
    primaryColor: Color(0xFF4CAF50), // Green
    secondaryColor: Color(0xFFC8E6C9),
    accentColor: Color(0xFF2E7D32),
    backgroundColor: Color(0xFFE8F5E8),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFE8F5E8), Color(0xFFE3F2FD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientColors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9)],
    genderIcon: Icons.male,
    welcomeMessage: "Ready to optimize your nutrition? 💪",
    motivationalMessage: "Tailored for men's metabolism and performance goals",
    healthTips: [
      "Your zinc needs are 11mg/day for optimal testosterone production",
      "Higher protein targets to support muscle building and recovery",
      "Nutrition timing optimized for training and performance",
      "Focus on nutrients that support cardiovascular health",
    ],
    goalMessages: {
      'lose_weight':
          "We'll preserve your muscle mass while creating an effective fat loss strategy.",
      'gain_muscle':
          "Optimized protein timing and calories to maximize your muscle-building potential.",
      'maintain_weight':
          "Maintain your strength and energy while supporting your active lifestyle.",
      'improve_health':
          "Focus on heart health, testosterone support, and sustained energy.",
    },
    nutritionInsights: {
      'testosterone_support': [
        'Zinc: 11mg for hormone production',
        'Vitamin D for testosterone levels',
        'Healthy fats: 25-30% of calories',
      ],
      'muscle_building': [
        'Protein: 1.6-2.2g per kg body weight',
        'Post-workout nutrition timing',
        'Creatine for strength gains',
      ],
      'cardiovascular_health': [
        'Omega-3s for heart health',
        'Fiber for cholesterol management',
        'Antioxidants for circulation',
      ],
    },
  );

  static const SexSpecificTheme _neutralTheme = SexSpecificTheme(
    primaryColor: Color(0xFF4CAF50), // Green
    secondaryColor: Color(0xFFC8E6C9),
    accentColor: Color(0xFF2E7D32),
    backgroundColor: Color(0xFFE8F5E8),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFE8F5E8), Color(0xFFF3E5F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradientColors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9)],
    genderIcon: Icons.person,
    welcomeMessage: "Welcome to personalized nutrition! 🌟",
    motivationalMessage: "Customized nutrition for your unique needs and goals",
    healthTips: [
      "Balanced nutrition approach for optimal health",
      "Focus on whole foods and nutrient density",
      "Personalized macronutrient distribution",
      "Sustainable lifestyle integration",
    ],
    goalMessages: {
      'lose_weight':
          "We'll create a balanced approach to sustainable weight management.",
      'gain_muscle':
          "Optimized nutrition to support your strength and muscle-building goals.",
      'maintain_weight':
          "Maintain your current weight while optimizing your health and energy.",
      'improve_health':
          "Focus on nutrient-dense foods that support overall wellness.",
    },
    nutritionInsights: {
      'balanced_nutrition': [
        'Varied protein sources',
        'Complex carbohydrates',
        'Healthy fats balance',
      ],
      'micronutrients': [
        'Vitamin and mineral balance',
        'Antioxidant-rich foods',
        'Hydration optimization',
      ],
      'lifestyle_integration': [
        'Sustainable meal planning',
        'Flexible eating patterns',
        'Long-term habit building',
      ],
    },
  );
}

class SexSpecificMessaging {
  static String getWelcomeMessage(String? gender) {
    final theme = SexSpecificTheme.getThemeFromString(gender);
    return theme.welcomeMessage;
  }

  static String getMotivationalMessage(String? gender) {
    final theme = SexSpecificTheme.getThemeFromString(gender);
    return theme.motivationalMessage;
  }

  static String getGoalMessage(String? gender, String goal) {
    final theme = SexSpecificTheme.getThemeFromString(gender);
    return theme.goalMessages[goal] ?? theme.goalMessages['improve_health']!;
  }

  static List<String> getHealthTips(String? gender) {
    final theme = SexSpecificTheme.getThemeFromString(gender);
    return theme.healthTips;
  }

  static Map<String, List<String>> getNutritionInsights(String? gender) {
    final theme = SexSpecificTheme.getThemeFromString(gender);
    return theme.nutritionInsights;
  }

  static String getEncouragementMessage(String? gender, String context) {
    final isFemale = gender?.toLowerCase() == 'female';
    final isMale = gender?.toLowerCase() == 'male';

    switch (context.toLowerCase()) {
      case 'goal_selection':
        if (isFemale) {
          return "Great choice! We'll create a plan that works with your body's natural rhythms. 💕";
        } else if (isMale) {
          return "Excellent! Let's build a plan that maximizes your potential. 💪";
        } else {
          return "Perfect! We'll customize everything to help you reach your goals. 🌟";
        }

      case 'physical_info':
        if (isFemale) {
          return "Your body is unique and amazing. We'll honor that in your nutrition plan. ✨";
        } else if (isMale) {
          return "We'll use this info to optimize your nutrition for maximum results. 🎯";
        } else {
          return "This helps us create the perfect nutrition plan for you. 📊";
        }

      case 'lifestyle':
        if (isFemale) {
          return "We'll make sure your nutrition fits beautifully into your life. 🌸";
        } else if (isMale) {
          return "Your nutrition will fuel your lifestyle and goals. ⚡";
        } else {
          return "We'll create a plan that works seamlessly with your routine. 🔄";
        }

      case 'completion':
        if (isFemale) {
          return "You're all set! Your personalized nutrition journey begins now. Ready to thrive? 🦋";
        } else if (isMale) {
          return "You're ready to dominate your nutrition goals! Let's get started. 🚀";
        } else {
          return "Your personalized nutrition plan is ready! Time to achieve your goals. 🎉";
        }

      default:
        return "You're doing great! Keep going. 👏";
    }
  }
}

class SexSpecificCard extends StatelessWidget {
  final String? gender;
  final Widget child;
  final EdgeInsets? padding;
  final double? elevation;

  const SexSpecificCard({
    super.key,
    this.gender,
    required this.child,
    this.padding,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(gender);

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.cardGradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.1),
            blurRadius: elevation ?? 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SexSpecificInsightCard extends StatefulWidget {
  final String? gender;
  final String title;
  final List<String> insights;
  final IconData? icon;

  const SexSpecificInsightCard({
    super.key,
    this.gender,
    required this.title,
    required this.insights,
    this.icon,
  });

  @override
  State<SexSpecificInsightCard> createState() => _SexSpecificInsightCardState();
}

class _SexSpecificInsightCardState extends State<SexSpecificInsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(widget.gender);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SexSpecificCard(
            gender: widget.gender,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: theme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    Icon(theme.genderIcon, color: theme.primaryColor, size: 18),
                  ],
                ),
                const SizedBox(height: 12),

                ...widget.insights.map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            insight,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SexSpecificBackground extends StatelessWidget {
  final String? gender;
  final Widget child;

  const SexSpecificBackground({super.key, this.gender, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(gender);

    return Container(
      decoration: BoxDecoration(gradient: theme.backgroundGradient),
      child: child,
    );
  }
}

class SexSpecificButton extends StatelessWidget {
  final String? gender;
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final Widget? icon;

  const SexSpecificButton({
    super.key,
    this.gender,
    required this.text,
    this.onPressed,
    this.isEnabled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(gender);

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: isEnabled ? 4 : 0,
        shadowColor: theme.primaryColor.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
