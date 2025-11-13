import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../user_database.dart';
import '../services/custom_exercise_service.dart';
import '../services/exercise_service.dart';
import '../services/progress_data_service.dart';
import '../my_app.dart';

class YourExerciseScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? initialUserSex;
  final Future<int> Function({
    required String usernameOrEmail,
    required String name,
    String? category,
    String? intensity,
    int? durationMin,
    int? reps,
    int? sets,
    String? notes,
    int? estCalories,
  })?
  onSaveCustomExercise; // for tests
  final bool closeOnSubmit;
  const YourExerciseScreen({
    super.key,
    required this.usernameOrEmail,
    this.initialUserSex,
    this.onSaveCustomExercise,
    this.closeOnSubmit = true,
  });

  @override
  State<YourExerciseScreen> createState() => _YourExerciseScreenState();
}

class _YourExerciseScreenState extends State<YourExerciseScreen>
    with TickerProviderStateMixin, RouteAware {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _category = 'Cardio';
  String _intensity = 'Medium';
  bool _submitting = false;
  String? _userGender;
  late TabController _tabController;

  // History tab data
  List<Map<String, dynamic>> loggedExercises = [];
  bool isLoadingHistory = false;
  Set<String> _customExerciseNames = {};

  Color get _primaryColor => ThemeService.getPrimaryColor(_userGender);
  Color get _backgroundColor => ThemeService.getBackgroundColor(_userGender);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _userGender = widget.initialUserSex;
    _loadUserGender();
    _loadLoggedExercises();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }


  void _onTabChanged() {
    if (_tabController.index == 0 && !_tabController.indexIsChanging) {
      // Switched to HISTORY tab - refresh data
      _loadLoggedExercises();
    }
  }

  @override
  void didPopNext() {
    // Returning to this screen - refresh history
    _loadLoggedExercises();
  }

  Future<void> _loadUserGender() async {
    try {
      final gender = await UserDatabase().getUserSex(widget.usernameOrEmail);
      if (mounted) {
        setState(() {
          _userGender = gender;
        });
      }
    } catch (e) {
      debugPrint('Error loading user gender: $e');
    }
  }

  Future<void> _loadLoggedExercises() async {
    if (isLoadingHistory) return;

    setState(() {
      isLoadingHistory = true;
    });

    try {
      debugPrint('🔄 Loading custom exercise history for: ${widget.usernameOrEmail}');
      
      // First, get custom exercise names
      final customNames = await CustomExerciseService.getCustomExerciseNames(
        user: widget.usernameOrEmail,
      );
      debugPrint('📋 Found ${customNames.length} custom exercise names');
      
      if (mounted) {
        setState(() {
          _customExerciseNames = customNames.toSet();
        });
      }

      // Then get all exercise sessions
      final data = await ExerciseService.getExerciseSessions(
        user: widget.usernameOrEmail,
      );

      if (data['success'] == true) {
        final sessions = data['sessions'] as List<dynamic>;
        debugPrint('📊 Found ${sessions.length} total exercise sessions');

        // Filter exercises by custom exercise names
        final filteredSessions = sessions.where((session) {
          final exerciseName = session['exercise_name'] as String? ?? '';
          final isCustomExercise = _customExerciseNames.contains(exerciseName);
          
          debugPrint(
            '   Exercise: $exerciseName -> Custom: $isCustomExercise',
          );

          return isCustomExercise;
        }).toList();

        debugPrint(
          '✅ Filtered to ${filteredSessions.length} custom exercises',
        );

        // Convert to display format
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        final workouts = filteredSessions.map((session) {
          final dateStr = session['date'] as String? ?? '';
          final durationSecs = session['duration_seconds'] as int? ?? 0;
          final durationMins = (durationSecs / 60).round();
          final calories =
              (session['calories_burned'] as num?)?.toDouble() ?? 0.0;

          return {
            'id': session['id'],
            'exercise_name': session['exercise_name'] ?? 'Exercise',
            'duration': durationMins,
            'calories': calories,
            'date': dateStr,
            'created_at': session['created_at'] ?? dateStr,
            'isToday': dateStr == todayStr,
          };
        }).toList();

        // Sort by date (newest first)
        workouts.sort((a, b) {
          final dateA = a['created_at'] as String;
          final dateB = b['created_at'] as String;
          return dateB.compareTo(dateA);
        });

        if (mounted) {
          setState(() {
            loggedExercises = workouts;
            isLoadingHistory = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            loggedExercises = [];
            isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading custom exercise history: $e');
      if (mounted) {
        setState(() {
          loggedExercises = [];
          isLoadingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.dispose();
    _durationController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    final sets = int.tryParse(_setsController.text.trim());

    final effectiveCalories = _estimateCalories(duration, _intensity);

    // Save locally; allow test injection override
    final saver =
        widget.onSaveCustomExercise ?? UserDatabase().saveCustomExercise;
    final id = await saver(
      usernameOrEmail: widget.usernameOrEmail,
      name: name,
      category: _category,
      intensity: _intensity,
      durationMin: duration,
      reps: reps,
      sets: sets,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      estCalories: effectiveCalories,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    // Fire-and-forget backend submission
    // ignore: unawaited_futures
    CustomExerciseService.submitCustomExercise(
      user: widget.usernameOrEmail,
      name: name,
      category: _category,
      intensity: _intensity,
      durationMin: duration,
      reps: reps,
      sets: sets,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      estCalories: effectiveCalories,
    );

    // Also log as exercise session if duration is provided
    if (duration != null && duration > 0) {
      final durationSeconds = duration * 60;
      // ignore: unawaited_futures
      ExerciseService.logExerciseSession(
        user: widget.usernameOrEmail,
        exerciseId: 'custom_$id', // Use custom ID format
        exerciseName: name,
        durationSeconds: durationSeconds,
        caloriesBurned: effectiveCalories.toDouble(),
        setsCompleted: sets ?? 1,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );
    }

    // Show professional success overlay
    _showSuccessOverlay(name, effectiveCalories, _category);
    
    // Refresh history after submission
    _loadLoggedExercises();
    
    // Clear form
    _nameController.clear();
    _durationController.clear();
    _repsController.clear();
    _setsController.clear();
    _notesController.clear();
    
    if (widget.closeOnSubmit) {
      // Close after overlay disappears
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } else {
      // Switch to history tab to show the new entry after overlay
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _tabController.animateTo(0);
        }
      });
    }
  }

  void _showSuccessOverlay(String exerciseName, int calories, String category) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon with animation
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: _primaryColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Exercise Created!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Calories info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: _primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$calories',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              'calories estimated',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Exercise name and category
                  Column(
                    children: [
                      Text(
                        exerciseName,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: _primaryColor,
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

    // Auto-close after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  int _estimateCalories(int? durationMin, String intensity) {
    if (durationMin == null || durationMin <= 0) return 0;
    // Simple heuristic for preview only
    final perMin = switch (intensity) {
      'Low' => 3,
      'Medium' => 6,
      'High' => 9,
      _ => 5,
    };
    return perMin * durationMin;
  }

  Widget _buildHistoryTab() {
    final content = loggedExercises.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  isLoadingHistory
                      ? 'Loading exercise history...'
                      : 'No custom exercise history yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add exercises to see them here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadLoggedExercises,
            color: _primaryColor,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: loggedExercises.length,
              itemBuilder: (context, index) {
                final workout = loggedExercises[index];
                final sessionId = workout['id'] as int?;
                final exerciseName =
                    workout['exercise_name'] as String? ?? 'Exercise';
                final duration = workout['duration'] as int? ?? 0;
                final calories = workout['calories'] as double? ?? 0.0;
                final dateTime = workout['created_at'] as String? ?? '';
                final isToday = workout['isToday'] as bool? ?? false;

                // Format date/time
                String displayDate = '';
                try {
                  if (dateTime.isNotEmpty) {
                    final dt = DateTime.parse(dateTime);
                    if (isToday) {
                      displayDate =
                          'Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    } else {
                      displayDate = '${dt.day}/${dt.month}/${dt.year}';
                    }
                  }
                } catch (e) {
                  displayDate = dateTime;
                }

                return Dismissible(
                  key: Key('custom_exercise_${sessionId}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    // Show confirmation dialog
                    return await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text('Delete Exercise?'),
                                content: Text(
                                  'Are you sure you want to delete "$exerciseName"? This action cannot be undone.',
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                        ) ??
                        false;
                  },
                  onDismissed: (direction) async {
                    if (sessionId != null) {
                      final success = await ExerciseService.deleteExerciseSession(
                        sessionId,
                      );
                      if (success) {
                        // Remove from local list
                        setState(() {
                          loggedExercises.removeAt(index);
                        });

                        // Clear progress cache to refresh dashboard/progress
                        ProgressDataService.clearCache();

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Exercise deleted'),
                            backgroundColor: _primaryColor,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        // Reload list if delete failed
                        _loadLoggedExercises();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete exercise'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.add_circle_outline,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        exerciseName,
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.timer,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$duration min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: _primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${calories.toStringAsFixed(1)} kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayDate,
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );

    return Stack(
      children: [
        content,
        if (isLoadingHistory)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              backgroundColor: _primaryColor.withValues(alpha: 0.2),
            ),
          ),
      ],
    );
  }

  Widget _buildAddExerciseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Exercise name *',
                    labelStyle: TextStyle(color: _primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Please enter exercise name'
                              : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: _primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Cardio',
                            child: Text('Cardio'),
                          ),
                          DropdownMenuItem(
                            value: 'Strength',
                            child: Text('Strength'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() => _category = v ?? 'Cardio'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _intensity,
                        decoration: InputDecoration(
                          labelText: 'Intensity',
                          labelStyle: TextStyle(color: _primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                          DropdownMenuItem(
                            value: 'Medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: 'High',
                            child: Text('High'),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() => _intensity = v ?? 'Medium'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (min)',
                          labelStyle: TextStyle(color: _primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if ((v == null || v.isEmpty) &&
                              (_repsController.text.isEmpty ||
                                  _setsController.text.isEmpty)) {
                            return 'Provide duration or reps & sets';
                          }
                          final n = int.tryParse(v ?? '');
                          if (v != null &&
                              v.isNotEmpty &&
                              (n == null || n <= 0 || n > 480)) {
                            return 'Enter 1-480';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          labelStyle: TextStyle(color: _primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _setsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sets',
                          labelStyle: TextStyle(color: _primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (equipment, description, etc.)',
                    labelStyle: TextStyle(color: _primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon:
                        _submitting
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.send),
                    label: Text(_submitting ? 'Submitting...' : 'Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: _primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Your Exercise',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tabs (HISTORY, ADD EXERCISE)
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 12 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'HISTORY'),
                Tab(text: 'ADD EXERCISE'),
              ],
            ),
          ),

          // Tab contents
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // HISTORY tab
                _buildHistoryTab(),

                // ADD EXERCISE tab
                _buildAddExerciseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
