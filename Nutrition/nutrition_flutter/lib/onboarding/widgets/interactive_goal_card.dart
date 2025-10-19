import 'package:flutter/material.dart';

class GoalOption {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final String benefit;
  final String successRate;
  final String description;
  final List<String> features;

  const GoalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.benefit,
    required this.successRate,
    required this.description,
    required this.features,
  });
}

class InteractiveGoalCard extends StatefulWidget {
  final GoalOption goal;
  final bool isSelected;
  final VoidCallback onTap;
  final AnimationController? animationController;

  const InteractiveGoalCard({
    super.key,
    required this.goal,
    required this.isSelected,
    required this.onTap,
    this.animationController,
  });

  @override
  State<InteractiveGoalCard> createState() => _InteractiveGoalCardState();
}

class _InteractiveGoalCardState extends State<InteractiveGoalCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _selectionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _selectionAnimation;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _selectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.elasticOut),
    );

    if (widget.isSelected) {
      _selectionController.forward();
    }
  }

  @override
  void didUpdateWidget(InteractiveGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionController.forward();
      } else {
        _selectionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _hoverController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _hoverController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _selectionAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color:
                    widget.isSelected
                        ? widget.goal.color.withValues(alpha: 0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      widget.isSelected ? widget.goal.color : Colors.grey[300]!,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        widget.isSelected
                            ? widget.goal.color.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.1),
                    blurRadius: _elevationAnimation.value * 2,
                    offset: Offset(0, _elevationAnimation.value / 2),
                    spreadRadius: widget.isSelected ? 1 : 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Main content row
                    Row(
                      children: [
                        // Emoji container with animation
                        AnimatedBuilder(
                          animation: _selectionAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_selectionAnimation.value * 0.2),
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: widget.goal.color.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                  border:
                                      widget.isSelected
                                          ? Border.all(
                                            color: widget.goal.color,
                                            width: 2,
                                          )
                                          : null,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.goal.emoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.goal.title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.isSelected
                                          ? widget.goal.color
                                          : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.goal.subtitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Benefits row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.goal.color.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.goal.benefit,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.goal.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.goal.successRate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Selection indicator
                        AnimatedBuilder(
                          animation: _selectionAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_selectionAnimation.value * 0.3),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      widget.isSelected
                                          ? widget.goal.color
                                          : Colors.grey[300],
                                  boxShadow:
                                      widget.isSelected
                                          ? [
                                            BoxShadow(
                                              color: widget.goal.color
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                          : null,
                                ),
                                child:
                                    widget.isSelected
                                        ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                        : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Expanded details when selected
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child:
                          widget.isSelected
                              ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: widget.goal.color.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: widget.goal.color.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'What you can expect:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: widget.goal.color,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.goal.description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Features list
                                        ...widget.goal.features.map(
                                          (feature) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: widget.goal.color,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    feature,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
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
                                ],
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Predefined goal options with comprehensive data
class GoalOptions {
  static List<GoalOption> getGoals() {
    return [
      GoalOption(
        id: 'lose_weight',
        title: 'Lose Weight',
        subtitle: 'Shed pounds safely and sustainably',
        emoji: '🔥',
        color: Colors.red,
        benefit: 'Lose 1-2 lbs/week',
        successRate: '87% success rate',
        description:
            'We\'ll create a sustainable calorie deficit tailored to your body type, metabolism, and lifestyle preferences.',
        features: [
          'Personalized calorie targets',
          'Flexible meal plans',
          'Progress tracking tools',
          'Habit building guidance',
        ],
      ),
      GoalOption(
        id: 'gain_muscle',
        title: 'Gain Muscle',
        subtitle: 'Build lean mass and strength',
        emoji: '💪',
        color: Colors.blue,
        benefit: 'Gain 0.5-1 lb/week',
        successRate: '82% success rate',
        description:
            'We\'ll optimize your protein intake, meal timing, and nutrition to maximize muscle growth and recovery.',
        features: [
          'High-protein meal plans',
          'Pre/post workout nutrition',
          'Muscle-building supplements guide',
          'Recovery optimization',
        ],
      ),
      GoalOption(
        id: 'maintain_weight',
        title: 'Maintain Weight',
        subtitle: 'Stay balanced and energized',
        emoji: '⚖️',
        color: Colors.green,
        benefit: 'Feel energized daily',
        successRate: '91% success rate',
        description:
            'We\'ll help you find your perfect balance of nutrition and activity to maintain your current weight while feeling your best.',
        features: [
          'Maintenance calorie targets',
          'Balanced macro distribution',
          'Energy optimization',
          'Lifestyle sustainability',
        ],
      ),
      GoalOption(
        id: 'improve_health',
        title: 'Improve Health',
        subtitle: 'Feel your absolute best',
        emoji: '❤️',
        color: Colors.purple,
        benefit: 'Better sleep & mood',
        successRate: '94% success rate',
        description:
            'We\'ll focus on nutrient-dense foods and eating patterns that boost your energy, mood, and overall wellbeing.',
        features: [
          'Nutrient-dense meal plans',
          'Anti-inflammatory foods',
          'Blood sugar optimization',
          'Digestive health support',
        ],
      ),
    ];
  }
}
