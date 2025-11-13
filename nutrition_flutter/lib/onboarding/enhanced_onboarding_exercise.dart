import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Preferences')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const Text(
                      'Preferred Exercise Types',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children:
                          _exerciseTypes
                              .map(
                                (type) => FilterChip(
                                  label: Text(type),
                                  selected: _selectedTypes.contains(type),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTypes.add(type);
                                      } else {
                                        _selectedTypes.remove(type);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Available Equipment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children:
                          _equipmentOptions
                              .map(
                                (eq) => FilterChip(
                                  label: Text(eq),
                                  selected: _selectedEquipment.contains(eq),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedEquipment.add(eq);
                                      } else {
                                        _selectedEquipment.remove(eq);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Experience Level',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children:
                          _experienceLevels
                              .map(
                                (level) => ChoiceChip(
                                  label: Text(level),
                                  selected: _selectedExperience == level,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedExperience =
                                          selected ? level : null;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Physical Limitations or Injuries',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Describe any injuries or limitations',
                      ),
                      onChanged: (val) => setState(() => _limitations = val),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Preferred Workout Duration (minutes)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _workoutDuration.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '$_workoutDuration min',
                      onChanged:
                          (val) =>
                              setState(() => _workoutDuration = val.round()),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Preferred Workout Frequency (days/week)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _workoutFrequency.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      label: '$_workoutFrequency days',
                      onChanged:
                          (val) =>
                              setState(() => _workoutFrequency = val.round()),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canProceed() ? _submit : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
