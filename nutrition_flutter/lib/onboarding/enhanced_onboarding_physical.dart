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
import '../design_system/app_design_system.dart';

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
                      padding: AppDesignSystem.getResponsivePaddingExact(
                        context,
                        xs: 8, // < 360px (matches isNarrowScreen ? 8)
                        sm: 12, // 360-600px (matches isSmallScreen ? 12)
                        md: 16, // 600-900px (matches default 16)
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Header
                            _buildHeader(context, theme),
                            SizedBox(
                              height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 16, // < 600px (matches isVerySmallScreen ? 16)
                                sm: 20, // 600-700px (matches isSmallScreen ? 20)
                                md: 24, // > 700px (matches default 24)
                              ),
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
                            _buildPhysicalInfoForm(context, theme),

                            SizedBox(
                              height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 16, // < 600px
                                sm: 20, // 600-700px
                                md: 24, // > 700px
                              ),
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
                                    AppDesignSystem.getResponsiveSpacingExact(
                                      context,
                                      xs: 16, // < 600px
                                      sm: 20, // 600-700px
                                      md: 24, // > 700px
                                    ),
                              ),
                            ],

                            // Navigation button
                            _buildNavigationButton(theme),

                            SizedBox(
                              height: AppDesignSystem.getResponsiveSpacingExact(
                                context,
                                xs: 16, // < 600px
                                sm: 24, // 600-700px
                                md: 32, // > 700px
                              ),
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

  Widget _buildHeader(BuildContext context, SexSpecificTheme theme) {
    return Container(
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 12, // < 600px (matches isVerySmallScreen ? 12)
        sm: 16, // 600-700px (matches isSmallScreen ? 16)
        md: 20, // > 700px (matches default 20)
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
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 36, // < 600px
                sm: 42, // 600-700px
                md: 48, // > 700px
              ),
            ),
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 8, // < 600px
              sm: 10, // 600-700px
              md: 12, // > 700px
            ),
          ),
          Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 22, // < 600px
                sm: 25, // 600-700px
                md: 28, // > 700px
              ),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 4, // < 600px
              sm: 6, // 600-700px
              md: 8, // > 700px
            ),
          ),
          Text(
            SexSpecificMessaging.getEncouragementMessage(
              _selectedGender,
              'physical_info',
            ),
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 12, // < 600px
                sm: 14, // 600-700px
                md: 16, // > 700px
              ),
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

  Widget _buildPhysicalInfoForm(BuildContext context, SexSpecificTheme theme) {
    return SexSpecificCard(
      gender: _selectedGender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 18, // < 600px
                sm: 19, // 600-700px
                md: 20, // > 700px
              ),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 12, // < 600px
              sm: 14, // 600-700px
              md: 16, // > 700px
            ),
          ),

          // Height and Weight inputs
          _buildHeightWeightInputs(context, theme),

          // Target Weight input (only show if goal is lose_weight)
          if (_selectedGoal == 'lose_weight') ...[
            SizedBox(
              height: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 12, // < 600px
                sm: 14, // 600-700px
                md: 16, // > 700px
              ),
            ),
            _buildTargetWeightInput(context, theme),
          ],

          // Health tips based on gender
          if (_selectedGender != null) ...[
            SizedBox(
              height: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 12, // < 600px
                sm: 14, // 600-700px
                md: 16, // > 700px
              ),
            ),
            Container(
              padding: AppDesignSystem.getResponsivePaddingExact(
                context,
                xs: 10, // < 600px
                sm: 12, // 600-700px
                md: 12, // > 700px
              ),
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
                          fontSize: AppDesignSystem.getResponsiveFontSize(
                            context,
                            xs: 12, // < 600px
                            sm: 13, // 600-700px
                            md: 14, // > 700px
                          ),
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: AppDesignSystem.getResponsiveSpacingExact(
                      context,
                      xs: 3, // < 600px
                      sm: 4, // 600-700px
                      md: 4, // > 700px
                    ),
                  ),
                  Text(
                    SexSpecificMessaging.getHealthTips(_selectedGender).first,
                    style: TextStyle(
                      fontSize: AppDesignSystem.getResponsiveFontSize(
                        context,
                        xs: 10, // < 600px
                        sm: 11, // 600-700px
                        md: 12, // > 700px
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
        ],
      ),
    );
  }

  // Build height and weight inputs with unit support
  Widget _buildHeightWeightInputs(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    final screenWidth = AppDesignSystem.getScreenWidth(context);
    final isCompactLayout = screenWidth < 340;
    final interItemSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 10,
      sm: 12,
      md: 16,
    );

    final heightWidget =
        _heightUnit == 'cm'
            ? _buildHeightCmInput(context, theme)
            : _buildHeightFtInInput(context, theme, isCompact: isCompactLayout);

    if (isCompactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heightWidget,
          SizedBox(height: interItemSpacing),
          _buildWeightInput(context, theme),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: heightWidget),
        SizedBox(
          width: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 12,
            sm: 16,
            md: 16,
          ),
        ),
        Expanded(child: _buildWeightInput(context, theme)),
      ],
    );
  }

  // Build height input in cm
  Widget _buildHeightCmInput(BuildContext context, SexSpecificTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14, // < 600px
              sm: 15, // 600-700px
              md: 16, // > 700px
            ),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 6, // < 600px
            sm: 8, // 600-700px
            md: 8, // > 700px
          ),
        ),
        ConstrainedBox(
          constraints: AppDesignSystem.getNumericInputConstraints(context),
          child: TextFormField(
            key: ValueKey('height_cm_$_heightUnit'),
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
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 14, // < 600px
                sm: 16, // 600-700px
                md: 16, // > 700px
              ),
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
              contentPadding: AppDesignSystem.getNumericInputPadding(context),
            ),
          ),
        ),
      ],
    );
  }

  // Build height input in ft/in
  Widget _buildHeightFtInInput(
    BuildContext context,
    SexSpecificTheme theme, {
    bool isCompact = false,
  }) {
    Widget buildFeetField({double? width}) {
      final field = ConstrainedBox(
        constraints: AppDesignSystem.getNumericInputConstraints(context),
        child: TextFormField(
          key: ValueKey('height_feet_$_heightUnit'),
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
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14,
              sm: 16,
              md: 16,
            ),
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
            contentPadding: AppDesignSystem.getNumericInputPadding(context),
          ),
        ),
      );

      if (width != null) {
        return SizedBox(width: width, child: field);
      }
      return Expanded(child: field);
    }

    Widget buildInchesField({double? width}) {
      final field = ConstrainedBox(
        constraints: AppDesignSystem.getNumericInputConstraints(context),
        child: TextFormField(
          key: ValueKey('height_inches_$_heightUnit'),
          initialValue: _heightInches?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              _heightInches = double.tryParse(value);
            });
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14,
              sm: 16,
              md: 16,
            ),
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
            contentPadding: AppDesignSystem.getNumericInputPadding(context),
          ),
        ),
      );

      if (width != null) {
        return SizedBox(width: width, child: field);
      }
      return Expanded(child: field);
    }

    final horizontalSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: isCompact ? 4 : 8,
      sm: isCompact ? 6 : 10,
      md: isCompact ? 8 : 12,
    );

    final compactFieldWidth = isCompact ? 72.0 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14,
              sm: 15,
              md: 16,
            ),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 6,
            sm: 8,
            md: 8,
          ),
        ),
        Row(
          children: [
            buildFeetField(width: compactFieldWidth),
            SizedBox(width: horizontalSpacing),
            buildInchesField(width: compactFieldWidth),
            SizedBox(width: horizontalSpacing),
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
  Widget _buildWeightInput(BuildContext context, SexSpecificTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weight',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14, // < 600px
              sm: 15, // 600-700px
              md: 16, // > 700px
            ),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 6, // < 600px
            sm: 8, // 600-700px
            md: 8, // > 700px
          ),
        ),
        ConstrainedBox(
          constraints: AppDesignSystem.getNumericInputConstraints(context),
          child: TextFormField(
            key: ValueKey('weight_$_weightUnit'),
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
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 14,
                sm: 16,
                md: 16,
              ),
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
              contentPadding: AppDesignSystem.getNumericInputPadding(context),
            ),
          ),
        ),
      ],
    );
  }

  // Build target weight input (uses same unit as weight)
  Widget _buildTargetWeightInput(BuildContext context, SexSpecificTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Weight',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 14, // < 600px
              sm: 15, // 600-700px
              md: 16, // > 700px
            ),
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(
          height: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 6, // < 600px
            sm: 8, // 600-700px
            md: 8, // > 700px
          ),
        ),
        ConstrainedBox(
          constraints: AppDesignSystem.getNumericInputConstraints(context),
          child: TextFormField(
            key: ValueKey('target_weight_$_weightUnit'),
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
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 14, // < 600px
                sm: 16, // 600-700px
                md: 16, // > 700px
              ),
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
              contentPadding: AppDesignSystem.getNumericInputPadding(context),
            ),
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
