import csv

# Read and fix the exercises CSV by adding estimated calories
input_file = 'data/exercises.csv'
output_file = 'data/exercises.csv'

# Calorie estimates based on category and difficulty
def estimate_calories(category, difficulty):
    """Estimate calories per minute based on exercise type"""
    category = category.lower() if category else 'strength'
    difficulty = difficulty.lower() if difficulty else 'beginner'
    
    base_calories = {
        'cardio': 10,
        'strength': 6,
        'stretching': 3,
        'plyometrics': 9,
        'powerlifting': 7,
        'olympic weightlifting': 8,
        'strongman': 8,
    }
    
    difficulty_multiplier = {
        'beginner': 0.8,
        'intermediate': 1.0,
        'expert': 1.2,
        'advanced': 1.2
    }
    
    base = base_calories.get(category, 5)
    multiplier = difficulty_multiplier.get(difficulty, 1.0)
    
    return int(base * multiplier)

rows = []
with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # If calories_per_minute is empty, estimate it
        if not row.get('calories_per_minute') or row['calories_per_minute'].strip() == '':
            row['calories_per_minute'] = str(estimate_calories(
                row.get('category', ''),
                row.get('difficulty', '')
            ))
        rows.append(row)

# Write back
fieldnames = ['id', 'name', 'category', 'body_part', 'target', 'equipment', 
              'difficulty', 'calories_per_minute', 'instructions', 'tags']

with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"[OK] Fixed {len(rows)} exercises with calorie estimates")
print("\nSample fixes:")
for row in rows[:5]:
    print(f"  - {row['name']}: {row['calories_per_minute']} cal/min ({row['category']}, {row['difficulty']})")

