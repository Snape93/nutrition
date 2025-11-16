import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/emoji_selector.dart';
import 'widgets/sex_specific_theme.dart';
import '../design_system/app_design_system.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart' as config; // centralized apiBase
import '../home.dart'; // for HomePage
import 'package:nutrition_flutter/user_database.dart';
import '../utils/user_profile_helper.dart';

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
  bool _showCelebration = false;
  bool _isLoading = false;
  String? _errorMessage;
  int? _predictedCalories;
  int? _userAge; // Age fetched from backend
  bool _isLoadingAge = false;

  final List<String> _stepNames = [
    'Choose Your Goal',
    'Basic Information',
    'Activity & Lifestyle',
    'Food Preferences',
    'Complete Setup',
  ];

  final _scrollController = ScrollController();
  final _heightKey = GlobalKey();
  final _weightKey = GlobalKey();
  final _activityKey = GlobalKey();
  final _foodPrefKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchUserAge();
  }

  Future<void> _fetchUserAge() async {
    if (_userAge != null || _isLoadingAge) return;
    
    setState(() {
      _isLoadingAge = true;
    });

    try {
      final age = await UserProfileHelper.fetchUserAge(widget.usernameOrEmail);
      if (mounted) {
        setState(() {
          _userAge = age;
          _isLoadingAge = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user age: $e');
      if (mounted) {
        setState(() {
          _isLoadingAge = false;
        });
      }
    }
  }

  List<String> _getMissingFields() {
    final missing = <String>[];
    // Age is fetched from backend, not required from widget
    if (_userAge == null && _isLoadingAge == false) {
      missing.add('Age (unable to fetch from profile)');
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
    // Ensure age is fetched before submission
    if (_userAge == null && !_isLoadingAge) {
      await _fetchUserAge();
    }

    final data = {
      'username': widget.usernameOrEmail,
      'goal': widget.goal ?? '',
      'sex': widget.gender ?? '',
      'age': _userAge ?? widget.age ?? '',
      'height_cm': widget.height ?? '',
      'weight_kg': widget.weight ?? '',
      'target_weight': widget.targetWeight,
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
    // Removed free-text optional fields (allergies/favorites/dislikes). These can be set later in Settings.
    // Debug print
    debugPrint('Submitting onboarding data: $data');
    try {
      // 1. First try to update user profile, if user doesn't exist, create them
      debugPrint(
        'DEBUG: Attempting to update user profile at ${config.apiBase}/user/${widget.usernameOrEmail}',
      );
      var updateResp = await http.put(
        Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      debugPrint(
        'DEBUG: Profile update response status: ${updateResp.statusCode}',
      );
      debugPrint('DEBUG: Profile update response body: ${updateResp.body}');

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
            debugPrint('DEBUG: Retrying profile update after user creation...');
            updateResp = await http.put(
              Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );
            debugPrint(
              'DEBUG: Profile update retry response status: ${updateResp.statusCode}',
            );
            debugPrint(
              'DEBUG: Profile update retry response body: ${updateResp.body}',
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
      } else {
        debugPrint('DEBUG: Profile update successful!');
      }
      // 2. Get calorie prediction
      debugPrint(
        'DEBUG: Requesting calorie goal from ${config.apiBase}/calculate/daily_goal',
      );
      final calorieResp = await http.post(
        Uri.parse('${config.apiBase}/calculate/daily_goal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      debugPrint(
        'DEBUG: Calorie goal response status: ${calorieResp.statusCode}',
      );
      debugPrint('DEBUG: Calorie goal response body: ${calorieResp.body}');
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

      // Mark tutorial as seen after successful onboarding completion
      await UserDatabase().markTutorialAsSeen(widget.usernameOrEmail);

      // Proceed directly to home screen after onboarding
      if (mounted) {
        // Get the correct background color for transition
        final theme = SexSpecificTheme.getThemeFromString(widget.gender);
        final backgroundColor = theme.backgroundColor;
        
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HomePage(
                  usernameOrEmail: widget.usernameOrEmail,
                  initialUserSex: widget.gender, // Pass gender to avoid green flash
                ),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Use SlideTransition to cover old screen completely
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0), // Slide from right
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: backgroundColor, // Use theme background color, not green
                  child: child,
                ),
              );
            },
          ),
          (route) => false,
        );
      } else {
        debugPrint(
          'DEBUG: Calorie goal calculation failed with status ${calorieResp.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Exception during onboarding submission: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');
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

  /// Checks for Step 2 (Basic Information) fields only
  /// Age is fetched from backend, so we don't check it here
  bool _canProceedStep2() {
    return widget.height != null &&
        widget.height.toString().isNotEmpty &&
        widget.weight != null &&
        widget.weight.toString().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(widget.gender);
    final screenHeight = AppDesignSystem.getScreenHeight(context);
    final isVerySmallScreen = screenHeight < 600;

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
                      padding: AppDesignSystem.getResponsivePaddingExact(
                        context,
                        xs: 8,
                        sm: 12,
                        md: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, theme),
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
                          ),
                          Container(
                            key: _foodPrefKey,
                            child: Text(
                              'Select your food preferences',
                              style: TextStyle(
                                fontSize: AppDesignSystem.getResponsiveFontSize(
                                  context,
                                  xs: 14,
                                  sm: 16,
                                  md: 18,
                                ),
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 4,
                              sm: 6,
                              md: 8,
                            ),
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
                                  AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 4,
                                sm: 6,
                                md: 8,
                              ),
                            ),
                          _buildPreferenceInsight(context, theme),
                          ],
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
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
          minimum: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 12,
                        sm: 14,
                        md: 16,
                      ),
                    ),
                    side: BorderSide(color: theme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: AppDesignSystem.getResponsiveFontSize(
                        context,
                        xs: 14,
                        sm: 15,
                        md: 16,
                      ),
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: AppDesignSystem.getResponsiveSpacingExact(
                  context,
                  xs: 12,
                  sm: 14,
                  md: 16,
                ),
              ),
              Expanded(
                flex: 2,
                child: SexSpecificButton(
                  gender: widget.gender,
                  text: isVerySmallScreen ? 'Finish' : 'Finish Setup',
                  isEnabled: _canProceedStep2(),
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: _canProceedStep2() ? _finish : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    return Container(
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 8,
        sm: 10,
        md: 12,
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
            size: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 24,
              sm: 28,
              md: 32,
            ),
          ),
          SizedBox(
            width: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 8,
              md: 12,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Preferences',
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 16,
                      sm: 18,
                      md: 20,
                    ),
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                if (AppDesignSystem.getScreenHeight(context) >= 600) ...[
                  Text(
                    'Help us personalize your meal plan by sharing your preferences.',
                    style: TextStyle(
                      fontSize: AppDesignSystem.getResponsiveFontSize(
                        context,
                        xs: 10,
                        sm: 11,
                        md: 12,
                      ),
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

  // Note: Free-text fields removed from onboarding for safety and clarity.

  Widget _buildPreferenceInsight(
    BuildContext context,
    SexSpecificTheme theme,
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
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 8,
        sm: 10,
        md: 12,
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
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 18,
                sm: 20,
                md: 22,
              ),
            ),
          ),
          SizedBox(
            width: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 6,
              md: 8,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.label,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 12,
                      sm: 13,
                      md: 14,
                    ),
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                SizedBox(
                  height: AppDesignSystem.getResponsiveSpacingExact(
                    context,
                    xs: 2,
                    sm: 3,
                    md: 4,
                  ),
                ),
                Text(
                  selected.description,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 10,
                      sm: 11,
                      md: 12,
                    ),
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
