import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

/// Single date picker widget for selecting a specific date to view
class SingleDatePicker extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Function(DateTime date) onDateSelected;
  final Color primaryColor;

  const SingleDatePicker({
    super.key,
    this.selectedDate,
    this.minDate,
    this.maxDate,
    required this.onDateSelected,
    required this.primaryColor,
  });

  @override
  State<SingleDatePicker> createState() => _SingleDatePickerState();
}

class _SingleDatePickerState extends State<SingleDatePicker>
    with SingleTickerProviderStateMixin {
  late DateTime? _selectedDate;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
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
  void didUpdateWidget(SingleDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // Calculate valid date range
    final minDate = widget.minDate ?? DateTime(2020);
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
    
    // Calculate safe initial date
    DateTime safeInitialDate;
    if (_selectedDate != null && 
        !_selectedDate!.isBefore(firstDate) && 
        !_selectedDate!.isAfter(lastDate)) {
      safeInitialDate = _selectedDate!;
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
        _selectedDate = picked;
        _errorMessage = null;
      });
      _validateAndView();
    }
  }

  void _validateAndView() {
    if (_selectedDate == null) {
      return;
    }

    // Validate: date must be >= min date
    if (widget.minDate != null && _selectedDate!.isBefore(widget.minDate!)) {
      setState(() {
        _errorMessage =
            'Date cannot be before ${_formatDate(widget.minDate!)}';
      });
      return;
    }

    // Validate: date must be <= max date
    if (widget.maxDate != null && _selectedDate!.isAfter(widget.maxDate!)) {
      setState(() {
        _errorMessage =
            'Date cannot be after ${_formatDate(widget.maxDate!)}';
      });
      return;
    }

    // All validations passed
    setState(() {
      _errorMessage = null;
    });
    widget.onDateSelected(_selectedDate!);
  }

  void _viewDate() {
    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select a date';
      });
      return;
    }
    _validateAndView();
  }

  void _cancel() {
    setState(() {
      _selectedDate = widget.selectedDate;
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
                'Select Date to View',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.onSurface,
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceMD),
              // Date field
              _buildDateField(
                label: 'Date',
                date: _selectedDate,
                onTap: () => _selectDate(context),
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
                    onPressed: _errorMessage == null && _selectedDate != null
                        ? _viewDate
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
                      'View',
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
                        : 'Select date',
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

