import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

/// Custom date range picker widget for selecting start and end dates
class CustomDateRangePicker extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Function(DateTime start, DateTime end) onDateRangeSelected;
  final Color primaryColor;

  const CustomDateRangePicker({
    super.key,
    this.startDate,
    this.endDate,
    this.minDate,
    this.maxDate,
    required this.onDateRangeSelected,
    required this.primaryColor,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker>
    with SingleTickerProviderStateMixin {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(CustomDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startDate != oldWidget.startDate) {
      _startDate = widget.startDate;
    }
    if (widget.endDate != oldWidget.endDate) {
      _endDate = widget.endDate;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    // Calculate valid date range
    final minDate = widget.minDate ?? DateTime(2020);
    final maxDate = widget.maxDate ?? DateTime.now().subtract(const Duration(days: 1));
    
    // Ensure firstDate <= lastDate
    final firstDate = minDate;
    final lastDate = maxDate.isAfter(minDate) ? maxDate : minDate;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? (lastDate.isAfter(minDate) ? lastDate.subtract(const Duration(days: 6)) : minDate),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-set end date to yesterday (maxDate) if not set or if it's before the new start date
        final maxDate = widget.maxDate ?? DateTime.now().subtract(const Duration(days: 1));
        if (_endDate == null || _endDate!.isBefore(picked)) {
          // Set end date to maxDate (yesterday) only if it's after the start date
          // If maxDate is before or equal to start date, we can't auto-fill (user must select manually)
          if (maxDate.isAfter(picked)) {
            _endDate = maxDate;
          } else {
            // Can't auto-fill - maxDate is before or equal to start date
            _endDate = null;
          }
        }
        _errorMessage = null;
        _validateAndApply();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    // Calculate valid date range
    final minDate = _startDate ?? widget.minDate ?? DateTime(2020);
    final maxDate = widget.maxDate ?? DateTime.now().subtract(const Duration(days: 1));
    
    // Ensure firstDate <= lastDate
    final firstDate = minDate;
    final lastDate = maxDate.isAfter(minDate) ? maxDate : minDate;
    
    // If lastDate is before firstDate, we can't show the picker
    if (lastDate.isBefore(firstDate)) {
      setState(() {
        _errorMessage = 'No valid date range available. Please check your date constraints.';
      });
      return;
    }
    
    // Calculate safe initial date - must be between firstDate and lastDate
    DateTime safeInitialDate;
    if (_endDate != null && _endDate!.isAfter(firstDate.subtract(const Duration(days: 1))) && 
        !_endDate!.isAfter(lastDate)) {
      safeInitialDate = _endDate!;
    } else {
      // Default to lastDate if it's valid, otherwise firstDate
      safeInitialDate = lastDate.isAfter(firstDate) ? lastDate : firstDate;
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _errorMessage = null;
        _validateAndApply();
      });
    }
  }

  void _validateAndApply() {
    if (_startDate == null || _endDate == null) {
      return;
    }

    // Validate: end date must be >= start date
    if (_endDate!.isBefore(_startDate!)) {
      setState(() {
        _errorMessage = 'End date must be after start date';
      });
      return;
    }

    // Validate: range must be 2-90 days
    final daysDiff = _endDate!.difference(_startDate!).inDays;
    if (daysDiff < 2) {
      setState(() {
        _errorMessage = 'Date range must be at least 2 days';
      });
      return;
    }
    if (daysDiff > 90) {
      setState(() {
        _errorMessage = 'Date range cannot exceed 90 days';
      });
      return;
    }

    // Validate: start date must be >= min date
    if (widget.minDate != null && _startDate!.isBefore(widget.minDate!)) {
      setState(() {
        _errorMessage =
            'Start date cannot be before ${_formatDate(widget.minDate!)}';
      });
      return;
    }

    // Validate: end date must be <= max date
    if (widget.maxDate != null && _endDate!.isAfter(widget.maxDate!)) {
      setState(() {
        _errorMessage =
            'End date cannot be after ${_formatDate(widget.maxDate!)}';
      });
      return;
    }

    // All validations passed
    setState(() {
      _errorMessage = null;
    });
    widget.onDateRangeSelected(_startDate!, _endDate!);
  }

  void _applyDateRange() {
    // Auto-set end date to yesterday if only start date is selected
    if (_startDate != null && _endDate == null) {
      final maxDate = widget.maxDate ?? DateTime.now().subtract(const Duration(days: 1));
      if (maxDate.isAfter(_startDate!)) {
        setState(() {
          _endDate = maxDate;
        });
      } else {
        setState(() {
          _errorMessage = 'Please select an end date';
        });
        return;
      }
    }
    
    if (_startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Please select a start date';
      });
      return;
    }
    _validateAndApply();
  }

  void _cancel() {
    setState(() {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
      _errorMessage = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: FadeTransition(
        opacity: _slideAnimation,
        child: Container(
          margin: EdgeInsets.only(
            top: AppDesignSystem.spaceMD,
            left: AppDesignSystem.spaceMD,
            right: AppDesignSystem.spaceMD,
          ),
          decoration: BoxDecoration(
            color: AppDesignSystem.surface,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(AppDesignSystem.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custom Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.onSurface,
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceMD),
              // Date fields
              isSmallScreen
                  ? Column(
                      children: [
                        _buildDateField(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: () => _selectStartDate(context),
                        ),
                        SizedBox(height: AppDesignSystem.spaceMD),
                        _buildDateField(
                          label: 'End Date',
                          date: _endDate,
                          onTap: () => _selectEndDate(context),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'Start Date',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppDesignSystem.spaceMD,
                          ),
                          child: Text(
                            'to',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppDesignSystem.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildDateField(
                            label: 'End Date',
                            date: _endDate,
                            onTap: () => _selectEndDate(context),
                          ),
                        ),
                      ],
                    ),
              // Error message
              if (_errorMessage != null) ...[
                SizedBox(height: AppDesignSystem.spaceSM),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppDesignSystem.error,
                    ),
                    SizedBox(width: AppDesignSystem.spaceXS),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppDesignSystem.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Buttons
              SizedBox(height: AppDesignSystem.spaceMD),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    style: TextButton.styleFrom(
                      foregroundColor: widget.primaryColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.spaceLG,
                        vertical: AppDesignSystem.spaceSM,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDesignSystem.radiusMD),
                        side: BorderSide(color: widget.primaryColor, width: 1),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: AppDesignSystem.spaceSM),
                  ElevatedButton(
                    onPressed: _errorMessage == null &&
                            _startDate != null
                        ? _applyDateRange
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppDesignSystem.outline,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.spaceLG,
                        vertical: AppDesignSystem.spaceSM,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDesignSystem.radiusMD),
                      ),
                    ),
                    child: Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppDesignSystem.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppDesignSystem.spaceXS),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceMD),
            decoration: BoxDecoration(
              color: AppDesignSystem.background,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              border: Border.all(
                color: AppDesignSystem.outline,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: widget.primaryColor,
                ),
                SizedBox(width: AppDesignSystem.spaceSM),
                Expanded(
                  child: Text(
                    date != null 
                        ? _formatDate(date) 
                        : (label == 'End Date' && _startDate != null 
                            ? 'Auto: Yesterday' 
                            : 'Select date'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: date != null
                          ? AppDesignSystem.onSurface
                          : AppDesignSystem.onSurfaceVariant,
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
}

