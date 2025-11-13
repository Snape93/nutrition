import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';

/// Widget to display weekly breakdown for monthly view
class MonthlyBreakdownWidget extends StatelessWidget {
  final List<WeeklyBreakdownData> weeklyBreakdown;
  final double dailyAverage;
  final Color primaryColor;

  const MonthlyBreakdownWidget({
    super.key,
    required this.weeklyBreakdown,
    required this.dailyAverage,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Weekly Breakdown',
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
        // Weekly cards
        ...weeklyBreakdown.map((week) => _buildWeekCard(week)),
      ],
    );
  }

  Widget _buildWeekCard(WeeklyBreakdownData week) {
    final maxCalories = weeklyBreakdown
        .map((w) => w.calories)
        .reduce((a, b) => a > b ? a : b);
    final progress = maxCalories > 0 ? (week.calories / maxCalories) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week label and date range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                week.weekLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '${week.weekStart.day}/${week.weekStart.month} - ${week.weekEnd.day}/${week.weekEnd.month}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          // Calories total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Calories',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${week.calories.toInt()} cal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


