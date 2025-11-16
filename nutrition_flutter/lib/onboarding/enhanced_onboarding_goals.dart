import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/interactive_goal_card.dart';
import 'widgets/sex_specific_theme.dart';
import '../design_system/app_design_system.dart';

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
                      padding: AppDesignSystem.getResponsivePaddingExact(
                        context,
                        xs: 8, // < 360px
                        sm: 12, // 360-600px
                        md: 16, // 600-900px
                      ),
                      child: Column(
                        children: [
                          // Welcome message - more compact
                          _buildWelcomeMessage(context, theme),
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
                          ),

                          // Gender selection (always show, allow changing)
                          _buildGenderSelection(context, theme),
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
                          ),

                          // Goal selection - more compact
                          _buildGoalSelection(context, theme),

                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
                          ),

                          // Navigation button
                          _buildNavigationButton(theme),

                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 8,
                              sm: 12,
                              md: 16,
                            ),
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
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    return Container(
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 12,
        sm: 16,
        md: 20,
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
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 32,
                sm: 36,
                md: 48,
              ),
            ),
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 8,
              md: 12,
            ),
          ),
          Text(
            _selectedGender != null
                ? SexSpecificMessaging.getWelcomeMessage(_selectedGender)
                : 'Welcome to Your Personalized Nutrition Journey!',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 18,
                sm: 20,
                md: 24,
              ),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 3,
              sm: 4,
              md: 8,
            ),
          ),
          Text(
            _selectedGender != null
                ? SexSpecificMessaging.getMotivationalMessage(_selectedGender)
                : 'We\'ll create a nutrition plan tailored specifically for you. This takes just 2 minutes!',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 12,
                sm: 14,
                md: 16,
              ),
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
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    return Column(
      children: [
        Text(
          'First, tell us about yourself',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 16,
              sm: 18,
              md: 22,
            ),
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 8,
            sm: 12,
            md: 16,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildGenderCard(context, 'female', '👩', 'Female'),
            ),
            SizedBox(
              width: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 8,
                sm: 16,
                md: 16,
              ),
            ),
            Expanded(
              child: _buildGenderCard(context, 'male', '👨', 'Male'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderCard(
    BuildContext context,
    String gender,
    String emoji,
    String label,
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
        padding: AppDesignSystem.getResponsivePaddingExact(
          context,
          xs: 12,
          sm: 16,
          md: 20,
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
                fontSize: AppDesignSystem.getResponsiveFontSize(
                  context,
                  xs: 32,
                  sm: 36,
                  md: 48,
                ),
              ),
            ),
            SizedBox(
              height: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 3,
                sm: 4,
                md: 8,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: AppDesignSystem.getResponsiveFontSize(
                  context,
                  xs: 14,
                  sm: 16,
                  md: 18,
                ),
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
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s your main goal?',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 20,
              sm: 22,
              md: 28,
            ),
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 2,
            sm: 4,
            md: 8,
          ),
        ),
        Text(
          'Choose the goal that best describes what you want to achieve.',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 12,
              sm: 14,
              md: 16,
            ),
            color: Colors.grey[600],
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 8,
            sm: 12,
            md: 16,
          ),
        ),

        // Enhanced goal cards - more compact
        ...GoalOptions.getGoals().map((goal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 4,
                sm: 6,
                md: 8,
              ),
            ),
            child: _buildCompactGoalCard(
              context,
              goal,
              theme,
            ),
          );
        }),

        // Sex-specific encouragement message - more compact
        if (_selectedGoal != null && _selectedGender != null) ...[
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 8,
              md: 12,
            ),
          ),
          Container(
            padding: AppDesignSystem.getResponsivePaddingExact(
              context,
              xs: 8,
              sm: 10,
              md: 12,
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
                          fontSize: AppDesignSystem.getResponsiveFontSize(
                            context,
                            xs: 11,
                            sm: 13,
                            md: 14,
                          ),
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
                          fontSize: AppDesignSystem.getResponsiveFontSize(
                            context,
                            xs: 10,
                            sm: 11,
                            md: 12,
                          ),
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
    BuildContext context,
    GoalOption goal,
    SexSpecificTheme theme,
  ) {
    final isVerySmallScreen =
        AppDesignSystem.getScreenHeight(context) < 600;
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
          horizontal: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 8,
            sm: 12,
            md: 16,
          ),
          vertical: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 6,
            sm: 8,
            md: 12,
          ),
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
              width: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 35,
                sm: 40,
                md: 45,
              ),
              height: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 35,
                sm: 40,
                md: 45,
              ),
              decoration: BoxDecoration(
                color: goal.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  goal.emoji,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 18,
                      sm: 20,
                      md: 24,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 8,
                sm: 10,
                md: 12,
              ),
            ),

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
                            fontSize: AppDesignSystem.getResponsiveFontSize(
                              context,
                              xs: 14,
                              sm: 16,
                              md: 18,
                            ),
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
                              size: AppDesignSystem.getResponsiveFontSize(
                                context,
                                xs: 12,
                                sm: 12,
                                md: 14,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              goal.successRate.replaceAll(' success rate', ''),
                              style: TextStyle(
                                fontSize: AppDesignSystem.getResponsiveFontSize(
                                  context,
                                  xs: 10,
                                  sm: 10,
                                  md: 11,
                                ),
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
                    height: AppDesignSystem.getResponsiveSpacingExact(
                      context,
                      xs: 1,
                      sm: 2,
                      md: 3,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.subtitle,
                          style: TextStyle(
                            fontSize: AppDesignSystem.getResponsiveFontSize(
                              context,
                              xs: 10,
                              sm: 12,
                              md: 13,
                            ),
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
                            horizontal: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 6,
                              sm: 6,
                              md: 8,
                            ),
                            vertical: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 2,
                              sm: 2,
                              md: 3,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: goal.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            goal.benefit,
                            style: TextStyle(
                              fontSize: AppDesignSystem.getResponsiveFontSize(
                                context,
                                xs: 9,
                                sm: 9,
                                md: 10,
                              ),
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

            SizedBox(
              width: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 6,
                sm: 8,
                md: 10,
              ),
            ),

            // Selection indicator - smaller
            Container(
              width: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 18,
                sm: 20,
                md: 24,
              ),
              height: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 18,
                sm: 20,
                md: 24,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? goal.color : Colors.grey[300],
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: AppDesignSystem.getResponsiveFontSize(
                          context,
                          xs: 10,
                          sm: 12,
                          md: 14,
                        ),
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
