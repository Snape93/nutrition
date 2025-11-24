"""
Test to verify why healthy preference is not filtering correctly
The user selected 'healthy' but got high-calorie meat dishes
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_healthy_preference_issue():
    """Test why healthy preference shows unhealthy foods"""
    print("=" * 70)
    print("TESTING HEALTHY PREFERENCE BUG")
    print("=" * 70)
    
    try:
        from app import _apply_preference_filtering
        import pandas as pd
        
        # Foods shown in the screenshot (NOT healthy)
        shown_foods = [
            "Lechon",
            "Kare-Kare",
            "Bicol Express",
            "Adobo Pork",
            "Adobo Chicken",
            "Sinigang na Baboy",
            "Palabok"
        ]
        
        print(f"\n[1] Foods shown to user (with 'healthy' preference):")
        for food in shown_foods:
            print(f"   - {food}")
        
        print(f"\n[2] Testing if these foods should be filtered with 'healthy' preference:")
        
        # Test with healthy preference
        filtered = _apply_preference_filtering(shown_foods, ['healthy'])
        
        print(f"   Input: {len(shown_foods)} foods")
        print(f"   Output: {len(filtered)} foods")
        print(f"   Filtered: {filtered}")
        
        # Check which foods passed the filter
        passed = [f for f in shown_foods if f in filtered]
        excluded = [f for f in shown_foods if f not in filtered]
        
        print(f"\n[3] Analysis:")
        print(f"   Foods that PASSED filter: {len(passed)}")
        for food in passed:
            print(f"     - {food} (SHOULD NOT BE HERE)")
        
        print(f"   Foods that were EXCLUDED: {len(excluded)}")
        for food in excluded:
            print(f"     - {food} (correctly excluded)")
        
        # Check calories from CSV
        print(f"\n[4] Checking calories from dataset:")
        try:
            csv_path = "data/Filipino_Food_Nutrition_Dataset.csv"
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path, encoding='utf-8')
                
                for food in shown_foods:
                    # Try to find food in dataset
                    matches = df[df['Food Name'].str.contains(food, case=False, na=False)]
                    if not matches.empty:
                        row = matches.iloc[0]
                        calories = row.get('Calories', 0)
                        category = row.get('Category', '')
                        print(f"   {food}: {calories} kcal, Category: {category}")
                    else:
                        print(f"   {food}: Not found in dataset")
        except Exception as e:
            print(f"   Error reading CSV: {e}")
        
        # The issue: These foods should NOT pass healthy filter
        print(f"\n[5] Expected Behavior:")
        print(f"   With 'healthy' preference, should see:")
        print(f"     - Vegetables (ampalaya, kangkong, pinakbet)")
        print(f"     - Fruits (mango, banana, apple)")
        print(f"     - Grains (rice, whole grains)")
        print(f"     - Low-calorie, nutrient-dense foods")
        print(f"\n   Should NOT see:")
        print(f"     - High-calorie meats (lechon, adobo, kare-kare)")
        print(f"     - High-fat dishes (bicol express)")
        print(f"     - Processed foods")
        
        # Check if the issue is in scoring vs filtering
        print(f"\n[6] Root Cause Analysis:")
        print(f"   The 'healthy' preference uses SCORING, not HARD EXCLUSION")
        print(f"   This means unhealthy foods can still appear if they score high")
        print(f"   on other factors (goal, activity, etc.)")
        print(f"\n   Solution needed:")
        print(f"     - Make 'healthy' a hard exclusion for very unhealthy foods")
        print(f"     - OR increase healthy preference weight in scoring")
        print(f"     - OR add calorie threshold for healthy preference")
        
        return False  # This is a bug
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def test_healthy_scoring():
    """Test how healthy preference is scored"""
    print(f"\n{'=' * 70}")
    print("TESTING HEALTHY PREFERENCE SCORING")
    print('=' * 70)
    
    try:
        # Simulate the scoring logic
        test_foods = {
            "Lechon": {"calories": 458, "category": "Main Dish", "protein": 30, "fiber": 0},
            "Kare-Kare": {"calories": 398, "category": "Main Dish", "protein": 24, "fiber": 2},
            "Ampalaya": {"calories": 20, "category": "Vegetable", "protein": 1, "fiber": 2},
            "Mango": {"calories": 99, "category": "Fruit", "protein": 1.4, "fiber": 2.6},
        }
        
        print("\n[1] Simulating scoring for 'healthy' preference:")
        
        for food_name, food_data in test_foods.items():
            # Simulate healthy preference scoring
            healthy_score = 0
            if food_data['category'] in ['Vegetable', 'Fruit', 'Grains']:
                healthy_score += 2
            if food_data['calories'] < 200:
                healthy_score += 1
            if food_data['fiber'] > 2:
                healthy_score += 1
            
            print(f"   {food_name}:")
            print(f"     Calories: {food_data['calories']}")
            print(f"     Category: {food_data['category']}")
            print(f"     Healthy score: {healthy_score}")
        
        print(f"\n[2] Issue:")
        print(f"   Even with healthy preference, other factors (goal, activity)")
        print(f"   can boost unhealthy foods' scores higher than healthy foods")
        
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    test_healthy_preference_issue()
    test_healthy_scoring()

