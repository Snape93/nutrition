import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

class EnhancedOnboardingExercise extends StatefulWidget {
  final String usernameOrEmail;
  final Map<String, dynamic>? previousData;

  const EnhancedOnboardingExercise({
    super.key,
    required this.usernameOrEmail,
    this.previousData,
  });

  @override
  State<EnhancedOnboardingExercise> createState() =>
      _EnhancedOnboardingExerciseState();
}

class _EnhancedOnboardingExerciseState
    extends State<EnhancedOnboardingExercise> {
  final List<String> _exerciseTypes = [
    'Cardio',
    'Strength',
    'Yoga',
    'Dance',
    'Sports',
    'Flexibility',
  ];
  final List<String> _equipmentOptions = [
    'None',
    'Dumbbells',
    'Resistance Bands',
    'Barbell',
    'Kettlebell',
    'Mat',
  ];
  final List<String> _experienceLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<String> _selectedTypes = [];
  final List<String> _selectedEquipment = [];
  String? _selectedExperience;
  String _limitations = '';
  int _workoutDuration = 30;
  int _workoutFrequency = 3;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[DEBUG] EnhancedOnboardingExercise: initState for user: ${widget.usernameOrEmail}',
    );
    if (widget.previousData != null) {
      debugPrint(
        '[DEBUG] EnhancedOnboardingExercise: previousData: ${widget.previousData}',
      );
    }
  }

  bool _canProceed() {
    return _selectedTypes.isNotEmpty &&
        _selectedExperience != null &&
        _workoutDuration > 0 &&
        _workoutFrequency > 0;
  }

  void _submit() async {
    debugPrint('[DEBUG] EnhancedOnboardingExercise: _submit called');
    if (!_canProceed()) {
      debugPrint(
        '[DEBUG] EnhancedOnboardingExercise: Cannot proceed, missing required fields',
      );
      setState(() {
        _errorMessage = 'Please complete all required fields.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Pass data to next onboarding step or save to backend
    final data = {
      ...?widget.previousData,
      'username': widget.usernameOrEmail,
      'exercise_types': _selectedTypes,
      'exercise_equipment': _selectedEquipment,
      'exercise_experience': _selectedExperience,
      'exercise_limitations': _limitations,
      'workout_duration': _workoutDuration,
      'workout_frequency': _workoutFrequency,
    };
    debugPrint(
      '[DEBUG] EnhancedOnboardingExercise: Navigating to /onboarding/enhanced_nutrition with data: $data',
    );
    Navigator.pushNamed(
      context,
      '/onboarding/enhanced_nutrition',
      arguments: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[DEBUG] EnhancedOnboardingExercise: build called');
    final headingStyle = TextStyle(
      fontSize: AppDesignSystem.getResponsiveFontSize(
        context,
        xs: 14,
        sm: 16,
        md: 18,
      ),
      fontWeight: FontWeight.bold,
      color: AppDesignSystem.onSurface,
    );
    final bodyStyle = TextStyle(
      fontSize: AppDesignSystem.getResponsiveFontSize(
        context,
        xs: 12,
        sm: 13,
        md: 14,
      ),
      color: AppDesignSystem.onSurface,
    );
    final chipSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 6,
      sm: 8,
      md: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Exercise Preferences',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 16,
              sm: 18,
              md: 20,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppDesignSystem.getResponsivePaddingExact(
                  context,
                  xs: 12,
                  sm: 16,
                  md: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: AppDesignSystem.getResponsiveSpacingExact(
                            context,
                            xs: 8,
                            sm: 10,
                            md: 12,
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Text('Preferred Exercise Types', style: headingStyle),
                    Wrap(
                      spacing: chipSpacing,
                      runSpacing: chipSpacing,
                      children: _exerciseTypes.map((type) {
                        final isSelected = _selectedTypes.contains(type);
                        return FilterChip(
                          label: Text(type, style: bodyStyle),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTypes.add(type);
                              } else {
                                _selectedTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 16,
                        sm: 18,
                        md: 24,
                      ),
                    ),
                    Text('Available Equipment', style: headingStyle),
                    Wrap(
                      spacing: chipSpacing,
                      runSpacing: chipSpacing,
                      children: _equipmentOptions.map((eq) {
                        final isSelected = _selectedEquipment.contains(eq);
                        return FilterChip(
                          label: Text(eq, style: bodyStyle),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedEquipment.add(eq);
                              } else {
                                _selectedEquipment.remove(eq);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 16,
                        sm: 18,
                        md: 24,
                      ),
                    ),
                    Text('Experience Level', style: headingStyle),
                    Wrap(
                      spacing: chipSpacing,
                      runSpacing: chipSpacing,
                      children: _experienceLevels.map((level) {
                        final isSelected = _selectedExperience == level;
                        return ChoiceChip(
                          label: Text(level, style: bodyStyle),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedExperience = selected ? level : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 16,
                        sm: 18,
                        md: 24,
                      ),
                    ),
                    Text('Physical Limitations or Injuries', style: headingStyle),
                    TextField(
                      decoration: AppDesignSystem.inputDecoration(
                        labelText: 'Details',
                        hintText: 'Describe any injuries or limitations',
                        primaryColor: Theme.of(context).colorScheme.primary,
                      ),
                      onChanged: (val) => setState(() => _limitations = val),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 16,
                        sm: 18,
                        md: 24,
                      ),
                    ),
                    Text(
                      'Preferred Workout Duration (minutes)',
                      style: headingStyle,
                    ),
                    Slider(
                      value: _workoutDuration.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '$_workoutDuration min',
                      onChanged: (val) =>
                          setState(() => _workoutDuration = val.round()),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 16,
                        sm: 18,
                        md: 24,
                      ),
                    ),
                    Text(
                      'Preferred Workout Frequency (days/week)',
                      style: headingStyle,
                    ),
                    Slider(
                      value: _workoutFrequency.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      label: '$_workoutFrequency days',
                      onChanged: (val) =>
                          setState(() => _workoutFrequency = val.round()),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 20,
                        sm: 24,
                        md: 32,
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canProceed() ? _submit : null,
                        style: AppDesignSystem.primaryButtonStyle(
                          primaryColor: Theme.of(context).colorScheme.primary,
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: AppDesignSystem.getResponsiveFontSize(
                              context,
                              xs: 14,
                              sm: 16,
                              md: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
