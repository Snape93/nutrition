import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme_service.dart';
import 'config.dart';
import 'models/food_item.dart';
import 'user_database.dart';

// Use centralized apiBase from config.dart

class FoodLogScreen extends StatefulWidget {
  final String usernameOrEmail;
  final String? userSex;
  const FoodLogScreen({super.key, required this.usernameOrEmail, this.userSex});
  @override
  FoodLogScreenState createState() => FoodLogScreenState();
}

class FoodLogScreenState extends State<FoodLogScreen> {
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
  String? _typedFoodName;

  @override
  void initState() {
    super.initState();
    fetchRecommendedFoods();
    fetchRecentFoods();
    fetchUserProfileAndSummary();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _typedFoodName = _searchController.text.trim();
        if (_typedFoodName != null &&
            _typedFoodName!.isNotEmpty &&
            _selectedFoods.isEmpty) {
          _nutritionInfoMap[_typedFoodName!] = {
            'name': _typedFoodName,
            'calories': 0,
            'protein': 0,
            'carbs': 0,
            'fat': 0,
          };
        }
      });
    });
  }

  Future<void> fetchRecommendedFoods() async {
    final user = widget.usernameOrEmail;
    final mealType = _selectedMeal?.toLowerCase() ?? '';
    final response = await http.get(
      Uri.parse('$apiBase/foods/recommend?user=$user&meal_type=$mealType'),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        _recommendedFoods =
            (data['recommended'] as List)
                .map((json) => FoodItem.fromJson(json))
                .toList();
      });
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
    final response = await http.get(
      Uri.parse('$apiBase/foods/search?query=$query'),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
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
  }

  Future<void> fetchAndSelectFood(String foodName) async {
    final response = await http.get(
      Uri.parse('$apiBase/foods/info?name=${Uri.encodeComponent(foodName)}'),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
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
  }

  Future<void> fetchRecentFoods() async {
    final logs = await UserDatabase().getFoodLogs(widget.usernameOrEmail);
    // Get unique recent foods (by food_name, most recent first)
    final seen = <String>{};
    final List<FoodItem> recent = [];
    for (final log in logs) {
      final name = log['food_name'] as String;
      if (!seen.contains(name)) {
        seen.add(name);
        // You may want to fetch more info (e.g., image) for each food
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

  Future<void> fetchUserProfileAndSummary() async {
    // All code in this function is now unused and can be removed to resolve warnings.
  }

  Future<void> _addFoodLog() async {
    debugPrint('DEBUG: _addFoodLog called');
    debugPrint(
      'DEBUG: _selectedFoods = ${_selectedFoods.map((f) => f.foodName).toList()}',
    );
    if (_selectedFoods.isEmpty) return;
    setState(() => _showSuccess = false);
    final user = widget.usernameOrEmail;
    final now = DateTime.now();
    // Prepare list of food logs
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
    final response = await http.post(
      Uri.parse('$apiBase/log/food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user, 'foods': foodLogs}),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      // Save each food log locally
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
      await Future.delayed(Duration(milliseconds: 800));
      setState(() => _showSuccess = false);
      debugPrint('Food log added successfully, popping');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Food(s) logged!')));
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } else {
      debugPrint(
        'Failed to add food log: ${response.statusCode} ${response.body}',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add food log!')));
      }
    }
  }

  Color get _primaryColor => ThemeService.getPrimaryColor(widget.userSex);
  Color get _backgroundColor => ThemeService.getBackgroundColor(widget.userSex);

  String get _motivationalMessage {
    final hour = DateTime.now().hour;
    String timeMsg;
    if (hour < 12) {
      timeMsg = "Good morning! Start your day with a healthy choice.";
    } else if (hour < 18) {
      timeMsg = "Keep going! You're doing great this afternoon.";
    } else {
      timeMsg = "Finish strong! Make your evening meal count.";
    }
    // final percent = _calorieGoal > 0 ? _todayCalories / _calorieGoal : 0;
    // if (percent < 0.3) {
    //   return "$timeMsg\nTip: Logging your meals early helps you stay on track!";
    // } else if (percent < 0.7) {
    //   return "$timeMsg\nYou're halfway to your goal. Keep it up!";
    // } else if (percent < 1.0) {
    //   return "$timeMsg\nAlmost there! Stay mindful of your choices.";
    // } else {
    //   return "$timeMsg\nGreat job! You've reached your calorie goal today.";
    // }
    return timeMsg;
  }

  // Add a helper to parse grams from serving size
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Log Food',
              style: TextStyle(
                color: Colors.white,
                fontSize: isVerySmallScreen ? 16 : 18,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isVerySmallScreen ? 8 : 12),
              // Motivational message
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.lightGreen[50],
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 10 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.emoji_emotions,
                        color: Colors.green,
                        size: isVerySmallScreen ? 20 : 26,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _motivationalMessage,
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 13 : 15,
                            color: Colors.green[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isVerySmallScreen ? 10 : 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Food',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      // Show selected foods as chips
                      if (_selectedFoods.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children:
                              _selectedFoods
                                  .map(
                                    (food) => Chip(
                                      label: Text(food.foodName),
                                      onDeleted: () {
                                        setState(() {
                                          _nutritionInfoMap.remove(
                                            food.foodName,
                                          );
                                          _selectedFoods.remove(food);
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      if (_selectedFoods.isNotEmpty) SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search for food...',
                          prefixIcon: Icon(Icons.search, color: _primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: _backgroundColor,
                        ),
                        onChanged: (value) {
                          fetchSearchSuggestions(value);
                        },
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
                      ),
                      if (_isSearching)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallScreen ? 6 : 8,
                          ),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_searchSuggestions.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(
                            top: isVerySmallScreen ? 6 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _searchSuggestions.length,
                            separatorBuilder:
                                (context, index) => Divider(height: 1),
                            itemBuilder: (context, i) {
                              final food = _searchSuggestions[i];
                              return ListTile(
                                leading:
                                    food.imageUrl != null &&
                                            food.imageUrl!.isNotEmpty
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            food.imageUrl!,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                                      Icons.restaurant,
                                                      color: _primaryColor,
                                                    ),
                                          ),
                                        )
                                        : Icon(
                                          Icons.restaurant,
                                          color: _primaryColor,
                                          size: 32,
                                        ),
                                title: Text(
                                  food.foodName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: isVerySmallScreen ? 14 : 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '${food.calories} kcal',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 12 : 14,
                                  ),
                                ),
                                onTap: () => fetchAndSelectFood(food.foodName),
                              );
                            },
                          ),
                        ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      if (_recentFoods.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                _recentFoods
                                    .map(
                                      (food) => Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                          avatar:
                                              food.imageUrl != null &&
                                                      food.imageUrl!.isNotEmpty
                                                  ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Image.network(
                                                      food.imageUrl!,
                                                      width: 28,
                                                      height: 28,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Icon(
                                                            Icons.restaurant,
                                                            color:
                                                                _primaryColor,
                                                            size: 20,
                                                          ),
                                                    ),
                                                  )
                                                  : Icon(
                                                    Icons.restaurant,
                                                    color: _primaryColor,
                                                    size: 20,
                                                  ),
                                          label: Text(
                                            food.foodName,
                                            style: TextStyle(
                                              fontSize:
                                                  isVerySmallScreen ? 12 : 14,
                                            ),
                                          ),
                                          onPressed:
                                              () => fetchAndSelectFood(
                                                food.foodName,
                                              ),
                                          backgroundColor: Colors.grey[100],
                                          elevation: 2,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      SizedBox(height: isVerySmallScreen ? 16 : 20),
                      Row(
                        children: [
                          Icon(Icons.restaurant, color: _primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedMeal,
                              decoration: InputDecoration(
                                labelText: 'Meal',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 12 : 16,
                                  vertical: isVerySmallScreen ? 8 : 12,
                                ),
                              ),
                              items:
                                  ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                                      .map(
                                        (meal) => DropdownMenuItem(
                                          value: meal,
                                          child: Text(
                                            meal,
                                            style: TextStyle(
                                              fontSize:
                                                  isVerySmallScreen ? 14 : 16,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMeal = value;
                                });
                                fetchRecommendedFoods();
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      Row(
                        children: [
                          Icon(Icons.scale, color: _primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _servingController,
                              decoration: InputDecoration(
                                labelText: 'Serving Size (e.g. 1 cup, 100g)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 12 : 16,
                                  vertical: isVerySmallScreen ? 8 : 12,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      Row(
                        children: [
                          Icon(Icons.confirmation_num, color: _primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 12 : 16,
                                  vertical: isVerySmallScreen ? 8 : 12,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isVerySmallScreen ? 16 : 24),
              Text(
                'Recommended for you',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmallScreen ? 16 : 18,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: isVerySmallScreen ? 8 : 12),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child:
                    _recommendedFoods.isNotEmpty
                        ? Column(
                          children: List.generate(_recommendedFoods.length, (
                            i,
                          ) {
                            final food = _recommendedFoods[i];
                            final isSelected = _selectedFoods.any(
                              (f) => f.foodName == food.foodName,
                            );
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 350 + i * 50),
                              curve: Curves.easeOutBack,
                              margin: EdgeInsets.only(
                                bottom: isVerySmallScreen ? 12 : 16,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    final alreadySelected = _selectedFoods.any(
                                      (f) => f.foodName == food.foodName,
                                    );
                                    if (alreadySelected) {
                                      _selectedFoods.removeWhere(
                                        (f) => f.foodName == food.foodName,
                                      );
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
                                child: Container(
                                  padding: EdgeInsets.all(
                                    isVerySmallScreen ? 12 : 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [
                                        isSelected
                                            ? _primaryColor
                                            : Colors.white,
                                        isSelected
                                            ? _primaryColor.withValues(
                                              alpha: 0.8,
                                            )
                                            : Colors.white,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isSelected
                                                ? _primaryColor.withValues(
                                                  alpha: 0.3,
                                                )
                                                : Colors.grey.withValues(
                                                  alpha: 0.2,
                                                ),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? _primaryColor
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading:
                                        food.imageUrl != null &&
                                                food.imageUrl!.isNotEmpty
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                food.imageUrl!,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      Icons.restaurant,
                                                      color:
                                                          isSelected
                                                              ? Colors.white
                                                              : _primaryColor,
                                                    ),
                                              ),
                                            )
                                            : Icon(
                                              Icons.restaurant,
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                      : _primaryColor,
                                              size: 32,
                                            ),
                                    title: Text(
                                      food.foodName,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : _primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isVerySmallScreen ? 16 : 18,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: EdgeInsets.only(
                                        top: isVerySmallScreen ? 2 : 4,
                                      ),
                                      child: Text(
                                        '${food.calories} kcal',
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? Colors.white70
                                                  : Colors.grey[700],
                                          fontSize: isVerySmallScreen ? 13 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    trailing: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : _primaryColor,
                                      size: isVerySmallScreen ? 20 : 24,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        )
                        : Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              isVerySmallScreen ? 16 : 20,
                            ),
                            child: Text(
                              'Loading recommendations...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isVerySmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
              ),
              SizedBox(height: isVerySmallScreen ? 16 : 24),
              _nutritionInfoMap.isNotEmpty && _selectedFoods.isNotEmpty
                  ? Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nutrition Information',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          SizedBox(height: isVerySmallScreen ? 12 : 16),
                          Text(
                            _selectedFoods.length == 1
                                ? _selectedFoods.first.foodName
                                : _selectedFoods
                                    .map((f) => f.foodName)
                                    .join(', '),
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: isVerySmallScreen ? 12 : 16),
                          // Calculate totals
                          Builder(
                            builder: (context) {
                              double totalCalories = 0;
                              double totalProtein = 0,
                                  totalCarbs = 0,
                                  totalFat = 0;
                              for (final food in _selectedFoods) {
                                final info =
                                    _nutritionInfoMap[food.foodName] ?? {};
                                // Parse serving size and quantity for this food
                                String servingSize =
                                    _servingController.text.isNotEmpty
                                        ? _servingController.text
                                        : '100g';
                                double grams = _parseGrams(servingSize);
                                double quantity =
                                    double.tryParse(_quantityController.text) ??
                                    1;
                                double factor = (grams / 100.0) * quantity;
                                totalCalories +=
                                    (info['calories'] ?? 0) * factor;
                                totalProtein += (info['protein'] ?? 0) * factor;
                                totalCarbs += (info['carbs'] ?? 0) * factor;
                                totalFat += (info['fat'] ?? 0) * factor;
                              }
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _nutriFact(
                                        Icons.local_fire_department,
                                        'Calories',
                                        '${totalCalories.toInt()}',
                                      ),
                                      _nutriFact(
                                        Icons.fitness_center,
                                        'Protein',
                                        '${totalProtein.toStringAsFixed(1)}g',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isVerySmallScreen ? 8 : 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _nutriFact(
                                        Icons.bubble_chart,
                                        'Carbs',
                                        '${totalCarbs.toStringAsFixed(1)}g',
                                      ),
                                      _nutriFact(
                                        Icons.oil_barrel,
                                        'Fat',
                                        '${totalFat.toStringAsFixed(1)}g',
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                  : SizedBox.shrink(),
              SizedBox(height: isVerySmallScreen ? 16 : 24),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: isVerySmallScreen ? 180 : 240,
                      height: isVerySmallScreen ? 48 : 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          elevation: 8,
                          shadowColor: _primaryColor.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallScreen ? 12 : 18,
                          ),
                        ),
                        onPressed:
                            (_selectedFoods.isNotEmpty)
                                ? () async {
                                  await _addFoodLog();
                                }
                                : null,
                        icon: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: isVerySmallScreen ? 22 : 28,
                        ),
                        label: Text(
                          'Add to Log',
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 16 : 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    if (_showSuccess)
                      Positioned(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: isVerySmallScreen ? 44 : 56,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nutriFact(IconData icon, String label, String value) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primaryColor, size: isVerySmallScreen ? 20 : 24),
            SizedBox(height: isVerySmallScreen ? 4 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 12 : 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper to capitalize meal names
extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}

// Group logs by meal type
Map<String, List<Map<String, dynamic>>> groupLogsByMeal(
  List<Map<String, dynamic>> logs,
) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  for (final log in logs) {
    final meal = (log['meal'] ?? 'Other').toString().capitalize();
    if (!grouped.containsKey(meal)) grouped[meal] = [];
    grouped[meal]!.add(log);
  }
  return grouped;
}
