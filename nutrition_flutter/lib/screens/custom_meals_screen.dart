import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../user_database.dart';

class CustomMealsScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const CustomMealsScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<CustomMealsScreen> createState() => _CustomMealsScreenState();
}

class _CustomMealsScreenState extends State<CustomMealsScreen> {
  List<Map<String, dynamic>> _customMeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMeals();
  }

  Future<void> _loadCustomMeals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final meals = await UserDatabase().getCustomMeals(widget.usernameOrEmail);
      setState(() {
        _customMeals = meals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load custom meals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color get primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(widget.userSex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Custom Meals',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: primaryColor),
            onPressed: _showCreateMealDialog,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _customMeals.isEmpty
              ? _buildEmptyState()
              : _buildMealsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu, size: 60, color: primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'No Custom Meals Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first custom meal to track foods not in our database!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateMealDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Custom Meal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customMeals.length,
      itemBuilder: (context, index) {
        final meal = _customMeals[index];
        return _buildMealCard(meal);
      },
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.restaurant_menu, color: primaryColor, size: 24),
        ),
        title: Text(
          meal['name'],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${meal['calories']?.toStringAsFixed(0) ?? '0'} cal • ${meal['carbs']?.toStringAsFixed(0) ?? '0'}g carbs • ${meal['fat']?.toStringAsFixed(0) ?? '0'}g fat',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Logged: ${meal['date']?.split('T')[0] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        onTap: () => _showMealDetails(meal),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'log') {
              _logMeal(meal);
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'log',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: primaryColor),
                      const SizedBox(width: 8),
                      const Text('Log Again'),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  void _showMealDetails(Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(meal['name']),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Calories: ${meal['calories']?.toStringAsFixed(0) ?? '0'}',
                        ),
                        Text(
                          'Carbs: ${meal['carbs']?.toStringAsFixed(0) ?? '0'}g',
                        ),
                        Text('Fat: ${meal['fat']?.toStringAsFixed(0) ?? '0'}g'),
                        Text('Meal Type: ${meal['meal_type'] ?? 'Other'}'),
                        Text(
                          'Logged: ${meal['date']?.split('T')[0] ?? 'Unknown'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _logMeal(meal);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log Again'),
              ),
            ],
          ),
    );
  }

  void _showCreateMealDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => _CreateMealDialog(
            usernameOrEmail: widget.usernameOrEmail,
            primaryColor: primaryColor,
            backgroundColor: backgroundColor,
          ),
    );

    if (result != null) {
      // Meal created successfully, refresh the list
      _loadCustomMeals();
    }
  }

  void _logMeal(Map<String, dynamic> meal) async {
    final success = await UserDatabase().logCustomMeal(
      usernameOrEmail: widget.usernameOrEmail,
      mealName: meal['name'],
      calories: meal['calories']?.toDouble() ?? 0.0,
      carbs: meal['carbs']?.toDouble() ?? 0.0,
      fat: meal['fat']?.toDouble() ?? 0.0,
      description: meal['description'] ?? '',
      mealType: meal['meal_type'] ?? 'Other',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Meal logged successfully!' : 'Failed to log meal',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _CreateMealDialog extends StatefulWidget {
  final String usernameOrEmail;
  final Color primaryColor;
  final Color backgroundColor;

  const _CreateMealDialog({
    required this.usernameOrEmail,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  State<_CreateMealDialog> createState() => _CreateMealDialogState();
}

class _CreateMealDialogState extends State<_CreateMealDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedMealType;
  bool _isLoading = false;

  final List<String> _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Other',
  ];

  @override
  void dispose() {
    _mealNameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSelectTypeWarning() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        // Auto-close after a short delay to reduce friction
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: widget.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Choose Meal Type',
                style: TextStyle(color: widget.primaryColor),
              ),
            ],
          ),
          content: const Text(
            'Please choose a meal type first.',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Future<void> _createMeal() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await UserDatabase().logCustomMeal(
      usernameOrEmail: widget.usernameOrEmail,
      mealName: _mealNameController.text,
      calories: double.tryParse(_caloriesController.text) ?? 0.0,
      carbs: double.tryParse(_carbsController.text) ?? 0.0,
      fat: double.tryParse(_fatController.text) ?? 0.0,
      description:
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
      mealType: _selectedMealType ?? 'Other',
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom meal logged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {'success': true});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to log custom meal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.backgroundColor,
      title: Text(
        'Add Custom Meal',
        style: TextStyle(color: widget.primaryColor),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal Type Selection
                DropdownButtonFormField<String>(
                  value: _selectedMealType,
                  decoration: InputDecoration(
                    labelText: 'Meal Type *',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  hint: const Text('Select meal type'),
                  items:
                      _mealTypes.map((String mealType) {
                        return DropdownMenuItem<String>(
                          value: mealType,
                          child: Text(mealType),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedMealType = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a meal type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Meal Name
                TextFormField(
                  controller: _mealNameController,
                  decoration: InputDecoration(
                    labelText: 'What\'s the name of your meal?',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  readOnly: _selectedMealType == null,
                  onTap: () {
                    if (_selectedMealType == null) {
                      FocusScope.of(context).unfocus();
                      _showSelectTypeWarning();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a meal name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Calories
                TextFormField(
                  controller: _caloriesController,
                  decoration: InputDecoration(
                    labelText: 'Calories *',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    hintText: 'e.g., 250',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: _selectedMealType == null,
                  onTap: () {
                    if (_selectedMealType == null) {
                      FocusScope.of(context).unfocus();
                      _showSelectTypeWarning();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter calories';
                    }
                    if (double.tryParse(value) == null ||
                        double.parse(value) <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Carbs
                TextFormField(
                  controller: _carbsController,
                  decoration: InputDecoration(
                    labelText: 'Carbs (grams)',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    hintText: 'e.g., 30',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: _selectedMealType == null,
                  onTap: () {
                    if (_selectedMealType == null) {
                      FocusScope.of(context).unfocus();
                      _showSelectTypeWarning();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Fat
                TextFormField(
                  controller: _fatController,
                  decoration: InputDecoration(
                    labelText: 'Fat (grams)',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    hintText: 'e.g., 15',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: _selectedMealType == null,
                  onTap: () {
                    if (_selectedMealType == null) {
                      FocusScope.of(context).unfocus();
                      _showSelectTypeWarning();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: widget.primaryColor),
                    hintText: 'e.g., Homemade with love',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 2,
                  readOnly: _selectedMealType == null,
                  onTap: () {
                    if (_selectedMealType == null) {
                      FocusScope.of(context).unfocus();
                      _showSelectTypeWarning();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: widget.primaryColor),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createMeal,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Log Meal'),
        ),
      ],
    );
  }
}
