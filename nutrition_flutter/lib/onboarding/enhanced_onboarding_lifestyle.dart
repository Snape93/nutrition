import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/emoji_selector.dart';
import 'widgets/sex_specific_theme.dart';
import '../design_system/app_design_system.dart';

class EnhancedOnboardingLifestyle extends StatefulWidget {
  final String usernameOrEmail;

  const EnhancedOnboardingLifestyle({super.key, required this.usernameOrEmail});

  @override
  State<EnhancedOnboardingLifestyle> createState() =>
      _EnhancedOnboardingLifestyleState();
}

class _EnhancedOnboardingLifestyleState
    extends State<EnhancedOnboardingLifestyle>
    with TickerProviderStateMixin {
  // Data from previous steps
  String? _selectedGoal;
  String? _selectedGender;
  double? _height;
  double? _weight;
  double? _targetWeight;

  // Current step data
  String? _activityLevel;
  String? _currentMood;
  String? _energyLevel;
  bool _showCelebration = false;

  final List<String> _stepNames = [
    'Choose Your Goal',
    'Basic Information',
    'Activity & Lifestyle',
    'Food Preferences',
    'Complete Setup',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get data from previous steps
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _selectedGoal = args['goal'] as String?;
      _selectedGender = args['gender'] as String?;
      _height = args['height'] as double?;
      _weight = args['weight'] as double?;
      _targetWeight = args['targetWeight'] as double?;
    }
  }

  void _continue() {
    if (_canProceed()) {
      setState(() {
        _showCelebration = true;
      });
      // Navigate after celebration
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/onboarding/enhanced_nutrition',
            arguments: {
              'goal': _selectedGoal,
              'gender': _selectedGender,
              'height': _height,
              'weight': _weight,
              'targetWeight': _targetWeight,
              'usernameOrEmail': widget.usernameOrEmail,
              'activityLevel': _activityLevel,
              'currentMood': _currentMood,
              'energyLevel': _energyLevel,
            },
          );
        }
      });
    }
  }

  bool _canProceed() {
    // Make step 3 less strict: require activity level only; mood/energy optional
    return _activityLevel != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SexSpecificTheme.getThemeFromString(_selectedGender);
    final screenHeight = AppDesignSystem.getScreenHeight(context);
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return SexSpecificBackground(
      gender: _selectedGender,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Enhanced progress bar
                  AnimatedProgressBar(
                    currentStep: 3,
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
                        xs: 8,
                        sm: 12,
                        md: 16,
                      ),
                      child: Column(
                        children: [
                          // Header - more compact
                          _buildCompactHeader(context, theme),
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 6,
                              sm: 8,
                              md: 12,
                            ),
                          ),

                          // Activity level selection - more compact
                          _buildCompactEmojiSelector(
                            context: context,
                            title: 'Activity Level',
                            options: EmojiOptions.getActivityOptions(),
                            selectedValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value;
                              });
                            },
                            theme: theme,
                          ),

                          // Show compliment for Activity Level as soon as it's selected
                          if (_activityLevel != null) ...[
                            _buildActivityLevelCompliment(
                              context,
                              theme,
                            ),
                            SizedBox(
                              height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 4,
                                sm: 6,
                                md: 8,
                              ),
                            ),
                          ],

                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 6,
                              sm: 8,
                              md: 12,
                            ),
                          ),

                          // Mood and Energy - always in one row for small screens, better layout for very small screens
                          if (isSmallScreen) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactEmojiSelector(
                                    context: context,
                                    title: 'Mood',
                                    options:
                                        EmojiOptions.getMoodOptions()
                                            .take(isVerySmallScreen ? 2 : 3)
                                            .toList(),
                                    selectedValue: _currentMood,
                                    onChanged: (value) {
                                      setState(() {
                                        _currentMood = value;
                                      });
                                    },
                                    theme: theme,
                                    crossAxisCount: 1,
                                    hideLabelOnSmallScreen: true,
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
                                  child: _buildCompactEmojiSelector(
                                    context: context,
                                    title: 'Energy',
                                    options: EmojiOptions.getEnergyOptions(),
                                    selectedValue: _energyLevel,
                                    onChanged: (value) {
                                      setState(() {
                                        _energyLevel = value;
                                      });
                                    },
                                    theme: theme,
                                    crossAxisCount: 1,
                                    hideLabelOnSmallScreen: true,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Current mood selection
                            EmojiSelector(
                              title: 'How are you feeling today?',
                              subtitle:
                                  'This helps us personalize your experience',
                              options: EmojiOptions.getMoodOptions(),
                              selectedValue: _currentMood,
                              onChanged: (value) {
                                setState(() {
                                  _currentMood = value;
                                });
                              },
                              primaryColor: theme.primaryColor,
                            ),

                            const SizedBox(height: 16),

                            // Energy level selection
                            EmojiSelector(
                              title: 'Energy Level',
                              subtitle: 'How energetic do you feel right now?',
                              options: EmojiOptions.getEnergyOptions(),
                              selectedValue: _energyLevel,
                              onChanged: (value) {
                                setState(() {
                                  _energyLevel = value;
                                });
                              },
                              primaryColor: theme.primaryColor,
                            ),
                          ],

                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 4,
                              sm: 6,
                              md: 8,
                            ),
                          ),

                          // Compact insights
                          if (_canProceed()) ...[
                            _buildCompactInsights(
                                context,
                              theme,
                            ),
                            SizedBox(
                                height: AppDesignSystem.getResponsiveSpacingExact(
                                  context,
                                  xs: 4,
                                  sm: 6,
                                  md: 8,
                                ),
                            ),
                          ],

                          // Remove navigation buttons from here
                          // Navigation buttons will be placed in bottomNavigationBar
                          SizedBox(
                            height: AppDesignSystem.getResponsiveSpacingExact(
                              context,
                              xs: 6,
                              sm: 8,
                              md: 12,
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
        bottomNavigationBar: SafeArea(
          minimum: EdgeInsets.only(bottom: 12, left: 12, right: 12),
          child: _buildNavigationButtons(
            context,
            theme,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(
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
          Text(
            _selectedGender == 'female' ? '🌸' : '⚡',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 24,
                sm: 28,
                md: 32,
              ),
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
                  'Activity & Lifestyle',
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
                    SexSpecificMessaging.getEncouragementMessage(
                      _selectedGender,
                      'lifestyle',
                    ),
                    style: TextStyle(
                      fontSize: AppDesignSystem.getResponsiveFontSize(
                        context,
                        xs: 10,
                        sm: 10,
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

  Widget _buildCompactEmojiSelector({
    required BuildContext context,
    required String title,
    required List<EmojiOption> options,
    required String? selectedValue,
    required ValueChanged<String> onChanged,
    required SexSpecificTheme theme,
    int? crossAxisCount,
    bool hideLabelOnSmallScreen = false,
  }) {
    final screenHeight = AppDesignSystem.getScreenHeight(context);
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final labelFontSize = AppDesignSystem.getResponsiveFontSize(
      context,
      xs: 8,
      sm: 9,
      md: 10,
    );
    final gridSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 2,
      sm: 4,
      md: 6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 12,
              sm: 14,
              md: 16,
            ),
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: gridSpacing),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount ?? (options.length > 4 ? 3 : 2),
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio:
                isVerySmallScreen ? 2.0 : (isSmallScreen ? 1.6 : 1.4),
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = selectedValue == option.value;
            return GestureDetector(
              onTap: () => onChanged(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: AppDesignSystem.getResponsiveSpacingExact(
                    context,
                    xs: 0,
                    sm: 2,
                    md: 4,
                  ),
                  horizontal: AppDesignSystem.getResponsiveSpacingExact(
                    context,
                    xs: 2,
                    sm: 4,
                    md: 6,
                  ),
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? theme.primaryColor.withValues(alpha: 0.15)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? theme.primaryColor : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isSelected
                              ? theme.primaryColor.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: isSelected ? 4 : 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.emoji,
                      style: TextStyle(
                        fontSize: AppDesignSystem.getResponsiveFontSize(
                          context,
                          xs: 14,
                          sm: 16,
                          md: 18,
                        ),
                      ),
                    ),
                    if (!(hideLabelOnSmallScreen && isVerySmallScreen)) ...[
                      SizedBox(
                        height: AppDesignSystem.getResponsiveSpacingExact(
                          context,
                          xs: 1,
                          sm: 1,
                          md: 2,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: labelFontSize,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color:
                                isSelected
                                    ? theme.primaryColor
                                    : Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getPersonalizedTip() {
    final isFemale = _selectedGender?.toLowerCase() == 'female';

    if (_energyLevel == 'low' || _energyLevel == 'very_low') {
      if (isFemale) {
        return 'Low energy can be related to iron levels. We\'ll include iron-rich foods in your meal plan.';
      } else {
        return 'For sustained energy, we\'ll focus on complex carbs and protein timing.';
      }
    } else if (_currentMood == 'stressed') {
      if (isFemale) {
        return 'Magnesium-rich foods can help with stress and hormonal balance.';
      } else {
        return 'We\'ll include omega-3 rich foods to support stress management.';
      }
    } else if (_activityLevel == 'very_active') {
      if (isFemale) {
        return 'Active women need extra attention to hydration and electrolyte balance.';
      } else {
        return 'High activity requires optimized protein timing for recovery.';
      }
    } else {
      if (isFemale) {
        return 'We\'ll create a plan that supports your natural energy cycles.';
      } else {
        return 'Your nutrition plan will be optimized for sustained energy and performance.';
      }
    }
  }

  Widget _buildCompactInsights(
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
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insights,
            color: theme.primaryColor,
            size: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 16,
              sm: 18,
              md: 18,
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
            child: Text(
              _getPersonalizedTip(),
              style: TextStyle(
                fontSize: AppDesignSystem.getResponsiveFontSize(
                  context,
                  xs: 9,
                  sm: 11,
                  md: 12,
                ),
                color: Colors.grey[700],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelCompliment(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    final selected = EmojiOptions.getActivityOptions().firstWhere(
      (o) => o.value == _activityLevel,
      orElse: () => EmojiOptions.getActivityOptions().first,
    );
    return Container(
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

  Widget _buildNavigationButtons(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    final screenHeight = AppDesignSystem.getScreenHeight(context);
    final isVerySmallScreen = screenHeight < 600;
    return Row(
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
            gender: _selectedGender,
            text:
                isVerySmallScreen ? 'Continue' : 'Continue to Food Preferences',
            isEnabled: _canProceed(),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: _continue,
          ),
        ),
      ],
    );
  }
}
