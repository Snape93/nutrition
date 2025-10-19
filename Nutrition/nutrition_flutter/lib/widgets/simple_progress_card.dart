import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

/// Simple progress card without animations to prevent paused exceptions
class SimpleProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double currentValue;
  final double goalValue;
  final String unit;
  final IconData icon;
  final Color primaryColor;

  const SimpleProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.goalValue,
    required this.unit,
    required this.icon,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        goalValue > 0 ? (currentValue / goalValue).clamp(0.0, 1.0) : 0.0;

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
                Icon(icon, color: primaryColor, size: 24),
                const SizedBox(width: AppDesignSystem.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppDesignSystem.titleLarge.copyWith(
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${currentValue.toInt()}/${goalValue.toInt()}$unit',
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppDesignSystem.outline.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 8,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% Complete',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(goalValue - currentValue).toInt()}$unit remaining',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
