import 'package:flutter/material.dart';

class CalorieCalculator {
  static double calculateBMR({
    required int age,
    required String gender,
    required double weight, // in kg
    required double height, // in cm
  }) {
    // Mifflin-St Jeor Equation
    if (gender.toLowerCase() == 'male') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        return bmr * 1.2;
      case 'lightly active':
        return bmr * 1.375;
      case 'moderately active':
        return bmr * 1.55;
      case 'very active':
        return bmr * 1.725;
      case 'extremely active':
        return bmr * 1.9;
      default:
        return bmr * 1.375; // Default to lightly active
    }
  }

  static Map<String, double> calculateGoalCalories({
    required double tdee,
    required String goal,
  }) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
      case 'lose weight':
        return {
          'calories': tdee - 500, // 1 lb/week loss
          'minCalories': tdee - 750, // 1.5 lb/week loss
          'maxCalories': tdee - 250, // 0.5 lb/week loss
        };
      case 'gain_muscle':
      case 'gain muscle':
        return {
          'calories': tdee + 300, // Moderate surplus
          'minCalories': tdee + 200, // Conservative surplus
          'maxCalories': tdee + 500, // Aggressive surplus
        };
      case 'maintain_weight':
      case 'maintain weight':
        return {
          'calories': tdee,
          'minCalories': tdee - 100,
          'maxCalories': tdee + 100,
        };
      default:
        return {
          'calories': tdee,
          'minCalories': tdee - 100,
          'maxCalories': tdee + 100,
        };
    }
  }

  static double calculateBMI({
    required double weight, // in kg
    required double height, // in cm
  }) {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  static Map<String, double> calculateMacros({
    required double calories,
    required String goal,
    required String gender,
  }) {
    double proteinRatio, fatRatio, carbRatio;

    switch (goal.toLowerCase()) {
      case 'lose_weight':
      case 'lose weight':
        proteinRatio = 0.35; // Higher protein for muscle preservation
        fatRatio = 0.25;
        carbRatio = 0.40;
        break;
      case 'gain_muscle':
      case 'gain muscle':
        proteinRatio = 0.30;
        fatRatio = 0.25;
        carbRatio = 0.45;
        break;
      default:
        proteinRatio = 0.25;
        fatRatio = 0.30;
        carbRatio = 0.45;
    }

    // Adjust for gender
    if (gender.toLowerCase() == 'female') {
      fatRatio += 0.05; // Women typically need slightly more fat
      carbRatio -= 0.05;
    }

    return {
      'protein': (calories * proteinRatio) / 4, // 4 cal/g
      'fat': (calories * fatRatio) / 9, // 9 cal/g
      'carbs': (calories * carbRatio) / 4, // 4 cal/g
    };
  }
}

class CalorieInsightCard extends StatefulWidget {
  final int? age;
  final String? gender;
  final double? weight;
  final double? height;
  final String? goal;
  final String? activityLevel;
  final Color primaryColor;

  const CalorieInsightCard({
    super.key,
    this.age,
    this.gender,
    this.weight,
    this.height,
    this.goal,
    this.activityLevel,
    required this.primaryColor,
  });

  @override
  State<CalorieInsightCard> createState() => _CalorieInsightCardState();
}

class _CalorieInsightCardState extends State<CalorieInsightCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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

  bool get _hasBasicData =>
      widget.age != null &&
      widget.gender != null &&
      widget.weight != null &&
      widget.height != null;

  bool get _hasAllData =>
      _hasBasicData && widget.goal != null && widget.activityLevel != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasBasicData) {
      return const SizedBox.shrink();
    }

    final bmr = CalorieCalculator.calculateBMR(
      age: widget.age!,
      gender: widget.gender!,
      weight: widget.weight!,
      height: widget.height!,
    );

    final bmi = CalorieCalculator.calculateBMI(
      weight: widget.weight!,
      height: widget.height!,
    );

    final bmiCategory = CalorieCalculator.getBMICategory(bmi);

    double? tdee;
    Map<String, double>? goalCalories;
    Map<String, double>? macros;

    if (_hasAllData) {
      tdee = CalorieCalculator.calculateTDEE(
        bmr: bmr,
        activityLevel: widget.activityLevel!,
      );

      goalCalories = CalorieCalculator.calculateGoalCalories(
        tdee: tdee,
        goal: widget.goal!,
      );

      macros = CalorieCalculator.calculateMacros(
        calories: goalCalories['calories']!,
        goal: widget.goal!,
        gender: widget.gender!,
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.primaryColor.withValues(alpha: 0.1),
                    widget.primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.primaryColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calculate,
                          color: widget.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Nutrition Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                            Text(
                              'Personalized calculations based on your data',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Basic metrics
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'BMI',
                          value: bmi.toStringAsFixed(1),
                          subtitle: bmiCategory,
                          color: _getBMIColor(bmi),
                          icon: Icons.monitor_weight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'BMR',
                          value: bmr.round().toString(),
                          subtitle: 'cal/day',
                          color: widget.primaryColor,
                          icon: Icons.local_fire_department,
                        ),
                      ),
                    ],
                  ),

                  if (_hasAllData) ...[
                    const SizedBox(height: 16),

                    // Goal calories
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.track_changes,
                                color: widget.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Daily Calorie Target',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Main calorie target
                          Text(
                            '${goalCalories!['calories']!.round()} calories',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: widget.primaryColor,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Range
                          Text(
                            'Range: ${goalCalories['minCalories']!.round()} - ${goalCalories['maxCalories']!.round()} cal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Macros
                          Text(
                            'Recommended Macros',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _MacroIndicator(
                                  label: 'Protein',
                                  value: '${macros!['protein']!.round()}g',
                                  color: Colors.red,
                                ),
                              ),
                              Expanded(
                                child: _MacroIndicator(
                                  label: 'Carbs',
                                  value: '${macros['carbs']!.round()}g',
                                  color: Colors.orange,
                                ),
                              ),
                              Expanded(
                                child: _MacroIndicator(
                                  label: 'Fat',
                                  value: '${macros['fat']!.round()}g',
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sex-specific insights
                    _buildSexSpecificInsights(),
                  ],

                  if (!_hasAllData) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Complete your profile to see personalized calorie targets and macro recommendations!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSexSpecificInsights() {
    final isFemale = widget.gender?.toLowerCase() == 'female';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isFemale
                ? Colors.pink.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isFemale
                  ? Colors.pink.withValues(alpha: 0.3)
                  : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFemale ? Icons.female : Icons.male,
                color: isFemale ? Colors.pink : Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isFemale
                    ? 'Female-Specific Insights'
                    : 'Male-Specific Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isFemale ? Colors.pink[800] : Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (isFemale) ...[
            _InsightRow(
              icon: Icons.favorite,
              text: 'Iron needs: 18mg/day (higher than typical apps)',
              color: Colors.pink,
            ),
            _InsightRow(
              icon: Icons.calendar_today,
              text: 'We\'ll adjust nutrition for your cycle phases',
              color: Colors.pink,
            ),
            _InsightRow(
              icon: Icons.spa,
              text: 'Calcium optimized for bone health',
              color: Colors.pink,
            ),
          ] else ...[
            _InsightRow(
              icon: Icons.fitness_center,
              text: 'Zinc: 11mg/day for optimal testosterone',
              color: Colors.blue,
            ),
            _InsightRow(
              icon: Icons.trending_up,
              text: 'Higher protein targets for muscle building',
              color: Colors.blue,
            ),
            _InsightRow(
              icon: Icons.energy_savings_leaf,
              text: 'Recovery nutrition optimized for training',
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _MacroIndicator extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroIndicator({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InsightRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
