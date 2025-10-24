import 'package:flutter/material.dart';
import '../services/progress_data_service.dart';
import '../models/graph_models.dart';
import '../widgets/beautiful_progress_card.dart';

/// Beautiful Progress Screen matching the new design
class BeautifulProgressScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const BeautifulProgressScreen({
    Key? key,
    required this.usernameOrEmail,
    this.userSex,
  }) : super(key: key);

  @override
  State<BeautifulProgressScreen> createState() =>
      _BeautifulProgressScreenState();
}

class _BeautifulProgressScreenState extends State<BeautifulProgressScreen> {
  // Progress metrics selection
  ProgressMetric _selectedMetric = ProgressMetric.calories;

  // Time range selection
  TimeRange _selectedTimeRange = TimeRange.daily;

  // Progress data
  ProgressData? _progressData;
  bool _isLoading = false;
  String? _errorMessage;

  // Color scheme matching the design
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _lightGreen = Color(0xFF4CAF50);
  static const Color _backgroundGreen = Color(0xFFE8F5E8);
  static const Color _textGray = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _loadProgressData();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundGreen,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryGreen,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricButton(
            metric: ProgressMetric.calories,
            icon: Icons.local_fire_department,
            label: 'Calories',
            isSelected: _selectedMetric == ProgressMetric.calories,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricButton(
            metric: ProgressMetric.exercise,
            icon: Icons.fitness_center,
            label: 'Exercise',
            isSelected: _selectedMetric == ProgressMetric.exercise,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricButton(
            metric: ProgressMetric.water,
            icon: Icons.water_drop,
            label: 'Water',
            isSelected: _selectedMetric == ProgressMetric.water,
          ),
        ),
      ],
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
          color: isSelected ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? _primaryGreen : _lightGreen,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _lightGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _lightGreen,
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
          _buildTimeRangeButton('Custom', TimeRange.custom),
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
          color: isSelected ? _lightGreen : _textGray,
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

    return _buildProgressCard();
  }

  Widget _buildLoadingState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_lightGreen),
        ),
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
              backgroundColor: _primaryGreen,
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
              color: _lightGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getMetricIcon(), color: _lightGreen, size: 40),
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
      ),
    );
  }

  Widget _buildProgressCard() {
    return BeautifulProgressCard(
      metric: _selectedMetric,
      progressData: _progressData!,
      timeRange: _selectedTimeRange,
      onRefresh: _onRefresh,
    );
  }

  IconData _getMetricIcon() {
    switch (_selectedMetric) {
      case ProgressMetric.calories:
        return Icons.local_fire_department;
      case ProgressMetric.exercise:
        return Icons.fitness_center;
      case ProgressMetric.water:
        return Icons.water_drop;
    }
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
      case ProgressMetric.water:
        // Navigate to water logging
        break;
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Home', false),
          _buildNavItem(Icons.fitness_center, 'Exercise', false),
          _buildNavItem(Icons.add, '', true), // Central plus button
          _buildNavItem(Icons.bar_chart, 'Progress', true), // Current screen
          _buildNavItem(Icons.more_horiz, 'More', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    if (label.isEmpty) {
      // Central plus button
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: _primaryGreen, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isSelected ? _lightGreen : _textGray, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? _lightGreen : _textGray,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

enum ProgressMetric { calories, exercise, water }
