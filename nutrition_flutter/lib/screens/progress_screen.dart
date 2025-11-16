import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../services/progress_data_service.dart';
import '../services/streak_service.dart';
import '../models/graph_models.dart';
import '../models/streak_model.dart';
import '../widgets/streak_card.dart';
import '../widgets/bar_graph_widget.dart';
import '../widgets/custom_date_range_picker.dart';
import '../widgets/bar_graph_statistics.dart';
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
  int _selectedTimeRange = 0; // 0: Daily, 1: Weekly, 2: Monthly, 3: Custom
  final List<String> _timeRanges = ['Daily', 'Weekly', 'Monthly', 'Custom'];
  
  // Custom date range state
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime? _userStartDate;
  DateTime? _maxEndDate; // Yesterday
  bool _isLoadingStartDate = false;
  
  // Bar graph data
  List<GraphDataPoint> _barGraphData = [];
  bool _isLoadingBarGraph = false;

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
    _maxEndDate = DateTime.now().subtract(const Duration(days: 1)); // Yesterday
    _loadWeightData();
    _loadCalorieGoal();
    _loadUserStartDate();
    _loadDataForTimeRange();
    _loadStreakData();
  }
  
  Future<void> _loadUserStartDate() async {
    setState(() {
      _isLoadingStartDate = true;
    });
    
    try {
      final startDate = await ProgressDataService.getUserStartDate(
        usernameOrEmail: widget.usernameOrEmail,
      );
      
      if (!mounted) return;
      
      setState(() {
        _userStartDate = startDate;
        _isLoadingStartDate = false;
      });
    } catch (e) {
      debugPrint('Error loading user start date: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingStartDate = false;
      });
    }
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
      // Reset custom dates when switching away from Custom
      if (index != 3) {
        _customStartDate = null;
        _customEndDate = null;
      }
    });
    _loadDataForTimeRange();
  }
  
  void _onCustomDateRangeSelected(DateTime start, DateTime end) {
    setState(() {
      _customStartDate = start;
      _customEndDate = end;
    });
    _loadDataForTimeRange();
  }


  Future<void> _loadDataForTimeRange() async {
    try {
      TimeRange timeRange;
      DateTime? customStart;
      DateTime? customEnd;
      
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
        case 3: // Custom
          timeRange = TimeRange.custom;
          customStart = _customStartDate;
          customEnd = _customEndDate;
          if (customStart == null || customEnd == null) {
            // Don't load data if custom dates not selected
            return;
          }
          break;
        default:
          timeRange = TimeRange.daily;
      }
      
      setState(() {
        _isLoadingBarGraph = true;
      });
      
      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: timeRange,
        customStartDate: customStart,
        customEndDate: customEnd,
      );
      
      // Load bar graph data
      await _loadBarGraphData(timeRange, customStart, customEnd);
      
      if (!mounted) return;
      
      // Update metrics with real data
      final updatedMetrics = List<MetricData>.from(_availableMetrics);
      
      // Update calories metric
      final caloriesIdx = updatedMetrics.indexWhere((m) => m.id == 'calories');
      if (caloriesIdx != -1) {
        // Show goal for all views now that weekly/monthly show averages (daily-equivalent values)
        final goalValue = progressData.calories.goal;
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
        _isLoadingBarGraph = false;
      });
    } catch (e) {
      debugPrint('Error loading progress data: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingBarGraph = false;
      });
    }
  }
  
  Future<void> _loadBarGraphData(
    TimeRange timeRange,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    try {
      // Calculate date range based on time range
      DateTime startDate;
      DateTime endDate;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      
      switch (timeRange) {
        case TimeRange.daily:
          // Last 7 days from yesterday
          endDate = yesterday;
          startDate = endDate.subtract(const Duration(days: 6));
          // But respect user's start date if they started < 7 days ago
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.weekly:
          // Last 4-5 weeks from last week
          endDate = yesterday;
          startDate = endDate.subtract(const Duration(days: 28));
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.monthly:
          // Last 12 months from last month
          endDate = yesterday;
          startDate = DateTime(endDate.year - 1, endDate.month, 1);
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.custom:
          if (customStart == null || customEnd == null) {
            return;
          }
          startDate = customStart;
          endDate = customEnd;
          break;
      }
      
      // Fetch raw data from backend
      final backendData = await ProgressDataService.fetchRawBackendData(
        widget.usernameOrEmail,
        DateRange(startDate, endDate),
      );
      
      final rawCaloriesData = backendData['calories'] as List<dynamic>? ?? [];
      final caloriesList = rawCaloriesData.map((e) => e as Map<String, dynamic>).toList();
      
      // Aggregate based on time range
      List<GraphDataPoint> aggregatedData;
      switch (timeRange) {
        case TimeRange.daily:
          aggregatedData = ProgressDataService.aggregateDailyDataForBarGraph(
            caloriesList,
            startDate,
            endDate,
          );
          break;
        case TimeRange.weekly:
          aggregatedData = ProgressDataService.aggregateWeeklyDataForBarGraph(
            caloriesList,
            startDate,
            endDate,
          );
          break;
        case TimeRange.monthly:
          aggregatedData = ProgressDataService.aggregateMonthlyDataForBarGraph(
            caloriesList,
            startDate,
            endDate,
          );
          break;
        case TimeRange.custom:
          aggregatedData = ProgressDataService.aggregateCustomDataForBarGraph(
            caloriesList,
            startDate,
            endDate,
          );
          break;
      }
      
      if (!mounted) return;
      setState(() {
        _barGraphData = aggregatedData;
      });
    } catch (e) {
      debugPrint('Error loading bar graph data: $e');
    }
  }

  String _getTimeRangeText() {
    // Use natural language for better UX
    switch (_selectedTimeRange) {
      case 0: // Daily
        return 'Last 7 days';
      case 1: // Weekly
        return 'Last 4 weeks';
      case 2: // Monthly
        return 'Last 12 months';
      case 3: // Custom
        if (_customStartDate != null && _customEndDate != null) {
          // Format custom date range
          final start = _customStartDate!;
          final end = _customEndDate!;
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${months[start.month - 1]} ${start.day}, ${start.year} - ${months[end.month - 1]} ${end.day}, ${end.year}';
        }
        return 'Select date range';
      default:
        return 'Last 7 days';
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
                  Align(
                    alignment: Alignment.center,
                    widthFactor: 1.0,
                    child: _buildTimeRangeTabs(),
                  ),
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Custom date range picker (only when Custom is selected)
                  if (_selectedTimeRange == 3)
                    CustomDateRangePicker(
                      startDate: _customStartDate,
                      endDate: _customEndDate,
                      minDate: _userStartDate,
                      maxDate: _maxEndDate,
                      onDateRangeSelected: _onCustomDateRangeSelected,
                      primaryColor: _primaryColor,
                    ),

                  // Bar graph card
                  if (_selectedTimeRange != 3 || (_customStartDate != null && _customEndDate != null))
                    _buildBarGraphCard(),
                  
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Weight tracking card
                  _buildWeightCard(),
                  SizedBox(height: AppDesignSystem.spaceMD),

                  // Streak card - only show for Daily view
                  if (_selectedTimeRange == 0) ...[
                    _buildStreakCard(),
                    SizedBox(height: AppDesignSystem.spaceMD),
                  ],

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
      constraints: BoxConstraints(maxWidth: 400),
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
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _timeRanges.asMap().entries.map((entry) {
          int index = entry.key;
          String label = entry.value;
          bool isSelected = _selectedTimeRange == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => _selectTimeRange(index),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: AppDesignSystem.outline,
                            width: 1,
                          ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildBarGraphCard() {
    final selectedMetric = _availableMetrics.isNotEmpty
        ? _availableMetrics[_selectedMetricIndex]
        : null;
    final goalValue = selectedMetric?.goalValue ?? 0.0;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Calories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.onSurface,
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            _getTimeRangeText(),
            style: TextStyle(
              fontSize: 12,
              color: AppDesignSystem.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          
          // Summary statistics
          if (_barGraphData.isNotEmpty) ...[
            _buildSummaryStats(goalValue),
            SizedBox(height: AppDesignSystem.spaceMD),
          ],
          
          // Bar graph
          BarGraphWidget(
            data: _barGraphData,
            goalValue: goalValue > 0 ? goalValue : null,
            unit: 'cal',
            primaryColor: _primaryColor,
            userGender: widget.userSex,
            isLoading: _isLoadingBarGraph,
          ),
          
          // Statistics cards
          if (_barGraphData.isNotEmpty) ...[
            SizedBox(height: AppDesignSystem.spaceMD),
            BarGraphStatistics(
              data: _barGraphData,
              unit: 'cal',
              primaryColor: _primaryColor,
              goalValue: goalValue > 0 ? goalValue : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStats(double? goalValue) {
    if (_barGraphData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Calculate statistics
    final values = _barGraphData.map((point) => point.value).toList();
    final average = values.fold(0.0, (sum, value) => sum + value) / values.length;
    final current = values.last; // Most recent value
    
    // Cap goal value at reasonable maximum (5,000) to prevent unrealistic change values
    // Goals above 5,000 are likely errors (weekly totals, etc.)
    final cappedGoal = goalValue != null && goalValue > 0 && goalValue <= 5000 
        ? goalValue 
        : null;
    
    final change = cappedGoal != null
        ? current - cappedGoal 
        : (values.length > 1 ? current - values[values.length - 2] : 0.0);
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            value: average,
            label: 'AVERAGE',
            unit: 'cal',
            color: _primaryColor,
          ),
        ),
        SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildSummaryCard(
            value: current,
            label: 'CURRENT',
            unit: 'cal',
            color: _primaryColor,
          ),
        ),
        SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildSummaryCard(
            value: change,
            label: 'CHANGE',
            unit: 'cal',
            color: change >= 0 ? AppDesignSystem.success : AppDesignSystem.error,
            showSign: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard({
    required double value,
    required String label,
    required String unit,
    required Color color,
    bool showSign = false,
  }) {
    final formattedValue = _formatSummaryValue(value, showSign);
    
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(
          color: AppDesignSystem.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatSummaryValue(double value, bool showSign) {
    final intValue = value.toInt();
    final absValue = value.abs();
    
    if (absValue >= 1000) {
      final thousands = absValue / 1000;
      final formatted = thousands >= 10 
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(1);
      final sign = showSign ? (value >= 0 ? '+' : '-') : '';
      return '$sign${formatted}K';
    } else {
      final sign = showSign ? (value >= 0 ? '+' : '-') : '';
      return '$sign$intValue';
    }
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
