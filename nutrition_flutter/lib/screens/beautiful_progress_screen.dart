import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';
import '../services/streak_service.dart';
import '../models/graph_models.dart';
import '../models/streak_model.dart';
import '../widgets/beautiful_progress_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/bar_graph_widget.dart';
import '../widgets/single_date_picker.dart';
import '../widgets/bar_graph_statistics.dart';
import '../design_system/app_design_system.dart';

/// Beautiful Progress Screen matching the new design
class BeautifulProgressScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const BeautifulProgressScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<BeautifulProgressScreen> createState() =>
      _BeautifulProgressScreenState();
}

class _BeautifulProgressScreenState extends State<BeautifulProgressScreen>
    with TickerProviderStateMixin {
  // Progress metrics selection
  final ProgressMetric _selectedMetric = ProgressMetric.calories;

  // Time range selection
  TimeRange _selectedTimeRange = TimeRange.daily;

  // Custom date state (single date selection)
  DateTime? _customSelectedDate;
  DateTime? _userStartDate;
  DateTime? _maxEndDate; // Yesterday
  bool _isLoadingStartDate = false;

  // Bar graph data
  List<GraphDataPoint> _barGraphData = [];
  bool _isLoadingBarGraph = false;

  // Progress data
  ProgressData? _progressData;
  bool _isLoading = false;
  String? _errorMessage;
  double? _historicalGoal; // Historical goal for single date view

  // Streak data
  StreakData? _caloriesStreak;
  StreakData? _exerciseStreak;
  bool _isLoadingStreak = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Dynamic color scheme based on user gender
  Color get _primaryColor => AppDesignSystem.getPrimaryColor(widget.userSex);
  Color get _lightColor =>
      AppDesignSystem.getPrimaryColor(widget.userSex).withValues(alpha: 0.7);
  Color get _backgroundColor =>
      AppDesignSystem.getBackgroundColor(widget.userSex);
  static const Color _textGray = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _maxEndDate = DateTime.now().subtract(const Duration(days: 1)); // Yesterday
    _setupAnimations();
    _loadUserStartDate();
    _loadProgressData();
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

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressData({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Don't load if Custom is selected but date not chosen
    if (_selectedTimeRange == TimeRange.custom && _customSelectedDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Only load bar graph for Custom time range
      if (_selectedTimeRange == TimeRange.custom) {
        _isLoadingBarGraph = true;
      }
    });

    try {
      // For single date view, fetch historical goal for that date
      double? historicalGoal;
      if (_selectedTimeRange == TimeRange.custom &&
          _customSelectedDate != null) {
        try {
          historicalGoal = await ProgressDataService.fetchGoalForDate(
            widget.usernameOrEmail,
            _customSelectedDate!,
          );
        } catch (e) {
          debugPrint('Error fetching historical goal: $e');
        }
      }

      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: _selectedTimeRange,
        customStartDate: _customSelectedDate,
        customEndDate:
            _customSelectedDate, // Same date for single date selection
        forceRefresh: forceRefresh,
      );

      // Store historical goal for use in UI
      _historicalGoal = historicalGoal;

      // Load bar graph data only for Custom time range
      if (_selectedTimeRange == TimeRange.custom) {
        await _loadBarGraphData();
      }

      if (mounted) {
        setState(() {
          _progressData = progressData;
          _isLoading = false;
          if (_selectedTimeRange == TimeRange.custom) {
            _isLoadingBarGraph = false;
          }
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load progress data: $e';
          _isLoading = false;
          if (_selectedTimeRange == TimeRange.custom) {
            _isLoadingBarGraph = false;
          }
        });
      }
    }
  }

  Future<void> _loadBarGraphData() async {
    try {
      // Calculate date range based on time range
      DateTime startDate;
      DateTime endDate;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      switch (_selectedTimeRange) {
        case TimeRange.daily:
          endDate = yesterday;
          startDate = endDate.subtract(const Duration(days: 6));
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.weekly:
          endDate = yesterday;
          startDate = endDate.subtract(const Duration(days: 28));
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.monthly:
          endDate = yesterday;
          startDate = DateTime(endDate.year - 1, endDate.month, 1);
          if (_userStartDate != null && _userStartDate!.isAfter(startDate)) {
            startDate = _userStartDate!;
          }
          break;
        case TimeRange.custom:
          // Custom date is handled separately via _loadBarGraphDataForSingleDate
          return;
      }

      // Fetch raw data from backend
      final backendData = await ProgressDataService.fetchRawBackendData(
        widget.usernameOrEmail,
        DateRange(startDate, endDate),
      );

      final rawCaloriesData = backendData['calories'] as List<dynamic>? ?? [];
      final caloriesList =
          rawCaloriesData.map((e) => e as Map<String, dynamic>).toList();

      // Aggregate based on time range
      List<GraphDataPoint> aggregatedData;
      switch (_selectedTimeRange) {
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
          // Custom date is handled separately via _loadBarGraphDataForSingleDate
          aggregatedData = [];
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

  void _onCustomDateSelected(DateTime date) {
    setState(() {
      _customSelectedDate = date;
    });
    // Load both progress data (for goal) and bar graph data
    _loadProgressData(forceRefresh: true);
    _loadBarGraphDataForSingleDate(date);
  }

  /// Load bar graph data for a single selected date (meal breakdown)
  Future<void> _loadBarGraphDataForSingleDate(DateTime date) async {
    try {
      setState(() {
        _isLoadingBarGraph = true;
      });

      // Fetch raw data for single date (same date for start and end)
      final backendData = await ProgressDataService.fetchRawBackendData(
        widget.usernameOrEmail,
        DateRange(date, date),
      );

      final rawCaloriesData = backendData['calories'] as List<dynamic>? ?? [];
      final caloriesList =
          rawCaloriesData.map((e) => e as Map<String, dynamic>).toList();

      // Process for meal breakdown
      final processedData = _processMealData(caloriesList, date);

      if (!mounted) return;
      setState(() {
        _barGraphData = processedData;
        _isLoadingBarGraph = false;
      });
    } catch (e) {
      debugPrint('Error loading single date data: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingBarGraph = false;
      });
    }
  }

  /// Process raw data into meal breakdown (Breakfast, Lunch, Dinner, Snacks)
  List<GraphDataPoint> _processMealData(
    List<Map<String, dynamic>> rawData,
    DateTime date,
  ) {
    // Initialize meal map
    final Map<String, double> mealCalories = {
      'Breakfast': 0.0,
      'Lunch': 0.0,
      'Dinner': 0.0,
      'Snacks': 0.0,
      'Other': 0.0,
    };

    // Process raw data
    for (var entry in rawData) {
      final calories = (entry['calories'] as num?)?.toDouble() ?? 0.0;
      final mealType = (entry['meal_type'] as String?)?.trim() ?? 'Other';

      // Normalize meal type
      final normalizedMeal = _normalizeMealType(mealType);
      mealCalories[normalizedMeal] =
          (mealCalories[normalizedMeal] ?? 0.0) + calories;
    }

    // Create GraphDataPoint for each meal (only if has calories)
    final List<GraphDataPoint> result = [];
    final mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Other'];

    for (final meal in mealOrder) {
      final calories = mealCalories[meal] ?? 0.0;
      if (calories > 0 || result.isEmpty) {
        // Include at least one bar
        result.add(
          GraphDataPoint(
            date: date,
            value: calories,
            label: meal,
            metadata: {'meal_type': meal, 'calories': calories},
          ),
        );
      }
    }

    // If no data at all, return empty list (will show "No data" message)
    if (result.isEmpty || result.every((point) => point.value == 0)) {
      return [];
    }

    return result;
  }

  /// Normalize meal type to standard names
  /// "Other" includes: unspecified, unknown, or custom meal types that don't match standard categories
  String _normalizeMealType(String mealType) {
    final lower = mealType.toLowerCase().trim();
    if (lower.isEmpty || lower == 'unspecified' || lower == 'unknown') {
      return 'Other';
    }
    if (lower.contains('breakfast')) return 'Breakfast';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('dinner') || lower.contains('supper')) return 'Dinner';
    if (lower.contains('snack')) return 'Snacks';
    return 'Other'; // Any other meal type (e.g., "Brunch", "Dessert", custom types)
  }

  void _onTimeRangeChanged(TimeRange timeRange) {
    setState(() {
      _selectedTimeRange = timeRange;
      // Reset custom date when switching away from Custom
      if (timeRange != TimeRange.custom) {
        _customSelectedDate = null;
      }
    });
    _loadProgressData(forceRefresh: true);
  }

  Future<void> _onRefresh() async {
    await _loadProgressData(forceRefresh: true);
    await _loadStreakData();
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
          debugPrint(
            '✅ Found calories streak: ${_caloriesStreak!.currentStreak} days',
          );
        } catch (e) {
          _caloriesStreak = null;
          debugPrint('ℹ️ No calories streak found');
        }

        try {
          _exerciseStreak = streaks.firstWhere(
            (s) => s.streakType.toLowerCase() == 'exercise',
          );
          debugPrint(
            '✅ Found exercise streak: ${_exerciseStreak!.currentStreak} days',
          );
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
    _navigateToAddData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.help_outline, color: Colors.white),
        onPressed: _showProgressInstructions,
      ),
      title: const Text(
        'Your Progress',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.trending_up, color: Colors.white),
          onPressed: _onRefresh,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeRangeSelector(),
            const SizedBox(height: 16),

            // Custom date picker and bar graph (only when Custom is selected)
            if (_selectedTimeRange == TimeRange.custom) ...[
              SingleDatePicker(
                selectedDate: _customSelectedDate,
                minDate: _userStartDate,
                maxDate: _maxEndDate,
                onDateSelected: _onCustomDateSelected,
                primaryColor: _primaryColor,
              ),
              // Bar graph card (only for Custom when date is selected)
              if (_customSelectedDate != null) ...[
                const SizedBox(height: 16),
                _buildBarGraphCard(),
              ],
            ],

            // Progress content (only show for multi-day views, not Custom)
            if (_selectedTimeRange != TimeRange.custom) ...[
              const SizedBox(height: 16),
              _buildProgressContent(),
              const SizedBox(height: AppDesignSystem.spaceMD),
            ],
            // Streak card - only show for Daily view
            if (_selectedTimeRange == TimeRange.daily) ...[
              _buildStreakCard(),
              const SizedBox(height: AppDesignSystem.spaceMD),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTimeRangeButton('Daily', TimeRange.daily),
            _buildTimeRangeButton('Weekly', TimeRange.weekly),
            _buildTimeRangeButton('Monthly', TimeRange.monthly),
            _buildTimeRangeButton('Custom', TimeRange.custom),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, TimeRange timeRange) {
    final isSelected = _selectedTimeRange == timeRange;
    return GestureDetector(
      onTap: () => _onTimeRangeChanged(timeRange),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? null
                  : Border.all(color: AppDesignSystem.outline, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBarGraphCard() {
    // Get goal value - for single date, use historical goal if available
    // For multi-day views, goal is calculated for the range
    double goalValue;

    if (_selectedTimeRange == TimeRange.custom && _customSelectedDate != null) {
      // Single date: use historical goal if available, otherwise use current goal
      goalValue = _historicalGoal ?? _progressData?.calories.goal ?? 0.0;
    } else {
      goalValue = _progressData?.calories.goal ?? 0.0;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      margin: EdgeInsets.only(bottom: 16),
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

          // Statistics cards (only show for multi-day views, not single-date)
          if (_barGraphData.isNotEmpty &&
              _selectedTimeRange != TimeRange.custom) ...[
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

    // Check if this is a single date view (Custom time range)
    final isSingleDateView = _selectedTimeRange == TimeRange.custom;

    if (isSingleDateView) {
      // Single date trackback view: TOTAL, GOAL, REMAINING/OVER
      return _buildSingleDateSummaryStats(goalValue);
    } else {
      // Multi-day view: AVERAGE, CURRENT, CHANGE
      return _buildMultiDaySummaryStats(goalValue);
    }
  }

  /// Summary stats for single date trackback view
  Widget _buildSingleDateSummaryStats(double? goalValue) {
    // Calculate total calories for the selected date
    final total = _barGraphData.fold(0.0, (sum, point) => sum + point.value);

    // Get daily goal - use historical goal if available, otherwise use current goal
    double? dailyGoal;

    // Prefer historical goal for old dates
    if (_historicalGoal != null &&
        _historicalGoal! > 0 &&
        _historicalGoal! <= 5000) {
      dailyGoal = _historicalGoal;
    } else if (goalValue != null && goalValue > 0 && goalValue <= 5000) {
      dailyGoal =
          goalValue; // Already daily goal for single date (daysInRange = 1)
    } else if (goalValue != null && goalValue > 5000) {
      // If goal is too high, it might be an error - use null to hide goal card
      dailyGoal = null;
    } else {
      dailyGoal = null;
    }

    // Calculate difference
    double difference = 0.0;
    String differenceLabel = 'REMAINING';
    Color differenceColor = _primaryColor;

    if (dailyGoal != null) {
      if (total < dailyGoal) {
        // Under goal - show remaining
        difference = dailyGoal - total;
        differenceLabel = 'REMAINING';
        differenceColor = AppDesignSystem.success; // Green
      } else {
        // Over goal - show over
        difference = total - dailyGoal;
        differenceLabel = 'OVER';
        differenceColor = AppDesignSystem.error; // Red
      }
    }

    // Format date for subtitle
    final selectedDate = _customSelectedDate;
    String dateSubtitle = '';
    if (selectedDate != null) {
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
        'Dec',
      ];
      dateSubtitle = 'on ${months[selectedDate.month - 1]} ${selectedDate.day}';
    }

    // Determine if viewing an old date (not today or yesterday)
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(Duration(days: 1));
    final selectedDateOnly =
        selectedDate != null
            ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
            : null;

    final isOldDate =
        selectedDateOnly != null && (selectedDateOnly.isBefore(yesterdayDate));

    // Goal subtitle: show "current goal" for old dates, "daily target" for recent dates
    final goalSubtitle = isOldDate ? 'current goal' : 'daily target';

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            value: total,
            label: 'TOTAL',
            unit: 'cal',
            subtitle: dateSubtitle,
            color: _primaryColor,
          ),
        ),
        SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildSummaryCard(
            value: dailyGoal ?? 0.0,
            label: 'GOAL',
            unit: 'cal',
            subtitle: goalSubtitle,
            color: _primaryColor,
          ),
        ),
        SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildSummaryCard(
            value: difference,
            label: differenceLabel,
            unit: 'cal',
            subtitle: 'vs goal',
            color: differenceColor,
            showSign:
                false, // Don't show sign, label already indicates direction
          ),
        ),
      ],
    );
  }

  /// Summary stats for multi-day views (Daily, Weekly, Monthly)
  Widget _buildMultiDaySummaryStats(double? goalValue) {
    // Calculate statistics
    final values = _barGraphData.map((point) => point.value).toList();
    final average =
        values.fold(0.0, (sum, value) => sum + value) / values.length;
    final current = values.last; // Most recent value

    // Cap goal value at reasonable maximum (5,000) to prevent unrealistic change values
    // Goals above 5,000 are likely errors (weekly totals, etc.)
    final cappedGoal =
        goalValue != null && goalValue > 0 && goalValue <= 5000
            ? goalValue
            : null;

    final change =
        cappedGoal != null
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
            color:
                change >= 0 ? AppDesignSystem.success : AppDesignSystem.error,
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
    String subtitle = '',
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
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: AppDesignSystem.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatSummaryValue(double value, bool showSign) {
    final intValue = value.toInt();
    final absValue = value.abs();

    if (absValue >= 1000) {
      final thousands = absValue / 1000;
      final formatted =
          thousands >= 10
              ? thousands.toStringAsFixed(0)
              : thousands.toStringAsFixed(1);
      final sign = showSign ? (value >= 0 ? '+' : '-') : '';
      return '$sign${formatted}K';
    } else {
      final sign = showSign ? (value >= 0 ? '+' : '-') : '';
      return '$sign$intValue';
    }
  }

  String _getTimeRangeText() {
    // Use natural language for better UX
    switch (_selectedTimeRange) {
      case TimeRange.daily:
        return 'Last 7 days';
      case TimeRange.weekly:
        return 'Last 4 weeks';
      case TimeRange.monthly:
        return 'Last 12 months';
      case TimeRange.custom:
        if (_customSelectedDate != null) {
          // Format custom date
          final date = _customSelectedDate!;
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
            'Dec',
          ];
          return '${months[date.month - 1]} ${date.day}, ${date.year}';
        }
        return 'Select date';
    }
  }

  Widget _buildProgressContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_progressData == null) {
      return _buildEmptyState();
    }

    return FadeTransition(opacity: _fadeAnimation, child: _buildProgressCard());
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildLoadingMessage(),
        const SizedBox(height: 16),
        _buildSkeletonProgressCard(),
        const SizedBox(height: 16),
        _buildSkeletonMetricCards(),
      ],
    );
  }

  Widget _buildLoadingMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _lightColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _lightColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_lightColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading your progress data...',
            style: TextStyle(
              color: _lightColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonProgressCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonBox(width: 80, height: 20),
                  const SizedBox(height: 4),
                  _buildSkeletonBox(width: 60, height: 14),
                ],
              ),
              Row(
                children: [
                  _buildSkeletonBox(width: 40, height: 16),
                  const SizedBox(width: 8),
                  _buildSkeletonBox(width: 20, height: 20, isCircle: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Metric cards skeleton
          Row(
            children: [
              Expanded(child: _buildSkeletonMetricCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonMetricCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonMetricCard()),
            ],
          ),
          const SizedBox(height: 32),
          // Center icon skeleton
          Center(
            child: _buildSkeletonBox(width: 80, height: 80, isCircle: true),
          ),
          const SizedBox(height: 16),
          // Text skeleton
          Center(
            child: Column(
              children: [
                _buildSkeletonBox(width: 120, height: 18),
                const SizedBox(height: 8),
                _buildSkeletonBox(width: 200, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Button skeleton
          _buildSkeletonBox(width: double.infinity, height: 48),
        ],
      ),
    );
  }

  Widget _buildSkeletonMetricCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSkeletonBox(width: 40, height: 16),
          const SizedBox(height: 4),
          _buildSkeletonBox(width: 30, height: 12),
        ],
      ),
    );
  }

  Widget _buildSkeletonMetricCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSkeletonCard(
            child: Column(
              children: [
                _buildSkeletonBox(width: 60, height: 20),
                const SizedBox(height: 8),
                _buildSkeletonBox(width: 40, height: 14),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSkeletonCard(
            child: Column(
              children: [
                _buildSkeletonBox(width: 60, height: 20),
                const SizedBox(height: 8),
                _buildSkeletonBox(width: 40, height: 14),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSkeletonCard(
            child: Column(
              children: [
                _buildSkeletonBox(width: 60, height: 20),
                const SizedBox(height: 8),
                _buildSkeletonBox(width: 40, height: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _lightColor.withValues(alpha: 0.3),
        borderRadius:
            isCircle
                ? BorderRadius.circular(height / 2)
                : BorderRadius.circular(4),
      ),
      child: _SkeletonAnimation(
        color: _lightColor.withValues(alpha: 0.1),
        highlightColor: _lightColor.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading progress data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadProgressData(forceRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your ${_selectedMetric.name} to see your progress',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textGray),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to add data screen
                _navigateToAddData();
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
      ),
    );
  }

  Widget _buildProgressCard() {
    return BeautifulProgressCard(
      metric: _selectedMetric,
      progressData: _progressData!,
      timeRange: _selectedTimeRange,
      onRefresh: _onRefresh,
      userSex: widget.userSex,
    );
  }

  IconData _getMetricIcon() {
    switch (_selectedMetric) {
      case ProgressMetric.calories:
        return Icons.local_fire_department;
      case ProgressMetric.exercise:
        return Icons.fitness_center;
    }
  }

  Widget _buildStreakCard() {
    // Only show the calories streak; exercise streak is used for insights only.
    final streakToShow = _caloriesStreak;

    // Always show the streak card, even if no data (will show empty state)
    return StreakCard(
      streakData: streakToShow,
      userSex: widget.userSex,
      onRefresh: _onStreakRefresh,
      onLogActivity: _onLogActivity,
    );
  }

  void _navigateToAddData() {
    // Navigate to appropriate add data screen based on selected metric
    switch (_selectedMetric) {
      case ProgressMetric.calories:
        // Navigate to food logging
        break;
      case ProgressMetric.exercise:
        // Navigate to exercise logging
        break;
    }
  }

  void _showProgressInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => _ProgressInstructionsSheet(
            primaryColor: _primaryColor,
            backgroundColor: _backgroundColor,
            userSex: widget.userSex,
          ),
    );
  }
}

enum ProgressMetric { calories, exercise }

/// Professional help instructions sheet for progress tracker
class _ProgressInstructionsSheet extends StatelessWidget {
  final Color primaryColor;
  final Color backgroundColor;
  final String? userSex;

  const _ProgressInstructionsSheet({
    required this.primaryColor,
    required this.backgroundColor,
    this.userSex,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppDesignSystem.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDesignSystem.radiusXL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppDesignSystem.spaceMD),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignSystem.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDesignSystem.spaceMD),
                    Expanded(
                      child: Text(
                        'How Progress Tracker Works',
                        style: AppDesignSystem.headlineMedium.copyWith(
                          color: AppDesignSystem.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppDesignSystem.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spaceLG,
                  ),
                  children: [
                    _buildInstructionSection(
                      icon: Icons.calendar_today,
                      title: 'Time Range Modes',
                      description:
                          'Switch between Daily, Weekly, Monthly, or Custom to change how your progress is grouped and analyzed.',
                      items: [
                        'Daily: Focus on today’s totals with progress bars, goals, and remaining calories.',
                        'Weekly: Aggregates the last 7 days and unlocks the daily breakdown list with averages.',
                        'Monthly: Summarizes the last 12 months with weekly cards and daily averages.',
                        'Custom: Pick any past date (up to two days ago) for a single-day deep dive.',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.event,
                      title: 'Single-Day Trackback',
                      description:
                          'Use the Custom view to inspect any past day with detailed summaries and meal-level insights.',
                      items: [
                        'Tap the date picker to choose a day since you started logging.',
                        'Summary tiles show your total calories, the historical goal for that date, and what is remaining or over.',
                        'The meal breakdown bar chart compares Breakfast, Lunch, Dinner, and Snacks against your goal line—tap a bar for tooltips.',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.assessment,
                      title: 'Progress Cards & Breakdowns',
                      description:
                          'Progress cards adapt to each time range so you always see the most helpful metrics.',
                      items: [
                        'Daily cards include Current/Average/Goal tiles, a progress bar, and Remaining calories.',
                        'Weekly view highlights the Daily Breakdown list so you can compare each day at a glance.',
                        'Monthly view shows Weekly Breakdown cards with totals, date ranges, and progress bars.',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.local_fire_department,
                      title: 'Streak Tracker & Motivation',
                      description:
                          'Keep momentum by monitoring your streaks (available on the Daily view).',
                      items: [
                        'See your current streak, longest streak, and streak type badge.',
                        'Get motivational nudges plus context like days since you started or last broke the streak.',
                        'Use the Log Activity button when a streak ends to quickly add meals or workouts.',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.refresh,
                      title: 'Keeping Data Updated',
                      description:
                          'Fresh data keeps every chart accurate, so refresh often and log consistently.',
                      items: [
                        'Pull down anywhere on the screen or tap the refresh icon in the header to reload progress data.',
                        'Logging meals or exercises (via Start/Log buttons) updates charts, summaries, and streaks automatically.',
                        'Streaks and breakdowns refresh instantly after new entries or manual refreshes.',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceXL),
                  ],
                ),
              ),
              // Footer button
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AppDesignSystem.primaryButtonStyle(
                      primaryColor: primaryColor,
                    ),
                    child: Text(
                      'Got it',
                      style: AppDesignSystem.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionSection({
    required IconData icon,
    required String title,
    required String description,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: AppDesignSystem.cardDecoration(
        elevation: AppDesignSystem.elevationLow,
        borderRadius: AppDesignSystem.radiusLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: AppDesignSystem.spaceMD),
              Expanded(
                child: Text(
                  title,
                  style: AppDesignSystem.titleLarge.copyWith(
                    color: AppDesignSystem.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            description,
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                top: AppDesignSystem.spaceSM,
                left: AppDesignSystem.spaceMD,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.spaceMD),
                  Expanded(
                    child: Text(
                      item,
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated skeleton loading widget with shimmer effect
class _SkeletonAnimation extends StatefulWidget {
  final Color color;
  final Color highlightColor;

  const _SkeletonAnimation({required this.color, required this.highlightColor});

  @override
  State<_SkeletonAnimation> createState() => _SkeletonAnimationState();
}

class _SkeletonAnimationState extends State<_SkeletonAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [widget.color, widget.highlightColor, widget.color],
              stops:
                  [
                    _animation.value - 0.3,
                    _animation.value,
                    _animation.value + 0.3,
                  ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}
