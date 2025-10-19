import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';
import 'exercise_category_screen.dart';
// Removed unused imports after tab reduction
import 'services/health_service.dart';
import 'screens/your_exercise_screen.dart';

class ExerciseScreen extends StatefulWidget {
  final String usernameOrEmail;
  const ExerciseScreen({super.key, required this.usernameOrEmail});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin {
  String? userSex;
  bool isLoading = true;
  int todayExerciseMinutes = 0;
  int todayCaloriesBurned = 0;
  String searchQuery = '';
  int selectedTabIndex = 0;

  // Real health data from connected devices
  int todaySteps = 0;
  int? currentHeartRate;
  double todayHealthCalories = 0.0;
  bool isHealthConnected = false;
  List<Map<String, dynamic>> recentWorkouts = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load user sex for theming
      final sex = await UserDatabase().getUserSex(widget.usernameOrEmail);
      setState(() {
        userSex = sex;
      });

      // Load exercise data (placeholder for now)
      await _loadExerciseData();

      _animationController.forward();
    } catch (e) {
      debugPrint('Error loading exercise data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadExerciseData() async {
    // Load exercise data from database
    setState(() {
      todayExerciseMinutes = 0;
      todayCaloriesBurned = 0;
    });

    // Load real health data
    await _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    try {
      // Check if Health Connect is connected
      final connected = await HealthService.isHealthConnectConnected();

      if (connected) {
        // Load real health data in parallel
        final results = await Future.wait([
          HealthService.getTodaySteps(),
          HealthService.getLatestHeartRate(),
          HealthService.getTodayCaloriesBurned(),
          HealthService.getRecentWorkouts(),
        ]);

        setState(() {
          isHealthConnected = true;
          todaySteps = results[0] as int;
          currentHeartRate = results[1] as int?;
          todayHealthCalories = results[2] as double;
          recentWorkouts = results[3] as List<Map<String, dynamic>>;
        });
      } else {
        setState(() {
          isHealthConnected = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading health data: $e');
      setState(() {
        isHealthConnected = false;
      });
    }
  }

  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Search Header
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
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
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Tab Bar
                      Container(
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
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: [Tab(text: 'HISTORY'), Tab(text: 'BROWSE ALL')],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildHistoryTab(), _buildBrowseAllTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed unused _startWorkoutTimer after tab reduction

  void _showCategoryExercises(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ExerciseCategoryScreen(
              category: category,
              usernameOrEmail: widget.usernameOrEmail,
            ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (recentWorkouts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No exercise history yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHealthData,
                child: ListView.builder(
                  itemCount: recentWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = recentWorkouts[index];
                    return Card(
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
                            _getWorkoutIcon(workout['type']),
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          _getWorkoutName(workout['type']),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${workout['duration']} minutes • ${_formatDate(workout['startTime'])}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getWorkoutIcon(String workoutType) {
    if (workoutType.toLowerCase().contains('running') ||
        workoutType.toLowerCase().contains('walk')) {
      return Icons.directions_run;
    } else if (workoutType.toLowerCase().contains('cycling') ||
        workoutType.toLowerCase().contains('bike')) {
      return Icons.directions_bike;
    } else if (workoutType.toLowerCase().contains('strength') ||
        workoutType.toLowerCase().contains('weight')) {
      return Icons.fitness_center;
    } else if (workoutType.toLowerCase().contains('yoga')) {
      return Icons.self_improvement;
    } else {
      return Icons.sports;
    }
  }

  String _getWorkoutName(String workoutType) {
    // Clean up the workout type name
    return workoutType.replaceAll('HealthDataType.', '').replaceAll('_', ' ');
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final workoutDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (workoutDate == today) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (workoutDate == yesterday) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Removed _buildMyExerciseTab after reducing tabs to two

  // Removed unused _buildHealthStatColumn after tab reduction

  Widget _buildBrowseAllTab() {
    final categories = [
      {'name': 'Cardio', 'icon': Icons.directions_run, 'color': Colors.red},
      {'name': 'Strength', 'icon': Icons.fitness_center, 'color': Colors.blue},
      {
        'name': 'Your Exercise',
        'icon': Icons.add_circle_outline,
        'color': Colors.green,
      },
    ];

    return Container(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                final name = category['name'] as String;
                if (name == 'Your Exercise') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => YourExerciseScreen(
                            usernameOrEmail: widget.usernameOrEmail,
                          ),
                    ),
                  );
                } else {
                  _showCategoryExercises(name);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (category['color'] as Color).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category['icon'] as IconData,
                        color: category['color'] as Color,
                        size: 24,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      category['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
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
}
