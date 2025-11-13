import 'package:flutter/material.dart';
import 'models/exercise.dart';
import 'services/exercise_service.dart';
import 'services/processed_exercise_service.dart';
import 'services/progress_data_service.dart';
import 'theme_service.dart';
import 'user_database.dart';
import 'my_app.dart';

class ExerciseCategoryScreen extends StatefulWidget {
  final String category;
  final String usernameOrEmail;
  final String? initialUserSex;

  const ExerciseCategoryScreen({
    super.key,
    required this.category,
    required this.usernameOrEmail,
    this.initialUserSex,
  });

  @override
  State<ExerciseCategoryScreen> createState() => _ExerciseCategoryScreenState();
}

class _ExerciseCategoryScreenState extends State<ExerciseCategoryScreen>
    with TickerProviderStateMixin, RouteAware {
  List<Exercise> exercises = [];
  bool isLoading = true;
  String? userSex;
  String searchQuery = '';
  late TabController _tabController;

  // History tab data
  List<Map<String, dynamic>> loggedExercises = [];
  bool isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    userSex = widget.initialUserSex;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadExercises();
    _loadUserSex();
    _loadLoggedExercises();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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

  // Helper method to determine exercise category from name
  String _getExerciseCategoryFromName(String exerciseName) {
    final nameLower = exerciseName.toLowerCase();

    // Cardio exercises
    if (nameLower.contains('run') ||
        nameLower.contains('jump') ||
        nameLower.contains('bike') ||
        nameLower.contains('cardio') ||
        nameLower.contains('dance') ||
        nameLower.contains('aerobic') ||
        nameLower.contains('cycling') ||
        nameLower.contains('walking') ||
        nameLower.contains('swimming') ||
        nameLower.contains('running') ||
        nameLower.contains('treadmill') ||
        nameLower.contains('elliptical') ||
        nameLower.contains('zumba') ||
        nameLower.contains('salsa')) {
      return 'Cardio';
    }

    // Strength exercises
    if (nameLower.contains('bicep') ||
        nameLower.contains('tricep') ||
        nameLower.contains('squat') ||
        nameLower.contains('press') ||
        nameLower.contains('curl') ||
        nameLower.contains('deadlift') ||
        nameLower.contains('bench') ||
        nameLower.contains('pull') ||
        nameLower.contains('push') ||
        nameLower.contains('lift') ||
        nameLower.contains('dumbbell') ||
        nameLower.contains('barbell') ||
        nameLower.contains('weight') ||
        nameLower.contains('strength')) {
      return 'Strength';
    }

    // Yoga exercises
    if (nameLower.contains('yoga') ||
        nameLower.contains('pose') ||
        nameLower.contains('meditation')) {
      return 'Yoga';
    }

    // Default to Strength if unclear
    return 'Strength';
  }

  Future<void> _loadLoggedExercises() async {
    if (isLoadingHistory) return;

    setState(() {
      isLoadingHistory = true;
    });

    try {
      debugPrint(
        '🔄 Loading logged exercises for category: ${widget.category}',
      );
      final data = await ExerciseService.getExerciseSessions(
        user: widget.usernameOrEmail,
      );

      if (data['success'] == true) {
        final sessions = data['sessions'] as List<dynamic>;
        debugPrint('📊 Found ${sessions.length} total exercise sessions');

        // Filter exercises by category
        final filteredSessions =
            sessions.where((session) {
              final exerciseName = session['exercise_name'] as String? ?? '';
              final detectedCategory = _getExerciseCategoryFromName(
                exerciseName,
              );
              final matchesCategory =
                  detectedCategory.toLowerCase() ==
                  widget.category.toLowerCase();

              debugPrint(
                '   Exercise: $exerciseName -> Category: $detectedCategory (matches ${widget.category}: $matchesCategory)',
              );

              return matchesCategory;
            }).toList();

        debugPrint(
          '✅ Filtered to ${filteredSessions.length} ${widget.category} exercises',
        );

        // Convert to display format
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        final workouts =
            filteredSessions.map((session) {
              final dateStr = session['date'] as String? ?? '';
              final durationSecs = session['duration_seconds'] as int? ?? 0;
              final durationMins = (durationSecs / 60).round();
              final calories =
                  (session['calories_burned'] as num?)?.toDouble() ?? 0.0;

              return {
                'id': session['id'], // Add session ID for deletion
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
      debugPrint('❌ Error loading logged exercises: $e');
      if (mounted) {
        setState(() {
          loggedExercises = [];
          isLoadingHistory = false;
        });
      }
    }
  }

  Widget _buildHistoryTab() {
    if (isLoadingHistory) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (loggedExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No ${widget.category.toLowerCase()} exercise history yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add exercises to see them here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLoggedExercises,
      color: primaryColor,
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
            key: Key('exercise_${sessionId}_$index'),
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
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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
                      backgroundColor: primaryColor,
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
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  exerciseName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Colors.grey[600]),
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
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${calories.toStringAsFixed(1)} kcal',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayDate,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadUserSex() async {
    // Load user sex for theming from the database
    try {
      final sex = await UserDatabase().getUserSex(widget.usernameOrEmail);
      if (!mounted) return;
      setState(() {
        userSex = sex;
      });
    } catch (e) {
      // Fallback to default if there's an error
      if (!mounted) return;
      setState(() {
        userSex = 'male'; // Default to male instead of female
      });
    }
  }

  Future<void> _loadExercises() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Try to load from processed exercise service first
      List<Exercise> categoryExercises;
      try {
        categoryExercises =
            await ProcessedExerciseService.getExercisesByCategory(
              widget.category,
            );
      } catch (e) {
        // Fallback to original service
        categoryExercises = await ExerciseService.getExercisesByCategory(
          widget.category,
        );
      }

      if (!mounted) return;
      setState(() {
        exercises = categoryExercises;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercises: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Exercise> get filteredExercises {
    if (searchQuery.isEmpty) {
      return exercises;
    }
    return exercises
        .where(
          (exercise) =>
              exercise.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              exercise.target.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              exercise.equipment.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.category} Exercises',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Container(
                padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'SEARCH',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Tabs (HISTORY, BROWSE ALL)
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'HISTORY'), Tab(text: 'BROWSE ALL')],
                ),
              ),

              // Tab contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // HISTORY tab
                    _buildHistoryTab(),

                    // BROWSE ALL tab
                    _buildBrowseAllTab(isVerySmallScreen),
                  ],
                ),
              ),
            ],
          ),
          if (isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                backgroundColor: primaryColor.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrowseAllTab(bool isVerySmallScreen) {
    final exercisesList = filteredExercises;
    final bool showLoadingPlaceholder = isLoading && exercisesList.isEmpty;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallScreen ? 12 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              Text(
                showLoadingPlaceholder
                    ? 'Loading exercises...'
                    : '${exercisesList.length} exercises found',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (searchQuery.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                    });
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: exercisesList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        showLoadingPlaceholder
                            ? 'Fetching ${widget.category.toLowerCase()} workouts...'
                            : searchQuery.isEmpty
                                ? 'No exercises found for ${widget.category}'
                                : 'No exercises match your search',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(
                    isVerySmallScreen ? 8 : 12,
                  ),
                  itemCount: exercisesList.length,
                  itemBuilder: (context, index) {
                    final exercise = exercisesList[index];
                    return _buildExerciseCard(
                      exercise,
                      isVerySmallScreen,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isVerySmallScreen) {
    return Card(
      margin: EdgeInsets.only(bottom: isVerySmallScreen ? 8 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showExerciseDetail(exercise),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
          child: Row(
            children: [
              // Exercise image placeholder
              Container(
                width: isVerySmallScreen ? 60 : 80,
                height: isVerySmallScreen ? 60 : 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getExerciseIcon(exercise.exerciseCategory),
                  color: primaryColor,
                  size: isVerySmallScreen ? 24 : 32,
                ),
              ),
              SizedBox(width: isVerySmallScreen ? 12 : 16),

              // Exercise details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.target,
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(
                              exercise.exerciseDifficulty,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            exercise.exerciseDifficulty,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getDifficultyColor(
                                exercise.exerciseDifficulty,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            exercise.equipment,
                            style: TextStyle(
                              fontSize: 10,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getExerciseIcon(String category) {
    switch (category) {
      case 'Cardio':
        return Icons.directions_run;
      case 'Strength':
        return Icons.fitness_center;
      case 'Your Exercise':
        return Icons.add_circle_outline;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showExerciseDetail(Exercise exercise) async {
    final exerciseAdded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Exercise details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exercise name and target
                        Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Target: ${exercise.target}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Exercise info cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Difficulty',
                                exercise.exerciseDifficulty,
                                _getDifficultyColor(
                                  exercise.exerciseDifficulty,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Equipment',
                                exercise.equipment,
                                primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Instructions
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...exercise.instructions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final instruction = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    instruction,
                                    style: TextStyle(fontSize: 16, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 20),

                        // Calories info
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Estimated ${exercise.exerciseCaloriesPerMinute.toStringAsFixed(1)} calories burned per minute',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Duration input and Calories computed section
                _DurationAndCaloriesFooter(
                  primaryColor: primaryColor,
                  exercise: exercise,
                  usernameOrEmail: widget.usernameOrEmail,
                  userSex: userSex,
                ),
              ],
            ),
          ),
    );

    // If exercise was added, refresh history and pop this screen
    if (exerciseAdded == true) {
      debugPrint('🔄 Exercise added in detail screen - refreshing history');
      _loadLoggedExercises();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationAndCaloriesFooter extends StatefulWidget {
  final Color primaryColor;
  final Exercise exercise;
  final String usernameOrEmail;
  final String? userSex;
  const _DurationAndCaloriesFooter({
    required this.primaryColor,
    required this.exercise,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<_DurationAndCaloriesFooter> createState() =>
      _DurationAndCaloriesFooterState();
}

class _DurationAndCaloriesFooterState
    extends State<_DurationAndCaloriesFooter> {
  final TextEditingController _durationCtrl = TextEditingController();
  String _unit = 'minutes';
  double? _calories;
  bool _loading = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  int _toSeconds(String value, String unit) {
    final v = int.tryParse(value.trim()) ?? 0;
    switch (unit) {
      case 'seconds':
        return v;
      case 'hours':
        return v * 3600;
      default:
        return v * 60; // minutes
    }
  }

  bool _hasValidDuration() {
    final text = _durationCtrl.text.trim();
    if (text.isEmpty) return false;
    final secs = _toSeconds(text, _unit);
    return secs > 0;
  }

  Future<void> _recalculate() async {
    final text = _durationCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _calories = null;
        _errorMessage = null;
      });
      return;
    }

    final secs = _toSeconds(text, _unit);
    if (secs <= 0) {
      setState(() {
        _calories = null;
        _errorMessage = 'Please enter a valid duration';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final cals = await ExerciseService.calculateCalories(
        id: widget.exercise.id,
        name: widget.exercise.name,
        durationSeconds: secs,
      );
      if (!mounted) return;

      if (cals == null) {
        // API failed or exercise not found - calculate locally as fallback
        final minutes = secs / 60.0;
        final estimatedCals =
            widget.exercise.exerciseCaloriesPerMinute * minutes;
        setState(() {
          _calories = estimatedCals;
          _loading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _calories = cals;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback to local calculation if API fails
      final minutes = secs / 60.0;
      final estimatedCals = widget.exercise.exerciseCaloriesPerMinute * minutes;
      setState(() {
        _calories = estimatedCals;
        _loading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _addExercise() async {
    // Validate duration is entered
    if (!_hasValidDuration()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid duration'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    // Ensure calories are calculated
    if (_calories == null || _calories! <= 0) {
      // Try to calculate first
      await _recalculate();
      if (_calories == null || _calories! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to calculate calories. Please try again.',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }
    }

    final secs = _toSeconds(_durationCtrl.text.trim(), _unit);

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final success = await ExerciseService.logExerciseSession(
        user: widget.usernameOrEmail,
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        durationSeconds: secs,
        caloriesBurned: _calories,
      );

      if (!mounted) return;

      if (success) {
        // Clear progress data cache so fresh data is loaded
        ProgressDataService.clearCache();

        // Show professional success overlay
        _showSuccessOverlay(_calories!);

        // Close the exercise detail screen after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(
              context,
              true,
            ); // Return true to indicate exercise was added
          }
        });
      } else {
        setState(() {
          _saving = false;
          _errorMessage = 'Failed to save exercise. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to save exercise. Check your connection.',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Error saving exercise: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showSuccessOverlay(double calories) {
    final primaryColor = ThemeService.getPrimaryColor(widget.userSex);
    final backgroundColor = ThemeService.getBackgroundColor(widget.userSex);

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
                    color: primaryColor.withValues(alpha: 0.3),
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
                    'Exercise Added!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
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
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${calories.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              'calories burned',
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
                  // Exercise name
                  Text(
                    widget.exercise.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );

    // Auto-close after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
                  decoration: InputDecoration(
                    labelText: 'Duration Time',
                    hintText: 'e.g., 5',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  items: const [
                    DropdownMenuItem(value: 'seconds', child: Text('seconds')),
                    DropdownMenuItem(value: 'minutes', child: Text('minutes')),
                    DropdownMenuItem(value: 'hours', child: Text('hours')),
                  ],
                  onChanged: (v) {
                    setState(() => _unit = v ?? 'minutes');
                    _recalculate();
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: widget.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calories Burned',
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _loading
                          ? const LinearProgressIndicator(minHeight: 4)
                          : _errorMessage != null
                          ? Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          )
                          : Text(
                            _calories == null
                                ? (_hasValidDuration()
                                    ? 'Calculating...'
                                    : 'Enter duration to calculate')
                                : '${_calories!.toStringAsFixed(2)} kcal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  _calories != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: widget.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _addExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: widget.primaryColor.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  child:
                      _saving
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Add Exercise',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
