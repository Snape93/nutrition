import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/graph_models.dart';
import 'time_range_selector.dart';

/// Professional graph card with modern design and interactive features
class ProfessionalGraphCard extends StatefulWidget {
  final GraphConfig config;
  final List<GraphDataPoint> data;
  final GraphStatistics statistics;
  final Function()? onRefresh;
  final bool isLoading;
  final String? userGender;

  const ProfessionalGraphCard({
    super.key,
    required this.config,
    required this.data,
    required this.statistics,
    this.onRefresh,
    this.isLoading = false,
    this.userGender,
  });

  @override
  State<ProfessionalGraphCard> createState() => _ProfessionalGraphCardState();
}

class _ProfessionalGraphCardState extends State<ProfessionalGraphCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Use WidgetsBinding to ensure the animation starts after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = GraphMetadata.fromType(
      widget.config.type,
      widget.userGender,
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: ProfessionalColors.outline, width: 1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ProfessionalColors.surface,
                        ProfessionalColors.background,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildGraphHeader(metadata),
                      _buildInteractiveChart(metadata),
                      _buildGraphFooter(metadata),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGraphHeader(GraphMetadata metadata) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ProfessionalColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeRangeUtils.getDisplayLabel(widget.config.timeRange),
                    style: TextStyle(
                      fontSize: 12,
                      color: ProfessionalColors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.statistics.changePercentage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.statistics.trendColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.statistics.trendIcon,
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.statistics.changePercentage!.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.statistics.trendColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onRefresh != null)
                    IconButton(
                      onPressed: widget.onRefresh,
                      icon: Icon(
                        Icons.refresh,
                        color: ProfessionalColors.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCards(metadata),
        ],
      ),
    );
  }

  Widget _buildStatCards(GraphMetadata metadata) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Current',
              '${widget.statistics.currentValue.toStringAsFixed(0)}${metadata.unit}',
              metadata.color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Average',
              '${widget.statistics.averageValue.toStringAsFixed(0)}${metadata.unit}',
              ProfessionalColors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Goal',
              widget.statistics.goalValue != null
                  ? '${widget.statistics.goalValue!.toStringAsFixed(0)}${metadata.unit}'
                  : 'Not set',
              ProfessionalColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart(GraphMetadata metadata) {
    if (widget.isLoading) {
      return _buildLoadingChart();
    }

    if (widget.data.isEmpty) {
      return _buildEmptyChart(metadata);
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: _buildChart(metadata),
    );
  }

  Widget _buildLoadingChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: widget.config.primaryColor,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading chart data...',
              style: TextStyle(
                fontSize: 14,
                color: ProfessionalColors.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(GraphMetadata metadata) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: metadata.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                metadata.icon,
                size: 32,
                color: metadata.color.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No data yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ProfessionalColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your ${metadata.title.toLowerCase()} to see your progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ProfessionalColors.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to data input screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${metadata.title} tracking coming soon!'),
                    backgroundColor: metadata.color,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(Icons.add, size: 16),
              label: Text('Start Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: metadata.color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(GraphMetadata metadata) {
    switch (widget.config.style) {
      case ChartStyle.line:
        return _buildLineChart(metadata);
      case ChartStyle.bar:
        return _buildBarChart(metadata);
      case ChartStyle.area:
        return _buildAreaChart(metadata);
      case ChartStyle.combined:
        return _buildCombinedChart(metadata);
    }
  }

  Widget _buildLineChart(GraphMetadata metadata) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(),
          getDrawingHorizontalLine:
              (value) => FlLine(
                color: ProfessionalColors.outline.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget:
                  (value, meta) => _buildYAxisLabel(value, metadata),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => _buildXAxisLabel(value),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _convertToFlSpot(widget.data),
            isCurved: true,
            color: widget.config.primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: widget.config.primaryColor,
                    strokeWidth: 2,
                    strokeColor: ProfessionalColors.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: widget.config.primaryColor.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final dataPoint = widget.data[touchedSpot.spotIndex];
                return LineTooltipItem(
                  '${dataPoint.value.toStringAsFixed(0)}${metadata.unit}\n${_formatDate(dataPoint.date)}',
                  TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(GraphMetadata metadata) {
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(),
          getDrawingHorizontalLine:
              (value) => FlLine(
                color: ProfessionalColors.outline.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget:
                  (value, meta) => _buildYAxisLabel(value, metadata),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => _buildXAxisLabel(value),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _convertToBarChartGroupData(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dataPoint = widget.data[groupIndex];
              return BarTooltipItem(
                '${dataPoint.value.toStringAsFixed(0)}${metadata.unit}\n${_formatDate(dataPoint.date)}',
                TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAreaChart(GraphMetadata metadata) {
    // Similar to line chart but with area fill
    return _buildLineChart(metadata);
  }

  Widget _buildCombinedChart(GraphMetadata metadata) {
    // Combined chart implementation
    return _buildLineChart(metadata);
  }

  Widget _buildGraphFooter(GraphMetadata metadata) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ProfessionalColors.background.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFooterStat('Min', widget.statistics.minValue, metadata.unit),
            const SizedBox(width: 16),
            _buildFooterStat('Max', widget.statistics.maxValue, metadata.unit),
            const SizedBox(width: 16),
            _buildFooterStat(
              'Total Points',
              widget.statistics.totalDataPoints.toDouble(),
              '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterStat(String label, double value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ProfessionalColors.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit.isEmpty
              ? value.toInt().toString()
              : '${value.toStringAsFixed(0)}$unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ProfessionalColors.onSurface,
          ),
        ),
      ],
    );
  }

  // Helper methods
  List<FlSpot> _convertToFlSpot(List<GraphDataPoint> data) {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();
  }

  List<BarChartGroupData> _convertToBarChartGroupData() {
    return widget.data.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value,
            color: widget.config.primaryColor,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();
  }

  double _calculateInterval() {
    if (widget.data.isEmpty) return 1.0;
    final maxValue = widget.data
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);
    return maxValue / 5; // 5 horizontal lines
  }

  Widget _buildYAxisLabel(double value, GraphMetadata metadata) {
    return Text(
      '${value.toInt()}${metadata.unit}',
      style: TextStyle(
        fontSize: 10,
        color: ProfessionalColors.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildXAxisLabel(double value) {
    if (value.toInt() >= widget.data.length) return const SizedBox();
    final dataPoint = widget.data[value.toInt()];
    return Text(
      _formatDateShort(dataPoint.date),
      style: TextStyle(
        fontSize: 10,
        color: ProfessionalColors.onSurface.withOpacity(0.6),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }
}
