import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';

class HistoryScreen extends StatefulWidget {
  final String usernameOrEmail;
  const HistoryScreen({super.key, required this.usernameOrEmail});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;
  String? userSex;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadUserSex();
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

  Future<void> _deleteLog(int id, Map<String, dynamic> log) async {
    await UserDatabase().deleteFoodLogById(id);
    setState(() {
      _logs = List<Map<String, dynamic>>.from(_logs);
      _logs.removeWhere((l) => l['id'] == id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Food log removed.'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await UserDatabase().saveFoodLog(
              usernameOrEmail: widget.usernameOrEmail,
              foodName: log['food_name'],
              calories: log['calories'],
              timestamp: DateTime.fromMillisecondsSinceEpoch(log['timestamp']),
              mealType: log['meal_type'] ?? 'Other',
            );
            if (!mounted) return;
            _loadLogs();
            // Pop with result to trigger dashboard refresh
            Navigator.of(context).pop('undo');
          },
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(
    List<Map<String, dynamic>> logs,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in logs) {
      final dt = DateTime.fromMillisecondsSinceEpoch(log['timestamp']);
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('History', style: TextStyle(color: primaryColor)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
        elevation: 1,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              )
              : _logs.isEmpty
              ? Center(child: Text('No food logs yet.'))
              : ListView.builder(
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
                        (log) => Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.restaurant,
                              color: primaryColor,
                            ),
                            title: Text(
                              log['food_name'] ?? '',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${log['meal_type'] ?? 'Meal'} • ${log['calories']} kcal',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: Text('Remove food log?'),
                                        content: Text(
                                          'Are you sure you want to remove this food log?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: Text(
                                              'Remove',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true) {
                                  _deleteLog(log['id'] as int, log);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}
