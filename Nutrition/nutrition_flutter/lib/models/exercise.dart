class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final String gifUrl;
  final List<String> instructions;
  final String? category;
  final String? difficulty;
  final double? estimatedCaloriesPerMinute;
  final List<String>? tags;

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.gifUrl,
    required this.instructions,
    this.category,
    this.difficulty,
    this.estimatedCaloriesPerMinute,
    this.tags,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bodyPart: json['bodyPart'] ?? '',
      equipment: json['equipment'] ?? '',
      target: json['target'] ?? '',
      gifUrl: json['gifUrl'] ?? '',
      instructions: List<String>.from(json['instructions'] ?? []),
      category: json['category'],
      difficulty: json['difficulty'],
      estimatedCaloriesPerMinute:
          json['estimatedCaloriesPerMinute']?.toDouble(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bodyPart': bodyPart,
      'equipment': equipment,
      'target': target,
      'gifUrl': gifUrl,
      'instructions': instructions,
      'category': category,
      'difficulty': difficulty,
      'estimatedCaloriesPerMinute': estimatedCaloriesPerMinute,
      'tags': tags,
    };
  }

  // Get category - use stored value or fallback to computed
  String get exerciseCategory {
    if (category != null) {
      return category!;
    }

    final bodyPartLower = bodyPart.toLowerCase();
    final targetLower = target.toLowerCase();
    final nameLower = name.toLowerCase();

    // Cardio exercises
    if (bodyPartLower == 'cardio' ||
        nameLower.contains('run') ||
        nameLower.contains('jump') ||
        nameLower.contains('bike') ||
        nameLower.contains('cardio')) {
      return 'Cardio';
    }

    // Yoga exercises
    if (nameLower.contains('yoga') ||
        nameLower.contains('pose') ||
        nameLower.contains('meditation') ||
        targetLower.contains('yoga')) {
      return 'Yoga';
    }

    // Dance exercises
    if (nameLower.contains('dance') ||
        nameLower.contains('zumba') ||
        nameLower.contains('salsa')) {
      return 'Dance';
    }

    // Sports exercises
    if (nameLower.contains('basketball') ||
        nameLower.contains('soccer') ||
        nameLower.contains('tennis') ||
        nameLower.contains('volleyball') ||
        nameLower.contains('sport')) {
      return 'Sports';
    }

    // Flexibility exercises
    if (bodyPartLower == 'neck' ||
        nameLower.contains('stretch') ||
        nameLower.contains('flexibility') ||
        targetLower.contains('flexibility')) {
      return 'Flexibility';
    }

    // Strength exercises (default for most exercises)
    return 'Strength';
  }

  // Get difficulty level - use stored value or fallback to computed
  String get exerciseDifficulty {
    if (difficulty != null) {
      return difficulty!;
    }

    if (equipment.toLowerCase() == 'body weight') {
      return 'Beginner';
    } else if (equipment.toLowerCase() == 'barbell' ||
        equipment.toLowerCase() == 'dumbbell') {
      return 'Intermediate';
    } else {
      return 'Advanced';
    }
  }

  // Get estimated calories burned per minute - use stored value or fallback to computed
  double get exerciseCaloriesPerMinute {
    if (estimatedCaloriesPerMinute != null) {
      return estimatedCaloriesPerMinute!;
    }

    switch (exerciseCategory) {
      case 'Cardio':
        return 8.0;
      case 'Strength':
        return 5.0;
      case 'Yoga':
        return 3.0;
      case 'Flexibility':
        return 2.0;
      case 'Dance':
        return 7.0;
      case 'Sports':
        return 6.0;
      default:
        return 4.0;
    }
  }
}
