import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/graph_models.dart';
import '../design_system/app_design_system.dart';

/// Professional bar graph widget with gender-based theming
class BarGraphWidget extends StatefulWidget {
  final List<GraphDataPoint> data;
  final double? goalValue;
  final String unit;
  final Color primaryColor;
  final String? userGender;
  final bool isLoading;
  final Function(GraphDataPoint)? onBarTap;

  const BarGraphWidget({
    super.key,
    required this.data,
    this.goalValue,
    required this.unit,
    required this.primaryColor,
    this.userGender,
    this.isLoading = false,
    this.onBarTap,
  });

  @override
  State<BarGraphWidget> createState() => _BarGraphWidgetState();
}

class _BarGraphWidgetState extends State<BarGraphWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _barAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, child) {
        return Container(
          height: _getChartHeight(context),
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spaceMD,
            vertical: AppDesignSystem.spaceMD,
          ),
          child: BarChart(
            _buildBarChartData(),
          ),
        );
      },
    );
  }

  double _getChartHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Reduced heights to prevent overflow and leave room for statistics
    if (screenWidth < 360) return 240; // Small phones: 240px
    if (screenWidth < 600) return 260; // Standard phones: 260px
    return 280; // Tablets: 280px
  }

  BarChartData _buildBarChartData() {
    final maxValue = _getMaxValue();
    final minValue = 0.0;
    final minDataValue = _getMinValue();

    // Dynamic scaling: adapt to actual data range
    // Calculate data range
    final dataRange = maxValue - minDataValue;
    
    // Ensure goal line is always visible above bars
    final goalValue = widget.goalValue ?? 0;
    final cappedGoal = goalValue > 5000 ? 0.0 : goalValue;
    
    // Calculate max considering both data and goal
    double baseMax = maxValue;
    if (cappedGoal > 0 && cappedGoal > maxValue) {
      baseMax = cappedGoal;
    }
    
    // Apply smart padding based on data range
    double finalMax;
    if (maxValue == 0) {
      // No data, use default scale
      finalMax = cappedGoal > 0 ? cappedGoal * 1.2 : 2000.0;
    } else if (dataRange < 500) {
      // Small range: add 20% padding and ensure minimum visible range
      finalMax = (baseMax * 1.2).clamp(baseMax * 1.1, baseMax + 500);
    } else if (dataRange < 1000) {
      // Medium range: add 15% padding
      finalMax = baseMax * 1.15;
    } else {
      // Large range: add 10% padding
      finalMax = baseMax * 1.1;
    }
    
    // Ensure goal line is always visible (add extra padding if goal exists)
    if (cappedGoal > 0) {
      // Ensure goal line has at least 5% space above the highest bar
      final minMaxForGoal = baseMax > cappedGoal 
          ? (baseMax * 1.05).clamp(cappedGoal * 1.05, double.infinity)
          : cappedGoal * 1.1;
      if (finalMax < minMaxForGoal) {
        finalMax = minMaxForGoal;
      }
    }
    
    // Round to clean number for better Y-axis intervals
    finalMax = _roundToCleanNumber(finalMax);
    
    // Cap at reasonable maximum for calories (5,000)
    // This ensures the scale never goes above 5,000 for daily-equivalent views
    if (finalMax > 5000) {
      finalMax = 5000.0;
    }
    
    // Ensure minimum scale for visibility (only if data exists)
    if (maxValue > 0 && finalMax < maxValue * 1.05) {
      finalMax = _roundToCleanNumber(maxValue * 1.05); // At least 5% padding
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: finalMax,
      minY: minValue,
      groupsSpace: _calculateGroupsSpace(),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => AppDesignSystem.onSurface.withValues(alpha: 0.9),
          tooltipPadding: EdgeInsets.all(AppDesignSystem.spaceSM),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final dataPoint = widget.data[groupIndex];
            final dateStr = _formatDate(dataPoint.date);
            final valueStr = '${_formatNumber(dataPoint.value)} ${widget.unit}';
            
            String statusText = '';
            if (widget.goalValue != null && widget.goalValue! > 0) {
              final percentage = (dataPoint.value / widget.goalValue! * 100).clamp(0.0, 999.9);
              final goalMet = dataPoint.value >= widget.goalValue!;
              final overGoal = dataPoint.value >= widget.goalValue! * 1.1;
              
              if (overGoal) {
                statusText = '⚠ ${percentage.toStringAsFixed(0)}% of goal';
              } else if (goalMet) {
                statusText = '✓ ${percentage.toStringAsFixed(0)}% of goal';
              } else {
                statusText = '${percentage.toStringAsFixed(0)}% of goal';
              }
            }

            return BarTooltipItem(
              '$dateStr\n$valueStr${statusText.isNotEmpty ? '\n$statusText' : ''}',
              TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
        touchCallback: (FlTouchEvent event, barTouchResponse) {
          if (!event.isInterestedForInteractions ||
              barTouchResponse == null ||
              barTouchResponse.spot == null) {
            return;
          }

          if (event is FlTapUpEvent && widget.onBarTap != null) {
            final index = barTouchResponse.spot!.touchedBarGroupIndex;
            if (index < widget.data.length) {
              widget.onBarTap!(widget.data[index]);
            }
          }
        },
      ),
      titlesData: _buildTitlesData(finalMax),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calculateInterval(finalMax),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppDesignSystem.outline,
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: AppDesignSystem.outline,
            width: 1,
          ),
          left: BorderSide(
            color: AppDesignSystem.outline,
            width: 1,
          ),
        ),
      ),
      barGroups: _buildBarGroups(),
      extraLinesData: widget.goalValue != null && widget.goalValue! > 0 && widget.goalValue! <= 5000
          ? ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: widget.goalValue!,
                  color: widget.primaryColor.withValues(alpha: 0.7),
                  strokeWidth: 2.5,
                  dashArray: [8, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: EdgeInsets.only(right: 8, bottom: 4),
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final dataPoint = entry.value;
      final hasGoal = widget.goalValue != null && widget.goalValue! > 0;
      final goalPercentage = hasGoal ? (dataPoint.value / widget.goalValue!) : 0.0;
      
      // Determine bar color based on MyFitnessPal design principles
      Color barColor;
      double barOpacity = 1.0;
      
      if (dataPoint.value == 0) {
        // Zero/No Data: Very light gray with subtle border
        barColor = const Color(0xFFE0E0E0); // Light gray
        barOpacity = 1.0;
      } else if (!hasGoal) {
        // No goal set: Use primary color at full opacity
        barColor = widget.primaryColor;
        barOpacity = 1.0;
      } else if (goalPercentage >= 1.1) {
        // Over Goal (>110%): Warning color (orange)
        barColor = AppDesignSystem.warning;
        barOpacity = 1.0;
      } else if (goalPercentage >= 1.0) {
        // Goal Met (100-110%): Full primary color
        barColor = widget.primaryColor;
        barOpacity = 1.0;
      } else if (goalPercentage >= 0.8) {
        // Near Goal (80-100%): Primary color at 80% opacity
        barColor = widget.primaryColor;
        barOpacity = 0.8;
      } else {
        // Under Goal (<80%): Primary color at 60% opacity
        barColor = widget.primaryColor;
        barOpacity = 0.6;
      }

      // Apply animation
      final animatedValue = dataPoint.value * _barAnimation.value;
      
      // For zero values, show a minimal height bar with border for visibility
      final displayValue = dataPoint.value == 0 ? 0.0 : animatedValue;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: displayValue,
            color: barColor.withValues(alpha: barOpacity),
            width: _getBarWidth(),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppDesignSystem.radiusSM),
              topRight: Radius.circular(AppDesignSystem.radiusSM),
            ),
            gradient: dataPoint.value > 0
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      barColor.withValues(alpha: barOpacity),
                      barColor.withValues(alpha: barOpacity * 0.8),
                    ],
                  )
                : null,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxValue() * 1.15, // Slightly higher for better visual
              color: dataPoint.value == 0 
                  ? const Color(0xFFF5F5F5) // Very light background for zero bars
                  : AppDesignSystem.background,
              fromY: 0,
            ),
          ),
        ],
        barsSpace: AppDesignSystem.spaceSM,
      );
    }).toList();
  }

  double _getBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    final dataCount = widget.data.length;
    
    // Dynamic bar width based on screen size and number of bars
    // More bars = thinner bars, fewer bars = wider bars
    double baseWidth;
    if (screenWidth < 360) {
      baseWidth = 24; // Small phones: wider bars for visibility
    } else if (screenWidth < 600) {
      baseWidth = 28; // Standard phones
    } else {
      baseWidth = 32; // Tablets: wider bars
    }
    
    // Adjust based on number of bars (7 for daily, 4-5 for weekly, 12 for monthly)
    if (dataCount > 10) {
      return baseWidth * 0.85; // Many bars: slightly thinner
    } else if (dataCount > 7) {
      return baseWidth * 0.9;
    } else {
      return baseWidth; // Few bars: use full width
    }
  }

  /// Calculate dynamic spacing between bar groups
  double _calculateGroupsSpace() {
    final dataCount = widget.data.length;
    
    // More bars = less space, fewer bars = more space
    double baseSpace = AppDesignSystem.spaceSM;
    
    if (dataCount > 10) {
      return baseSpace * 0.7; // Tight spacing for many bars
    } else if (dataCount > 7) {
      return baseSpace * 0.85;
    } else if (dataCount <= 5) {
      return baseSpace * 1.5; // More space for few bars
    }
    
    return baseSpace;
  }

  FlTitlesData _buildTitlesData(double maxY) {
    return FlTitlesData(
      show: true,
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.data.length) {
              return const SizedBox.shrink();
            }
            final dataPoint = widget.data[index];
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatXAxisLabel(dataPoint),
                style: TextStyle(
                  color: AppDesignSystem.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
          reservedSize: 40,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: (value, meta) {
            if (value == meta.min) {
              return const SizedBox.shrink();
            }
            return Text(
              _formatNumber(value),
              style: TextStyle(
                color: AppDesignSystem.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            );
          },
          interval: _calculateInterval(maxY),
        ),
      ),
    );
  }

  String _formatXAxisLabel(GraphDataPoint dataPoint) {
    if (dataPoint.label != null) {
      return dataPoint.label!;
    }
    // Format date based on data density
    if (widget.data.length <= 7) {
      // Daily view - show day name
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dataPoint.date.weekday - 1];
    } else if (widget.data.length <= 12) {
      // Monthly view - show month abbreviation
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
      return months[dataPoint.date.month - 1];
    } else {
      // Custom or dense view - show day number
      return '${dataPoint.date.day}';
    }
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format number with comma separators for thousands
  /// Example: 15736 -> "15,736"
  String _formatNumber(double value) {
    final intValue = value.toInt();
    if (intValue < 1000) {
      return intValue.toString();
    }
    
    final parts = <String>[];
    var remaining = intValue.abs();
    final isNegative = intValue < 0;
    
    while (remaining > 0) {
      final part = (remaining % 1000).toString().padLeft(remaining >= 1000 ? 3 : 0, '0');
      parts.insert(0, part);
      remaining ~/= 1000;
    }
    
    final result = parts.join(',');
    return isNegative ? '-$result' : result;
  }

  /// Get the maximum value from data (no padding applied)
  double _getMaxValue() {
    if (widget.data.isEmpty) return 100;
    final maxDataValue = widget.data
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    final goalValue = widget.goalValue ?? 0;
    
    // Cap goal value at reasonable maximum (5,000 calories) to prevent inflated scales
    // Goals above 5,000 are likely errors (weekly totals, etc.)
    final cappedGoal = goalValue > 5000 ? 0.0 : goalValue;
    
    // Return raw max value (max of data or capped goal), no padding
    return maxDataValue > cappedGoal ? maxDataValue : cappedGoal;
  }

  /// Get the minimum value from data (excluding zeros for better scaling)
  double _getMinValue() {
    if (widget.data.isEmpty) return 0;
    final nonZeroValues = widget.data
        .map((point) => point.value)
        .where((value) => value > 0)
        .toList();
    if (nonZeroValues.isEmpty) return 0;
    return nonZeroValues.reduce((a, b) => a < b ? a : b);
  }

  /// Round to clean number for better Y-axis scaling
  /// Examples: 2640 -> 3000, 2450 -> 2500, 1234 -> 1500
  double _roundToCleanNumber(double value) {
    if (value <= 0) return 0;
    
    // Round up to next clean interval
    if (value <= 500) {
      return (value / 100).ceil() * 100;
    } else if (value <= 1000) {
      return (value / 200).ceil() * 200;
    } else if (value <= 2000) {
      return (value / 500).ceil() * 500;
    } else if (value <= 5000) {
      return (value / 500).ceil() * 500;
    } else {
      return (value / 1000).ceil() * 1000;
    }
  }

  double _calculateInterval(double maxValue) {
    // Dynamic interval calculation for better readability
    // Aim for 4-6 grid lines for optimal readability
    if (maxValue <= 0) return 500;
    
    // Calculate interval based on rounded max value
    // This ensures clean intervals that don't create crowded labels
    if (maxValue <= 500) {
      return 100;
    } else if (maxValue <= 1000) {
      return 200;
    } else if (maxValue <= 2000) {
      return 500;
    } else if (maxValue <= 3000) {
      // For 2000-3000 range, use 500 interval to avoid crowding
      // This prevents labels like 2500, 2600 being too close
      return 500;
    } else if (maxValue <= 5000) {
      return 1000;
    } else {
      return 2000;
    }
  }

  Widget _buildLoadingState() {
    return Container(
      height: _getChartHeight(context),
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: widget.primaryColor,
              strokeWidth: 3,
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'Loading chart data...',
              style: TextStyle(
                color: AppDesignSystem.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: _getChartHeight(context),
      padding: EdgeInsets.all(AppDesignSystem.spaceXXL),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: AppDesignSystem.outline,
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'No data available',
              style: TextStyle(
                color: AppDesignSystem.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppDesignSystem.spaceSM),
            Text(
              'Start tracking your calories to see your progress',
              style: TextStyle(
                color: AppDesignSystem.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

