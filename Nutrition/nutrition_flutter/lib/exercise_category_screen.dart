import 'package:flutter/material.dart';
import 'models/exercise.dart';
import 'services/exercise_service.dart';
import 'services/processed_exercise_service.dart';
import 'theme_service.dart';
import 'user_database.dart'; // Add this import

class ExerciseCategoryScreen extends StatefulWidget {
  final String category;
  final String usernameOrEmail;

  const ExerciseCategoryScreen({
    super.key,
    required this.category,
    required this.usernameOrEmail,
  });

  @override
  State<ExerciseCategoryScreen> createState() => _ExerciseCategoryScreenState();
}

class _ExerciseCategoryScreenState extends State<ExerciseCategoryScreen>
    with TickerProviderStateMixin {
  List<Exercise> exercises = [];
  bool isLoading = true;
  String? userSex;
  String searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExercises();
    _loadUserSex();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: Column(
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
                // HISTORY tab (no watch CTA)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No exercise history yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // BROWSE ALL tab - existing list
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : Column(
                      children: [
                        // Exercise count row
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 12 : 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${filteredExercises.length} exercises found',
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
                          child:
                              filteredExercises.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.fitness_center,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchQuery.isEmpty
                                              ? 'No exercises found for ${widget.category}'
                                              : 'No exercises match your search',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: EdgeInsets.all(
                                      isVerySmallScreen ? 8 : 12,
                                    ),
                                    itemCount: filteredExercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise = filteredExercises[index];
                                      return _buildExerciseCard(
                                        exercise,
                                        isVerySmallScreen,
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
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

  void _showExerciseDetail(Exercise exercise) {
    showModalBottomSheet(
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
                ),
              ],
            ),
          ),
    );
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
  const _DurationAndCaloriesFooter({
    required this.primaryColor,
    required this.exercise,
    required this.usernameOrEmail,
  });

  @override
  State<_DurationAndCaloriesFooter> createState() =>
      _DurationAndCaloriesFooterState();
}

class _DurationAndCaloriesFooterState
    extends State<_DurationAndCaloriesFooter> {
  final TextEditingController _durationCtrl = TextEditingController(text: '5');
  String _unit = 'minutes';
  double? _calories;
  bool _loading = false;

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

  Future<void> _recalculate() async {
    final secs = _toSeconds(_durationCtrl.text, _unit);
    if (secs <= 0) {
      setState(() => _calories = 0);
      return;
    }
    setState(() => _loading = true);
    final cals = await ExerciseService.calculateCalories(
      id: widget.exercise.id,
      name: widget.exercise.name,
      durationSeconds: secs,
    );
    if (!mounted) return;
    setState(() {
      _calories = cals;
      _loading = false;
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
                          : Text(
                            _calories == null
                                ? 'Enter duration to calculate'
                                : '${_calories!.toStringAsFixed(2)} kcal',
                            style: const TextStyle(fontSize: 16),
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
                  onPressed: _recalculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Calculate',
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
