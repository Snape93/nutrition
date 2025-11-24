import 'package:flutter/material.dart';
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

  bool get _isFemaleTheme => (_selectedGender ?? '').toLowerCase() == 'female';

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
  double? _weightDisplay; // Display value (kg or lbs)
  double? _targetWeightDisplay; // Display value (kg or lbs)

  // Controllers for text fields
  final TextEditingController _heightCmController = TextEditingController();
  final TextEditingController _heightFtController = TextEditingController();
  final TextEditingController _heightInController = TextEditingController();

  final List<String> _stepNames = [
    'Choose Your Goal',
    'Basic Information',
    'Activity & Lifestyle',
    'Food Preferences',
    'Complete Setup',
  ];

  @override
  void initState() {
    super.initState();
    // Clear controller to ensure it starts empty
    _heightCmController.clear();
    _heightFtController.clear();
    _heightInController.clear();
  }

  @override
  void dispose() {
    _heightCmController.dispose();
    _heightFtController.dispose();
    _heightInController.dispose();
    super.dispose();
  }

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

  // Convert height to metric (cm) from current inputs
  void _convertHeightToMetric({String? fromUnit}) {
    final unitToUse = fromUnit ?? _heightUnit;

    if (unitToUse == 'cm') {
      _height = double.tryParse(_heightCmController.text);
      return;
    }

    final ft = int.tryParse(_heightFtController.text);
    final inches = double.tryParse(_heightInController.text);

    if (ft == null && inches == null) {
      _height = null;
      return;
    }

    final totalInches = ((ft ?? 0) * 12) + (inches ?? 0);
    if (totalInches <= 0) {
      _height = null;
      return;
    }

    _height = UnitConverter.feetInchesToCm(ft ?? 0, inches ?? 0);
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
  void _updateDisplayValuesForUnitChange({String? oldWeightUnit}) {
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

  // Update height input fields when switching between cm and ft units
  void _updateHeightInputsForUnitChange({required String oldUnit}) {
    // First, ensure _height (in cm) reflects the value entered using the OLD unit
    _convertHeightToMetric(fromUnit: oldUnit);

    if (_height == null) {
      _heightCmController.clear();
      _heightFtController.clear();
      _heightInController.clear();
      return;
    }

    // Normalize stored height value
    _height = double.parse(_height!.toStringAsFixed(2));

    if (_heightUnit == 'cm') {
      // Show value in centimeters
      final cmValue = double.parse(_height!.toStringAsFixed(1));
      _heightCmController.text = cmValue.toString();
    } else {
      // Show value as feet / inches
      final fi = UnitConverter.cmToFeetInches(_height!);
      final feet = fi['feet'] ?? 0;
      final inches = fi['inches'] ?? 0;
      _heightFtController.text = feet.toStringAsFixed(0);
      _heightInController.text = inches.toStringAsFixed(0);
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
    // Check height (always in cm)
    bool hasHeight = _height != null;

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
        xs: 12,
        sm: 16,
        md: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                xs: 30,
                sm: 34,
                md: 38,
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
                xs: 18,
                sm: 20,
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
                xs: 12,
                sm: 13,
                md: 14,
              ),
              color: Colors.grey[700],
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
          if (_isFemaleTheme)
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.straighten,
                    color: theme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildHeaderText(context, theme)),
              ],
            )
          else
            _buildHeaderText(context, theme),
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
            _buildDidYouKnowCard(context, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderText(BuildContext context, SexSpecificTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 20,
              sm: 21,
              md: 22,
            ),
            fontWeight: FontWeight.w700,
            color: _isFemaleTheme ? theme.accentColor : theme.primaryColor,
          ),
        ),
        Text(
          _isFemaleTheme
              ? 'Share your current stats so we can tailor the plan to you.'
              : 'Input your stats so we can personalize everything.',
          style: TextStyle(
            fontSize: AppDesignSystem.getResponsiveFontSize(
              context,
              xs: 11,
              sm: 12,
              md: 13,
            ),
            color: _isFemaleTheme
                ? Colors.black.withValues(alpha: 0.6)
                : theme.primaryColor.withValues(alpha: 0.75),
          ),
        ),
      ],
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

    final heightWidget = _heightUnit == 'cm'
        ? _buildMetricHeightInput(context, theme)
        : _buildImperialHeightInput(context, theme);

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

  // Build height input in metric (cm) format
  Widget _buildMetricHeightInput(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
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
        ConstrainedBox(
          constraints: AppDesignSystem.getNumericInputConstraints(context),
          child: TextFormField(
            key: const ValueKey('height_cm'),
            controller: _heightCmController,
            autofocus: false,
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
                xs: 14,
                sm: 16,
                md: 16,
              ),
              color: Colors.black87,
            ),
            decoration: _buildMetricInputDecoration(
              context: context,
              theme: theme,
              suffix: _buildUnitSelectorInField(
                options: ['cm', 'ft'],
                selected: _heightUnit,
                onChanged: (value) {
                  setState(() {
                    final oldUnit = _heightUnit;
                    _heightUnit = value;
                    _updateHeightInputsForUnitChange(oldUnit: oldUnit);
                  });
                },
                theme: theme,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build height input in ft/in format (converted to cm internally)
  Widget _buildImperialHeightInput(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    final fieldSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 6,
      sm: 8,
      md: 10,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            _buildUnitSelectorInField(
              options: ['cm', 'ft'],
              selected: _heightUnit,
              onChanged: (value) {
                setState(() {
                  final oldUnit = _heightUnit;
                  _heightUnit = value;
                  _updateHeightInputsForUnitChange(oldUnit: oldUnit);
                });
              },
              theme: theme,
            ),
          ],
        ),
        SizedBox(height: fieldSpacing),
        Row(
          children: [
            Expanded(
              child: _buildHeightSegmentField(
                context: context,
                controller: _heightFtController,
                label: 'FT',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Req';
                  }
                  final n = double.tryParse(value);
                  if (n == null || n < 1 || n > 8) {
                    return '1-8';
                  }
                  return null;
                },
                onChanged: (_) => _handleHeightChanged(),
                theme: theme,
              ),
            ),
            SizedBox(width: fieldSpacing),
            Expanded(
              child: _buildHeightSegmentField(
                context: context,
                controller: _heightInController,
                label: 'IN',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Req';
                  }
                  final n = double.tryParse(value);
                  if (n == null || n < 0 || n >= 12) {
                    return '0-11';
                  }
                  return null;
                },
                onChanged: (_) => _handleHeightChanged(),
                theme: theme,
              ),
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
            decoration: _buildMetricInputDecoration(
              context: context,
              theme: theme,
              suffix: _buildUnitSelectorInField(
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
            ),
          ),
        ),
      ],
    );
  }

  // Build target weight input (uses same unit as weight)
  Widget _buildTargetWeightInput(BuildContext context, SexSpecificTheme theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                decoration: _buildMetricInputDecoration(
                  context: context,
                  theme: theme,
                  suffix: _buildUnitSelectorInField(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build unit selector dropdown inside input field
  Widget _buildUnitSelectorInField({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required SexSpecificTheme theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        tooltip: 'Change unit',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: Colors.white,
        elevation: 4,
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
        child: _buildUnitChip(
          selected.toUpperCase(),
          theme,
          showChevron: true,
        ),
      ),
    );
  }

  InputDecoration _buildMetricInputDecoration({
    required BuildContext context,
    required SexSpecificTheme theme,
    Widget? suffix,
  }) {
    final radiusValue = _isFemaleTheme ? 20.0 : 14.0;
    final borderRadius = BorderRadius.circular(radiusValue);

    OutlineInputBorder border(Color color, {double width = 1.2}) {
      return OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final subtleBorderColor = theme.primaryColor.withValues(
      alpha: _isFemaleTheme ? 0.2 : 0.4,
    );

    return InputDecoration(
      filled: true,
      fillColor: _resolveMetricFieldFill(theme),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 40,
      ),
      contentPadding: _isFemaleTheme
          ? AppDesignSystem.getNumericInputPadding(context)
          : EdgeInsets.symmetric(
              horizontal: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 10,
                sm: 12,
                md: 14,
              ),
              vertical: AppDesignSystem.getResponsiveSpacingExact(
                context,
                xs: 12,
                sm: 14,
                md: 16,
              ),
            ),
      border: border(subtleBorderColor),
      enabledBorder: border(subtleBorderColor),
      focusedBorder: border(theme.primaryColor, width: 2),
      errorBorder: border(Colors.redAccent),
    );
  }

  Color _resolveMetricFieldFill(SexSpecificTheme theme) {
    if (_isFemaleTheme) {
      return const Color(0xFFFFF5F8);
    }
    return Colors.white;
  }

  Widget _buildUnitChip(
    String label,
    SexSpecificTheme theme, {
    bool showChevron = false,
  }) {
    // Use square-style chips for all themes on this screen
    final borderRadius = BorderRadius.circular(10);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: borderRadius,
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.5),
        ),
        boxShadow: null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 11,
                sm: 12,
                md: 13,
              ),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: theme.primaryColor,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: theme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeightSegmentField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String>? validator,
    required ValueChanged<String> onChanged,
    required SexSpecificTheme theme,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        DecimalInputFormatter(maxDecimalPlaces: 0),
      ],
      validator: validator,
      textAlign: TextAlign.center,
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
      decoration: _buildMetricInputDecoration(
        context: context,
        theme: theme,
        suffix: _buildUnitChip(label, theme),
      ).copyWith(
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 44,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: AppDesignSystem.getResponsiveSpacingExact(
            context,
            xs: 12,
            sm: 14,
            md: 16,
          ),
        ),
      ),
    );
  }

  void _handleHeightChanged() {
    setState(() {
      _convertHeightToMetric();
    });
  }

  Widget _buildDidYouKnowCard(
    BuildContext context,
    SexSpecificTheme theme,
  ) {
    final tips = SexSpecificMessaging.getHealthTips(_selectedGender);
    final message =
        tips.isNotEmpty ? tips.first : 'Balanced nutrition keeps you thriving.';

    return Container(
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 12,
        sm: 14,
        md: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.12),
            theme.primaryColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: theme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Did you know?',
                style: TextStyle(
                  fontSize: AppDesignSystem.getResponsiveFontSize(
                    context,
                    xs: 12,
                    sm: 13,
                    md: 14,
                  ),
                  fontWeight: FontWeight.w700,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 8,
              md: 10,
            ),
          ),
          Text(
            message,
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 11,
                sm: 12,
                md: 13,
              ),
              height: 1.4,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
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
