import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import '../design_system/app_design_system.dart';
import '../config.dart';
import '../models/food_item.dart';
import '../user_database.dart';

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

  final List<FoodItem> _selectedFoods = [];
  final Map<String, Map<String, dynamic>> _nutritionInfoMap = {};
  String? _selectedMeal = 'Breakfast';
  List<FoodItem> _recommendedFoods = [];
  List<FoodItem> _searchSuggestions = [];
  bool _isSearching = false;
  bool _showSuccess = false;
  List<FoodItem> _recentFoods = [];

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
    try {
      final response = await _safeGet(
        Uri.parse('$apiBase/foods/recommend?user=$user&meal_type=$mealType'),
        timeoutSeconds: 6,
        retries: 1,
      );

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _recommendedFoods =
              (data['recommended'] as List)
                  .map((json) => FoodItem.fromJson(json))
                  .toList();
        });
      } else {
        // Keep UI responsive; show empty state on failure
        if (!mounted) return;
        setState(() => _recommendedFoods = []);
      }
    } catch (_) {
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
          if (!_selectedFoods.any((f) => f.foodName == food.foodName)) {
            _selectedFoods.add(food);
            _nutritionInfoMap[food.foodName] = {
              'name': food.foodName,
              'calories': food.calories,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
            };
          }
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
    if (_selectedFoods.isEmpty) return;

    setState(() => _showSuccess = false);
    final user = widget.usernameOrEmail;
    final now = DateTime.now();

    final List<Map<String, dynamic>> foodLogs =
        _selectedFoods.map((food) {
          final info = _nutritionInfoMap[food.foodName] ?? {};
          String servingSize =
              _servingController.text.isNotEmpty
                  ? _servingController.text
                  : '100g';
          double grams = _parseGrams(servingSize);
          double quantity = double.tryParse(_quantityController.text) ?? 1;
          double factor = (grams / 100.0) * quantity;

          return {
            'food_name': food.foodName,
            'calories': (info['calories'] ?? 0) * factor,
            'protein': (info['protein'] ?? 0) * factor,
            'carbs': (info['carbs'] ?? 0) * factor,
            'fat': (info['fat'] ?? 0) * factor,
            'serving_size': servingSize,
            'quantity': quantity,
            'meal_type': _selectedMeal,
            'timestamp': now.toIso8601String(),
          };
        }).toList();

    final response = await _safePost(
      Uri.parse('$apiBase/log/food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user, 'foods': foodLogs}),
      timeoutSeconds: 8,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      for (final log in foodLogs) {
        await UserDatabase().saveFoodLog(
          usernameOrEmail: user,
          foodName: log['food_name'],
          calories: (log['calories'] as num?)?.toInt() ?? 0,
          timestamp: now,
          mealType: _selectedMeal ?? 'Other',
        );
      }

      setState(() {
        _showSuccess = true;
        _selectedFoods.clear();
        _nutritionInfoMap.clear();
      });

      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _showSuccess = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food(s) logged successfully!')),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to log food. Please try again.'),
          ),
        );
      }
    }
  }

  double _parseGrams(String servingSize) {
    final match = RegExp(
      r'(\d+(\.\d+)?)\s*g',
    ).firstMatch(servingSize.toLowerCase());
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 100.0;
    }
    return 100.0;
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
      body: Padding(
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
              const SizedBox(height: AppDesignSystem.spaceLG),
              _buildLogButton(),
            ],
          ),
        ),
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
    if (_selectedFoods.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppDesignSystem.spaceSM,
      runSpacing: AppDesignSystem.spaceXS,
      children:
          _selectedFoods
              .map(
                (food) => Chip(
                  label: Text(food.foodName),
                  onDeleted: () {
                    setState(() {
                      _nutritionInfoMap.remove(food.foodName);
                      _selectedFoods.remove(food);
                    });
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: AppDesignSystem.inputDecoration(
        labelText: 'Search for food...',
        hintText: 'Enter food name',
        prefixIcon: Icons.search,
        primaryColor: _primaryColor,
      ),
      onChanged: fetchSearchSuggestions,
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          setState(() {
            _selectedFoods.add(
              FoodItem(
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
              ),
            );
            _nutritionInfoMap[value] = {
              'name': value,
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0,
            };
          });
        }
      },
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
          return ListTile(
            leading: _buildFoodIcon(food),
            title: Text(food.foodName, style: AppDesignSystem.bodyMedium),
            subtitle: Text(
              '${food.calories} kcal',
              style: AppDesignSystem.bodySmall,
            ),
            onTap: () => fetchAndSelectFood(food.foodName),
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
                          onPressed: () => fetchAndSelectFood(food.foodName),
                          backgroundColor: AppDesignSystem.outline.withOpacity(
                            0.1,
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
                  labelText: 'Meal',
                  primaryColor: _primaryColor,
                ),
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
                  setState(() => _selectedMeal = value);
                  fetchRecommendedFoods();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),
        Row(
          children: [
            Icon(Icons.scale, color: _primaryColor),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Expanded(
              child: TextField(
                controller: _servingController,
                decoration: AppDesignSystem.inputDecoration(
                  labelText: 'Serving Size (e.g. 1 cup, 100g)',
                  primaryColor: _primaryColor,
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
                keyboardType: TextInputType.number,
                decoration: AppDesignSystem.inputDecoration(
                  labelText: 'Quantity',
                  primaryColor: _primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendedSection() {
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
    final isSelected = _selectedFoods.any((f) => f.foodName == food.foodName);

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
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedFoods.removeWhere((f) => f.foodName == food.foodName);
              _nutritionInfoMap.remove(food.foodName);
            } else {
              _selectedFoods.add(food);
              _nutritionInfoMap[food.foodName] = {
                'name': food.foodName,
                'calories': food.calories,
                'protein': food.protein,
                'carbs': food.carbs,
                'fat': food.fat,
              };
            }
          });
        },
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
    return Center(
      child: SizedBox(
        width: 200,
        child: ElevatedButton.icon(
          onPressed: _selectedFoods.isNotEmpty ? _addFoodLog : null,
          icon:
              _showSuccess
                  ? const Icon(Icons.check, color: Colors.white)
                  : const Icon(Icons.add, color: Colors.white),
          label: Text(
            _showSuccess ? 'Logged!' : 'Add to Log',
            style: AppDesignSystem.titleMedium.copyWith(color: Colors.white),
          ),
          style: AppDesignSystem.primaryButtonStyle(
            primaryColor: _primaryColor,
          ),
        ),
      ),
    );
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
}
