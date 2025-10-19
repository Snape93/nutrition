class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final String gifUrl;
  final List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.gifUrl,
    required this.instructions,
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
    };
  }

  // Get category based on bodyPart and target
  String get category {
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

  // Get difficulty level based on equipment and body part
  String get difficulty {
    if (equipment.toLowerCase() == 'body weight') {
      return 'Beginner';
    } else if (equipment.toLowerCase() == 'barbell' ||
        equipment.toLowerCase() == 'dumbbell') {
      return 'Intermediate';
    } else {
      return 'Advanced';
    }
  }

  // Get estimated calories burned per minute (rough estimate)
  int get estimatedCaloriesPerMinute {
    switch (category) {
      case 'Cardio':
        return 8;
      case 'Strength':
        return 5;
      case 'Yoga':
        return 3;
      case 'Flexibility':
        return 2;
      case 'Dance':
        return 7;
      case 'Sports':
        return 6;
      default:
        return 4;
    }
  }
}
