import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';
import '../services/streak_service.dart';
import '../models/graph_models.dart';
import '../models/streak_model.dart';
import '../widgets/beautiful_progress_card.dart';
import '../widgets/streak_card.dart';
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
  ProgressMetric _selectedMetric = ProgressMetric.calories;

  // Time range selection
  TimeRange _selectedTimeRange = TimeRange.daily;

  // Progress data
  ProgressData? _progressData;
  bool _isLoading = false;
  String? _errorMessage;

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
    _setupAnimations();
    _loadProgressData();
    _loadStreakData();
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: _selectedTimeRange,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _progressData = progressData;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load progress data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onMetricChanged(ProgressMetric metric) {
    setState(() {
      _selectedMetric = metric;
    });
  }

  void _onTimeRangeChanged(TimeRange timeRange) {
    setState(() {
      _selectedTimeRange = timeRange;
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
            _buildMetricSelector(),
            const SizedBox(height: 16),
            _buildTimeRangeSelector(),
            const SizedBox(height: 16),
            _buildProgressContent(),
            const SizedBox(height: AppDesignSystem.spaceMD),
            _buildStreakCard(),
            const SizedBox(height: AppDesignSystem.spaceMD),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricButton(
            metric: ProgressMetric.calories,
            icon: Icons.local_fire_department,
            label: 'Calories',
            isSelected: _selectedMetric == ProgressMetric.calories,
          ),
          const SizedBox(width: 12),
          _buildMetricButton(
            metric: ProgressMetric.exercise,
            icon: Icons.fitness_center,
            label: 'Exercise',
            isSelected: _selectedMetric == ProgressMetric.exercise,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricButton({
    required ProgressMetric metric,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _onMetricChanged(metric),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? _primaryColor : _lightColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _lightColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _lightColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeRangeButton('Daily', TimeRange.daily),
          _buildTimeRangeButton('Weekly', TimeRange.weekly),
          _buildTimeRangeButton('Monthly', TimeRange.monthly),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, TimeRange timeRange) {
    final isSelected = _selectedTimeRange == timeRange;
    return GestureDetector(
      onTap: () => _onTimeRangeChanged(timeRange),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? _lightColor : _textGray,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
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
      builder: (context) => _ProgressInstructionsSheet(
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
                      icon: Icons.local_fire_department,
                      title: 'Metric Selection',
                      description:
                          'Choose between Calories and Exercise to track your progress. Tap on the metric buttons at the top to switch between different tracking options.',
                      items: [
                        'Calories: Track your daily calorie intake and goals',
                        'Exercise: Monitor your workout duration and activity levels',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.calendar_today,
                      title: 'Time Range Selection',
                      description:
                          'View your progress over different time periods. Select Daily, Weekly, or Monthly to see your data aggregated accordingly.',
                      items: [
                        'Daily: See your progress for today',
                        'Weekly: View your weekly averages and trends',
                        'Monthly: Track your long-term progress and patterns',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.assessment,
                      title: 'Progress Cards',
                      description:
                          'Each progress card displays key metrics to help you understand your performance.',
                      items: [
                        'Current: Your current value for the selected metric',
                        'Average: Your average value over the selected time period',
                        'Goal: Your target value to achieve',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.show_chart,
                      title: 'Progress Visualization',
                      description:
                          'Visual charts and graphs help you understand your progress trends over time.',
                      items: [
                        'Line graphs show your progress over the selected period',
                        'Percentage indicators show how close you are to your goals',
                        'Trend indicators show whether you\'re improving or need adjustment',
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spaceLG),
                    _buildInstructionSection(
                      icon: Icons.add_circle_outline,
                      title: 'Tracking Your Progress',
                      description:
                          'To see your progress, make sure to log your activities regularly.',
                      items: [
                        'Log meals to track calorie intake',
                        'Record exercises to track workout duration',
                        'Data updates automatically as you log activities',
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
          ...items.map((item) => Padding(
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
              )),
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
