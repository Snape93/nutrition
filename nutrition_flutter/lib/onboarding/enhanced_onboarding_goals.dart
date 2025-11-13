import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/interactive_goal_card.dart';
import 'widgets/sex_specific_theme.dart';

class EnhancedOnboardingGoals extends StatefulWidget {
  final String usernameOrEmail;

  const EnhancedOnboardingGoals({super.key, required this.usernameOrEmail});

  @override
  State<EnhancedOnboardingGoals> createState() =>
      _EnhancedOnboardingGoalsState();
}

class _EnhancedOnboardingGoalsState extends State<EnhancedOnboardingGoals>
    with TickerProviderStateMixin {
  String? _selectedGoal;
  String? _selectedGender;
  bool _showCelebration = false;

  final List<String> _stepNames = [
    'Choose Your Goal',
    'Basic Information',
    'Activity & Lifestyle',
    'Food Preferences',
    'Complete Setup',
  ];

  void _continue() {
    if (_selectedGender == null) {
      _showGenderRequiredWarning();
      return;
    }
    
    if (_selectedGoal != null) {
      setState(() {
        _showCelebration = true;
      });

      // Navigate after celebration
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/onboarding/physical',
            arguments: {
              'goal': _selectedGoal,
              'gender': _selectedGender,
              'usernameOrEmail': widget.usernameOrEmail,
            },
          );
        }
      });
    }
  }

  void _showGenderRequiredWarning() {
    // Use neutral theme since gender isn't selected yet
    final neutralTheme = SexSpecificTheme.getThemeFromString(null);
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: neutralTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning icon with professional styling
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Gender Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: neutralTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Message
                Text(
                  'Please select your gender first before choosing a goal. This helps us create a personalized nutrition plan tailored specifically for you.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // OK button with theme styling
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neutralTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: neutralTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(_selectedGender);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;

    return SexSpecificBackground(
      gender: _selectedGender,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Enhanced progress bar - more compact for small screens
                  AnimatedProgressBar(
                    currentStep: 1,
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

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isNarrowScreen ? 8 : (isSmallScreen ? 12 : 16),
                        vertical:
                            isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
                      ),
                      child: Column(
                        children: [
                          // Welcome message - more compact
                          _buildWelcomeMessage(
                            theme,
                            isSmallScreen,
                            isVerySmallScreen,
                          ),
                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),

                          // Gender selection (always show, allow changing)
                          _buildGenderSelection(
                            theme,
                            isSmallScreen,
                            isVerySmallScreen,
                          ),
                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),

                          // Goal selection - more compact
                          _buildGoalSelection(
                            theme,
                            isSmallScreen,
                            isVerySmallScreen,
                          ),

                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),

                          // Navigation button
                          _buildNavigationButton(theme),

                          SizedBox(
                            height:
                                isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Celebration overlay
              CelebrationOverlay(
                show: _showCelebration,
                color: theme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _selectedGender != null
                ? (_selectedGender == 'female' ? '💕' : '💪')
                : '🎯',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 32 : (isSmallScreen ? 36 : 48),
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
          Text(
            _selectedGender != null
                ? SexSpecificMessaging.getWelcomeMessage(_selectedGender)
                : 'Welcome to Your Personalized Nutrition Journey!',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 8)),
          Text(
            _selectedGender != null
                ? SexSpecificMessaging.getMotivationalMessage(_selectedGender)
                : 'We\'ll create a nutrition plan tailored specifically for you. This takes just 2 minutes!',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelection(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      children: [
        Text(
          'First, tell us about yourself',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 22),
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
        Row(
          children: [
            Expanded(
              child: _buildGenderCard(
                'female',
                '👩',
                'Female',
                isSmallScreen,
                isVerySmallScreen,
              ),
            ),
            SizedBox(width: isVerySmallScreen ? 8 : 16),
            Expanded(
              child: _buildGenderCard(
                'male',
                '👨',
                'Male',
                isSmallScreen,
                isVerySmallScreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderCard(
    String gender,
    String emoji,
    String label,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    final isSelected = _selectedGender == gender;
    final cardTheme = SexSpecificTheme.getThemeFromString(gender);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(
          isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20),
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? cardTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cardTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? cardTheme.primaryColor.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 32 : (isSmallScreen ? 36 : 48),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 8)),
            Text(
              label,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                fontWeight: FontWeight.bold,
                color: isSelected ? cardTheme.primaryColor : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSelection(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s your main goal?',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 28),
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 8)),
        Text(
          'Choose the goal that best describes what you want to achieve.',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),

        // Enhanced goal cards - more compact
        ...GoalOptions.getGoals().map((goal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
            ),
            child: _buildCompactGoalCard(
              goal,
              theme,
              isSmallScreen,
              isVerySmallScreen,
            ),
          );
        }),

        // Sex-specific encouragement message - more compact
        if (_selectedGoal != null && _selectedGender != null) ...[
          SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
          Container(
            padding: EdgeInsets.all(
              isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
            ),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(theme.genderIcon, color: theme.primaryColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalized for You',
                        style: TextStyle(
                          fontSize:
                              isVerySmallScreen
                                  ? 11
                                  : (isSmallScreen ? 13 : 14),
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        SexSpecificMessaging.getGoalMessage(
                          _selectedGender,
                          _selectedGoal!,
                        ),
                        style: TextStyle(
                          fontSize:
                              isVerySmallScreen
                                  ? 10
                                  : (isSmallScreen ? 11 : 12),
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactGoalCard(
    GoalOption goal,
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    final isSelected = _selectedGoal == goal.id;

    return GestureDetector(
      onTap: () {
        // Check if gender is selected before allowing goal selection
        if (_selectedGender == null) {
          _showGenderRequiredWarning();
          return;
        }
        
        setState(() {
          _selectedGoal = goal.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
          vertical: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12),
        ),
        decoration: BoxDecoration(
          color: isSelected ? goal.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? goal.color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? goal.color.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
              blurRadius: isSelected ? 4 : 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji container - much smaller
            Container(
              width: isVerySmallScreen ? 35 : (isSmallScreen ? 40 : 45),
              height: isVerySmallScreen ? 35 : (isSmallScreen ? 40 : 45),
              decoration: BoxDecoration(
                color: goal.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  goal.emoji,
                  style: TextStyle(
                    fontSize:
                        isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
                  ),
                ),
              ),
            ),
            SizedBox(width: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),

            // Content - very compact
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontSize:
                                isVerySmallScreen
                                    ? 14
                                    : (isSmallScreen ? 16 : 18),
                            fontWeight: FontWeight.bold,
                            color: isSelected ? goal.color : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Success rate inline
                      if (!isVerySmallScreen) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green,
                              size: isSmallScreen ? 12 : 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              goal.successRate.replaceAll(' success rate', ''),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  SizedBox(
                    height: isVerySmallScreen ? 1 : (isSmallScreen ? 2 : 3),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.subtitle,
                          style: TextStyle(
                            fontSize:
                                isVerySmallScreen
                                    ? 10
                                    : (isSmallScreen ? 12 : 13),
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isVerySmallScreen) ...[
                        const SizedBox(width: 8),
                        // Benefit badge - smaller
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6 : 8,
                            vertical: isSmallScreen ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: goal.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            goal.benefit,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              color: goal.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),

            // Selection indicator - smaller
            Container(
              width: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
              height: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? goal.color : Colors.grey[300],
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size:
                            isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(SexSpecificTheme theme) {
    return SizedBox(
      width: double.infinity,
      child: SexSpecificButton(
        gender: _selectedGender,
        text: 'Continue to Basic Information',
        isEnabled: _selectedGoal != null && _selectedGender != null,
        icon: const Icon(Icons.arrow_forward, color: Colors.white),
        onPressed: _continue,
      ),
    );
  }
}
