import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';
import '../widgets/simple_progress_card.dart';

/// Simple progress screen without animations to prevent paused exceptions
class SimpleProgressScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const SimpleProgressScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<SimpleProgressScreen> createState() => _SimpleProgressScreenState();
}

class _SimpleProgressScreenState extends State<SimpleProgressScreen> {
  int _selectedTimeRange = 0; // 0: Daily, 1: Weekly, 2: Monthly
  final List<String> _timeRanges = ['Daily', 'Weekly', 'Monthly'];

  Color get _primaryColor => AppDesignSystem.getPrimaryColor(widget.userSex);
  Color get _backgroundColor =>
      AppDesignSystem.getBackgroundColor(widget.userSex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Text(
          'Your Progress',
          style: AppDesignSystem.headlineMedium.copyWith(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: AppDesignSystem.getResponsivePadding(context),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeRangeSelector(),
              const SizedBox(height: AppDesignSystem.spaceLG),
              _buildProgressCards(),
              const SizedBox(height: AppDesignSystem.spaceLG),
              _buildInsightsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: AppDesignSystem.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: _primaryColor),
            const SizedBox(width: AppDesignSystem.spaceMD),
            Text(
              'Time Range:',
              style: AppDesignSystem.titleMedium.copyWith(color: _primaryColor),
            ),
            const SizedBox(width: AppDesignSystem.spaceMD),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _timeRanges.asMap().entries.map((entry) {
                        final index = entry.key;
                        final range = entry.value;
                        final isSelected = _selectedTimeRange == index;

                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppDesignSystem.spaceSM,
                          ),
                          child: FilterChip(
                            label: Text(range),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTimeRange = index;
                              });
                            },
                            selectedColor: _primaryColor.withOpacity(0.2),
                            checkmarkColor: _primaryColor,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCards() {
    return Column(
      children: [
        SimpleProgressCard(
          title: 'Calories',
          subtitle: 'Daily intake vs goal',
          currentValue: 1200,
          goalValue: 2000,
          unit: ' cal',
          icon: Icons.local_fire_department,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Water Intake',
          subtitle: 'Hydration tracking',
          currentValue: 1500,
          goalValue: 2000,
          unit: ' ml',
          icon: Icons.water_drop,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Exercise',
          subtitle: 'Daily activity',
          currentValue: 30,
          goalValue: 60,
          unit: ' min',
          icon: Icons.fitness_center,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Steps',
          subtitle: 'Daily movement',
          currentValue: 7500,
          goalValue: 10000,
          unit: ' steps',
          icon: Icons.directions_walk,
          primaryColor: _primaryColor,
        ),
      ],
    );
  }

  Widget _buildInsightsCard() {
    return Card(
      elevation: AppDesignSystem.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: _primaryColor, size: 24),
                const SizedBox(width: AppDesignSystem.spaceMD),
                Text(
                  'Insights',
                  style: AppDesignSystem.titleLarge.copyWith(
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildInsightItem(
              'Great job on staying hydrated!',
              'You\'ve met 75% of your water goal today.',
              Icons.water_drop,
              AppDesignSystem.info,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            _buildInsightItem(
              'Keep up the exercise routine',
              'You\'re halfway to your daily exercise goal.',
              Icons.fitness_center,
              AppDesignSystem.warning,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            _buildInsightItem(
              'Calorie balance is good',
              'You\'re on track with your nutrition goals.',
              Icons.check_circle,
              AppDesignSystem.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppDesignSystem.spaceMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppDesignSystem.titleMedium.copyWith(color: color),
              ),
              Text(
                description,
                style: AppDesignSystem.bodySmall.copyWith(
                  color: AppDesignSystem.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
