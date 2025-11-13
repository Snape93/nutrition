import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/calorie_calculator.dart';
import 'widgets/sex_specific_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart' as config;
import '../utils/user_profile_helper.dart';
import '../utils/unit_converter.dart';
import '../utils/input_formatters.dart';

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

  // Current step data (stored in metric internally)
  double? _height; // in cm
  double? _weight; // in kg
  double? _targetWeight; // in kg
  bool _showCelebration = false;
  int? _userAge; // Age fetched from backend
  bool _isLoadingAge = false;

  // Unit selection
  String _heightUnit = 'cm'; // 'cm' or 'ft'
  String _weightUnit = 'kg'; // 'kg' or 'lbs'

  // Display values for imperial units
  int? _heightFeet;
  double? _heightInches;
  double? _weightDisplay; // Display value (kg or lbs)
  double? _targetWeightDisplay; // Display value (kg or lbs)

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

    // Fetch age from backend
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

  // Convert height to metric (cm) based on selected unit
  void _convertHeightToMetric() {
    if (_heightUnit == 'ft') {
      if (_heightFeet != null && _heightInches != null) {
        _height = UnitConverter.feetInchesToCm(_heightFeet!, _heightInches!);
      } else {
        _height = null;
      }
    } else {
      // Already in cm, use _height directly (stored from input)
    }
  }

  // Convert weight to metric (kg) based on selected unit
  void _convertWeightToMetric() {
    if (_weightUnit == 'lbs') {
      if (_weightDisplay != null) {
        _weight = UnitConverter.lbsToKg(_weightDisplay!);
      } else {
        _weight = null;
      }
    } else {
      // Already in kg
      _weight = _weightDisplay;
    }
  }

  // Convert target weight to metric (kg) based on selected unit
  void _convertTargetWeightToMetric() {
    if (_weightUnit == 'lbs') {
      if (_targetWeightDisplay != null) {
        _targetWeight = UnitConverter.lbsToKg(_targetWeightDisplay!);
      } else {
        _targetWeight = null;
      }
    } else {
      // Already in kg
      _targetWeight = _targetWeightDisplay;
    }
  }

  // Update display values when switching units
  // Converts values correctly and formats to 1-2 decimal places
  void _updateDisplayValuesForUnitChange({
    String? oldWeightUnit,
    String? oldHeightUnit,
  }) {
    // Convert current display values to metric using OLD units before converting to new units
    // This ensures we have the correct metric values

    // Convert weight to metric using old unit (if provided) or current unit
    if (_weightDisplay != null) {
      final unitToUse = oldWeightUnit ?? _weightUnit;
      if (unitToUse == 'lbs') {
        _weight = UnitConverter.lbsToKg(_weightDisplay!);
      } else {
        _weight = _weightDisplay;
      }
    }

    // Convert target weight to metric using old unit (if provided) or current unit
    if (_targetWeightDisplay != null) {
      final unitToUse = oldWeightUnit ?? _weightUnit;
      if (unitToUse == 'lbs') {
        _targetWeight = UnitConverter.lbsToKg(_targetWeightDisplay!);
      } else {
        _targetWeight = _targetWeightDisplay;
      }
    }

    // Convert height to metric using old unit (if provided) or current unit
    final heightUnitToUse = oldHeightUnit ?? _heightUnit;
    if (heightUnitToUse == 'ft') {
      if (_heightFeet != null && _heightInches != null) {
        _height = UnitConverter.feetInchesToCm(_heightFeet!, _heightInches!);
      }
    } else {
      // Already in cm, _height should already be set
      // If we have cm value, keep it
    }

    // Now convert from metric to new display units

    // Convert height display
    if (_heightUnit == 'ft' && _height != null) {
      final feetInches = UnitConverter.cmToFeetInches(_height!);
      _heightFeet = feetInches['feet']!.toInt();
      // Round inches to 1-2 decimal places
      _heightInches = double.parse(feetInches['inches']!.toStringAsFixed(2));
    } else if (_heightUnit == 'cm' && _height != null) {
      // Keep _height as is (already in cm), format to 1-2 decimal places
      _height = double.parse(_height!.toStringAsFixed(2));
      _heightFeet = null;
      _heightInches = null;
    }

    // Convert weight display - convert from metric to new unit
    if (_weight != null) {
      if (_weightUnit == 'lbs') {
        // Convert kg to lbs and format to 1-2 decimal places
        final lbs = UnitConverter.kgToLbs(_weight!);
        _weightDisplay = double.parse(lbs.toStringAsFixed(2));
      } else if (_weightUnit == 'kg') {
        // Already in kg, format to 1-2 decimal places
        _weightDisplay = double.parse(_weight!.toStringAsFixed(2));
      }
    }

    // Convert target weight display - convert from metric to new unit
    if (_targetWeight != null) {
      if (_weightUnit == 'lbs') {
        // Convert kg to lbs and format to 1-2 decimal places
        final lbs = UnitConverter.kgToLbs(_targetWeight!);
        _targetWeightDisplay = double.parse(lbs.toStringAsFixed(2));
      } else if (_weightUnit == 'kg') {
        // Already in kg, format to 1-2 decimal places
        _targetWeightDisplay = double.parse(_targetWeight!.toStringAsFixed(2));
      }
    }
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      // Convert all values to metric before saving
      _convertHeightToMetric();
      _convertWeightToMetric();
      _convertTargetWeightToMetric();

      _formKey.currentState?.save();

      // Persist partial profile early so recommendations work even before final submit
      _persistPartialProfile();

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

  Future<void> _persistPartialProfile() async {
    try {
      final payload = {
        'sex': _selectedGender,
        'height_cm': _height,
        'weight_kg': _weight,
        'goal': _selectedGoal?.replaceAll('_', ' '),
      };
      await http.put(
        Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      // Non-blocking: proceed even if this early save fails; final step will retry
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
                            if (_userAge != null &&
                                _height != null &&
                                _weight != null) ...[
                              CalorieInsightCard(
                                age: _userAge,
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
    // Check height
    bool hasHeight = false;
    if (_heightUnit == 'cm') {
      hasHeight = _height != null;
    } else {
      hasHeight = _heightFeet != null && _heightInches != null;
    }

    // Check weight
    bool hasWeight = _weightDisplay != null;

    // Check target weight (only for lose_weight goal)
    final needsTarget = _selectedGoal == 'lose_weight';
    bool hasTargetOk = !needsTarget || _targetWeightDisplay != null;

    return hasHeight && hasWeight && hasTargetOk;
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

          // Height and Weight inputs
          _buildHeightWeightInputs(theme, isSmallScreen, isVerySmallScreen),

          // Target Weight input (only show if goal is lose_weight)
          if (_selectedGoal == 'lose_weight') ...[
            SizedBox(
              height: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
            ),
            _buildTargetWeightInput(theme, isSmallScreen, isVerySmallScreen),
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

  // Build height and weight inputs with unit support
  Widget _buildHeightWeightInputs(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Row(
      children: [
        Expanded(
          child:
              _heightUnit == 'cm'
                  ? _buildHeightCmInput(theme, isSmallScreen, isVerySmallScreen)
                  : _buildHeightFtInInput(
                    theme,
                    isSmallScreen,
                    isVerySmallScreen,
                  ),
        ),
        SizedBox(width: isVerySmallScreen ? 12 : 16),
        Expanded(
          child: _buildWeightInput(theme, isSmallScreen, isVerySmallScreen),
        ),
      ],
    );
  }

  // Build height input in cm
  Widget _buildHeightCmInput(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        TextFormField(
          key: ValueKey('height_cm_${_heightUnit}'),
          initialValue: _height?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              _height = double.tryParse(value);
            });
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 1)],
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
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            suffixIcon: _buildUnitSelectorInField(
              options: ['cm', 'ft'],
              selected: _heightUnit,
              onChanged: (value) {
                setState(() {
                  final oldHeightUnit = _heightUnit;
                  _heightUnit = value;
                  _updateDisplayValuesForUnitChange(
                    oldHeightUnit: oldHeightUnit,
                  );
                });
              },
              theme: theme,
            ),
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

  // Build height input in ft/in
  Widget _buildHeightFtInInput(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('height_feet_${_heightUnit}'),
                initialValue: _heightFeet?.toString() ?? '',
                onChanged: (value) {
                  setState(() {
                    _heightFeet = int.tryParse(value);
                  });
                },
                keyboardType: TextInputType.number,
                inputFormatters: [FeetInputFormatter()],
                validator: (value) {
                  if (_heightUnit == 'ft' && (value == null || value.isEmpty)) {
                    return 'Enter feet';
                  }
                  final n = int.tryParse(value ?? '');
                  if (n != null && (n < 1 || n > 8)) {
                    return '1-8 ft';
                  }
                  return null;
                },
                onSaved: (value) {
                  _heightFeet = int.tryParse(value ?? '');
                },
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 14 : 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
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
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey('height_inches_${_heightUnit}'),
                initialValue: _heightInches?.toString() ?? '',
                onChanged: (value) {
                  setState(() {
                    _heightInches = double.tryParse(value);
                  });
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [InchesInputFormatter(maxDecimalPlaces: 2)],
                validator: (value) {
                  if (_heightUnit == 'ft' && (value == null || value.isEmpty)) {
                    return 'Enter inches';
                  }
                  final n = double.tryParse(value ?? '');
                  if (n != null && (n < 0 || n >= 12)) {
                    return '0-11.99 in';
                  }
                  return null;
                },
                onSaved: (value) {
                  _heightInches = double.tryParse(value ?? '');
                },
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 14 : 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
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
            ),
            SizedBox(width: 8),
            _buildUnitSelectorInField(
              options: ['cm', 'ft'],
              selected: _heightUnit,
              onChanged: (value) {
                setState(() {
                  final oldHeightUnit = _heightUnit;
                  _heightUnit = value;
                  _updateDisplayValuesForUnitChange(
                    oldHeightUnit: oldHeightUnit,
                  );
                });
              },
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  // Build weight input
  Widget _buildWeightInput(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weight',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        TextFormField(
          key: ValueKey('weight_${_weightUnit}'),
          initialValue: _weightDisplay?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              _weightDisplay = double.tryParse(value);
            });
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 1)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter weight';
            }
            final n = double.tryParse(value);
            if (n == null) {
              return 'Enter numbers only';
            }
            if (_weightUnit == 'kg') {
              if (n < 20 || n > 300) {
                return 'Valid weight (20-300 kg)';
              }
            } else {
              // lbs
              if (n < 44 || n > 661) {
                return 'Valid weight (44-661 lbs)';
              }
            }
            return null;
          },
          onSaved: (value) {
            _weightDisplay = double.tryParse(value ?? '');
          },
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            suffixIcon: _buildUnitSelectorInField(
              options: ['kg', 'lbs'],
              selected: _weightUnit,
              onChanged: (value) {
                setState(() {
                  final oldWeightUnit = _weightUnit;
                  _weightUnit = value;
                  _updateDisplayValuesForUnitChange(
                    oldWeightUnit: oldWeightUnit,
                  );
                });
              },
              theme: theme,
            ),
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

  // Build target weight input (uses same unit as weight)
  Widget _buildTargetWeightInput(
    SexSpecificTheme theme,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Weight',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        TextFormField(
          key: ValueKey('target_weight_${_weightUnit}'),
          initialValue: _targetWeightDisplay?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              _targetWeightDisplay = double.tryParse(value);
            });
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 1)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter target weight';
            }
            final n = double.tryParse(value);
            if (n == null) {
              return 'Enter numbers only';
            }
            if (_weightUnit == 'kg') {
              if (n < 20 || n > 300) {
                return 'Valid weight (20-300 kg)';
              }
            } else {
              // lbs
              if (n < 44 || n > 661) {
                return 'Valid weight (44-661 lbs)';
              }
            }
            // Check if target is less than current weight for lose_weight goal
            if (_weightDisplay != null) {
              if (n >= _weightDisplay!) {
                return 'Target must be less than current weight';
              }
            }
            return null;
          },
          onSaved: (value) {
            _targetWeightDisplay = double.tryParse(value ?? '');
          },
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            suffixIcon: _buildUnitSelectorInField(
              options: ['kg', 'lbs'],
              selected: _weightUnit,
              onChanged: (value) {
                setState(() {
                  final oldWeightUnit = _weightUnit;
                  _weightUnit = value;
                  _updateDisplayValuesForUnitChange(
                    oldWeightUnit: oldWeightUnit,
                  );
                });
              },
              theme: theme,
            ),
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

  // Build unit selector dropdown inside input field
  Widget _buildUnitSelectorInField({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required SexSpecificTheme theme,
  }) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          selected.toUpperCase(),
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (BuildContext context) {
        return options.map((option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                if (selected == option)
                  Icon(Icons.check, color: theme.primaryColor, size: 18),
                if (selected == option) const SizedBox(width: 8),
                Text(
                  option.toUpperCase(),
                  style: TextStyle(
                    fontWeight:
                        selected == option
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color:
                        selected == option
                            ? theme.primaryColor
                            : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
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
