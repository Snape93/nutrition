import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/emoji_selector.dart';
import 'widgets/sex_specific_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart' as config; // centralized apiBase
import '../../home.dart'; // for HomePage
import 'package:nutrition_flutter/user_database.dart';

class EnhancedOnboardingNutrition extends StatefulWidget {
  final String usernameOrEmail;
  final String? goal;
  final String? gender;
  final int? age;
  final double? height;
  final double? weight;
  final double? targetWeight;
  final String? activityLevel;
  final String? currentMood;
  final String? energyLevel;

  const EnhancedOnboardingNutrition({
    super.key,
    required this.usernameOrEmail,
    this.goal,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.targetWeight,
    this.activityLevel,
    this.currentMood,
    this.energyLevel,
  });

  @override
  State<EnhancedOnboardingNutrition> createState() =>
      _EnhancedOnboardingNutritionState();
}

class _EnhancedOnboardingNutritionState
    extends State<EnhancedOnboardingNutrition>
    with TickerProviderStateMixin {
  List<String> _selectedPreferences = [];
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _favoritesController = TextEditingController();
  final TextEditingController _dislikesController = TextEditingController();
  bool _showCelebration = false;
  bool _isLoading = false;
  String? _errorMessage;
  int? _predictedCalories;

  final List<String> _stepNames = [
    'Choose Your Goal',
    'Basic Information',
    'Activity & Lifestyle',
    'Food Preferences',
    'Complete Setup',
  ];

  final _scrollController = ScrollController();
  final _ageKey = GlobalKey();
  final _heightKey = GlobalKey();
  final _weightKey = GlobalKey();
  final _activityKey = GlobalKey();
  final _foodPrefKey = GlobalKey();

  @override
  void dispose() {
    _allergiesController.dispose();
    _favoritesController.dispose();
    _dislikesController.dispose();
    super.dispose();
  }

  List<String> _getMissingFields() {
    final missing = <String>[];
    if (widget.age == null ||
        widget.age.toString().isEmpty ||
        widget.age.toString().toLowerCase() == 'no') {
      missing.add('Age');
    }
    if (widget.height == null ||
        widget.height.toString().isEmpty ||
        widget.height.toString().toLowerCase() == 'no') {
      missing.add('Height');
    }
    if (widget.weight == null ||
        widget.weight.toString().isEmpty ||
        widget.weight.toString().toLowerCase() == 'no') {
      missing.add('Weight');
    }
    if (widget.activityLevel == null ||
        widget.activityLevel.toString().isEmpty ||
        widget.activityLevel.toString().toLowerCase() == 'no') {
      missing.add('Activity Level');
    }
    if (widget.goal == null ||
        widget.goal.toString().isEmpty ||
        widget.goal.toString().toLowerCase() == 'no') {
      missing.add('Goal');
    }
    if (widget.gender == null ||
        widget.gender.toString().isEmpty ||
        widget.gender.toString().toLowerCase() == 'no') {
      missing.add('Sex');
    }
    if (_selectedPreferences.isEmpty) missing.add('Food Preferences');
    // Do NOT require allergies, favorites, dislikes
    return missing;
  }

  void _scrollToField(String field) {
    final contextMap = {
      'Age': _ageKey,
      'Height': _heightKey,
      'Weight': _weightKey,
      'Activity Level': _activityKey,
      'Food Preferences': _foodPrefKey,
    };
    final key = contextMap[field];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitOnboarding() async {
    final missing = _getMissingFields();
    if (missing.isNotEmpty) {
      setState(() {
        _errorMessage = 'Please fill in:  ${missing.join(', ')}';
      });
      _scrollToField(missing.first);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final data = {
      'username': widget.usernameOrEmail,
      'goal': widget.goal ?? '',
      'sex': widget.gender ?? '',
      'age': widget.age ?? '',
      'height_cm': widget.height ?? '',
      'weight_kg': widget.weight ?? '',
      'target_weight_kg': widget.targetWeight,
      'activity_level': widget.activityLevel ?? '',
      'currentMood': widget.currentMood ?? '',
      'energyLevel': widget.energyLevel ?? '',
      'foodPreferences': _selectedPreferences,
      // Add exercise-related fields if present in arguments
      'exercise_types':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['exercise_types'],
      'exercise_equipment':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['exercise_equipment'],
      'exercise_experience':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['exercise_experience'],
      'exercise_limitations':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['exercise_limitations'],
      'workout_duration':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['workout_duration'],
      'workout_frequency':
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?)?['workout_frequency'],
    };
    // Only add optional fields if not empty, not 'none', and not 'no'
    if (_allergiesController.text.trim().isNotEmpty &&
        _allergiesController.text.trim().toLowerCase() != 'none' &&
        _allergiesController.text.trim().toLowerCase() != 'no') {
      data['allergies'] = _allergiesController.text.trim();
    }
    if (_favoritesController.text.trim().isNotEmpty &&
        _favoritesController.text.trim().toLowerCase() != 'none' &&
        _favoritesController.text.trim().toLowerCase() != 'no') {
      data['favorites'] = _favoritesController.text.trim();
    }
    if (_dislikesController.text.trim().isNotEmpty &&
        _dislikesController.text.trim().toLowerCase() != 'none' &&
        _dislikesController.text.trim().toLowerCase() != 'no') {
      data['dislikes'] = _dislikesController.text.trim();
    }
    // Debug print
    debugPrint('Submitting onboarding data: $data');
    try {
      // 1. First try to update user profile, if user doesn't exist, create them
      var updateResp = await http.put(
        Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // If user not found, create the user first
      if (updateResp.statusCode == 404) {
        debugPrint('User not found in backend, creating user first...');

        // Get user data from local database
        final userData = await UserDatabase().getUserData(
          widget.usernameOrEmail,
        );
        if (userData != null) {
          final createData = {
            'username': userData['username'],
            'email': userData['email'],
            'password': userData['password'],
            'full_name': userData['full_name'],
          };

          final createResp = await http.post(
            Uri.parse('${config.apiBase}/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(createData),
          );

          debugPrint(
            'Backend create response: ${createResp.statusCode} - ${createResp.body}',
          );
          debugPrint('Create data sent: $createData');

          if (createResp.statusCode == 200 || createResp.statusCode == 201) {
            // Now try to update the profile again
            updateResp = await http.put(
              Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );
          } else {
            debugPrint(
              'Failed to create user in backend: ${createResp.statusCode} - ${createResp.body}',
            );
            // Continue with local database only if backend fails
            debugPrint('Continuing with local database only...');
          }
        }
      }

      // Only fail if we can't update the profile and backend creation also failed
      if (updateResp.statusCode != 200) {
        debugPrint(
          'Profile update failed: ${updateResp.statusCode} - ${updateResp.body}',
        );
        // Continue with local database only
        debugPrint('Continuing with local database only...');
      }
      // 2. Get calorie prediction
      final calorieResp = await http.post(
        Uri.parse('${config.apiBase}/calculate/daily_goal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (calorieResp.statusCode == 200) {
        final result = jsonDecode(calorieResp.body);
        setState(() {
          _predictedCalories =
              result['daily_calorie_goal'] ?? result['calories'];
        });
        // Update local database with new calorie goal
        if (_predictedCalories != null) {
          await UserDatabase().setDailyCalorieGoal(
            widget.usernameOrEmail,
            _predictedCalories!,
          );
        }
      }
      setState(() {
        _isLoading = false;
      });

      // Update local database with comprehensive user data
      final db = await UserDatabase().database;
      await db.update(
        'users',
        {
          'sex': widget.gender,
          'height': widget.height,
          'weight': widget.weight,
          'target_weight': widget.targetWeight,
          'activity_level': widget.activityLevel,
          'goal': widget.goal,
          'current_mood': widget.currentMood,
          'energy_level': widget.energyLevel,
          'dietary_preferences': _selectedPreferences.join(','),
          'allergies': _allergiesController.text.trim(),
          'favorites': _favoritesController.text.trim(),
          'dislikes': _dislikesController.text.trim(),
          'daily_calorie_goal': _predictedCalories,
        },
        where: 'username = ? OR email = ?',
        whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
      );

      // Mark tutorial as seen after successful onboarding completion
      await UserDatabase().markTutorialAsSeen(widget.usernameOrEmail);

      // Proceed directly to home screen after onboarding
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomePage(usernameOrEmail: widget.usernameOrEmail),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  void _finish() {
    _submitOnboarding();
  }

  bool _canProceed() {
    return _selectedPreferences.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(widget.gender);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;

    return SexSpecificBackground(
      gender: widget.gender,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  AnimatedProgressBar(
                    currentStep: 4,
                    totalSteps: 5,
                    stepNames: _stepNames,
                    primaryColor: theme.primaryColor,
                    showCelebration: _showCelebration,
                    onCelebrationComplete: () {
                      setState(() {
                        _showCelebration = false;
                      });
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isNarrowScreen ? 8 : (isSmallScreen ? 12 : 16),
                        vertical:
                            isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(theme, isSmallScreen, isVerySmallScreen),
                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),
                          Container(
                            key: _foodPrefKey,
                            child: Text(
                              'Select your food preferences',
                              style: TextStyle(
                                fontSize:
                                    isVerySmallScreen
                                        ? 14
                                        : (isSmallScreen ? 16 : 18),
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            height:
                                isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                          ),
                          EmojiSelector(
                            options: EmojiOptions.getFoodPreferenceOptions(),
                            selectedValues: _selectedPreferences,
                            allowMultipleSelection: true,
                            onMultipleChanged: (values) {
                              setState(() {
                                _selectedPreferences = values;
                              });
                            },
                            onChanged: (_) {},
                            title: '',
                            primaryColor: theme.primaryColor,
                          ),
                          if (_selectedPreferences.isNotEmpty) ...[
                            SizedBox(
                              height:
                                  isVerySmallScreen
                                      ? 4
                                      : (isSmallScreen ? 6 : 8),
                            ),
                            _buildPreferenceInsight(
                              theme,
                              isSmallScreen,
                              isVerySmallScreen,
                            ),
                          ],
                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),
                          Container(
                            key: _ageKey,
                            child: _buildTextField(
                              controller: _allergiesController,
                              label: 'Allergies (comma separated)',
                              icon: Icons.warning_amber_rounded,
                              theme: theme,
                              isSmallScreen: isSmallScreen,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Container(
                            key: _heightKey,
                            child: _buildTextField(
                              controller: _favoritesController,
                              label: 'Favorite Foods (comma separated)',
                              icon: Icons.favorite,
                              theme: theme,
                              isSmallScreen: isSmallScreen,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Container(
                            key: _weightKey,
                            child: _buildTextField(
                              controller: _dislikesController,
                              label: 'Disliked Foods (comma separated)',
                              icon: Icons.block,
                              theme: theme,
                              isSmallScreen: isSmallScreen,
                            ),
                          ),
                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),
                          if (_isLoading)
                            Center(child: CircularProgressIndicator()),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_showCelebration)
                CelebrationOverlay(
                  show: _showCelebration,
                  color: theme.primaryColor,
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: EdgeInsets.only(bottom: 12, left: 12, right: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 16,
                    ),
                    side: BorderSide(color: theme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isVerySmallScreen ? 12 : 16),
              Expanded(
                flex: 2,
                child: SexSpecificButton(
                  gender: widget.gender,
                  text: isVerySmallScreen ? 'Finish' : 'Finish Setup',
                  isEnabled: _canProceed(),
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: _canProceed() ? _finish : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant,
            color: theme.primaryColor,
            size: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
          ),
          SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Preferences',
                  style: TextStyle(
                    fontSize:
                        isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                if (!isVerySmallScreen) ...[
                  Text(
                    'Help us personalize your meal plan by sharing your preferences.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required SexSpecificTheme theme,
    required bool isSmallScreen,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label (optional)',
        prefixIcon: Icon(icon, color: theme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
    );
  }

  Widget _buildPreferenceInsight(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    final selected =
        _selectedPreferences.isNotEmpty
            ? EmojiOptions.getFoodPreferenceOptions().firstWhere(
              (o) => o.value == _selectedPreferences.first,
              orElse: () => EmojiOptions.getFoodPreferenceOptions().first,
            )
            : null;
    if (selected == null) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.all(
        isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            selected.emoji,
            style: TextStyle(fontSize: isSmallScreen ? 18 : 22),
          ),
          SizedBox(width: isVerySmallScreen ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  selected.description,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
