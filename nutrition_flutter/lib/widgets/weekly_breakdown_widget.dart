import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';

/// Widget to display daily breakdown for weekly view
class WeeklyBreakdownWidget extends StatelessWidget {
  final List<DailyBreakdownData> dailyBreakdown;
  final double dailyAverage;
  final Color primaryColor;

  const WeeklyBreakdownWidget({
    super.key,
    required this.dailyBreakdown,
    required this.dailyAverage,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        // Daily average display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Daily Average: ${dailyAverage.toInt()} cal/day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Daily list
        ...dailyBreakdown.map((day) => _buildDayCard(day)),
      ],
    );
  }

  Widget _buildDayCard(DailyBreakdownData day) {
    final maxCalories = dailyBreakdown
        .map((d) => d.calories)
        .reduce((a, b) => a > b ? a : b);
    final progress = maxCalories > 0 ? (day.calories / maxCalories) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Day name
          SizedBox(
            width: 50,
            child: Text(
              day.dayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date
          Expanded(
            child: Text(
              '${day.date.day}/${day.date.month}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          // Progress bar
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Calories
          Text(
            '${day.calories.toInt()} cal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}


