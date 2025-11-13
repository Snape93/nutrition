import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';
import '../models/graph_models.dart';
import '../screens/beautiful_progress_screen.dart';
import '../design_system/app_design_system.dart';
import 'weekly_breakdown_widget.dart';
import 'monthly_breakdown_widget.dart';

/// Beautiful Progress Card matching the new design
class BeautifulProgressCard extends StatelessWidget {
  final ProgressMetric metric;
  final ProgressData progressData;
  final TimeRange timeRange;
  final VoidCallback onRefresh;
  final String? userSex;

  const BeautifulProgressCard({
    super.key,
    required this.metric,
    required this.progressData,
    required this.timeRange,
    required this.onRefresh,
    this.userSex,
  });

  // Dynamic color scheme based on user gender
  Color get _primaryColor => AppDesignSystem.getPrimaryColor(userSex);
  Color get _lightColor =>
      AppDesignSystem.getPrimaryColor(userSex).withValues(alpha: 0.7);
  static const Color _textGray = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDataSummary(),
          const SizedBox(height: 20),
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getMetricTitle(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTimeRangeLabel(),
                style: TextStyle(fontSize: 14, color: _textGray),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildTrendIndicator(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _lightColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, color: _lightColor, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    try {
      final percentage = _getCurrentPercentage();
      final trend = _getTrendDirection();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend == 'up' ? Icons.trending_up : Icons.trending_down,
            color: _lightColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${(percentage * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: _lightColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDataSummary() {
    // Only show Goal for daily view, hide for weekly/monthly
    final showGoal = timeRange == TimeRange.daily;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryBox('Current', _getCurrentValue(), _lightColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryBox('Average', _getAverageValue(), _textGray),
        ),
        if (showGoal) ...[
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryBox('Goal', _getGoalValue(), _textGray)),
        ],
      ],
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final hasData = _hasData();

    if (!hasData) {
      return _buildEmptyContent();
    }

    return _buildProgressContent();
  }

  Widget _buildEmptyContent() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _lightColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getMetricIcon(), color: _lightColor, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'No data yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start tracking your ${metric.name} to see your progress',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _textGray),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to add data screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              '+ Start',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressContent() {
    // Show breakdowns for weekly/monthly, regular content for daily
    if (timeRange == TimeRange.weekly && progressData.dailyBreakdown != null) {
      final dailyAverage = progressData.calories.current / 7;
      return WeeklyBreakdownWidget(
        dailyBreakdown: progressData.dailyBreakdown!,
        dailyAverage: dailyAverage,
        primaryColor: _primaryColor,
      );
    }

    if (timeRange == TimeRange.monthly &&
        progressData.weeklyBreakdown != null) {
      final daysInMonth =
          progressData.dateRange.end
              .difference(progressData.dateRange.start)
              .inDays +
          1;
      final dailyAverage = progressData.calories.current / daysInMonth;
      return MonthlyBreakdownWidget(
        weeklyBreakdown: progressData.weeklyBreakdown!,
        dailyAverage: dailyAverage,
        primaryColor: _primaryColor,
      );
    }

    // Daily view - show regular progress content
    return Column(
      children: [
        _buildProgressBar(),
        const SizedBox(height: 16),
        _buildProgressDetails(),
      ],
    );
  }

  Widget _buildProgressBar() {
    // Only show progress bar for daily view, hide for weekly/monthly
    if (timeRange != TimeRange.daily) {
      return const SizedBox.shrink();
    }

    try {
      final percentage = _getCurrentPercentage();
      final safePercentage = percentage.clamp(0.0, 1.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textGray,
                ),
              ),
              Text(
                '${(safePercentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _lightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: safePercentage,
              backgroundColor: _lightColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_lightColor),
              minHeight: 8,
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildProgressDetails() {
    // Only show Goal and Remaining for daily view, hide for weekly/monthly
    final showGoal = timeRange == TimeRange.daily;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDetailRow('Current', _getCurrentValue()),
          if (showGoal) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Goal', _getGoalValue()),
            const SizedBox(height: 8),
            _buildDetailRow('Remaining', _getRemainingValue()),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isNegative = label == 'Remaining' && _isRemainingNegative();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: _textGray)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isNegative ? Colors.grey : _lightColor,
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _getMetricTitle() {
    switch (metric) {
      case ProgressMetric.calories:
        return 'Calories';
      case ProgressMetric.exercise:
        return 'Exercise';
    }
  }

  String _getTimeRangeLabel() {
    switch (timeRange) {
      case TimeRange.daily:
        return 'Today';
      case TimeRange.weekly:
        return 'This Week';
      case TimeRange.monthly:
        return 'This Month';
      case TimeRange.custom:
        return 'Custom Range';
    }
  }

  IconData _getMetricIcon() {
    switch (metric) {
      case ProgressMetric.calories:
        return Icons.local_fire_department;
      case ProgressMetric.exercise:
        return Icons.fitness_center;
    }
  }

  bool _hasData() {
    switch (metric) {
      case ProgressMetric.calories:
        return progressData.calories.current > 0;
      case ProgressMetric.exercise:
        return progressData.exercise.duration > 0;
    }
  }

  double _getCurrentPercentage() {
    try {
      switch (metric) {
        case ProgressMetric.calories:
          final percentage = progressData.calories.percentage;
          if (percentage.isNaN || percentage.isInfinite) return 0.0;
          return percentage;
        case ProgressMetric.exercise:
          final duration = progressData.exercise.duration;
          if (duration <= 0) return 0.0;
          final percentage = duration / 30.0; // 30 min goal
          if (percentage.isNaN || percentage.isInfinite) return 0.0;
          return percentage;
      }
    } catch (e) {
      return 0.0;
    }
  }

  String _getTrendDirection() {
    // Simple trend calculation - in real app, this would be more sophisticated
    final percentage = _getCurrentPercentage();
    return percentage > 0.5 ? 'up' : 'down';
  }

  String _getCurrentValue() {
    switch (metric) {
      case ProgressMetric.calories:
        return '${progressData.calories.current.toInt()} cal';
      case ProgressMetric.exercise:
        return '${progressData.exercise.duration} min';
    }
  }

  String _getAverageValue() {
    // For now, return current value as average
    // In real app, this would calculate actual averages
    return _getCurrentValue();
  }

  String _getGoalValue() {
    switch (metric) {
      case ProgressMetric.calories:
        return '${progressData.calories.goal.toInt()} cal';
      case ProgressMetric.exercise:
        return '30 min';
    }
  }

  String _getRemainingValue() {
    switch (metric) {
      case ProgressMetric.calories:
        final remaining = progressData.calories.remaining;
        // Show absolute value with proper sign (negative values allowed)
        return '${remaining.toInt()} cal';
      case ProgressMetric.exercise:
        final remaining = 30 - progressData.exercise.duration;
        return '${remaining.clamp(0, 30)} min';
    }
  }

  bool _isRemainingNegative() {
    switch (metric) {
      case ProgressMetric.calories:
        return progressData.calories.remaining < 0;
      case ProgressMetric.exercise:
        return false;
    }
  }
}
