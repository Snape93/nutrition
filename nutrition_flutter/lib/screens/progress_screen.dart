import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../services/progress_data_service.dart';
import '../services/streak_service.dart';
import '../models/graph_models.dart';
import '../models/streak_model.dart';
import '../widgets/streak_card.dart';
import '../design_system/app_design_system.dart';
import '../my_app.dart'; // For routeObserver

/// Data class for tracking metrics
class MetricData {
  final String id;
  final String name;
  final IconData icon;
  final double currentValue;
  final double goalValue;
  final String unit;
  final bool isSelected;

  MetricData({
    required this.id,
    required this.name,
    required this.icon,
    required this.currentValue,
    required this.goalValue,
    required this.unit,
    this.isSelected = false,
  });

  MetricData copyWith({
    String? id,
    String? name,
    IconData? icon,
    double? currentValue,
    double? goalValue,
    String? unit,
    bool? isSelected,
  }) {
    return MetricData(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      currentValue: currentValue ?? this.currentValue,
      goalValue: goalValue ?? this.goalValue,
      unit: unit ?? this.unit,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Progress screen that matches the UI design with weight tracking and no overflow
class ProgressScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const ProgressScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with RouteAware {
  int _selectedTimeRange = 0; // 0: Daily, 1: Weekly, 2: Monthly
  final List<String> _timeRanges = ['Daily', 'Weekly', 'Monthly'];

  // Weight tracking data
  double currentWeight = 0.0;
  double averageWeight = 0.0;
  double goalWeight = 0.0;
  bool hasWeightData = false;

  // Streak data
  StreakData? _caloriesStreak;
  StreakData? _exerciseStreak;
  bool _isLoadingStreak = false;

  // Metric management
  int _selectedMetricIndex = 0;
  List<MetricData> _availableMetrics = [
    MetricData(
      id: 'calories',
      name: 'Calories',
      icon: Icons.local_fire_department,
      currentValue: 0,
      goalValue: 2000,
      unit: 'cal',
      isSelected: true,
    ),
    MetricData(
      id: 'exercise',
      name: 'Exercise',
      icon: Icons.fitness_center,
      currentValue: 0,
      goalValue: 60,
      unit: 'min',
      isSelected: false,
    ),
    MetricData(
      id: 'weight',
      name: 'Weight',
      icon: Icons.monitor_weight,
      currentValue: 0,
      goalValue: 0,
      unit: 'kg',
      isSelected: false,
    ),
  ];


  Color get _primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get _backgroundColor => ThemeService.getBackgroundColor(widget.userSex);

  @override
  void initState() {
    super.initState();
    _loadWeightData();
    _loadCalorieGoal();
    _loadDataForTimeRange();
    _loadStreakData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    // Screen was pushed (navigated to)
    _loadDataForTimeRange();
    _loadStreakData();
  }

  @override
  void didPopNext() {
    // Returning to this screen from another screen
    _loadDataForTimeRange();
    _loadStreakData();
  }

  Future<void> _loadWeightData() async {
    // TODO: Load actual weight data from database
    // For now, using placeholder data
    setState(() {
      hasWeightData = false; // Set to false to show "No data yet" state
      currentWeight = 0.0;
      averageWeight = 0.0;
      goalWeight = 0.0;
    });
  }

  Future<void> _loadCalorieGoal() async {
    try {
      final data = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: TimeRange.daily,
      );
      if (!mounted) return;
      setState(() {
        // Update the calories metric goal to match backend/user goal
        final idx = _availableMetrics.indexWhere((m) => m.id == 'calories');
        if (idx != -1) {
          _availableMetrics[idx] = _availableMetrics[idx].copyWith(
            goalValue: data.calories.goal,
          );
        }
      });
    } catch (_) {
      // keep defaults on failure
    }
  }

  void _startTracking() {
    // TODO: Implement start tracking functionality
    // This could open a dialog to set initial weight or connect to health data
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Start Weight Tracking'),
            content: Text(
              'Would you like to set your current weight to start tracking?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Open weight input dialog or connect to health data
                },
                child: Text('Set Weight'),
              ),
            ],
          ),
    );
  }

  void _selectMetric(int index) {
    setState(() {
      _selectedMetricIndex = index;
      // Update selection state
      for (int i = 0; i < _availableMetrics.length; i++) {
        _availableMetrics[i] = _availableMetrics[i].copyWith(
          isSelected: i == index,
        );
      }
    });
  }

  void _selectTimeRange(int index) {
    setState(() {
      _selectedTimeRange = index;
    });
    _loadDataForTimeRange();
  }


  Future<void> _loadDataForTimeRange() async {
    try {
      TimeRange timeRange;
      
      switch (_selectedTimeRange) {
        case 0: // Daily
          timeRange = TimeRange.daily;
          break;
        case 1: // Weekly
          timeRange = TimeRange.weekly;
          break;
        case 2: // Monthly
          timeRange = TimeRange.monthly;
          break;
        default:
          timeRange = TimeRange.daily;
      }
      
      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: timeRange,
      );
      
      if (!mounted) return;
      
      // Update metrics with real data
      final updatedMetrics = List<MetricData>.from(_availableMetrics);
      
      // Update calories metric
      final caloriesIdx = updatedMetrics.indexWhere((m) => m.id == 'calories');
      if (caloriesIdx != -1) {
        // Only show goal for daily view, hide for weekly/monthly
        final goalValue = _selectedTimeRange == 0 
            ? progressData.calories.goal 
            : 0.0;
        updatedMetrics[caloriesIdx] = updatedMetrics[caloriesIdx].copyWith(
          currentValue: progressData.calories.current,
          goalValue: goalValue,
        );
      }
      
      // Update exercise metric
      final exerciseIdx = updatedMetrics.indexWhere((m) => m.id == 'exercise');
      if (exerciseIdx != -1) {
        // Only show goal for daily view, hide for weekly/monthly
        final exerciseGoal = _selectedTimeRange == 0
            ? (progressData.goals['exercise']?.toDouble() ?? 30.0)
            : 0.0;
        updatedMetrics[exerciseIdx] = updatedMetrics[exerciseIdx].copyWith(
          currentValue: progressData.exercise.duration.toDouble(),
          goalValue: exerciseGoal,
        );
      }
      
      // Update weight metric
      final weightIdx = updatedMetrics.indexWhere((m) => m.id == 'weight');
      if (weightIdx != -1 && progressData.weight.current > 0) {
        updatedMetrics[weightIdx] = updatedMetrics[weightIdx].copyWith(
          currentValue: progressData.weight.current,
          goalValue: progressData.weight.current, // Can be updated if goal weight is tracked
        );
        setState(() {
          hasWeightData = true;
          currentWeight = progressData.weight.current;
          averageWeight = progressData.weight.current; // Can calculate average from historical data
        });
      }
      
      setState(() {
        _availableMetrics = updatedMetrics;
      });
    } catch (e) {
      debugPrint('Error loading progress data: $e');
    }
  }

  String _getTimeRangeText() {
    switch (_selectedTimeRange) {
      case 0: // Daily
        return 'Today';
      case 1: // Weekly
        return 'This Week';
      case 2: // Monthly
        return 'This Month';
      default:
        return 'Today';
    }
  }

  Future<void> _loadStreakData() async {
    if (_isLoadingStreak) {
      debugPrint('⏸️ Streak data already loading, skipping...');
      return;
    }
    
    debugPrint('🔥 Starting to load streak data for ${widget.usernameOrEmail}');
    
    setState(() {
      _isLoadingStreak = true;
    });

    try {
      debugPrint('🔥 Calling StreakService.getStreaks...');
      final streaks = await StreakService.getStreaks(
        usernameOrEmail: widget.usernameOrEmail,
      );

      debugPrint('🔥 Received ${streaks.length} streak(s) from service');

      if (!mounted) {
        debugPrint('⚠️ Widget not mounted, skipping state update');
        return;
      }

      setState(() {
        try {
          _caloriesStreak = streaks.firstWhere(
            (s) => s.streakType.toLowerCase() == 'calories',
          );
          debugPrint('✅ Found calories streak: ${_caloriesStreak!.currentStreak} days');
        } catch (e) {
          _caloriesStreak = null;
          debugPrint('ℹ️ No calories streak found');
        }
        
        try {
          _exerciseStreak = streaks.firstWhere(
            (s) => s.streakType.toLowerCase() == 'exercise',
          );
          debugPrint('✅ Found exercise streak: ${_exerciseStreak!.currentStreak} days');
        } catch (e) {
          _exerciseStreak = null;
          debugPrint('ℹ️ No exercise streak found');
        }
        
        _isLoadingStreak = false;
        debugPrint('✅ Streak data loading complete');
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading streak data: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoadingStreak = false;
      });
    }
  }

  void _onStreakRefresh() {
    _loadStreakData();
  }

  void _onLogActivity() {
    // Navigate to appropriate logging screen based on selected metric
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to logging screen'),
        backgroundColor: _primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Row(
          children: [
            Text(
              'Your Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.show_chart, color: Colors.white, size: 24),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight -
                  kBottomNavigationBarHeight,
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metric buttons row
                  _buildMetricButtons(),
                  SizedBox(height: 20),

                  // Time range tabs
                  _buildTimeRangeTabs(),
                  SizedBox(height: 20),

                  // Weight tracking card
                  _buildWeightCard(),
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Streak card
                  _buildStreakCard(),
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Additional space to prevent overflow
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Display available metrics
          ..._availableMetrics.asMap().entries.map((entry) {
            int index = entry.key;
            MetricData metric = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: 12),
              child: _buildMetricButton(
                icon: metric.icon,
                label: metric.name,
                isSelected: metric.isSelected,
                onTap: () => _selectMetric(index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(25), // More oval shape
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _primaryColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Icon(Icons.check, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children:
            _timeRanges.asMap().entries.map((entry) {
              int index = entry.key;
              String label = entry.value;
              bool isSelected = _selectedTimeRange == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectTimeRange(index),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? _primaryColor : Colors.grey[600],
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildWeightCard() {
    final selectedMetric =
        _availableMetrics.isNotEmpty
            ? _availableMetrics[_selectedMetricIndex]
            : null;
    final timeRangeText = _getTimeRangeText();
    final progressPercentage =
        selectedMetric != null && selectedMetric.goalValue > 0
            ? ((selectedMetric.currentValue / selectedMetric.goalValue) * 100)
                .clamp(0.0, 100.0)
            : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress badge
          Row(
            children: [
              Text(
                selectedMetric?.name ?? 'Weight',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              if (selectedMetric != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: _primaryColor),
                      SizedBox(width: 4),
                      Text(
                        '${progressPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(width: 8),
              Icon(Icons.refresh, color: Colors.grey[600], size: 20),
            ],
          ),
          SizedBox(height: 4),
          Text(
            timeRangeText,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 20),

          // Data boxes
          Row(
            children: [
              Expanded(
                child: _buildWeightBox(
                  label: 'Current',
                  value:
                      selectedMetric != null
                          ? (selectedMetric.currentValue > 0
                              ? '${selectedMetric.currentValue.toInt()}${selectedMetric.unit}'
                              : 'No data')
                          : (hasWeightData
                              ? '${currentWeight.toStringAsFixed(1)}kg'
                              : 'No data'),
                  isHighlighted: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildWeightBox(
                  label: 'Average',
                  value:
                      selectedMetric != null
                          ? (selectedMetric.currentValue > 0
                              ? '${(selectedMetric.currentValue * 0.8).toInt()}${selectedMetric.unit}'
                              : 'No data')
                          : (hasWeightData
                              ? '${averageWeight.toStringAsFixed(1)}kg'
                              : 'No data'),
                  isHighlighted: false,
                ),
              ),
              // Only show Goal box for Daily view
              if (_selectedTimeRange == 0) ...[
                SizedBox(width: 12),
                Expanded(
                  child: _buildWeightBox(
                    label: 'Goal',
                    value:
                        selectedMetric != null
                            ? (selectedMetric.goalValue > 0
                                ? '${selectedMetric.goalValue.toInt()}${selectedMetric.unit}'
                                : 'Not set')
                            : (hasWeightData
                                ? '${goalWeight.toStringAsFixed(1)}kg'
                                : 'Not set'),
                    isHighlighted: false,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 20),

          // Line graph or no data state
          if (selectedMetric != null && selectedMetric.currentValue > 0)
            _buildLineGraph(selectedMetric)
          else
            _buildNoDataState(),
        ],
      ),
    );
  }

  Widget _buildWeightBox({
    required String label,
    required String value,
    required bool isHighlighted,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color:
            isHighlighted
                ? _primaryColor.withValues(alpha: 0.1)
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border:
            isHighlighted
                ? Border.all(
                  color: _primaryColor.withValues(alpha: 0.3),
                  width: 1,
                )
                : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? _primaryColor : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineGraph(MetricData metric) {
    // Generate sample data for the week
    final now = DateTime.now();
    final weekData = _generateWeekData(metric);

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Column(
        children: [
          // Y-axis labels and graph
          Expanded(
            child: Row(
              children: [
                // Y-axis labels
                SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${metric.goalValue.toInt()}${metric.unit}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(metric.goalValue * 0.8).toInt()}${metric.unit}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(metric.goalValue * 0.6).toInt()}${metric.unit}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(metric.goalValue * 0.4).toInt()}${metric.unit}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Graph area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: LineGraphPainter(
                          data: weekData,
                          color: _primaryColor,
                          maxValue: metric.goalValue,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // X-axis labels (dates)
          Padding(
            padding: EdgeInsets.only(left: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  weekData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final date = now.subtract(Duration(days: 6 - index));
                    return Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.more_horiz, color: _primaryColor, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              'No data yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startTracking,
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    // Show calories streak by default, or exercise if calories not available
    final streakToShow = _caloriesStreak ?? _exerciseStreak;
    
    // Always show the streak card, even if no data (will show empty state)
    return StreakCard(
      streakData: streakToShow,
      userSex: widget.userSex,
      onRefresh: _onStreakRefresh,
      onLogActivity: _onLogActivity,
    );
  }

  List<double> _generateWeekData(MetricData metric) {
    // Generate realistic sample data for the week
    final baseValue = metric.currentValue;
    final variation = metric.goalValue * 0.3;

    return List.generate(7, (index) {
      final random = (index * 0.3 + 0.5) % 1.0; // Pseudo-random based on index
      return (baseValue + (random - 0.5) * variation).clamp(
        0.0,
        metric.goalValue * 1.2,
      );
    });
  }
}

class LineGraphPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  LineGraphPainter({
    required this.data,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    final pointPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    // Calculate points
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] / maxValue) * size.height;
      points.add(Offset(x, y));
    }

    // Draw line
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw points
    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
