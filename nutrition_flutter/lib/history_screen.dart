import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';
import 'dart:async';

class HistoryScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? initialUserSex;
  const HistoryScreen({
    super.key,
    required this.usernameOrEmail,
    this.initialUserSex,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;
  String? userSex;
  Timer? _refreshTimer;
  bool _isSelectionMode = false;
  Set<int> _selectedLogIds = {};
  bool _isDeleting = false; // For multiple deletions
  bool _isDeletingSingle = false; // For single deletion
  int _deletingCount = 0; // Track count during deletion

  @override
  void initState() {
    super.initState();
    userSex = widget.initialUserSex;
    _loadLogs();
    _loadUserSex();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadLogs();
      }
    });
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await UserDatabase().getFoodLogs(widget.usernameOrEmail);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load history.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserSex() async {
    final sex = await UserDatabase().getUserSex(widget.usernameOrEmail);
    setState(() {
      userSex = sex;
    });
  }

  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  // Phase detection logic
  String getFoodLogPhase(Map<String, dynamic> log) {
    final phase = log['phase'] as String?;
    return phase ?? 'deletable'; // Default to deletable if phase not available
  }

  bool canDeleteFoodLog(Map<String, dynamic> log) {
    final canDelete = log['can_delete'] as bool?;
    return canDelete ?? true; // Default to true if not available
  }

  String getTimeRemaining(Map<String, dynamic> log) {
    final timeRemaining = log['time_remaining'];
    if (timeRemaining == null) return '';

    // Handle both int and double types safely
    double timeValue;
    if (timeRemaining is int) {
      timeValue = timeRemaining.toDouble();
    } else if (timeRemaining is double) {
      timeValue = timeRemaining;
    } else {
      return '';
    }

    final minutes = timeValue.toInt();
    final seconds = ((timeValue - minutes) * 60).toInt();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double getProgressPercentage(Map<String, dynamic> log) {
    final progress = log['progress_percentage'];
    if (progress == null) return 0.0;

    // Handle both int and double types safely
    if (progress is int) {
      return progress.toDouble();
    } else if (progress is double) {
      return progress;
    } else {
      return 0.0;
    }
  }

  Color getPhaseColor(String phase) {
    switch (phase) {
      case 'restricted':
        return Colors.orange.withValues(alpha: 0.7);
      case 'deletable':
        return Colors.amber.withValues(alpha: 0.7);
      case 'auto_removed':
        return Colors.grey.withValues(alpha: 0.5);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  IconData getPhaseIcon(String phase) {
    switch (phase) {
      case 'restricted':
        return Icons.lock;
      case 'deletable':
        return Icons.warning;
      case 'auto_removed':
        return Icons.delete;
      default:
        return Icons.restaurant;
    }
  }

  Future<void> _deleteLog(int id, Map<String, dynamic> log) async {
    // Show loading state
    if (!mounted) return;
    setState(() {
      _isDeletingSingle = true;
    });

    try {
      await UserDatabase().deleteFoodLogById(id);
      
      if (!mounted) return;
      setState(() {
        _isDeletingSingle = false;
        _logs = List<Map<String, dynamic>>.from(_logs);
        _logs.removeWhere((l) => l['id'] == id);
      });

      // Show success dialog
      if (mounted) {
        _showDeleteSuccessDialog(1, log['food_name'] as String? ?? 'Food log');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeletingSingle = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete food log. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLogIds.clear();
      }
    });
  }

  void _toggleLogSelection(int logId, bool canDelete) {
    if (!canDelete) return;
    setState(() {
      if (_selectedLogIds.contains(logId)) {
        _selectedLogIds.remove(logId);
      } else {
        _selectedLogIds.add(logId);
      }
    });
  }

  void _selectAllDeletable() {
    setState(() {
      _selectedLogIds.clear();
      for (final log in _logs) {
        if (canDeleteFoodLog(log)) {
          final logId = log['id'] as int?;
          if (logId != null) {
            _selectedLogIds.add(logId);
          }
        }
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedLogIds.clear();
    });
  }

  Future<void> _deleteSelectedLogs() async {
    if (_selectedLogIds.isEmpty || _isDeleting) return;

    final count = _selectedLogIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Items?'),
        content: Text(
          'Are you sure you want to delete $count food log${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
        _deletingCount = count;
      });

      try {
        // Delete all selected logs
        for (final logId in _selectedLogIds) {
          await UserDatabase().deleteFoodLogById(logId);
        }

        if (!mounted) return;
        setState(() {
          _isDeleting = false;
          _deletingCount = 0;
          _selectedLogIds.clear();
          _isSelectionMode = false;
        });
        _loadLogs();

        // Show success dialog
        if (mounted) {
          _showDeleteSuccessDialog(count, null);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isDeleting = false;
          _deletingCount = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete items. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(
    List<Map<String, dynamic>> logs,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in logs) {
      // Use current date since timestamp is not available in API response
      final dt = DateTime.now();
      final dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateStr, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isVerySmallScreen = MediaQuery.of(context).size.height < 600;
    final groupedLogs = _groupLogsByDate(_logs);
    final sortedDates =
        groupedLogs.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // newest first

    Widget content;
    if (_error != null) {
      content = Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else if (_logs.isEmpty) {
      content = Center(
        child: Text(
          _isLoading ? 'Loading history…' : 'No food logs yet.',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      content = ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 8 : 16,
          vertical: isVerySmallScreen ? 8 : 16,
        ),
        itemCount: sortedDates.length,
        itemBuilder: (context, i) {
          final date = sortedDates[i];
          final logs = groupedLogs[date]!;
          final dt = DateTime.parse(date);
          final today = DateTime.now();
          String dateLabel;
          if (dt.year == today.year &&
              dt.month == today.month &&
              dt.day == today.day) {
            dateLabel = 'Today';
          } else {
            dateLabel = '${dt.year}/${dt.month}/${dt.day}';
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isVerySmallScreen ? 15 : 18,
                    color: primaryColor,
                  ),
                ),
              ),
              ...logs.map(
                (log) => _buildFoodLogCard(
                  log,
                  isVerySmallScreen,
                  isSelected: _isSelectionMode &&
                      _selectedLogIds.contains(log['id']),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedLogIds.length} selected',
                style: TextStyle(color: primaryColor),
              )
            : Text('History', style: TextStyle(color: primaryColor)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
        elevation: 1,
        actions: _isSelectionMode
            ? [
                if (_selectedLogIds.length <
                    _logs.where((log) => canDeleteFoodLog(log)).length)
                  IconButton(
                    icon: Icon(Icons.select_all, color: primaryColor),
                    onPressed: _selectAllDeletable,
                    tooltip: 'Select all',
                  ),
                if (_selectedLogIds.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.deselect, color: primaryColor),
                    onPressed: _deselectAll,
                    tooltip: 'Deselect all',
                  ),
                IconButton(
                  icon: Icon(Icons.close, color: primaryColor),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Cancel',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.checklist, color: primaryColor),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Select items',
                ),
              ],
      ),
      body: Stack(
        children: [
          content,
          // Centered loading overlay for single deletion
          if (_isDeletingSingle)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Deleting food log...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Centered loading overlay for multiple deletions
          if (_isDeleting && _deletingCount > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Deleting $_deletingCount item${_deletingCount > 1 ? 's' : ''}...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: backgroundColor.withValues(alpha: 0.6),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode && _selectedLogIds.isNotEmpty
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedLogIds.length} item${_selectedLogIds.length > 1 ? 's' : ''} selected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    _isDeleting
                        ? Container(
                            width: 120,
                            height: 48,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primaryColor,
                              ),
                              strokeWidth: 3,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _deleteSelectedLogs,
                            icon: Icon(Icons.delete, color: Colors.white),
                            label: Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFoodLogCard(
    Map<String, dynamic> log,
    bool isVerySmallScreen, {
    bool isSelected = false,
  }) {
    final phase = getFoodLogPhase(log);
    final canDelete = canDeleteFoodLog(log);
    final timeRemaining = getTimeRemaining(log);
    final progressPercentage = getProgressPercentage(log);
    final phaseColor = getPhaseColor(phase);
    final phaseIcon = getPhaseIcon(phase);
    final logId = log['id'] as int?;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: phase == 'restricted' ? 2 : 1,
      color: _isSelectionMode && isSelected
          ? primaryColor.withValues(alpha: 0.1)
          : phase == 'restricted'
              ? phaseColor.withValues(alpha: 0.1)
              : Colors.white,
      shape: _isSelectionMode && isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: primaryColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        children: [
          ListTile(
            leading: _isSelectionMode && canDelete
                ? Checkbox(
                    value: isSelected,
                    onChanged: logId != null
                        ? (value) => _toggleLogSelection(logId, canDelete)
                        : null,
                    activeColor: primaryColor,
                  )
                : Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: phaseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(phaseIcon, color: Colors.white, size: 20),
                  ),
            title: Text(
              log['food_name'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: phase == 'restricted' ? Colors.grey[700] : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['meal_type'] ?? 'Meal'} • ${log['calories']} kcal',
                  style: TextStyle(
                    color:
                        phase == 'restricted'
                            ? Colors.grey[600]
                            : Colors.grey[700],
                  ),
                ),
                if (phase == 'restricted' && timeRemaining.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Can delete in $timeRemaining',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (phase == 'deletable')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.amber[700]),
                        SizedBox(width: 4),
                        Text(
                          'Disappears in 1 hour',
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: _isSelectionMode
                ? null
                : canDelete
                    ? IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(log),
                      )
                    : Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lock,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
            onTap: _isSelectionMode && canDelete && logId != null
                ? () => _toggleLogSelection(logId, canDelete)
                : null,
          ),
          if (phase == 'restricted' || phase == 'deletable')
            Container(
              height: 4,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(
                value: progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Remove food log?'),
            content: Text('Are you sure you want to remove this food log?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final logId = log['id'];
      if (logId != null) {
        _deleteLog(logId as int, log);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot delete: Missing log ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDeleteSuccessDialog(int count, String? foodName) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: primaryColor,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                count == 1
                    ? 'Food Log Deleted Successfully!'
                    : 'Food Logs Deleted Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Info container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    if (count == 1 && foodName != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              foodName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          count == 1
                              ? '1 item removed'
                              : '$count items removed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Message
              Text(
                count == 1
                    ? 'The food log has been permanently removed from your history.'
                    : 'The selected food logs have been permanently removed from your history.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
