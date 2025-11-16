import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import '../design_system/app_design_system.dart';
import '../config.dart';
import '../models/food_item.dart';
import '../user_database.dart';
import '../utils/input_formatters.dart';

// Use centralized apiBase from config.dart

/// Professional food logging screen with consistent design
class ProfessionalFoodLogScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;

  const ProfessionalFoodLogScreen({
    super.key,
    required this.usernameOrEmail,
    this.userSex,
  });

  @override
  State<ProfessionalFoodLogScreen> createState() =>
      _ProfessionalFoodLogScreenState();
}

class _ProfessionalFoodLogScreenState extends State<ProfessionalFoodLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _servingController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  FoodItem? _selectedFood; // Single selection only
  Map<String, dynamic>? _nutritionInfo; // Nutrition info for selected food
  String? _selectedMeal; // Must be selected first before using other features
  List<FoodItem> _recommendedFoods = [];
  List<FoodItem> _searchSuggestions = [];
  bool _isSearching = false;
  bool _showSuccess = false;
  List<FoodItem> _recentFoods = [];
  bool _isLoggingFood = false; // Loading state for food logging
  String _selectedServingUnit = 'g'; // Default unit
  bool _showMoreUnits = false; // Track if showing "More..." units
  final GlobalKey _unitSelectorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fetchRecommendedFoods();
    fetchRecentFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _servingController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Color get _primaryColor => AppDesignSystem.getPrimaryColor(widget.userSex);
  Color get _backgroundColor =>
      AppDesignSystem.getBackgroundColor(widget.userSex);

  Future<http.Response?> _safeGet(
    Uri uri, {
    int timeoutSeconds = 6,
    int retries = 1,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        return await http.get(uri).timeout(Duration(seconds: timeoutSeconds));
      } on TimeoutException catch (_) {
        if (attempt == retries) rethrow;
      } on SocketException catch (_) {
        if (attempt == retries) rethrow;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  Future<http.Response?> _safePost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int timeoutSeconds = 8,
  }) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(Duration(seconds: timeoutSeconds));
    } on TimeoutException catch (_) {
      return null;
    } on SocketException catch (_) {
      return null;
    }
  }

  Future<void> fetchRecommendedFoods() async {
    final user = widget.usernameOrEmail;
    final mealType = _selectedMeal?.toLowerCase() ?? '';

    final queryParams = <String, String>{'user': user, 'meal_type': mealType};

    final uri = Uri.parse(
      '$apiBase/foods/recommend',
    ).replace(queryParameters: queryParams);

    debugPrint('DEBUG: [Professional Food Recommendations] Starting request');
    debugPrint('DEBUG: [Professional Food Recommendations] User: $user');
    debugPrint(
      'DEBUG: [Professional Food Recommendations] Meal Type: $mealType',
    );
    debugPrint('DEBUG: [Professional Food Recommendations] API URL: $uri');

    try {
      final response = await _safeGet(uri, timeoutSeconds: 6, retries: 1);

      if (!mounted) return;

      if (response != null) {
        debugPrint(
          'DEBUG: [Professional Food Recommendations] Response status: ${response.statusCode}',
        );
        debugPrint(
          'DEBUG: [Professional Food Recommendations] Response body length: ${response.body.length}',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint(
            'DEBUG: [Professional Food Recommendations] Parsed response data: $data',
          );
          final recommended = data['recommended'] as List? ?? [];
          debugPrint(
            'DEBUG: [Professional Food Recommendations] Found ${recommended.length} recommendations',
          );

          if (recommended.isNotEmpty) {
            debugPrint(
              'DEBUG: [Professional Food Recommendations] First item: ${recommended[0]}',
            );
          }

          if (!mounted) return;
          setState(() {
            _recommendedFoods =
                recommended.map((json) => FoodItem.fromJson(json)).toList();
          });
          debugPrint(
            'DEBUG: [Professional Food Recommendations] Successfully loaded ${_recommendedFoods.length} food items',
          );
        } else {
          debugPrint(
            'DEBUG: [Professional Food Recommendations] Request failed with status ${response.statusCode}',
          );
          debugPrint(
            'DEBUG: [Professional Food Recommendations] Response body: ${response.body}',
          );
          if (!mounted) return;
          setState(() => _recommendedFoods = []);
        }
      } else {
        debugPrint(
          'DEBUG: [Professional Food Recommendations] Response is null (likely timeout or connection error)',
        );
        if (!mounted) return;
        setState(() => _recommendedFoods = []);
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: [Professional Food Recommendations] Error: $e');
      debugPrint(
        'DEBUG: [Professional Food Recommendations] Stack trace: $stackTrace',
      );
      if (!mounted) return;
      setState(() => _recommendedFoods = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach server. Please retry.')),
      );
    }
  }

  Future<void> fetchSearchSuggestions(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() => _searchSuggestions = []);
      return;
    }

    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final response = await _safeGet(
        Uri.parse('$apiBase/foods/search?query=$query'),
        timeoutSeconds: 6,
        retries: 1,
      );

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _searchSuggestions =
              (data['foods'] as List)
                  .map((json) => FoodItem.fromJson(json))
                  .toList();
          _isSearching = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _searchSuggestions = [];
          _isSearching = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> fetchAndSelectFood(String foodName) async {
    try {
      final response = await _safeGet(
        Uri.parse('$apiBase/foods/info?name=${Uri.encodeComponent(foodName)}'),
        timeoutSeconds: 6,
        retries: 1,
      );

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final food = FoodItem.fromJson(data['food']);
        if (!mounted) return;
        setState(() {
          // Replace any existing selection with new food
          _selectedFood = food;
          _nutritionInfo = {
            'name': food.foodName,
            'calories': food.calories,
            'protein': food.protein,
            'carbs': food.carbs,
            'fat': food.fat,
          };
          _searchController.clear();
          _searchSuggestions = [];
        });
      }
    } catch (_) {
      // Silently ignore; keep UI responsive
    }
  }

  Future<void> fetchRecentFoods() async {
    final logs = await UserDatabase().getFoodLogs(widget.usernameOrEmail);
    final seen = <String>{};
    final List<FoodItem> recent = [];

    for (final log in logs) {
      final name = log['food_name'] as String;
      if (!seen.contains(name)) {
        seen.add(name);
        recent.add(
          FoodItem(
            foodName: name,
            category: '',
            servingSize: '',
            calories: (log['calories'] as num?)?.toDouble() ?? 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: 0,
            sodium: 0,
            imageUrl: null,
          ),
        );
      }
      if (recent.length >= 8) break;
    }

    if (!mounted) return;
    setState(() => _recentFoods = recent);
  }

  Future<void> _addFoodLog() async {
    if (_selectedFood == null) return;

    // Show loading state
    if (!mounted) return;
    setState(() {
      _isLoggingFood = true;
      _showSuccess = false;
    });

    final user = widget.usernameOrEmail;
    final now = DateTime.now();
    final info = _nutritionInfo ?? {};

    // Calculate nutrition values
    double servingValue = double.tryParse(_servingController.text) ?? 100.0;
    double grams = _convertToGrams(servingValue, _selectedServingUnit);
    double quantity = double.tryParse(_quantityController.text) ?? 1;
    double factor = (grams / 100.0) * quantity;

    final foodLog = {
      'food_name': _selectedFood!.foodName,
      'calories': ((info['calories'] ?? 0) as num).toDouble() * factor,
      'protein': ((info['protein'] ?? 0) as num).toDouble() * factor,
      'carbs': ((info['carbs'] ?? 0) as num).toDouble() * factor,
      'fat': ((info['fat'] ?? 0) as num).toDouble() * factor,
      'serving_size':
          '${_servingController.text.isNotEmpty ? _servingController.text : "100"}$_selectedServingUnit',
      'quantity': quantity,
      'meal_type': _selectedMeal,
      'timestamp': now.toIso8601String(),
    };

    final response = await _safePost(
      Uri.parse('$apiBase/log/food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': user,
        'foods': [foodLog],
      }),
      timeoutSeconds: 8,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      // Food logs are already saved to Neon PostgreSQL database by the backend API
      // No need to call saveFoodLog() again as it would create duplicate entries

      if (!mounted) return;

      // Calculate total calories for display before resetting
      double totalCalories = (foodLog['calories'] as num).toDouble();

      // Reset form completely (including meal type)
      setState(() {
        _isLoggingFood = false;
        _selectedFood = null;
        _nutritionInfo = null;
        _selectedMeal = null; // Clear meal type
        _servingController.clear();
        _quantityController.text = '1';
        _searchController.clear();
        _searchSuggestions = [];
        _selectedServingUnit = 'g'; // Reset to default
      });

      // Refresh recommendations (will be empty since meal is null)
      fetchRecommendedFoods();

      if (mounted) {
        _showFoodLogSuccessDialog(totalCalories, 1);
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoggingFood = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to log food. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _convertToGrams(double value, String unit) {
    // Conversion factors to grams
    // Note: Volume-to-weight conversions are approximations (based on water density)
    // For accurate nutrition, food-specific conversions may be needed later
    switch (unit.toLowerCase()) {
      case 'g':
        return value;
      case 'oz':
        return value * 28.3495; // 1 oz = 28.3495 g (exact)
      case 'cup':
        return value * 240.0; // 1 US cup = 240 ml ≈ 240g (for water/liquids)
      case 'ml':
        return value * 1.0; // 1 ml ≈ 1g (for water/liquids at 4°C)
      case 'tbsp':
        return value * 15.0; // 1 tbsp = 15 ml ≈ 15g
      case 'tsp':
        return value * 5.0; // 1 tsp = 5 ml ≈ 5g
      case 'lb':
        return value * 453.592; // 1 lb = 453.592 g (exact)
      case 'kg':
        return value * 1000.0; // 1 kg = 1000 g (exact)
      case 'serving':
        // "Serving" is typically defined per food item in the database
        // For now, use 100g as default (1 serving = 100g)
        // TODO: This should ideally reference the food's actual serving size from database
        return value * 100.0;
      case 'piece':
        // For pieces, use a default (e.g., 100g per piece)
        // This will need food-specific logic later (e.g., 1 apple ≈ 182g)
        return value * 100.0;
      default:
        return value; // Default to grams
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: Colors.white),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Text(
              'Log Food',
              style: AppDesignSystem.headlineMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Padding(
            padding: AppDesignSystem.getResponsivePadding(context),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMotivationalCard(),
                  const SizedBox(height: AppDesignSystem.spaceLG),
                  _buildSearchCard(),
                  const SizedBox(height: AppDesignSystem.spaceLG),
                  _buildRecommendedSection(),
                  const SizedBox(height: 100), // Space for sticky button
                ],
              ),
            ),
          ),
          // Sticky "Add to Log" button at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: AppDesignSystem.spaceMD,
                right: AppDesignSystem.spaceMD,
                top: AppDesignSystem.spaceMD,
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    AppDesignSystem.spaceMD,
              ),
              decoration: BoxDecoration(
                color: _backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildLogButton(),
            ),
          ),
          // Centered loading overlay
          if (_isLoggingFood)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Logging food...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMotivationalCard() {
    return Card(
      elevation: AppDesignSystem.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Row(
          children: [
            Icon(Icons.emoji_emotions, color: _primaryColor, size: 24),
            const SizedBox(width: AppDesignSystem.spaceMD),
            Expanded(
              child: Text(
                _getMotivationalMessage(),
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: AppDesignSystem.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: AppDesignSystem.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Food',
              style: AppDesignSystem.headlineSmall.copyWith(
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildSelectedFoodsChips(),
            const SizedBox(height: AppDesignSystem.spaceMD),
            _buildSearchField(),
            if (_isSearching) _buildLoadingIndicator(),
            if (_searchSuggestions.isNotEmpty) _buildSearchSuggestions(),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildRecentFoods(),
            const SizedBox(height: AppDesignSystem.spaceLG),
            _buildMealAndServingInputs(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFoodsChips() {
    if (_selectedFood == null) return const SizedBox.shrink();

    return Chip(
      label: Text(_selectedFood!.foodName),
      onDeleted: () {
        setState(() {
          _selectedFood = null;
          _nutritionInfo = null;
        });
      },
    );
  }

  Widget _buildSearchField() {
    final isEnabled = _selectedMeal != null;
    return TextField(
      controller: _searchController,
      enabled: isEnabled,
      decoration: AppDesignSystem.inputDecoration(
        labelText: 'Search for food...',
        hintText: isEnabled ? 'Enter food name' : 'Select meal type first',
        prefixIcon: Icons.search,
        primaryColor: _primaryColor,
      ).copyWith(
        labelStyle: TextStyle(color: _primaryColor),
        hintStyle: TextStyle(color: isEnabled ? null : Colors.grey[400]),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
      ],
      onChanged: isEnabled ? fetchSearchSuggestions : null,
      onSubmitted:
          isEnabled
              ? (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    // Replace any existing selection
                    _selectedFood = FoodItem(
                      foodName: value,
                      category: '',
                      servingSize: '',
                      calories: 0,
                      protein: 0,
                      carbs: 0,
                      fat: 0,
                      fiber: 0,
                      sodium: 0,
                      imageUrl: null,
                    );
                    _nutritionInfo = {
                      'name': value,
                      'calories': 0,
                      'protein': 0,
                      'carbs': 0,
                      'fat': 0,
                    };
                  });
                }
              }
              : null,
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppDesignSystem.spaceMD),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(color: AppDesignSystem.outline),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchSuggestions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final food = _searchSuggestions[index];
          final isEnabled = _selectedMeal != null;
          return ListTile(
            leading: _buildFoodIcon(food),
            title: Text(food.foodName, style: AppDesignSystem.bodyMedium),
            subtitle: Text(
              '${food.calories} kcal',
              style: AppDesignSystem.bodySmall,
            ),
            enabled: isEnabled,
            onTap: isEnabled ? () => fetchAndSelectFood(food.foodName) : null,
          );
        },
      ),
    );
  }

  Widget _buildRecentFoods() {
    if (_recentFoods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Foods',
          style: AppDesignSystem.titleMedium.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                _recentFoods
                    .map(
                      (food) => Padding(
                        padding: const EdgeInsets.only(
                          right: AppDesignSystem.spaceSM,
                        ),
                        child: ActionChip(
                          avatar: _buildFoodIcon(food, size: 20),
                          label: Text(
                            food.foodName,
                            style: AppDesignSystem.bodySmall,
                          ),
                          onPressed:
                              _selectedMeal != null
                                  ? () => fetchAndSelectFood(food.foodName)
                                  : null,
                          backgroundColor: AppDesignSystem.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMealAndServingInputs() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.restaurant, color: _primaryColor),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMeal,
                decoration: AppDesignSystem.inputDecoration(
                  labelText: 'Meal *',
                  hintText: 'Select meal type',
                  primaryColor: _primaryColor,
                ).copyWith(labelStyle: TextStyle(color: _primaryColor)),
                items:
                    ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                        .map(
                          (meal) => DropdownMenuItem(
                            value: meal,
                            child: Text(
                              meal,
                              style: AppDesignSystem.bodyMedium,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMeal = value;
                    // Clear selected food when meal changes
                    _selectedFood = null;
                    _nutritionInfo = null;
                    _servingController.clear();
                    _quantityController.text = '1';
                    _searchController.clear();
                    _searchSuggestions.clear();
                  });
                  if (value != null) {
                    fetchRecommendedFoods();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        if (_selectedMeal == null)
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
              border: Border.all(
                color: _primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _primaryColor, size: 20),
                const SizedBox(width: AppDesignSystem.spaceSM),
                Expanded(
                  child: Text(
                    'Please select a meal type first to continue',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Icon(Icons.scale, color: _primaryColor),
              const SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: TextField(
                  controller: _servingController,
                  enabled: _selectedMeal != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  decoration: AppDesignSystem.inputDecoration(
                    labelText: 'Serving Size',
                    primaryColor: _primaryColor,
                  ).copyWith(
                    labelStyle: TextStyle(color: _primaryColor),
                    suffixIcon: _buildUnitSelector(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spaceMD),
          Row(
            children: [
              Icon(Icons.confirmation_num, color: _primaryColor),
              const SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  enabled: _selectedMeal != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  decoration: AppDesignSystem.inputDecoration(
                    labelText: 'Quantity',
                    primaryColor: _primaryColor,
                  ).copyWith(labelStyle: TextStyle(color: _primaryColor)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendedSection() {
    if (_selectedMeal == null) {
      return const SizedBox.shrink(); // Don't show recommendations until meal is selected
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended for you',
          style: AppDesignSystem.headlineSmall.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        if (_recommendedFoods.isNotEmpty)
          ..._recommendedFoods.map((food) => _buildRecommendedFoodCard(food))
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildRecommendedFoodCard(FoodItem food) {
    final isSelected = _selectedFood?.foodName == food.foodName;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceMD),
      elevation:
          isSelected
              ? AppDesignSystem.elevationHigh
              : AppDesignSystem.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        side:
            isSelected
                ? BorderSide(color: _primaryColor, width: 2)
                : BorderSide.none,
      ),
      child: ListTile(
        leading: _buildFoodIcon(food),
        title: Text(food.foodName, style: AppDesignSystem.titleMedium),
        subtitle: Text(
          '${food.calories} kcal',
          style: AppDesignSystem.bodySmall,
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle : Icons.add_circle_outline,
          color: isSelected ? _primaryColor : AppDesignSystem.onSurfaceVariant,
        ),
        enabled: _selectedMeal != null,
        onTap:
            _selectedMeal != null
                ? () {
                  setState(() {
                    if (isSelected) {
                      // Deselect if already selected
                      _selectedFood = null;
                      _nutritionInfo = null;
                    } else {
                      // Replace any existing selection with new food
                      _selectedFood = food;
                      _nutritionInfo = {
                        'name': food.foodName,
                        'calories': food.calories,
                        'protein': food.protein,
                        'carbs': food.carbs,
                        'fat': food.fat,
                      };
                    }
                  });
                }
                : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spaceXL),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 48,
              color: AppDesignSystem.onSurfaceVariant,
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'No recommendations available',
              style: AppDesignSystem.titleMedium.copyWith(
                color: AppDesignSystem.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceSM),
            Text(
              'Try searching for foods or check back later',
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedFood != null ? _addFoodLog : null,
        icon:
            _showSuccess
                ? const Icon(Icons.check, color: Colors.white)
                : const Icon(Icons.add, color: Colors.white),
        label: Text(
          _showSuccess ? 'Logged!' : 'Add to Log',
          style: AppDesignSystem.titleMedium.copyWith(color: Colors.white),
        ),
        style: AppDesignSystem.primaryButtonStyle(primaryColor: _primaryColor),
      ),
    );
  }

  Widget _buildUnitSelector() {
    // Common units shown first
    const commonUnits = ['g', 'oz', 'cup', 'ml', 'piece'];
    // Extra units shown when "More..." is clicked
    const extraUnits = ['tbsp', 'tsp', 'lb', 'kg', 'serving'];

    final isEnabled = _selectedMeal != null;

    return PopupMenuButton<String>(
      key: _unitSelectorKey,
      enabled: isEnabled,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _selectedServingUnit,
          style: TextStyle(
            color: isEnabled ? _primaryColor : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      onSelected: (value) {
        if (value == '__more__') {
          // Toggle to show "More..." units and re-open menu
          setState(() {
            _showMoreUnits = true;
          });
          // Re-open the menu immediately to show the new items
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted && _unitSelectorKey.currentContext != null) {
              final button =
                  _unitSelectorKey.currentContext!.findRenderObject()
                      as RenderBox?;
              if (button != null) {
                final screenSize = MediaQuery.of(context).size;
                final buttonPosition = button.localToGlobal(Offset.zero);
                final position = RelativeRect.fromLTRB(
                  buttonPosition.dx,
                  buttonPosition.dy + button.size.height,
                  screenSize.width - buttonPosition.dx - button.size.width,
                  screenSize.height - buttonPosition.dy - button.size.height,
                );
                showMenu<String>(
                  context: context,
                  position: position,
                  items: _buildMoreUnitsMenuItems(),
                ).then((value) {
                  if (value == '__back__') {
                    // Go back to common units
                    setState(() {
                      _showMoreUnits = false;
                    });
                    // Re-open menu with common units
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted &&
                          _unitSelectorKey.currentContext != null) {
                        final button =
                            _unitSelectorKey.currentContext!.findRenderObject()
                                as RenderBox?;
                        if (button != null) {
                          final screenSize = MediaQuery.of(context).size;
                          final buttonPosition = button.localToGlobal(
                            Offset.zero,
                          );
                          final newPosition = RelativeRect.fromLTRB(
                            buttonPosition.dx,
                            buttonPosition.dy + button.size.height,
                            screenSize.width -
                                buttonPosition.dx -
                                button.size.width,
                            screenSize.height -
                                buttonPosition.dy -
                                button.size.height,
                          );
                          showMenu<String>(
                            context: context,
                            position: newPosition,
                            items: _buildCommonUnitsMenuItems(),
                          ).then((selectedValue) {
                            if (selectedValue != null &&
                                selectedValue != '__more__') {
                              setState(() {
                                _selectedServingUnit = selectedValue;
                                _showMoreUnits = false;
                              });
                            }
                          });
                        }
                      }
                    });
                  } else if (value != null) {
                    setState(() {
                      _selectedServingUnit = value;
                      _showMoreUnits = false;
                    });
                  }
                });
              }
            }
          });
        } else if (value == '__back__') {
          // Go back to common units and re-open menu
          setState(() {
            _showMoreUnits = false;
          });
          // Re-open the menu to show common units
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted && _unitSelectorKey.currentContext != null) {
              final button =
                  _unitSelectorKey.currentContext!.findRenderObject()
                      as RenderBox?;
              if (button != null) {
                final screenSize = MediaQuery.of(context).size;
                final buttonPosition = button.localToGlobal(Offset.zero);
                final position = RelativeRect.fromLTRB(
                  buttonPosition.dx,
                  buttonPosition.dy + button.size.height,
                  screenSize.width - buttonPosition.dx - button.size.width,
                  screenSize.height - buttonPosition.dy - button.size.height,
                );
                showMenu<String>(
                  context: context,
                  position: position,
                  items: _buildCommonUnitsMenuItems(),
                ).then((value) {
                  if (value != null && value != '__more__') {
                    setState(() {
                      _selectedServingUnit = value;
                      _showMoreUnits = false;
                    });
                  }
                });
              }
            }
          });
        } else {
          // Handle regular unit selection
          setState(() {
            _selectedServingUnit = value;
            _showMoreUnits = false; // Reset to common units view
          });
        }
      },
      itemBuilder: (BuildContext context) {
        final items = <PopupMenuEntry<String>>[];

        if (_showMoreUnits) {
          // Show extra units with back option
          items.add(
            PopupMenuItem<String>(
              value: '__back__',
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: _primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
          items.add(const PopupMenuDivider());

          // Add extra units
          for (final unit in extraUnits) {
            items.add(
              PopupMenuItem<String>(
                value: unit,
                child: Row(
                  children: [
                    if (_selectedServingUnit == unit)
                      Icon(Icons.check, color: _primaryColor, size: 18),
                    if (_selectedServingUnit == unit) const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontWeight:
                            _selectedServingUnit == unit
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color:
                            _selectedServingUnit == unit
                                ? _primaryColor
                                : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          // Show common units
          for (final unit in commonUnits) {
            items.add(
              PopupMenuItem<String>(
                value: unit,
                child: Row(
                  children: [
                    if (_selectedServingUnit == unit)
                      Icon(Icons.check, color: _primaryColor, size: 18),
                    if (_selectedServingUnit == unit) const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontWeight:
                            _selectedServingUnit == unit
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color:
                            _selectedServingUnit == unit
                                ? _primaryColor
                                : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Add divider and "More..." option
          items.add(const PopupMenuDivider());
          items.add(
            PopupMenuItem<String>(
              value: '__more__',
              child: Row(
                children: [
                  const Text(
                    'More...',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
                ],
              ),
            ),
          );
        }

        return items;
      },
    );
  }

  List<PopupMenuEntry<String>> _buildCommonUnitsMenuItems() {
    const commonUnits = ['g', 'oz', 'cup', 'ml', 'piece'];
    final items = <PopupMenuEntry<String>>[];

    for (final unit in commonUnits) {
      items.add(
        PopupMenuItem<String>(
          value: unit,
          child: Row(
            children: [
              if (_selectedServingUnit == unit)
                Icon(Icons.check, color: _primaryColor, size: 18),
              if (_selectedServingUnit == unit) const SizedBox(width: 8),
              Text(
                unit,
                style: TextStyle(
                  fontWeight:
                      _selectedServingUnit == unit
                          ? FontWeight.bold
                          : FontWeight.normal,
                  color:
                      _selectedServingUnit == unit
                          ? _primaryColor
                          : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    items.add(const PopupMenuDivider());
    items.add(
      PopupMenuItem<String>(
        value: '__more__',
        child: Row(
          children: [
            const Text(
              'More...',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );

    return items;
  }

  List<PopupMenuEntry<String>> _buildMoreUnitsMenuItems() {
    const extraUnits = ['tbsp', 'tsp', 'lb', 'kg', 'serving'];
    final items = <PopupMenuEntry<String>>[];

    items.add(
      PopupMenuItem<String>(
        value: '__back__',
        child: Row(
          children: [
            Icon(Icons.arrow_back, color: _primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    items.add(const PopupMenuDivider());

    for (final unit in extraUnits) {
      items.add(
        PopupMenuItem<String>(
          value: unit,
          child: Row(
            children: [
              if (_selectedServingUnit == unit)
                Icon(Icons.check, color: _primaryColor, size: 18),
              if (_selectedServingUnit == unit) const SizedBox(width: 8),
              Text(
                unit,
                style: TextStyle(
                  fontWeight:
                      _selectedServingUnit == unit
                          ? FontWeight.bold
                          : FontWeight.normal,
                  color:
                      _selectedServingUnit == unit
                          ? _primaryColor
                          : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildFoodIcon(FoodItem food, {double size = 32}) {
    if (food.imageUrl != null && food.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
        child: Image.network(
          food.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  Icon(Icons.restaurant, color: _primaryColor, size: size),
        ),
      );
    }
    return Icon(Icons.restaurant, color: _primaryColor, size: size);
  }

  String _getMotivationalMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning! Start your day with a healthy choice.";
    } else if (hour < 18) {
      return "Keep going! You're doing great this afternoon.";
    } else {
      return "Finish strong! Make your evening meal count.";
    }
  }

  void _showFoodLogSuccessDialog(double totalCalories, int foodCount) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon with animation
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: _primaryColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Meal Logged Successfully!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Calories info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: _primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalCalories.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              'calories logged',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Food count info
                  Text(
                    foodCount == 1
                        ? '1 food item added to your log'
                        : '$foodCount food items added to your log',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Close button - just closes dialog, stays on screen
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog only
                        // Stay on screen - form is already reset
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
