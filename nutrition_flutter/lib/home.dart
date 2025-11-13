import 'package:flutter/material.dart';

import 'profile_view.dart';
import 'settings.dart';
import 'theme_service.dart';
import 'user_database.dart';
import 'screens/professional_food_log_screen.dart';
import 'screens/beautiful_progress_screen.dart';
import 'my_app.dart'; // Import routeObserver
import 'history_screen.dart'; // Added import for HistoryScreen
import 'exercise_screen.dart'; // Added import for ExerciseScreen
import 'exercise_category_screen.dart';
import 'screens/your_exercise_screen.dart';
import 'connect_platforms.dart'; // Added import for ConnectPlatformsScreen
import 'services/health_service.dart'; // Added import for HealthService
import 'services/remaining_service.dart';
import 'widgets/add_options_sheet.dart';
import 'screens/custom_meals_screen.dart';
import 'services/progress_data_service.dart';
import 'models/graph_models.dart';
// Removed graph-related imports to prevent paused exceptions

class HomePage extends StatefulWidget {
  final String usernameOrEmail;
  const HomePage({super.key, required this.usernameOrEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

const Color kUserIconGray = Color(0xFF5A5A5A); // extracted from the image

class _HomePageState extends State<HomePage> with RouteAware {
  int _selectedIndex = 0;
  String? userSex;

  // Add state variables for calories
  int baseGoal =
      2000; // Example default, replace with user-specific if available
  int foodCalories = 0;
  int exerciseCalories = 0;
  bool isLoading = false;
  String? _errorMessage;

  // Water intake tracking
  int waterIntake = 0; // in milliliters
  int dailyWaterGoal = 2000; // 2 liters default goal

  // Removed graph system state to prevent paused exceptions

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadRecentFoods();
    _loadWeeklyCalories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint('DEBUG: didPopNext called - returning to HomePage');
    // Only call _refreshDashboard (it loads all data)
    _refreshDashboard();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _loadUserSex(),
        _loadCalorieGoal(),
        _loadTodayCalories(),
        _loadRemainingFromBackend(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dashboard data. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRemainingFromBackend() async {
    try {
      // Use ProgressDataService for consistency with Progress screen
      final progressData = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: TimeRange.daily,
        forceRefresh: true, // Always get fresh data
      );

      if (!mounted) return;
      setState(() {
        baseGoal = progressData.calories.goal.toInt();
        foodCalories = progressData.calories.current.toInt();
        // Exercise calories from ProgressDataService
        exerciseCalories = progressData.exercise.caloriesBurned.toInt();
      });

      debugPrint('DEBUG: Loaded from ProgressDataService:');
      debugPrint('   Goal: $baseGoal');
      debugPrint('   Food: $foodCalories');
      debugPrint('   Exercise: $exerciseCalories');
    } catch (e) {
      debugPrint(
        'DEBUG: ProgressDataService failed, falling back to /remaining: $e',
      );
      // Fallback to /remaining endpoint
      try {
        final data = await RemainingService.fetchRemaining(
          user: widget.usernameOrEmail,
        );
        if (!mounted) return;
        setState(() {
          baseGoal = (data['daily_calorie_goal'] as num?)?.toInt() ?? baseGoal;
          final ft = data['food_totals'] as Map<String, dynamic>?;
          final et = data['exercise_totals'] as Map<String, dynamic>?;
          if (ft != null) {
            foodCalories = (ft['calories'] as num?)?.toInt() ?? foodCalories;
          }
          if (et != null) {
            exerciseCalories = (et['calories'] as num?)?.toInt() ?? 0;
          }
        });
      } catch (_) {
        // Keep existing UI if backend unreachable
      }
    }
  }

  Future<void> _loadUserSex() async {
    final sex = await UserDatabase().getUserSex(widget.usernameOrEmail);
    debugPrint(
      'DEBUG: Loaded user sex: $sex for user: ${widget.usernameOrEmail}',
    );
    if (!mounted) return;
    setState(() {
      userSex = sex;
    });
    debugPrint('DEBUG: Set userSex to: $userSex');
  }

  Future<void> _loadCalorieGoal() async {
    // Prefer the same source as the Progress screen for a single source of truth
    try {
      // Use progress data service (same service as progress screen)
      final progress = await ProgressDataService.getProgressData(
        usernameOrEmail: widget.usernameOrEmail,
        timeRange: TimeRange.daily,
      );
      if (mounted) {
        setState(() {
          baseGoal = progress.calories.goal.toInt();
        });
      }
    } catch (_) {
      // Fallback to previous user API in case progress endpoint is unavailable
      final calorieGoal = await UserDatabase().getDailyCalorieGoal(
        widget.usernameOrEmail,
      );
      if (!mounted) return;
      setState(() {
        baseGoal = calorieGoal;
      });
    }
  }

  Future<void> _loadTodayCalories() async {
    final foodCals = await UserDatabase().getTodayFoodCaloriesLocal(
      widget.usernameOrEmail,
    );
    if (!mounted) return;

    setState(() {
      foodCalories = foodCals;
      debugPrint(
        'DEBUG: _loadTodayCalories set foodCalories=$foodCalories, baseGoal=$baseGoal',
      );
    });
  }

  Future<void> _loadRecentFoods() async {
    final logs = await UserDatabase().getFoodLogs(widget.usernameOrEmail);
    // Get unique recent foods (by food_name, most recent first)
    final seen = <String>{};
    final List<Map<String, dynamic>> recent = [];
    for (final log in logs) {
      final name = log['food_name'] as String;
      if (!seen.contains(name)) {
        seen.add(name);
        recent.add(log);
      }
      if (recent.length >= 5) break;
    }
    // if (!mounted) return;
    // setState(() => _recentFoods = recent);
  }

  Future<void> _loadWeeklyCalories() async {
    // This method is kept for compatibility but data is now loaded through _loadGraphData
    // The old chart system has been replaced with the professional graph system
  }

  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  // Add this method to support pull-to-refresh
  Future<void> _refreshDashboard() async {
    await _loadAllData();
    await _loadRecentFoods();
    await _loadWeeklyCalories();
  }

  // Removed all graph-related methods to prevent paused exceptions

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreContent(bool isVerySmallScreen, bool isNarrowScreen) {
    return Center(
      child: Text(
        'More content coming soon!',
        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;

    if (isLoading) {
      bodyContent = Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    } else if (_errorMessage != null) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAllData, child: Text('Retry')),
          ],
        ),
      );
    } else if (_selectedIndex == 4) {
      // More tab content
      bodyContent = ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrowScreen ? 16 : 24,
          vertical: isVerySmallScreen ? 16 : 24,
        ),
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(
              bottom: isVerySmallScreen ? 24 : 32,
              top: isVerySmallScreen ? 8 : 16,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                fontSize: isVerySmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),

          // Profile Card
          _buildMenuCard(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'View and edit your personal information',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => ProfileViewScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        initialUserSex: userSex,
                      ),
                ),
              );
            },
          ),

          SizedBox(height: isVerySmallScreen ? 12 : 16),

          // Settings Card
          _buildMenuCard(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'App preferences and account settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => SettingsScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        initialUserSex: userSex,
                        onCalorieGoalUpdated: (int newGoal) {
                          setState(() {
                            baseGoal = newGoal;
                          });
                        },
                      ),
                ),
              );
            },
          ),

          SizedBox(height: isVerySmallScreen ? 12 : 16),

          // History Card
          _buildMenuCard(
            icon: Icons.history,
            title: 'History',
            subtitle: 'View your nutrition and progress history',
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => HistoryScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        initialUserSex: userSex,
                      ),
                ),
              );
              if (result == 'undo') {
                _refreshDashboard();
              }
            },
          ),
        ],
      );
    } else if (_selectedIndex == 1) {
      // Exercise tab content
      bodyContent = ExerciseScreen(
        usernameOrEmail: widget.usernameOrEmail,
        initialUserSex: userSex,
      );
    } else if (_selectedIndex == 3) {
      // Progress tab content - beautiful progress screen with real-time data
      bodyContent = BeautifulProgressScreen(
        usernameOrEmail: widget.usernameOrEmail,
        userSex: userSex,
      );
    } else if (_selectedIndex == 4) {
      // More tab content
      bodyContent = _buildMoreContent(isVerySmallScreen, isNarrowScreen);
    } else {
      // Home tab content (default)
      bodyContent = RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrowScreen ? 12 : 16,
            vertical: isVerySmallScreen ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: isVerySmallScreen ? 4 : 8),
              Text(
                'Let\'s track your nutrition today',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: isVerySmallScreen ? 16 : 24),

              // Calories Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Calories',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isVerySmallScreen ? 16 : 20),
                      Builder(
                        builder: (context) {
                          final remaining =
                              baseGoal - foodCalories + exerciseCalories;
                          final isNegative = remaining < 0;
                          // For progress indicator: clamp to 0-1 for display, but show full circle when exceeded
                          final progressValue =
                              baseGoal > 0
                                  ? ((baseGoal -
                                              foodCalories +
                                              exerciseCalories) /
                                          baseGoal)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                          // If exceeded, show full circle (1.0) with gray color
                          final showFullCircle = remaining < 0;

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: isVerySmallScreen ? 100 : 120,
                                height: isVerySmallScreen ? 100 : 120,
                                child: CircularProgressIndicator(
                                  value: showFullCircle ? 1.0 : progressValue,
                                  strokeWidth: isVerySmallScreen ? 10 : 12,
                                  backgroundColor: backgroundColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isNegative ? Colors.grey : primaryColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${remaining.toInt()}',
                                    style: TextStyle(
                                      color:
                                          isNegative
                                              ? Colors.grey
                                              : primaryColor,
                                      fontSize: isVerySmallScreen ? 28 : 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'left',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: isVerySmallScreen ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: isVerySmallScreen ? 16 : 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCalorieStatColumn(
                            icon: Icons.flag,
                            color: primaryColor,
                            label: 'Target',
                            value: '$baseGoal',
                            isVerySmallScreen: isVerySmallScreen,
                          ),
                          _buildCalorieStatColumn(
                            icon: Icons.restaurant,
                            color: Colors.lightBlueAccent,
                            label: 'Food',
                            value: '$foodCalories',
                            isVerySmallScreen: isVerySmallScreen,
                          ),
                          _buildCalorieStatColumn(
                            icon: Icons.fitness_center,
                            color: Colors.orangeAccent,
                            label: 'Exercise',
                            value: '$exerciseCalories',
                            isVerySmallScreen: isVerySmallScreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Personalized Tips Card
              SizedBox(height: isVerySmallScreen ? 12 : 18),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.lightGreen[100],
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.emoji_emotions,
                        color: Colors.green[600],
                        size: isVerySmallScreen ? 22 : 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _motivationalMessage,
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 14 : 16,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Manual Health Data Input Card
              SizedBox(height: isVerySmallScreen ? 12 : 18),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildHealthDataButton(
                                icon: Icons.directions_walk,
                                label: 'Steps',
                                value: '0',
                                color: Colors.blue,
                                isVerySmallScreen: isVerySmallScreen,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildHealthDataButton(
                                icon: Icons.favorite,
                                label: 'Heart Rate',
                                value: '0',
                                color: Colors.red,
                                isVerySmallScreen: isVerySmallScreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildHealthDataButton(
                                icon: Icons.bedtime,
                                label: 'Sleep',
                                value: '0h',
                                color: Colors.purple,
                                isVerySmallScreen: isVerySmallScreen,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildHealthDataButton(
                                icon: Icons.water_drop,
                                label: 'Water',
                                value: '${waterIntake}ml',
                                color: Colors.blue,
                                isVerySmallScreen: isVerySmallScreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Replace the Connect Platforms card in the Home tab with an enhanced version
              // Find the section in the Home tab (default) where the Connect Platforms card is built
              // Replace it with the following:
              // Modern Connect Platforms Preview Card
              SizedBox(height: isVerySmallScreen ? 16 : 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        primaryColor.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.link,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Health Platform Integration',
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    'Connect Google Fit or Health Connect',
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 12 : 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmallScreen ? 16 : 20),
                        Text(
                          'Seamlessly sync your health data from Google Fit or Health Connect to automatically track your fitness progress and maintain accurate calorie calculations.',
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 13 : 15,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: isVerySmallScreen ? 16 : 20),
                        // Enhanced Platform Preview Row - Fixed Overflow
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ModernPlatformPreview(
                                name: 'Health Connect',
                                icon: Icons.health_and_safety,
                                color: Color(0xFF4285F4),
                                recommended: true,
                              ),
                              SizedBox(width: 12),
                              _ModernPlatformPreview(
                                name: 'Google Fit',
                                icon: Icons.fitness_center,
                                color: Color(0xFF0F9D58),
                                recommended: false,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isVerySmallScreen ? 20 : 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to Connect Platforms Screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const ConnectPlatformsScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Manage Connections',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldMessengerKey,
            backgroundColor: backgroundColor,
            body: bodyContent,
            bottomNavigationBar: _buildBottomNavigationBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.black38,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: _selectedIndex,
      onTap: (index) async {
        if (index == 2) {
          // + button - show action sheet with options
          _showAddOptions();
        } else if (index == 3) {
          // Progress tab - show simple progress screen
          if (mounted) {
            setState(() {
              _selectedIndex = index;
            });
          }
        } else if (index == 4) {
          // More tab - show settings
          setState(() {
            _selectedIndex = index;
          });
        } else if (index == 1) {
          // Exercise tab: always show category picker first
          final selected = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.directions_run),
                      title: const Text('Cardio'),
                      onTap: () => Navigator.pop(context, 'Cardio'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: const Text('Strength'),
                      onTap: () => Navigator.pop(context, 'Strength'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Your Exercise'),
                      onTap: () => Navigator.pop(context, 'Your Exercise'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );

          if (selected != null && mounted) {
            if (selected == 'Your Exercise') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => YourExerciseScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        initialUserSex: userSex,
                      ),
                ),
              );
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ExerciseCategoryScreen(
                        category: selected,
                        usernameOrEmail: widget.usernameOrEmail,
                        initialUserSex: userSex,
                      ),
                ),
              );
            }
            if (mounted) {
              await _loadRemainingFromBackend();
            }
          }
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: const Icon(Icons.fitness_center),
          label: 'Exercise',
        ),
        BottomNavigationBarItem(
          icon: Container(
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.bar_chart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddOptionsSheet(
            onFoodLog: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ProfessionalFoodLogScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        userSex: userSex,
                      ),
                ),
              );
              if (result == true) {
                _refreshDashboard();
              }
            },
            onCustomMeals: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CustomMealsScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        userSex: userSex,
                      ),
                ),
              );
              if (result == true) {
                _refreshDashboard();
              }
            },
            userSex: userSex,
          ),
    );
  }

  String get _motivationalMessage {
    final percent = baseGoal > 0 ? foodCalories / baseGoal : 0;
    if (percent < 0.3) {
      return "Great start! Logging early helps you stay on track.";
    } else if (percent < 0.7) {
      return "You're halfway there! Keep it up!";
    } else if (percent < 1.0) {
      return "Almost done! Stay mindful of your choices.";
    } else {
      return "Awesome! You've reached your goal today.";
    }
  }

  Widget _buildHealthDataButton({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isVerySmallScreen,
  }) {
    return InkWell(
      onTap: () {
        // TODO: Implement manual health data input
        String message =
            label == 'Water'
                ? 'Water intake logging coming soon!'
                : 'Manual $label input coming soon!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 8 : 12,
          vertical: isVerySmallScreen ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isVerySmallScreen ? 16 : 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 10 : 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 11 : 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildCalorieStatColumn({
  required IconData icon,
  required Color color,
  required String label,
  required String value,
  required bool isVerySmallScreen,
}) {
  return Column(
    children: [
      Icon(icon, color: color, size: isVerySmallScreen ? 18 : 22),
      SizedBox(height: isVerySmallScreen ? 2 : 4),
      Text(
        label,
        style: TextStyle(
          fontSize: isVerySmallScreen ? 11 : 13,
          color: Colors.black54,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: isVerySmallScreen ? 12 : 14,
        ),
      ),
    ],
  );
}

class _ModernPlatformPreview extends StatefulWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool recommended;

  const _ModernPlatformPreview({
    required this.name,
    required this.icon,
    required this.color,
    required this.recommended,
  });

  @override
  State<_ModernPlatformPreview> createState() => _ModernPlatformPreviewState();
}

class _ModernPlatformPreviewState extends State<_ModernPlatformPreview> {
  bool connected = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    final statuses = await HealthService.getAllConnectionStatuses();
    if (mounted) {
      setState(() {
        connected = statuses[widget.name] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              connected
                  ? widget.color.withValues(alpha: 0.3)
                  : Colors.grey[300]!,
          width: connected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
              if (widget.recommended)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.star, color: Colors.white, size: 8),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 9,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                connected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: connected ? Colors.green : Colors.grey[400],
                size: 10,
              ),
              SizedBox(width: 2),
              Flexible(
                child: Text(
                  connected ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    fontSize: 7,
                    color: connected ? Colors.green : Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
