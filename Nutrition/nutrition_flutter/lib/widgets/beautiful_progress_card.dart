import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';
import '../models/graph_models.dart';
import '../screens/beautiful_progress_screen.dart';

/// Beautiful Progress Card matching the new design
class BeautifulProgressCard extends StatelessWidget {
  final ProgressMetric metric;
  final ProgressData progressData;
  final TimeRange timeRange;
  final VoidCallback onRefresh;

  const BeautifulProgressCard({
    Key? key,
    required this.metric,
    required this.progressData,
    required this.timeRange,
    required this.onRefresh,
  }) : super(key: key);

  // Color scheme matching the design
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _lightGreen = Color(0xFF4CAF50);
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
                  color: _lightGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: _lightGreen, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    final percentage = _getCurrentPercentage();
    final trend = _getTrendDirection();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          trend == 'up' ? Icons.trending_up : Icons.trending_down,
          color: _lightGreen,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${(percentage * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: _lightGreen,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDataSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryBox('Current', _getCurrentValue(), _lightGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryBox('Average', _getAverageValue(), _textGray),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryBox('Goal', _getGoalValue(), _textGray)),
      ],
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
            color: _lightGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getMetricIcon(), color: _lightGreen, size: 40),
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
              backgroundColor: _primaryGreen,
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
    return Column(
      children: [
        _buildProgressBar(),
        const SizedBox(height: 16),
        _buildProgressDetails(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final percentage = _getCurrentPercentage();

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
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _lightGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: _lightGreen.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(_lightGreen),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDetailRow('Current', _getCurrentValue()),
          const SizedBox(height: 8),
          _buildDetailRow('Goal', _getGoalValue()),
          const SizedBox(height: 8),
          _buildDetailRow('Remaining', _getRemainingValue()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: _textGray)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _lightGreen,
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
      case ProgressMetric.water:
        return 'Water';
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
      case ProgressMetric.water:
        return Icons.water_drop;
    }
  }

  bool _hasData() {
    switch (metric) {
      case ProgressMetric.calories:
        return progressData.calories.current > 0;
      case ProgressMetric.exercise:
        return progressData.exercise.duration > 0;
      case ProgressMetric.water:
        return progressData.waterIntake.current > 0;
    }
  }

  double _getCurrentPercentage() {
    switch (metric) {
      case ProgressMetric.calories:
        return progressData.calories.percentage;
      case ProgressMetric.exercise:
        return progressData.exercise.duration / 30.0; // 30 min goal
      case ProgressMetric.water:
        return progressData.waterIntake.percentage;
    }
  }

  String _getTrendDirection() {
    // Simple trend calculation - in real app, this would be more sophisticated
    return _getCurrentPercentage() > 0.5 ? 'up' : 'down';
  }

  String _getCurrentValue() {
    switch (metric) {
      case ProgressMetric.calories:
        return '${progressData.calories.current.toInt()} cal';
      case ProgressMetric.exercise:
        return '${progressData.exercise.duration} min';
      case ProgressMetric.water:
        return '${progressData.waterIntake.current.toInt()} ml';
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
      case ProgressMetric.water:
        return '${progressData.waterIntake.goal.toInt()} ml';
    }
  }

  String _getRemainingValue() {
    switch (metric) {
      case ProgressMetric.calories:
        return '${progressData.calories.remaining.toInt()} cal';
      case ProgressMetric.exercise:
        final remaining = 30 - progressData.exercise.duration;
        return '${remaining.clamp(0, 30)} min';
      case ProgressMetric.water:
        return '${progressData.waterIntake.remaining.toInt()} ml';
    }
  }
}

