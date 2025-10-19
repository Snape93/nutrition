import 'package:flutter/material.dart';
import '../theme_service.dart';

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

class _ProgressScreenState extends State<ProgressScreen> {
  int _selectedTimeRange = 0; // 0: Daily, 1: Weekly, 2: Monthly, 3: Custom
  final List<String> _timeRanges = ['Daily', 'Weekly', 'Monthly', 'Custom'];

  // Weight tracking data
  double currentWeight = 0.0;
  double averageWeight = 0.0;
  double goalWeight = 0.0;
  bool hasWeightData = false;

  // Metric management
  int _selectedMetricIndex = 0;
  final List<MetricData> _availableMetrics = [
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
      id: 'water',
      name: 'Water Intake',
      icon: Icons.water_drop,
      currentValue: 0,
      goalValue: 2000,
      unit: 'ml',
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

  // Time range data
  DateTime _selectedDate = DateTime.now();
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  Color get _primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get _backgroundColor => ThemeService.getBackgroundColor(widget.userSex);

  @override
  void initState() {
    super.initState();
    _loadWeightData();
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
      _updateTimeRange();
    });
  }

  void _updateTimeRange() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case 0: // Daily
        _selectedDate = now;
        _customStartDate = null;
        _customEndDate = null;
        break;
      case 1: // Weekly
        _selectedDate = now;
        _customStartDate = now.subtract(Duration(days: now.weekday - 1));
        _customEndDate = _customStartDate!.add(Duration(days: 6));
        break;
      case 2: // Monthly
        _selectedDate = now;
        _customStartDate = DateTime(now.year, now.month, 1);
        _customEndDate = DateTime(now.year, now.month + 1, 0);
        break;
      case 3: // Custom
        _showCustomDateRangeDialog();
        break;
    }
  }

  void _showCustomDateRangeDialog() {
    // Reset custom dates if they're invalid
    final now = DateTime.now();
    if (_customStartDate != null && _customStartDate!.isAfter(now)) {
      _customStartDate = null;
    }
    if (_customEndDate != null && _customEndDate!.isAfter(now)) {
      _customEndDate = null;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Custom Date Range'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Start Date'),
                  subtitle: Text(
                    _customStartDate?.toString().split(' ')[0] ??
                        'Not selected',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final initialDate = _customStartDate ?? now;
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initialDate.isAfter(now) ? now : initialDate,
                      firstDate: DateTime(2020),
                      lastDate: now,
                    );
                    if (date != null) {
                      setState(() {
                        _customStartDate = date;
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text('End Date'),
                  subtitle: Text(
                    _customEndDate?.toString().split(' ')[0] ?? 'Not selected',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final initialDate = _customEndDate ?? now;
                    final firstDate = _customStartDate ?? DateTime(2020);
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initialDate.isAfter(now) ? now : initialDate,
                      firstDate: firstDate,
                      lastDate: now,
                    );
                    if (date != null) {
                      setState(() {
                        _customEndDate = date;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_customStartDate != null && _customEndDate != null) {
                    // Validate that end date is not before start date
                    if (_customEndDate!.isBefore(_customStartDate!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('End date must be after start date'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _loadDataForTimeRange();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select both start and end dates'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Text('Apply'),
              ),
            ],
          ),
    );
  }

  void _loadDataForTimeRange() {
    // TODO: Load data based on selected time range
    // This would typically fetch data from a database or API
    debugPrint(
      'Loading data for time range: ${_timeRanges[_selectedTimeRange]}',
    );
    debugPrint('Selected date: $_selectedDate');
    if (_customStartDate != null && _customEndDate != null) {
      debugPrint('Custom range: $_customStartDate to $_customEndDate');
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
      case 3: // Custom
        if (_customStartDate != null && _customEndDate != null) {
          return '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}';
        }
        return 'Custom Range';
      default:
        return 'Today';
    }
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
                  SizedBox(height: 20),

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
