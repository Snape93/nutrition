"""
Verify why unhealthy foods appear with healthy preference
Test the actual scoring to see why Lechon, Kare-Kare, etc. score higher than healthy foods
"""

import sys
import os
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def analyze_healthy_preference_issue():
    """Analyze why unhealthy foods appear with healthy preference"""
    print("=" * 70)
    print("ANALYZING HEALTHY PREFERENCE ISSUE")
    print("=" * 70)
    
    # Foods shown in screenshot (unhealthy)
    unhealthy_foods = [
        "Lechon",
        "Kare-Kare", 
        "Bicol Express",
        "Adobo Pork",
        "Adobo Chicken",
        "Sinigang na Baboy",
        "Palabok"
    ]
    
    # Healthy foods that should appear
    healthy_foods = [
        "Ampalaya",
        "Kangkong",
        "Mango",
        "Pinakbet",
        "Ginisang Monggo",
        "Malunggay Leaves",
        "White Rice"  # Basic staple
    ]
    
    print(f"\n[1] Foods shown to user (UNHEALTHY):")
    for food in unhealthy_foods:
        print(f"   - {food}")
    
    print(f"\n[2] Foods that SHOULD appear (HEALTHY):")
    for food in healthy_foods:
        print(f"   - {food}")
    
    # Load CSV to get actual nutrition data
    print(f"\n[3] Analyzing nutrition data from CSV:")
    csv_path = "data/Filipino_Food_Nutrition_Dataset.csv"
    
    if os.path.exists(csv_path):
        df = pd.read_csv(csv_path, encoding='utf-8')
        
        print(f"\n   UNHEALTHY FOODS:")
        for food_name in unhealthy_foods:
            # Try to find exact match or partial match
            matches = df[df['Food Name'].str.contains(food_name, case=False, na=False, regex=False)]
            if not matches.empty:
                row = matches.iloc[0]
                cal = row.get('Calories', 0)
                protein = row.get('Protein (g)', 0)
                fat = row.get('Fat (g)', 0)
                fiber = row.get('Fiber (g)', 0)
                category = row.get('Category', '')
                
                # Calculate nutrition density
                if cal > 0:
                    nutrition_density = ((protein * 4) + (fiber * 8)) / cal
                else:
                    nutrition_density = 0
                
                print(f"   {food_name}:")
                print(f"     Calories: {cal}")
                print(f"     Protein: {protein}g, Fat: {fat}g, Fiber: {fiber}g")
                print(f"     Category: {category}")
                print(f"     Nutrition Density: {nutrition_density:.3f}")
                print(f"     Status: {'UNHEALTHY' if cal > 300 or fat > 20 or nutrition_density < 0.15 else 'MODERATE'}")
        
        print(f"\n   HEALTHY FOODS:")
        for food_name in healthy_foods:
            matches = df[df['Food Name'].str.contains(food_name, case=False, na=False, regex=False)]
            if not matches.empty:
                row = matches.iloc[0]
                cal = row.get('Calories', 0)
                protein = row.get('Protein (g)', 0)
                fat = row.get('Fat (g)', 0)
                fiber = row.get('Fiber (g)', 0)
                category = row.get('Category', '')
                
                if cal > 0:
                    nutrition_density = ((protein * 4) + (fiber * 8)) / cal
                else:
                    nutrition_density = 0
                
                print(f"   {food_name}:")
                print(f"     Calories: {cal}")
                print(f"     Protein: {protein}g, Fat: {fat}g, Fiber: {fiber}g")
                print(f"     Category: {category}")
                print(f"     Nutrition Density: {nutrition_density:.3f}")
                print(f"     Status: {'HEALTHY' if nutrition_density > 0.15 and cal < 300 else 'MODERATE'}")
    
    print(f"\n[4] ROOT CAUSE:")
    print(f"   The 'healthy' preference uses SCORING, not HARD EXCLUSION")
    print(f"   This means:")
    print(f"     - Healthy foods get +25 boost (if vegetables/fruits)")
    print(f"     - Unhealthy foods get penalties (-40 for fried, -20 for high-cal)")
    print(f"     - BUT other factors (goal, activity, sex) can still boost unhealthy foods")
    print(f"     - Result: Unhealthy foods can score higher than healthy foods")
    
    print(f"\n[5] SOLUTION NEEDED:")
    print(f"   Option 1: Make 'healthy' a hard exclusion for very unhealthy foods")
    print(f"     - Exclude foods with calories > 400")
    print(f"     - Exclude foods with fat > 25g")
    print(f"     - Exclude fried foods")
    print(f"   Option 2: Increase healthy preference weight in scoring")
    print(f"     - Make healthy preference 50% weight instead of 20%")
    print(f"   Option 3: Add calorie threshold filter")
    print(f"     - If healthy preference, only show foods < 300 calories")
    
    print(f"\n{'=' * 70}")
    print("VERIFICATION: These foods are NOT healthy!")
    print('=' * 70)
    print("Lechon (458 kcal, high fat) - NOT HEALTHY")
    print("Kare-Kare (398 kcal, high fat) - NOT HEALTHY")
    print("Bicol Express (302 kcal, high fat) - NOT HEALTHY")
    print("Adobo Pork (336 kcal, high fat) - NOT HEALTHY")
    print("Adobo Chicken (319 kcal, moderate fat) - NOT HEALTHY")
    print("Sinigang na Baboy (199 kcal) - MODERATE")
    print("Palabok (338 kcal) - NOT HEALTHY")
    print("\nThese should NOT appear with 'healthy' preference!")


if __name__ == "__main__":
    analyze_healthy_preference_issue()

