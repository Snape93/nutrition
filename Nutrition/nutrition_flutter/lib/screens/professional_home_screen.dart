import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';
import '../user_database.dart';
import 'professional_food_log_screen.dart';

/// Professional home screen with consistent design and no overfitting
class ProfessionalHomeScreen extends StatefulWidget {
  final String usernameOrEmail;

  const ProfessionalHomeScreen({super.key, required this.usernameOrEmail});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  int _selectedIndex = 0;
  String? userSex;

  // Calorie tracking
  int baseGoal = 2000;
  int foodCalories = 0;
  int exerciseCalories = 0;
  bool isLoading = false;
  String? _errorMessage;

  // Water intake
  int waterIntake = 0;
  int dailyWaterGoal = 2000;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Color get _primaryColor => AppDesignSystem.getPrimaryColor(userSex);
  Color get _backgroundColor => AppDesignSystem.getBackgroundColor(userSex);

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      await _loadUserSex();
      await _loadCalorieGoal();
      await _loadTodayCalories();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadUserSex() async {
    final sex = await UserDatabase().getUserSex(widget.usernameOrEmail);
    setState(() => userSex = sex);
  }

  Future<void> _loadCalorieGoal() async {
    // Load user's calorie goal from database
    // For now, using default value
  }

  Future<void> _loadTodayCalories() async {
    // Load today's calorie intake from database
    // For now, using default values
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildExerciseTab();
      case 2:
        return _buildFoodLogTab();
      case 3:
        return _buildProgressTab();
      case 4:
        return _buildSettingsTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spaceXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppDesignSystem.error),
              const SizedBox(height: AppDesignSystem.spaceLG),
              Text(
                'Something went wrong',
                style: AppDesignSystem.headlineSmall,
              ),
              const SizedBox(height: AppDesignSystem.spaceMD),
              Text(
                _errorMessage!,
                style: AppDesignSystem.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignSystem.spaceLG),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: SingleChildScrollView(
        padding: AppDesignSystem.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildCaloriesCard(),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildWaterIntakeCard(),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back!',
          style: AppDesignSystem.displaySmall.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: AppDesignSystem.spaceSM),
        Text(
          'Let\'s track your nutrition today',
          style: AppDesignSystem.bodyLarge.copyWith(
            color: AppDesignSystem.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesCard() {
    final remainingCalories = baseGoal - foodCalories + exerciseCalories;
    final progress =
        baseGoal > 0 ? (remainingCalories / baseGoal).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: AppDesignSystem.elevationMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Calories',
                  style: AppDesignSystem.titleLarge.copyWith(
                    color: _primaryColor,
                  ),
                ),
                Text(
                  '$foodCalories / $baseGoal',
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: _backgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$remainingCalories',
                      style: AppDesignSystem.displayMedium.copyWith(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'left',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterIntakeCard() {
    final progress =
        dailyWaterGoal > 0
            ? (waterIntake / dailyWaterGoal).clamp(0.0, 1.0)
            : 0.0;

    return Card(
      elevation: AppDesignSystem.elevationMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Water Intake',
                  style: AppDesignSystem.titleLarge.copyWith(
                    color: _primaryColor,
                  ),
                ),
                Text(
                  '$waterIntake / $dailyWaterGoal ml',
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: AppDesignSystem.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: _backgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 8,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildWaterButton(250, 'Small'),
                _buildWaterButton(500, 'Medium'),
                _buildWaterButton(750, 'Large'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterButton(int amount, String label) {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          waterIntake = (waterIntake + amount).clamp(0, dailyWaterGoal);
        });
      },
      icon: const Icon(Icons.water_drop),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor.withValues(alpha: 0.1),
        foregroundColor: _primaryColor,
        elevation: 0,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppDesignSystem.headlineSmall.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.restaurant_menu,
                title: 'Log Food',
                subtitle: 'Track your meals',
                onTap: () => _navigateToFoodLog(),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spaceMD),
            Expanded(
              child: _buildActionCard(
                icon: Icons.fitness_center,
                title: 'Exercise',
                subtitle: 'Log workouts',
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.trending_up,
                title: 'Progress',
                subtitle: 'View your stats',
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spaceMD),
            Expanded(
              child: _buildActionCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'App preferences',
                onTap: () => setState(() => _selectedIndex = 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: AppDesignSystem.elevationLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
          child: Column(
            children: [
              Icon(icon, color: _primaryColor, size: 32),
              const SizedBox(height: AppDesignSystem.spaceMD),
              Text(
                title,
                style: AppDesignSystem.titleMedium.copyWith(
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spaceXS),
              Text(
                subtitle,
                style: AppDesignSystem.bodySmall.copyWith(
                  color: AppDesignSystem.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: _primaryColor),
          const SizedBox(height: AppDesignSystem.spaceLG),
          Text(
            'Exercise Tracking',
            style: AppDesignSystem.headlineLarge.copyWith(color: _primaryColor),
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'Coming soon! Track your workouts and activities.',
            style: AppDesignSystem.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogTab() {
    return ProfessionalFoodLogScreen(
      usernameOrEmail: widget.usernameOrEmail,
      userSex: userSex,
    );
  }

  Widget _buildProgressTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: _primaryColor),
          const SizedBox(height: AppDesignSystem.spaceLG),
          Text(
            'Progress Tracking',
            style: AppDesignSystem.headlineLarge.copyWith(color: _primaryColor),
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'View your nutrition progress and insights.',
            style: AppDesignSystem.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: _primaryColor),
          const SizedBox(height: AppDesignSystem.spaceLG),
          Text(
            'Settings',
            style: AppDesignSystem.headlineLarge.copyWith(color: _primaryColor),
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'Manage your app preferences and account.',
            style: AppDesignSystem.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      backgroundColor: AppDesignSystem.surface,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _primaryColor,
      unselectedItemColor: AppDesignSystem.onSurfaceVariant,
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 2) {
          _navigateToFoodLog();
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Exercise',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Log Food'),
        BottomNavigationBarItem(
          icon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  Future<void> _navigateToFoodLog() async {
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

    if (result == true && mounted) {
      _loadUserData();
    }
  }
}
