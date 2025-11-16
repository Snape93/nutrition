import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';
import '../models/graph_models.dart';

/// Statistics cards widget for displaying bar graph statistics
class BarGraphStatistics extends StatelessWidget {
  final List<GraphDataPoint> data;
  final String unit;
  final Color primaryColor;
  final double? goalValue;

  const BarGraphStatistics({
    super.key,
    required this.data,
    required this.unit,
    required this.primaryColor,
    this.goalValue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = _calculateStatistics();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    // Check if all values are zero
    final allZero = stats['average'] == 0.0 && 
                    stats['total'] == 0.0 && 
                    stats['highest'] == 0.0 && 
                    stats['lowest'] == 0.0;

    // Show encouraging message if all values are zero
    if (allZero) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceMD),
        child: Container(
          padding: EdgeInsets.all(AppDesignSystem.spaceMD),
          decoration: BoxDecoration(
            color: AppDesignSystem.surface,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
            border: Border.all(
              color: AppDesignSystem.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
                size: 20,
              ),
              SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: Text(
                  'Start logging meals to see your calorie statistics',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceMD),
      child: isSmallScreen
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.bar_chart,
                        label: 'Average',
                        value: stats['average']!,
                        subtitle: 'per day',
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceSM),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.calculate,
                        label: 'Total',
                        value: stats['total']!,
                        subtitle: 'for period',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppDesignSystem.spaceSM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.trending_up,
                        label: 'Highest',
                        value: stats['highest']!,
                        subtitle: stats['highestDate'] ?? '',
                        color: AppDesignSystem.success,
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceSM),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.trending_down,
                        label: 'Lowest',
                        value: stats['lowest']!,
                        subtitle: stats['lowestDate'] ?? '',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : isMediumScreen
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: Icons.bar_chart,
                            label: 'Average',
                            value: stats['average']!,
                            subtitle: 'per day',
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(width: AppDesignSystem.spaceSM),
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: Icons.calculate,
                            label: 'Total',
                            value: stats['total']!,
                            subtitle: 'for period',
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppDesignSystem.spaceSM),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: Icons.trending_up,
                            label: 'Highest',
                            value: stats['highest']!,
                            subtitle: stats['highestDate'] ?? '',
                            color: AppDesignSystem.success,
                          ),
                        ),
                        SizedBox(width: AppDesignSystem.spaceSM),
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: Icons.trending_down,
                            label: 'Lowest',
                            value: stats['lowest']!,
                            subtitle: stats['lowestDate'] ?? '',
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.bar_chart,
                        label: 'Average',
                        value: stats['average']!,
                        subtitle: 'per day',
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceSM),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.calculate,
                        label: 'Total',
                        value: stats['total']!,
                        subtitle: 'for period',
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceSM),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.trending_up,
                        label: 'Highest',
                        value: stats['highest']!,
                        subtitle: stats['highestDate'] ?? '',
                        color: AppDesignSystem.success,
                      ),
                    ),
                    SizedBox(width: AppDesignSystem.spaceSM),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        icon: Icons.trending_down,
                        label: 'Lowest',
                        value: stats['lowest']!,
                        subtitle: stats['lowestDate'] ?? '',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
    );
  }

  Map<String, dynamic> _calculateStatistics() {
    if (data.isEmpty) {
      return {
        'average': 0.0,
        'total': 0.0,
        'highest': 0.0,
        'lowest': 0.0,
        'highestDate': null,
        'lowestDate': null,
      };
    }

    final values = data.map((point) => point.value).toList();
    final total = values.fold(0.0, (sum, value) => sum + value);
    final average = total / values.length;
    final highest = values.reduce((a, b) => a > b ? a : b);
    final lowest = values.reduce((a, b) => a < b ? a : b);

    // Find dates for highest and lowest
    final highestPoint = data.firstWhere((point) => point.value == highest);
    final lowestPoint = data.firstWhere((point) => point.value == lowest);

    return {
      'average': average,
      'total': total,
      'highest': highest,
      'lowest': lowest,
      'highestDate': _formatDate(highestPoint.date),
      'lowestDate': _formatDate(lowestPoint.date),
    };
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double value,
    required String subtitle,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    // Responsive card sizing - increased height to prevent overflow
    final cardHeight = isSmallScreen ? 100.0 : 110.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final valueFontSize = isSmallScreen ? 18.0 : 22.0;
    final labelFontSize = isSmallScreen ? 10.0 : 11.0;
    final unitFontSize = isSmallScreen ? 9.0 : 10.0;
    final subtitleFontSize = isSmallScreen ? 8.0 : 9.0;
    
    return Container(
      height: cardHeight,
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and label row
          Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          // Value and unit row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _formatValue(value),
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.1, // Tighter line height
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 3),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: unitFontSize,
                    fontWeight: FontWeight.w400,
                    color: AppDesignSystem.onSurfaceVariant,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          // Subtitle
          if (subtitle.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  fontWeight: FontWeight.w400,
                  color: AppDesignSystem.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    final intValue = value.toInt();
    
    // Format with commas for thousands
    if (intValue >= 1000000) {
      final millions = (value / 1000000);
      if (millions >= 10) {
        return '${millions.toStringAsFixed(0)}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    } else if (intValue >= 1000) {
      final thousands = (value / 1000);
      if (thousands >= 10) {
        return '${thousands.toStringAsFixed(0)}K';
      }
      return '${thousands.toStringAsFixed(1)}K';
    } else {
      // Format numbers with commas
      return _formatNumberWithCommas(intValue);
    }
  }

  /// Format number with comma separators for thousands
  /// Example: 15736 -> "15,736"
  String _formatNumberWithCommas(int value) {
    if (value < 1000) {
      return value.toString();
    }
    
    final parts = <String>[];
    var remaining = value.abs();
    final isNegative = value < 0;
    
    while (remaining > 0) {
      final part = (remaining % 1000).toString().padLeft(remaining >= 1000 ? 3 : 0, '0');
      parts.insert(0, part);
      remaining ~/= 1000;
    }
    
    final result = parts.join(',');
    return isNegative ? '-$result' : result;
  }
}


