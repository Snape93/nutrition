import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart' as config;
// No local DB usage here – we rely on backend via UserDatabase

class ProfileViewScreen extends StatefulWidget {
  final String usernameOrEmail;
  final ValueChanged<int>? onCalorieGoalUpdated;
  final String? initialUserSex;
  const ProfileViewScreen({
    super.key,
    required this.usernameOrEmail,
    this.onCalorieGoalUpdated,
    this.initialUserSex,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Map<String, dynamic>? userData = <String, dynamic>{};
  String? userSex;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  String? _selectedGoal;
  bool _isEditingWeight = false;
  bool _isEditingGoal = false;
  bool _isProfileLoading = true;
  List<double> _recentWeights = [];
  List<DateTime> _recentDates = [];
  int _selectedRangeDays = 14; // 7, 14, 30
  double _bandWidthKg = 1.0; // adjustable maintenance band width

  final List<String> _goalOptions = [
    'lose_weight',
    'gain_muscle',
    'maintain_weight',
    'improve_health',
  ];

  final Map<String, String> _goalDisplayNames = {
    'lose_weight': 'Lose Weight',
    'gain_muscle': 'Gain Muscle',
    'maintain_weight': 'Maintain Weight',
    'improve_health': 'Improve Health',
  };

  // Map Flutter goal values to backend expected values
  final Map<String, String> _goalBackendMapping = {
    'lose_weight': 'lose weight',
    'gain_muscle': 'gain muscle',
    'maintain_weight': 'maintain weight',
    'improve_health': 'improve health',
  };

  @override
  void initState() {
    super.initState();
    userSex = widget.initialUserSex;
    _loadProfile();
    _loadRecentWeightLogs();
  }

  List<double> _getValuesForSelectedRange(List<double> all) {
    if (all.length <= 2) return all;
    final int days = _selectedRangeDays;
    // We don't have dates bound to each value here; approximate by last N points
    final int take = days.clamp(2, 30);
    if (all.length <= take) return all;
    return all.sublist(all.length - take);
  }

  (List<double>, List<DateTime>) _getSeriesForSelectedRange() {
    if (_recentWeights.length <= 2) return (_recentWeights, _recentDates);
    final int days = _selectedRangeDays;
    final int take = days.clamp(2, 30);
    if (_recentWeights.length <= take) return (_recentWeights, _recentDates);
    return (
      _recentWeights.sublist(_recentWeights.length - take),
      _recentDates.sublist(_recentDates.length - take),
    );
  }

  double? _computeWeeklyRateKg() {
    final series = _getSeriesForSelectedRange();
    final vals = series.$1;
    final dates = series.$2;
    if (vals.length < 2 || dates.length < 2) return null;
    final start = dates.first;
    final end = dates.last;
    final days = end.difference(start).inDays.abs();
    if (days == 0) return null;
    final delta = vals.last - vals.first;
    return delta / (days / 7.0);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentWeightLogs() async {
    try {
      final logs = await UserDatabase().getWeightLogs(
        widget.usernameOrEmail,
        limit: 30,
      );
      // Expecting list of maps with 'date' and 'weight'
      logs.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      final weights = <double>[];
      final dates = <DateTime>[];
      for (final log in logs) {
        final w = double.tryParse(log['weight']?.toString() ?? '');
        final dStr = log['date']?.toString();
        if (w != null && dStr != null) {
          weights.add(w);
          dates.add(DateTime.parse(dStr));
        }
      }
      if (!mounted) return;
      setState(() {
        _recentWeights = weights;
        _recentDates = dates;
      });
    } catch (_) {
      // ignore silently for profile summary
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isProfileLoading = true;
    });
    if (!mounted) return;
    try {
      final backendUser = await UserDatabase().getUserData(widget.usernameOrEmail);
      if (!mounted) return;

      if (backendUser != null) {
        final mapped = <String, dynamic>{
          'username': backendUser['username'],
          'email': backendUser['email'],
          'sex': backendUser['sex'],
          'age': backendUser['age'],
          'height': backendUser['height_cm'],
          'weight': backendUser['weight_kg'],
          'weight_kg': backendUser['weight_kg'],
          'target_weight': backendUser['target_weight'],
          'activity_level': backendUser['activity_level'],
          'daily_calorie_goal': backendUser['daily_calorie_goal'],
          'goal': _goalToUiValue(backendUser['goal']?.toString()),
        };

        setState(() {
          userData = mapped;
          userSex = mapped['sex'] as String?;
          _weightController.text = (mapped['weight_kg'] ?? mapped['weight'])?.toString() ?? '';
          _targetWeightController.text =
              mapped['target_weight']?.toString() ?? '';
          _selectedGoal = mapped['goal']?.toString();
          _isProfileLoading = false;
        });
      } else {
        setState(() {
          userData = {}; // avoid infinite loader
          _isProfileLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userData = {};
          _isProfileLoading = false;
        });
      }
    }
  }

  // Convert backend goal string (with spaces) into our UI enum-like value
  String? _goalToUiValue(String? backendGoal) {
    if (backendGoal == null) return null;
    final normalized = backendGoal.trim().toLowerCase();
    switch (normalized) {
      case 'lose weight':
        return 'lose_weight';
      case 'gain muscle':
        return 'gain_muscle';
      case 'maintain':
      case 'maintain weight':
        return 'maintain_weight';
      case 'improve health':
        return 'improve_health';
      default:
        return backendGoal.replaceAll(' ', '_');
    }
  }

  // Dynamic colors based on user sex
  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  Future<void> _updateWeight() async {
    if (_weightController.text.trim().isEmpty) {
      _showSnackBar('Please enter a weight value', isError: true);
      return;
    }

    try {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null || weight <= 0) {
        _showSnackBar('Please enter a valid weight', isError: true);
        return;
      }

      // Update backend
      try {
        final response = await http.put(
          Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'weight_kg': weight}),
        );

        if (response.statusCode == 200) {
          debugPrint('Backend weight update successful');
        } else {
          debugPrint('Backend weight update failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Backend weight update error: $e');
        // Continue with local database only
      }

      // Recalculate and update daily calorie goal
      await _updateCalorieGoal();

      _showSnackBar('Weight updated successfully!');
      setState(() {
        _isEditingWeight = false;
      });
      _loadProfile(); // Reload data
    } catch (e) {
      _showSnackBar('Failed to update weight: $e', isError: true);
    }
  }

  Future<void> _updateGoal() async {
    if (_selectedGoal == null) {
      _showSnackBar('Please select a goal', isError: true);
      return;
    }

    try {
      // Only require target weight for lose_weight goal
      if (_selectedGoal == 'lose_weight') {
        if (_targetWeightController.text.trim().isEmpty) {
          _showSnackBar('Please enter a target weight for Lose Weight goal', isError: true);
          return;
        }
        final targetWeight = double.tryParse(_targetWeightController.text.trim());
        if (targetWeight == null || targetWeight <= 0) {
          _showSnackBar('Please enter a valid target weight', isError: true);
          return;
        }
      }

      final targetWeight = _selectedGoal == 'lose_weight'
          ? double.tryParse(_targetWeightController.text.trim())
          : null;

      // Update backend
      try {
        final updateData = <String, dynamic>{
          'goal': _goalBackendMapping[_selectedGoal] ?? _selectedGoal,
        };

        // Only include target_weight for lose_weight, or clear it for other goals
        if (_selectedGoal == 'lose_weight' && targetWeight != null) {
          updateData['target_weight'] = targetWeight;
        } else if (_selectedGoal != 'lose_weight') {
          // Clear target weight for non-lose-weight goals
          updateData['target_weight'] = null;
        }

        final response = await http.put(
          Uri.parse('${config.apiBase}/user/${widget.usernameOrEmail}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updateData),
        );

        if (response.statusCode == 200) {
          debugPrint('Backend goal update successful');
        } else {
          debugPrint('Backend goal update failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Backend goal update error: $e');
        // Continue with local database only
      }

      // Recalculate and update daily calorie goal
      await _updateCalorieGoal();

      _showSnackBar('Goal updated successfully!');
      setState(() {
        _isEditingGoal = false;
      });
      _loadProfile(); // Reload data
    } catch (e) {
      _showSnackBar('Failed to update goal: $e', isError: true);
    }
  }

  Future<void> _updateCalorieGoal() async {
    try {
      // Get current user data from memory for calorie calculation
      final data = userData ?? {};
      final age = data['age'] as int?;
      if (age == null) {
        debugPrint('Warning: Age not found in user data for calorie calculation');
        return; // Cannot calculate without age
      }
      final sex = data['sex'] as String? ?? 'male';
      final weight = double.tryParse(data['weight']?.toString() ?? '0') ?? 0;
      final height = double.tryParse(data['height']?.toString() ?? '0') ?? 0;
      final activityLevel = data['activity_level'] as String? ?? 'moderate';
      final goal = data['goal'] as String? ?? 'maintain_weight';

      if (weight > 0 && height > 0) {
          // Try backend API first
          try {
            final response = await http.post(
              Uri.parse('${config.apiBase}/calculate/daily_goal'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'age': age,
                'sex': sex,
                'weight': weight,
                'height': height,
                'activity_level': activityLevel,
                'goal': _goalBackendMapping[goal] ?? goal,
              }),
            );

            if (response.statusCode == 200) {
              final result = jsonDecode(response.body);
              final dailyCalorieGoal = result['daily_calorie_goal'] as int?;

              if (dailyCalorieGoal != null) {
                // Update in-memory data so UI can reflect it
                userData = {
                  ...data,
                  'daily_calorie_goal': dailyCalorieGoal,
                };
                debugPrint(
                  'Updated daily calorie goal via backend to: $dailyCalorieGoal',
                );
                return;
              }
            }
          } catch (e) {
            debugPrint('Backend calorie calculation failed: $e');
          }

          // Fallback to local calculation
          // Calculate BMR using Mifflin-St Jeor Equation
          double bmr;
          if (sex.toLowerCase() == 'female') {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161;
          } else {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5;
          }

          // Activity multipliers
          final activityMultipliers = {
            'sedentary': 1.2,
            'lightly active': 1.375,
            'lightly_active': 1.375,
            'active': 1.55,
            'moderately active': 1.55,
            'moderately_active': 1.55,
            'very active': 1.725,
            'very_active': 1.725,
          };

          final multiplier =
              activityMultipliers[activityLevel.toLowerCase()] ?? 1.55;
          double tdee = bmr * multiplier;

          // Goal adjustments
          if (goal.toLowerCase() == 'lose_weight') {
            tdee -= 300;
          } else if (goal.toLowerCase() == 'gain_muscle') {
            tdee += 200;
          } else if (goal.toLowerCase() == 'improve_health') {
            // For improve health, maintain current weight with slight optimization
            tdee += 50;
          }
          // maintain_weight keeps tdee as is (no adjustment)

          final dailyCalorieGoal = tdee.round();
          userData = {
            ...data,
            'daily_calorie_goal': dailyCalorieGoal,
          };
          debugPrint(
            'Updated daily calorie goal locally to: $dailyCalorieGoal',
          );
      }
    } catch (e) {
      debugPrint('Error updating calorie goal: $e');
      // Don't show error to user as this is a background calculation
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildProgressChart() {
    final currentWeight =
        double.tryParse(userData?['weight_kg']?.toString() ?? '0') ?? 0;
    final targetWeight =
        double.tryParse(userData?['target_weight']?.toString() ?? '0') ?? 0;
    final goal = (userData?['goal'] ?? '').toString();

    // For "maintain_weight", use current weight as target if no target set
    final effectiveTarget = (goal == 'maintain_weight' && targetWeight == 0)
        ? currentWeight
        : targetWeight;

    // For "lose_weight", require both current and target
    // For other goals, only require current weight
    final needsTarget = goal == 'lose_weight';
    if (currentWeight == 0 || (needsTarget && effectiveTarget == 0)) {
      return Container(
        height: 200,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              needsTarget
                  ? 'Set your weight and target to see progress'
                  : 'Set your weight to see progress',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Track your journey toward your goals',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final progress =
        effectiveTarget > currentWeight
            ? (currentWeight / effectiveTarget).clamp(0.0, 1.0)
            : (effectiveTarget / currentWeight).clamp(0.0, 1.0);

    final weightDifference = (effectiveTarget - currentWeight).abs();
    final isLosing = effectiveTarget < currentWeight;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: primaryColor, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (effectiveTarget > 0 || goal == 'maintain_weight') ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${currentWeight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        goal == 'maintain_weight' ? 'Maintain' : 'Target',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 2),
                      Text(
                        effectiveTarget > 0
                            ? '${effectiveTarget.toStringAsFixed(1)} kg'
                            : '—',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (effectiveTarget > 0) ...[
            SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: (MediaQuery.of(context).size.width - 80) * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            if (goal == 'lose_weight') ...[
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% complete',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    '${weightDifference.toStringAsFixed(1)} kg ${isLosing ? 'to lose' : 'to gain'}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
          if (_recentWeights.length >= 2) ...[
            SizedBox(height: 10),
            Container(
              height: 65,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: _getValuesForSelectedRange(_recentWeights),
                  target: effectiveTarget > 0 ? effectiveTarget : null,
                  bandLow: (userData?['goal'] == 'maintain_weight' && effectiveTarget > 0)
                      ? effectiveTarget - _bandWidthKg
                      : null,
                  bandHigh: (userData?['goal'] == 'maintain_weight' && effectiveTarget > 0)
                      ? effectiveTarget + _bandWidthKg
                      : null,
                  color: primaryColor,
                ),
              ),
            ),
            SizedBox(height: 4),
            Builder(builder: (context) {
              final rate = _computeWeeklyRateKg();
              final goalText = (userData?['goal'] ?? '').toString();
              final currentW = double.tryParse(userData?['weight_kg']?.toString() ?? '0') ?? 0;
              final targetW = double.tryParse(userData?['target_weight']?.toString() ?? '0') ?? 0;
              final effectiveT = (goalText == 'maintain_weight' && targetW == 0) ? currentW : targetW;
              String text = '';
              if (rate != null) {
                if (goalText == 'gain_muscle') {
                  final sign = rate >= 0 ? '+' : '';
                  text = '$sign${rate.toStringAsFixed(2)} kg/week';
                } else if (goalText == 'maintain_weight') {
                  final (vals, _) = _getSeriesForSelectedRange();
                  final maintTarget = effectiveT > 0 ? effectiveT : currentW;
                  final low = maintTarget - _bandWidthKg;
                  final high = maintTarget + _bandWidthKg;
                  final within = vals.where((v) => v >= low && v <= high).length;
                  text = '$within/${vals.length} within ±${_bandWidthKg.toStringAsFixed(1)}kg';
                } else if (goalText == 'improve_health') {
                  text = 'Stable trend';
                } else {
                  final sign = rate >= 0 ? '+' : '';
                  text = '$sign${rate.toStringAsFixed(2)} kg/week';
                }
              }
              return Text(
                text,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              );
            }),
          ],
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _goalDisplayNames[userData?['goal']?.toString()] ?? 'No goal set',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onEdit, {
    bool isEditing = false,
    Widget? editWidget,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              if (!isEditing)
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, color: primaryColor, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (isEditing && editWidget != null)
            editWidget
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeightEditWidget() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter current weight (kg)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixText: 'kg',
                ),
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: _updateWeight,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Save'),
            ),
            SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isEditingWeight = false;
                  _weightController.text =
                      userData?['weight']?.toString() ?? '';
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalEditWidget() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedGoal,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          hint: Text('Select your goal'),
          items:
              _goalOptions.map((goal) {
                return DropdownMenuItem<String>(
                  value: goal,
                  child: Text(
                    _goalDisplayNames[goal]!,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedGoal = value;
              // Clear target weight if switching away from lose_weight
              if (value != 'lose_weight') {
                _targetWeightController.clear();
              }
            });
          },
          isExpanded: true,
        ),
        if (_selectedGoal == 'lose_weight') ...[
          SizedBox(height: 16),
          TextField(
            controller: _targetWeightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Target weight (kg)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixText: 'kg',
            ),
          ),
        ],
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isEditingGoal = false;
                  _targetWeightController.text =
                      userData?['target_weight']?.toString() ?? '';
                  _selectedGoal = userData?['goal']?.toString();
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Cancel'),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _updateGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;
    final bool isProfileLoaded =
        userData != null && userData!.isNotEmpty && !_isProfileLoading;
    final data = userData ?? const <String, dynamic>{};
    final displayUsername = (data['username'] as String?) ?? 'User';
    final weightValue = data['weight_kg'] ?? data['weight'];
    final weightText =
        weightValue != null ? '${weightValue.toString()} kg' : 'Not set';
    final goalKey = data['goal']?.toString();
    final targetWeight = data['target_weight'];
    final targetText =
        targetWeight != null ? 'Target: $targetWeight kg' : '';
    final goalText =
        (_goalDisplayNames[goalKey] ?? 'Not set') +
        (targetText.isNotEmpty ? '\n$targetText' : '');

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontSize: isVerySmallScreen ? 18 : 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrowScreen ? 16 : 24,
                vertical: isVerySmallScreen ? 16 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Username Section
                  Container(
                    width: isVerySmallScreen ? 100 : 120,
                    height: isVerySmallScreen ? 100 : 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: isVerySmallScreen ? 50 : 60,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: isVerySmallScreen ? 16 : 24),

                  // Username
                  Text(
                    displayUsername,
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isVerySmallScreen ? 24 : 32),

                  // Progress Chart
                  _buildProgressChart(),

                  SizedBox(height: isVerySmallScreen ? 20 : 24),

                  // Current Weight Card
                  _buildInfoCard(
                    'Current Weight',
                    weightText,
                    Icons.monitor_weight,
                    () {
                      if (!isProfileLoaded) return;
                      setState(() {
                        _isEditingWeight = true;
                      });
                    },
                    isEditing: _isEditingWeight && isProfileLoaded,
                    editWidget: _buildWeightEditWidget(),
                  ),

                  SizedBox(height: isVerySmallScreen ? 16 : 20),

                  // Goal & Target Weight Card
                  _buildInfoCard(
                    'Fitness Goal',
                    goalText,
                    Icons.flag,
                    () {
                      if (!isProfileLoaded) return;
                      setState(() {
                        _isEditingGoal = true;
                      });
                    },
                    isEditing: _isEditingGoal && isProfileLoaded,
                    editWidget: _buildGoalEditWidget(),
                  ),
                ],
              ),
            ),
          ),
          if (!isProfileLoaded)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: backgroundColor.withValues(alpha: 0.6),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
              ),
            ),
          if (_isProfileLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                backgroundColor: primaryColor.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double? target;
  final double? bandLow;
  final double? bandHigh;
  final Color color;
  _SparklinePainter({required this.values, required this.color, this.target, this.bandLow, this.bandHigh});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);

    // Draw maintenance band if provided
    if (bandLow != null && bandHigh != null) {
      final lowNorm = (bandLow! - minV) / range;
      final highNorm = (bandHigh! - minV) / range;
      final yHigh = size.height - highNorm * size.height;
      final yLow = size.height - lowNorm * size.height;
      final rect = Rect.fromLTRB(0, yHigh, size.width, yLow);
      final bandPaint = Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, bandPaint);
    }

    // Draw target line if provided
    if (target != null) {
      final norm = (target! - minV) / range;
      final y = size.height - norm * size.height;
      final targetPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), targetPaint);
    }

    // Optional fade fill under line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color || oldDelegate.target != target || oldDelegate.bandLow != bandLow || oldDelegate.bandHigh != bandHigh;
  }
}
