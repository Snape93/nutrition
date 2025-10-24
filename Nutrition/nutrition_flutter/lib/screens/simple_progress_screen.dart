import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';
import '../widgets/simple_progress_card.dart';
import '../services/progress_data_service.dart';
import '../models/graph_models.dart';

/// Enhanced progress screen with real-time data integration
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

  // Progress data state
  ProgressData? _progressData;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastRefresh;

  Color get _primaryColor => AppDesignSystem.getPrimaryColor(widget.userSex);
  Color get _backgroundColor =>
      AppDesignSystem.getBackgroundColor(widget.userSex);

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final timeRange = _getTimeRangeFromIndex(_selectedTimeRange);
      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: timeRange,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        debugPrint('📊 Progress data loaded:');
        debugPrint(
          '   Calories: ${progressData.calories.current}/${progressData.calories.goal}',
        );
        debugPrint(
          '   Steps: ${progressData.steps.current}/${progressData.steps.goal}',
        );
        debugPrint('   Exercise: ${progressData.exercise.duration} min');
        debugPrint(
          '   Water: ${progressData.waterIntake.current}/${progressData.waterIntake.goal}',
        );

        setState(() {
          _progressData = progressData;
          _lastRefresh = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load progress data: $e';
          _isLoading = false;
        });
      }
    }
  }

  TimeRange _getTimeRangeFromIndex(int index) {
    switch (index) {
      case 0:
        return TimeRange.daily;
      case 1:
        return TimeRange.weekly;
      case 2:
        return TimeRange.monthly;
      default:
        return TimeRange.daily;
    }
  }

  Future<void> _onTimeRangeChanged(int index) async {
    setState(() {
      _selectedTimeRange = index;
    });
    await _loadProgressData(forceRefresh: true);
  }

  Future<void> _onRefresh() async {
    await _loadProgressData(forceRefresh: true);
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Padding(
          padding: AppDesignSystem.getResponsivePadding(context),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeRangeSelector(),
                const SizedBox(height: AppDesignSystem.spaceLG),
                if (_isLoading)
                  _buildLoadingState()
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_progressData != null)
                  _buildProgressContent()
                else
                  _buildEmptyState(),
                if (_lastRefresh != null) _buildLastRefreshIndicator(),
              ],
            ),
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
                              _onTimeRangeChanged(index);
                            },
                            selectedColor: _primaryColor.withValues(alpha: 0.2),
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

  Widget _buildProgressContent() {
    if (_progressData == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildProgressCards(),
        const SizedBox(height: AppDesignSystem.spaceLG),
        _buildInsightsCard(),
      ],
    );
  }

  Widget _buildProgressCards() {
    if (_progressData == null) return const SizedBox.shrink();

    return Column(
      children: [
        SimpleProgressCard(
          title: 'Calories',
          subtitle: '${_timeRanges[_selectedTimeRange]} intake vs goal',
          currentValue: _progressData!.calories.current,
          goalValue: _progressData!.calories.goal,
          unit: ' cal',
          icon: Icons.local_fire_department,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Water Intake',
          subtitle: 'Hydration tracking',
          currentValue: _progressData!.waterIntake.current,
          goalValue: _progressData!.waterIntake.goal,
          unit: ' ml',
          icon: Icons.water_drop,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Exercise',
          subtitle: '${_timeRanges[_selectedTimeRange]} activity',
          currentValue: _progressData!.exercise.duration.toDouble(),
          goalValue: _progressData!.goals['exercise']?.toDouble() ?? 30.0,
          unit: ' min',
          icon: Icons.fitness_center,
          primaryColor: _primaryColor,
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SimpleProgressCard(
          title: 'Steps',
          subtitle: '${_timeRanges[_selectedTimeRange]} movement',
          currentValue: _progressData!.steps.current.toDouble(),
          goalValue: _progressData!.steps.goal.toDouble(),
          unit: ' steps',
          icon: Icons.directions_walk,
          primaryColor: _primaryColor,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: AppDesignSystem.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceXL),
        child: Column(
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'Loading progress data...',
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      elevation: AppDesignSystem.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppDesignSystem.error, size: 48),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'Failed to load progress data',
              style: AppDesignSystem.titleMedium.copyWith(
                color: AppDesignSystem.error,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceSM),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: AppDesignSystem.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceXL),
        child: Column(
          children: [
            Icon(Icons.trending_up, color: _primaryColor, size: 48),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'No progress data available',
              style: AppDesignSystem.titleMedium.copyWith(color: _primaryColor),
            ),
            const SizedBox(height: AppDesignSystem.spaceSM),
            Text(
              'Start tracking your health metrics to see your progress here.',
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastRefreshIndicator() {
    final timeAgo = DateTime.now().difference(_lastRefresh!);
    String timeText;

    if (timeAgo.inMinutes < 1) {
      timeText = 'Just now';
    } else if (timeAgo.inMinutes < 60) {
      timeText = '${timeAgo.inMinutes}m ago';
    } else {
      timeText = '${timeAgo.inHours}h ago';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppDesignSystem.spaceMD),
      child: Text(
        'Last updated: $timeText',
        style: AppDesignSystem.bodySmall.copyWith(
          color: AppDesignSystem.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInsightsCard() {
    if (_progressData == null) return const SizedBox.shrink();

    final insights = _generateInsights();

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
            if (insights.isEmpty)
              Text(
                'Keep tracking your progress to see personalized insights!',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: AppDesignSystem.onSurfaceVariant,
                ),
              )
            else
              ...insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDesignSystem.spaceMD,
                  ),
                  child: _buildInsightItem(
                    insight['title']!,
                    insight['description']!,
                    insight['icon']!,
                    insight['color']!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    if (_progressData == null) return [];

    final insights = <Map<String, dynamic>>[];

    // Calorie insights
    final caloriesPercentage = _progressData!.calories.percentage;
    if (caloriesPercentage >= 1.0) {
      insights.add({
        'title': '🎯 Calorie goal achieved!',
        'description':
            'Great job meeting your ${_timeRanges[_selectedTimeRange].toLowerCase()} calorie target.',
        'icon': Icons.local_fire_department,
        'color': AppDesignSystem.success,
      });
    } else if (caloriesPercentage >= 0.8) {
      insights.add({
        'title': 'Almost there!',
        'description':
            'You\'re ${(100 - caloriesPercentage * 100).toInt()}% away from your calorie goal.',
        'icon': Icons.trending_up,
        'color': AppDesignSystem.warning,
      });
    }

    // Exercise insights
    final exerciseDuration = _progressData!.exercise.duration;
    if (exerciseDuration >= 30) {
      insights.add({
        'title': '💪 Great exercise session!',
        'description':
            'You\'ve completed $exerciseDuration minutes of exercise.',
        'icon': Icons.fitness_center,
        'color': AppDesignSystem.success,
      });
    }

    // Steps insights
    final stepsPercentage = _progressData!.steps.percentage;
    if (stepsPercentage >= 1.0) {
      insights.add({
        'title': '🚶 Step goal achieved!',
        'description': 'Excellent! You\'ve reached your daily step target.',
        'icon': Icons.directions_walk,
        'color': AppDesignSystem.success,
      });
    }

    // Water insights
    final waterPercentage = _progressData!.waterIntake.percentage;
    if (waterPercentage >= 1.0) {
      insights.add({
        'title': '💧 Hydration goal met!',
        'description': 'Perfect! You\'ve stayed well hydrated.',
        'icon': Icons.water_drop,
        'color': AppDesignSystem.info,
      });
    }

    return insights;
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
