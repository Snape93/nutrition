import 'package:flutter/material.dart';
import 'user_database.dart';
import 'theme_service.dart';
import 'settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart' as config;

class ProfileViewScreen extends StatefulWidget {
  final String usernameOrEmail;
  final ValueChanged<int>? onCalorieGoalUpdated;
  const ProfileViewScreen({
    super.key,
    required this.usernameOrEmail,
    this.onCalorieGoalUpdated,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Map<String, dynamic>? userData;
  String? userSex;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  String? _selectedGoal;
  bool _isEditingWeight = false;
  bool _isEditingGoal = false;

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
    _loadProfile();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final db = await UserDatabase().database;
    if (!mounted) return;
    final user = await db.query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
    );
    if (!mounted) return;
    if (user.isNotEmpty) {
      setState(() {
        userData = user.first;
        userSex = user.first['sex'] as String?;
        _weightController.text = user.first['weight']?.toString() ?? '';
        _targetWeightController.text =
            user.first['target_weight']?.toString() ?? '';
        _selectedGoal = user.first['goal']?.toString();
      });
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

      // Update local database
      final db = await UserDatabase().database;
      await db.update(
        'users',
        {'weight': _weightController.text.trim()},
        where: 'username = ? OR email = ?',
        whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
      );

      // Try to update backend
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
      final targetWeight = double.tryParse(_targetWeightController.text.trim());

      // Update local database
      final db = await UserDatabase().database;
      await db.update(
        'users',
        {
          'goal': _selectedGoal,
          'target_weight': _targetWeightController.text.trim(),
        },
        where: 'username = ? OR email = ?',
        whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
      );

      // Try to update backend
      try {
        final updateData = <String, dynamic>{
          'goal': _goalBackendMapping[_selectedGoal] ?? _selectedGoal,
        };

        if (targetWeight != null) {
          updateData['target_weight'] = targetWeight;
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
      // Get current user data for calorie calculation
      final db = await UserDatabase().database;
      final user = await db.query(
        'users',
        where: 'username = ? OR email = ?',
        whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
      );

      if (user.isNotEmpty) {
        final userData = user.first;
        final age = userData['age'] as int? ?? 25;
        final sex = userData['sex'] as String? ?? 'male';
        final weight =
            double.tryParse(userData['weight']?.toString() ?? '0') ?? 0;
        final height =
            double.tryParse(userData['height']?.toString() ?? '0') ?? 0;
        final activityLevel =
            userData['activity_level'] as String? ?? 'moderate';
        final goal = userData['goal'] as String? ?? 'maintain_weight';

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
                // Update daily calorie goal in database
                await db.update(
                  'users',
                  {'daily_calorie_goal': dailyCalorieGoal},
                  where: 'username = ? OR email = ?',
                  whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
                );

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

          // Update daily calorie goal in database
          await db.update(
            'users',
            {'daily_calorie_goal': dailyCalorieGoal},
            where: 'username = ? OR email = ?',
            whereArgs: [widget.usernameOrEmail, widget.usernameOrEmail],
          );

          debugPrint(
            'Updated daily calorie goal locally to: $dailyCalorieGoal',
          );
        }
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
        double.tryParse(userData?['weight']?.toString() ?? '0') ?? 0;
    final targetWeight =
        double.tryParse(userData?['target_weight']?.toString() ?? '0') ?? 0;

    if (currentWeight == 0 || targetWeight == 0) {
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
              'Set your weight and target to see progress',
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
        targetWeight > currentWeight
            ? (currentWeight / targetWeight).clamp(0.0, 1.0)
            : (targetWeight / currentWeight).clamp(0.0, 1.0);

    final weightDifference = (targetWeight - currentWeight).abs();
    final isLosing = targetWeight < currentWeight;

    return Container(
      height: 240,
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
              Icon(Icons.trending_up, color: primaryColor, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${currentWeight.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${targetWeight.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 12,
                width: (MediaQuery.of(context).size.width - 88) * progress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${(progress * 100).toStringAsFixed(1)}% complete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${weightDifference.toStringAsFixed(1)} kg ${isLosing ? 'to lose' : 'to gain'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _goalDisplayNames[userData?['goal']?.toString()] ?? 'No goal set',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
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
            });
          },
          isExpanded: true,
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
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
            ),
            SizedBox(width: 12),
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
            SizedBox(width: 8),
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

    if (userData == null) {
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SettingsScreen(
                        usernameOrEmail: widget.usernameOrEmail,
                        onCalorieGoalUpdated: widget.onCalorieGoalUpdated,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
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
                userData!['username'] ?? 'User',
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
                '${userData!['weight']?.toString() ?? 'Not set'} kg',
                Icons.monitor_weight,
                () {
                  setState(() {
                    _isEditingWeight = true;
                  });
                },
                isEditing: _isEditingWeight,
                editWidget: _buildWeightEditWidget(),
              ),

              SizedBox(height: isVerySmallScreen ? 16 : 20),

              // Goal & Target Weight Card
              _buildInfoCard(
                'Fitness Goal',
                '${_goalDisplayNames[userData!['goal']?.toString()] ?? 'Not set'}\n${userData!['target_weight']?.toString() != null ? 'Target: ${userData!['target_weight']} kg' : ''}',
                Icons.flag,
                () {
                  setState(() {
                    _isEditingGoal = true;
                  });
                },
                isEditing: _isEditingGoal,
                editWidget: _buildGoalEditWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
