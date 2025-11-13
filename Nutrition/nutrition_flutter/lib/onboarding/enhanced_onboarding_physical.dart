import 'package:flutter/material.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/calorie_calculator.dart';
import 'widgets/sex_specific_theme.dart';

class EnhancedOnboardingPhysical extends StatefulWidget {
  final String usernameOrEmail;

  const EnhancedOnboardingPhysical({super.key, required this.usernameOrEmail});

  @override
  State<EnhancedOnboardingPhysical> createState() =>
      _EnhancedOnboardingPhysicalState();
}

class _EnhancedOnboardingPhysicalState extends State<EnhancedOnboardingPhysical>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Data from previous step
  String? _selectedGoal;
  String? _selectedGender;

  // Current step data
  int? _age;
  double? _height;
  double? _weight;
  double? _targetWeight;
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

    // Get data from previous step
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _selectedGoal = args['goal'] as String?;
      _selectedGender = args['gender'] as String?;
    }
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      setState(() {
        _showCelebration = true;
      });

      // Navigate after celebration
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/onboarding/lifestyle',
            arguments: {
              'goal': _selectedGoal,
              'gender': _selectedGender,
              'age': _age,
              'height': _height,
              'weight': _weight,
              'targetWeight': _targetWeight,
              'usernameOrEmail': widget.usernameOrEmail,
            },
          );
        }
      });
    }
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
                  // Enhanced progress bar
                  AnimatedProgressBar(
                    currentStep: 2,
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Header
                            _buildHeader(
                              theme,
                              isSmallScreen,
                              isVerySmallScreen,
                            ),
                            SizedBox(
                              height:
                                  isVerySmallScreen
                                      ? 16
                                      : (isSmallScreen ? 20 : 24),
                            ),

                            // Gender selection (REMOVE from step 2)
                            // _buildGenderSelection(
                            //   theme,
                            //   isSmallScreen,
                            //   isVerySmallScreen,
                            // ),
                            // SizedBox(
                            //   height:
                            //       isVerySmallScreen
                            //           ? 16
                            //           : (isSmallScreen ? 20 : 24),
                            // ),

                            // Physical info form
                            _buildPhysicalInfoForm(
                              theme,
                              isSmallScreen,
                              isVerySmallScreen,
                            ),

                            SizedBox(
                              height:
                                  isVerySmallScreen
                                      ? 16
                                      : (isSmallScreen ? 20 : 24),
                            ),

                            // Real-time calorie insights - more compact
                            if (_age != null &&
                                _height != null &&
                                _weight != null) ...[
                              CalorieInsightCard(
                                age: _age,
                                gender: _selectedGender,
                                weight: _weight,
                                height: _height,
                                goal: _selectedGoal,
                                primaryColor: theme.primaryColor,
                              ),
                              SizedBox(
                                height:
                                    isVerySmallScreen
                                        ? 16
                                        : (isSmallScreen ? 20 : 24),
                              ),
                            ],

                            // Navigation button
                            _buildNavigationButton(theme),

                            SizedBox(
                              height:
                                  isVerySmallScreen
                                      ? 16
                                      : (isSmallScreen ? 24 : 32),
                            ),
                          ],
                        ),
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

  bool _canContinue() {
    final hasCore = _age != null && _height != null && _weight != null;
    final needsTarget =
        _selectedGoal == 'lose_weight' || _selectedGoal == 'gain_muscle';
    final hasTargetOk = !needsTarget || _targetWeight != null;
    return hasCore && hasTargetOk; // gender optional in this step
  }

  Widget _buildHeader(
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _selectedGender == 'female' ? '✨' : '🎯',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 36 : (isSmallScreen ? 42 : 48),
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 22 : (isSmallScreen ? 25 : 28),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
          Text(
            SexSpecificMessaging.getEncouragementMessage(
              _selectedGender,
              'physical_info',
            ),
            style: TextStyle(
              fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Gender selection UI was removed from this step; keeping helpers below for future reuse.

  // _buildGenderCard removed (not used in this step)

  Widget _buildPhysicalInfoForm(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return SexSpecificCard(
      gender: _selectedGender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 18 : (isSmallScreen ? 19 : 20),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),

          // Age input
          _buildNumberInput(
            label: 'Age',
            value: _age?.toString() ?? '',
            onChanged: (value) {
              setState(() {
                _age = int.tryParse(value);
              });
            },
            unit: 'years',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your age';
              }
              final n = int.tryParse(value);
              if (n == null || n < 10 || n > 120) {
                return 'Please enter a valid age (10-120)';
              }
              return null;
            },
            onSaved: (value) {
              _age = int.tryParse(value ?? '');
            },
            theme: theme,
            isSmallScreen: isSmallScreen,
            isVerySmallScreen: isVerySmallScreen,
          ),

          SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),

          // Height and Weight in a row
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  label: 'Height',
                  value: _height?.toString() ?? '',
                  onChanged: (value) {
                    setState(() {
                      _height = double.tryParse(value);
                    });
                  },
                  unit: 'cm',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter height';
                    }
                    final n = double.tryParse(value);
                    if (n == null || n < 50 || n > 250) {
                      return 'Valid height (50-250 cm)';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _height = double.tryParse(value ?? '');
                  },
                  theme: theme,
                  isSmallScreen: isSmallScreen,
                  isVerySmallScreen: isVerySmallScreen,
                ),
              ),
              SizedBox(width: isVerySmallScreen ? 12 : 16),
              Expanded(
                child: _buildNumberInput(
                  label: 'Weight',
                  value: _weight?.toString() ?? '',
                  onChanged: (value) {
                    setState(() {
                      _weight = double.tryParse(value);
                    });
                  },
                  unit: 'kg',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter weight';
                    }
                    final n = double.tryParse(value);
                    if (n == null || n < 20 || n > 300) {
                      return 'Valid weight (20-300 kg)';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _weight = double.tryParse(value ?? '');
                  },
                  theme: theme,
                  isSmallScreen: isSmallScreen,
                  isVerySmallScreen: isVerySmallScreen,
                ),
              ),
            ],
          ),

          // Target Weight input (only show if goal is lose_weight)
          if (_selectedGoal == 'lose_weight') ...[
            SizedBox(
              height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
            ),
            _buildNumberInput(
              label: 'Target Weight',
              value: _targetWeight?.toString() ?? '',
              onChanged: (value) {
                setState(() {
                  _targetWeight = double.tryParse(value);
                });
              },
              unit: 'kg',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter target weight';
                }
                final n = double.tryParse(value);
                if (n == null || n < 20 || n > 300) {
                  return 'Valid weight (20-300 kg)';
                }
                return null;
              },
              onSaved: (value) {
                _targetWeight = double.tryParse(value ?? '');
              },
              theme: theme,
              isSmallScreen: isSmallScreen,
              isVerySmallScreen: isVerySmallScreen,
            ),
          ],

          // Health tips based on gender
          if (_selectedGender != null) ...[
            SizedBox(
              height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
            ),
            Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Did you know?',
                        style: TextStyle(
                          fontSize:
                              isVerySmallScreen
                                  ? 12
                                  : (isSmallScreen ? 13 : 14),
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isVerySmallScreen ? 3 : 4),
                  Text(
                    SexSpecificMessaging.getHealthTips(_selectedGender).first,
                    style: TextStyle(
                      fontSize:
                          isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required String unit,
    required String? Function(String?) validator,
    required void Function(String?) onSaved,
    required SexSpecificTheme theme,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          validator: validator,
          onSaved: onSaved,
          style: TextStyle(fontSize: isVerySmallScreen ? 14 : 16),
          decoration: InputDecoration(
            suffixText: unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 12 : 16,
              vertical: isVerySmallScreen ? 10 : 12,
            ),
            isDense: isVerySmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton(SexSpecificTheme theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: theme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SexSpecificButton(
            gender: _selectedGender,
            text: 'Continue to Lifestyle',
            isEnabled: _canContinue(),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: _continue,
          ),
        ),
      ],
    );
  }
}
