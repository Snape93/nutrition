import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app import db, Exercise, app

with app.app_context():
    count = Exercise.query.count()
    print(f"Current exercises in database: {count}")
    
    if count > 0:
        print(f"\nFirst 10 exercises in database:")
        exercises = Exercise.query.limit(10).all()
        for ex in exercises:
            print(f"  - {ex.name}")
            print(f"    Category: {ex.category}, Difficulty: {ex.difficulty}")
            print(f"    Body Part: {ex.body_part}, Equipment: {ex.equipment}")
        
        print(f"\nCategories breakdown:")
        categories = {}
        all_exercises = Exercise.query.all()
        for ex in all_exercises:
            cat = ex.category or 'unknown'
            categories[cat] = categories.get(cat, 0) + 1
        for cat, num in sorted(categories.items()):
            print(f"  - {cat}: {num} exercises")
    else:
        print("\n[INFO] Database is empty. When you start the app, it will:")
        print("  1. Check if exercises.csv exists")
        print("  2. Import all 873 exercises from the new ExerciseDB dataset")
        print("  3. Store them in the database")

