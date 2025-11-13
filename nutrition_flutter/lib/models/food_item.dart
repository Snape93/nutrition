class FoodItem {
  final String foodName;
  final String category;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;
  final String? imageUrl;

  FoodItem({
    required this.foodName,
    required this.category,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
    this.imageUrl,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    foodName: json['Food Name'] as String,
    category: json['Category'] as String,
    servingSize: json['Serving Size'] as String,
    calories: (json['Calories'] as num).toDouble(),
    protein: (json['Protein (g)'] as num).toDouble(),
    carbs: (json['Carbs (g)'] as num).toDouble(),
    fat: (json['Fat (g)'] as num).toDouble(),
    fiber: (json['Fiber (g)'] as num).toDouble(),
    sodium: (json['Sodium (mg)'] as num).toDouble(),
    imageUrl: json['ImageUrl'] as String?,
  );
}
