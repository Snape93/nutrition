import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';
import 'exercise_category_screen.dart';
// Removed unused imports after tab reduction
import 'services/health_service.dart';
import 'services/exercise_service.dart';
import 'screens/your_exercise_screen.dart';
import 'my_app.dart';

class ExerciseScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? initialUserSex;
  const ExerciseScreen({super.key, required this.usernameOrEmail, this.initialUserSex});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin, RouteAware {
  String? userSex;
  bool isLoading = true;
  int todayExerciseMinutes = 0;
  double todayCaloriesBurned = 0.0;
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
    userSex = widget.initialUserSex;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning to this screen from another screen (e.g., after adding exercise)
    debugPrint('🔄 ExerciseScreen: didPopNext called - refreshing exercise data');
    _loadExerciseData();
  }

  @override
  void didPush() {
    // Screen was pushed (opened)
    debugPrint('🔄 ExerciseScreen: didPush called - loading exercise data');
    _loadExerciseData();
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
    // Load logged exercises from backend
    await _loadLoggedExercises();
    
    // Load real health data
    await _loadHealthData();
  }

  Future<void> _loadLoggedExercises() async {
    try {
      debugPrint('🔄 Loading logged exercises for user: ${widget.usernameOrEmail}');
      final data = await ExerciseService.getExerciseSessions(
        user: widget.usernameOrEmail,
      );
      
      debugPrint('📊 Exercise sessions response: success=${data['success']}, sessions count=${data['sessions']?.length ?? 0}');
      
      if (data['success'] == true) {
        final sessions = data['sessions'] as List<dynamic>;
        debugPrint('📋 Found ${sessions.length} exercise sessions');
        if (sessions.isEmpty) {
          debugPrint('⚠️ No exercise sessions found in response');
        } else {
          debugPrint('📋 First session: ${sessions.first}');
        }
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        
        // Calculate today's totals
        int todayMinutes = 0;
        double todayCalories = 0.0;
        
        // Convert sessions to workout format for display
        final loggedWorkouts = sessions.map((session) {
          final dateStr = session['date'] as String? ?? '';
          final durationSecs = session['duration_seconds'] as int? ?? 0;
          final durationMins = (durationSecs / 60).round();
          final calories = (session['calories_burned'] as num?)?.toDouble() ?? 0.0;
          
          // Check if this is today's exercise
          if (dateStr == todayStr) {
            todayMinutes += durationMins;
            todayCalories += calories;
          }
          
          return {
            'type': session['exercise_name'] ?? 'Exercise',
            'duration': durationMins,
            'calories': calories,
            'date': dateStr,
            'startTime': session['created_at'] ?? dateStr,
            'isLogged': true,
          };
        }).toList();
        
        // Sort by date (newest first)
        loggedWorkouts.sort((a, b) {
          final dateA = a['startTime'] as String;
          final dateB = b['startTime'] as String;
          return dateB.compareTo(dateA);
        });
        
        if (mounted) {
          debugPrint('✅ Updating exercise screen: ${loggedWorkouts.length} workouts, today: ${todayMinutes}min, ${todayCalories}cal');
          setState(() {
            recentWorkouts = loggedWorkouts;
            todayExerciseMinutes = todayMinutes;
            todayCaloriesBurned = todayCalories;
          });
        }
      } else {
        debugPrint('❌ Failed to load exercise sessions: success=false');
        debugPrint('   Response data: $data');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading logged exercises: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
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
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SafeArea(
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
                              onTap: (index) {
                                // Refresh history when switching to HISTORY tab
                                if (index == 0) {
                                  debugPrint('🔄 Switched to HISTORY tab - refreshing data');
                                  _loadExerciseData();
                                }
                              },
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

  // Removed unused _startWorkoutTimer after tab reduction

  void _showCategoryExercises(String category) async {
    // Wait for the category screen to return, then refresh
    final exerciseAdded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ExerciseCategoryScreen(
              category: category,
              usernameOrEmail: widget.usernameOrEmail,
            ),
      ),
    );
    // Refresh exercise data when returning from category screen
    if (exerciseAdded == true) {
      debugPrint('🔄 Exercise was added - refreshing exercise data');
    } else {
      debugPrint('🔄 Returned from category screen - refreshing exercise data');
    }
    _loadExerciseData();
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
                    SizedBox(height: 8),
                    Text(
                      'Add exercises to see them here',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadLoggedExercises();
                  await _loadHealthData();
                },
                color: primaryColor,
                child: ListView.builder(
                  itemCount: recentWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = recentWorkouts[index];
                    final workoutName = workout['type'] as String? ?? 'Exercise';
                    final duration = workout['duration'] as int? ?? 0;
                    final calories = workout['calories'] as double? ?? 0.0;
                    final dateTime = workout['startTime'] as String? ?? '';
                    
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
                            _getWorkoutIcon(workoutName),
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          workoutName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              '$duration min • ${calories.toStringAsFixed(1)} kcal',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _formatDate(dateTime),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
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

  String _formatDate(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
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
    } catch (e) {
      // If parsing fails, return the date string as-is
      return dateTimeStr.split('T')[0]; // Extract date part if ISO format
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
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
