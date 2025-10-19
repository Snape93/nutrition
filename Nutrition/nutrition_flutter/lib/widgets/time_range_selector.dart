import 'package:flutter/material.dart';
import '../models/graph_models.dart';

/// Professional time range selector with modern segmented control design
class TimeRangeSelector extends StatefulWidget {
  final TimeRange selectedRange;
  final Function(TimeRange) onRangeSelected;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Function(DateTime, DateTime)? onCustomRangeSelected;

  const TimeRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
    this.customStartDate,
    this.customEndDate,
    this.onCustomRangeSelected,
  });

  @override
  State<TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends State<TimeRangeSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSegmentedControl(),
            if (widget.selectedRange == TimeRange.custom) ...[
              const SizedBox(height: 12),
              _buildCustomDateRange(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: ProfessionalColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfessionalColors.outline, width: 1),
      ),
      child: Row(
        children: [
          _buildTimeRangeButton('Daily', TimeRange.daily),
          _buildTimeRangeButton('Weekly', TimeRange.weekly),
          _buildTimeRangeButton('Monthly', TimeRange.monthly),
          _buildTimeRangeButton('Custom', TimeRange.custom),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, TimeRange range) {
    final isSelected = range == widget.selectedRange;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onRangeSelected(range),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? ProfessionalColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? ProfessionalColors.onSurface
                        : ProfessionalColors.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateRange() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfessionalColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfessionalColors.outline, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.date_range, size: 20, color: ProfessionalColors.info),
              const SizedBox(width: 8),
              Text(
                'Custom Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ProfessionalColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  widget.customStartDate,
                  (date) => _onStartDateChanged(date),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  widget.customEndDate,
                  (date) => _onEndDateChanged(date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canApplyCustomRange() ? _applyCustomRange : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfessionalColors.info,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Apply Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ProfessionalColors.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(onChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: ProfessionalColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ProfessionalColors.outline, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ProfessionalColors.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          date != null
                              ? ProfessionalColors.onSurface
                              : ProfessionalColors.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectDate(Function(DateTime) onChanged) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ProfessionalColors.info,
              onPrimary: Colors.white,
              surface: ProfessionalColors.surface,
              onSurface: ProfessionalColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      onChanged(date);
    }
  }

  void _onStartDateChanged(DateTime date) {
    setState(() {
      // Update the custom start date
    });
  }

  void _onEndDateChanged(DateTime date) {
    setState(() {
      // Update the custom end date
    });
  }

  bool _canApplyCustomRange() {
    return widget.customStartDate != null &&
        widget.customEndDate != null &&
        widget.customStartDate!.isBefore(widget.customEndDate!);
  }

  void _applyCustomRange() {
    if (widget.onCustomRangeSelected != null &&
        widget.customStartDate != null &&
        widget.customEndDate != null) {
      widget.onCustomRangeSelected!(
        widget.customStartDate!,
        widget.customEndDate!,
      );
    }
  }
}

/// Helper class for time range utilities
class TimeRangeUtils {
  /// Get the start date for a given time range
  static DateTime getStartDate(TimeRange range, {DateTime? customStart}) {
    final now = DateTime.now();

    switch (range) {
      case TimeRange.daily:
        return DateTime(now.year, now.month, now.day);
      case TimeRange.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case TimeRange.monthly:
        return DateTime(now.year, now.month, 1);
      case TimeRange.custom:
        return customStart ?? now;
    }
  }

  /// Get the end date for a given time range
  static DateTime getEndDate(TimeRange range, {DateTime? customEnd}) {
    final now = DateTime.now();

    switch (range) {
      case TimeRange.daily:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case TimeRange.weekly:
        final endOfWeek = now.add(Duration(days: 7 - now.weekday));
        return DateTime(
          endOfWeek.year,
          endOfWeek.month,
          endOfWeek.day,
          23,
          59,
          59,
        );
      case TimeRange.monthly:
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(days: 1));
      case TimeRange.custom:
        return customEnd ?? now;
    }
  }

  /// Get the display label for a time range
  static String getDisplayLabel(TimeRange range) {
    switch (range) {
      case TimeRange.daily:
        return 'Today';
      case TimeRange.weekly:
        return 'This Week';
      case TimeRange.monthly:
        return 'This Month';
      case TimeRange.custom:
        return 'Custom Range';
    }
  }

  /// Get the number of days in a time range
  static int getDaysInRange(TimeRange range) {
    final start = getStartDate(range);
    final end = getEndDate(range);
    return end.difference(start).inDays + 1;
  }
}
