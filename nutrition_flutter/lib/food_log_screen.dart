import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isLoadingRecommendations = false;
  bool _isLoggingFood = false; // Loading state for food logging
  List<FoodItem> _recentFoods = [];
  String? _typedFoodName;
  String? _recommendationError;

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
    if (!mounted) return;
    setState(() {
      _isLoadingRecommendations = true;
      _recommendationError = null;
    });
    
    try {
      final user = widget.usernameOrEmail;
      final mealType = _selectedMeal?.toLowerCase() ?? 'breakfast';
      
      final queryParams = <String, String>{
        'user': user,
        'meal_type': mealType,
      };
      
      final uri = Uri.parse('$apiBase/foods/recommend').replace(queryParameters: queryParams);
      
      debugPrint('DEBUG: [Food Recommendations] Starting request');
      debugPrint('DEBUG: [Food Recommendations] User: $user');
      debugPrint('DEBUG: [Food Recommendations] Meal Type: $mealType');
      debugPrint('DEBUG: [Food Recommendations] API URL: $uri');
      
      final response = await http.get(uri).timeout(
        Duration(seconds: 8),
        onTimeout: () {
          debugPrint('DEBUG: [Food Recommendations] Request timed out after 8 seconds');
          throw TimeoutException('Request timed out');
        },
      );
      
      debugPrint('DEBUG: [Food Recommendations] Response status: ${response.statusCode}');
      debugPrint('DEBUG: [Food Recommendations] Response body length: ${response.body.length}');
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('DEBUG: [Food Recommendations] Parsed response data: $data');
        final recommended = data['recommended'] as List? ?? [];
        debugPrint('DEBUG: [Food Recommendations] Found ${recommended.length} recommendations');
        
        if (recommended.isNotEmpty) {
          debugPrint('DEBUG: [Food Recommendations] First item: ${recommended[0]}');
        }
        
        if (!mounted) return;
        setState(() {
          _recommendedFoods = recommended
                .map((json) => FoodItem.fromJson(json))
                .toList();
          _isLoadingRecommendations = false;
          _recommendationError = null;
        });
        debugPrint('DEBUG: [Food Recommendations] Successfully loaded ${_recommendedFoods.length} food items');
      } else {
        debugPrint('DEBUG: [Food Recommendations] Request failed with status ${response.statusCode}');
        debugPrint('DEBUG: [Food Recommendations] Response body: ${response.body}');
        if (!mounted) return;
        setState(() {
          _isLoadingRecommendations = false;
          _recommendationError = 'Failed to load recommendations (${response.statusCode})';
          _recommendedFoods = [];
        });
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint('DEBUG: [Food Recommendations] Error fetching recommendations: $e');
      debugPrint('DEBUG: [Food Recommendations] Stack trace: $stackTrace');
      setState(() {
        _isLoadingRecommendations = false;
        _recommendationError = 'Unable to load recommendations. Please try again.';
        _recommendedFoods = [];
      });
    }
  }

  Future<void> fetchSearchSuggestions(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() => _searchSuggestions = []);
      return;
    }
    
    debugPrint('DEBUG: [Food Search Suggestions] Starting search');
    debugPrint('DEBUG: [Food Search Suggestions] Query: $query');
    
    if (!mounted) return;
    setState(() => _isSearching = true);
    
    final uri = Uri.parse('$apiBase/foods/search?query=$query');
    debugPrint('DEBUG: [Food Search Suggestions] API URL: $uri');
    
    try {
      final response = await http.get(uri);
      debugPrint('DEBUG: [Food Search Suggestions] Response status: ${response.statusCode}');
      debugPrint('DEBUG: [Food Search Suggestions] Response body length: ${response.body.length}');
      
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('DEBUG: [Food Search Suggestions] Parsed response data: $data');
        final foods = data['foods'] as List? ?? [];
        debugPrint('DEBUG: [Food Search Suggestions] Found ${foods.length} suggestions');
        
        if (foods.isNotEmpty) {
          debugPrint('DEBUG: [Food Search Suggestions] First suggestion: ${foods[0]}');
        }
        
        if (!mounted) return;
        setState(() {
          _searchSuggestions =
              foods
                  .map((json) => FoodItem.fromJson(json))
                  .toList();
          _isSearching = false;
        });
        debugPrint('DEBUG: [Food Search Suggestions] Successfully loaded ${_searchSuggestions.length} suggestions');
      } else {
        debugPrint('DEBUG: [Food Search Suggestions] Request failed with status ${response.statusCode}');
        debugPrint('DEBUG: [Food Search Suggestions] Response body: ${response.body}');
        if (!mounted) return;
        setState(() {
          _searchSuggestions = [];
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: [Food Search Suggestions] Error: $e');
      debugPrint('DEBUG: [Food Search Suggestions] Stack trace: $stackTrace');
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
    
    // Set loading state
    if (!mounted) return;
    setState(() {
      _isLoggingFood = true;
    });
    
    try {
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
      
      // Make API call with timeout for faster response
      final response = await http.post(
        Uri.parse('$apiBase/log/food'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': user, 'foods': foodLogs}),
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        // Food logs are already saved to Neon PostgreSQL database by the backend API
        // No need to call saveFoodLog() again as it would create duplicate entries
        
        if (!mounted) return;
        setState(() {
          _isLoggingFood = false;
          _selectedFoods.clear();
          _nutritionInfoMap.clear();
        });
        
        debugPrint('Food log added successfully');
        
        if (mounted) {
          // Calculate total calories for display
          double totalCalories = foodLogs.fold<double>(
            0,
            (sum, log) => sum + ((log['calories'] as num?)?.toDouble() ?? 0),
          );
          
          _showFoodLogSuccessDialog(totalCalories, foodLogs.length);
        }
      } else {
        debugPrint(
          'Failed to add food log: ${response.statusCode} ${response.body}',
        );
        if (!mounted) return;
        setState(() => _isLoggingFood = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add food log!')));
        }
      }
    } catch (e) {
      debugPrint('Error adding food log: $e');
      if (!mounted) return;
      setState(() => _isLoggingFood = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Error logging food. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
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
      body: Stack(
        children: [
          Padding(
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
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        ],
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
              // Loading indicator
              if (_isLoadingRecommendations)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading personalized recommendations...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isVerySmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Error state
              else if (_recommendationError != null)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _recommendationError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: isVerySmallScreen ? 14 : 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: fetchRecommendedFoods,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Recommendations list
              else
              AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child:
                    _recommendedFoods.isNotEmpty
                        ? Column(
                              key: ValueKey('recommendations_${_selectedMeal}'),
                              children: [
                                // Optional: Show preference indicator
                                if (_recommendedFoods.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isVerySmallScreen ? 8 : 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.psychology,
                                          color: _primaryColor,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Personalized for you',
                                          style: TextStyle(
                                            fontSize: isVerySmallScreen ? 12 : 14,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ...List.generate(_recommendedFoods.length, (i) {
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
                              ],
                        )
                        : Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              isVerySmallScreen ? 16 : 20,
                            ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      color: Colors.grey[400],
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No recommendations available',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isVerySmallScreen ? 14 : 16,
                              ),
                            ),
                                    SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: fetchRecommendedFoods,
                                      icon: Icon(Icons.refresh),
                                      label: Text('Refresh'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _primaryColor,
                                      ),
                                    ),
                                  ],
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
          // Centered loading overlay
          if (_isLoggingFood)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 24 : 32),
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
                        width: isVerySmallScreen ? 50 : 60,
                        height: isVerySmallScreen ? 50 : 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 16 : 20),
                      Text(
                        'Logging food...',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 16 : 18,
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

  void _showFoodLogSuccessDialog(double totalCalories, int foodCount) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                          '${totalCalories.toStringAsFixed(0)}',
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pop(context, true); // Return to previous screen
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
