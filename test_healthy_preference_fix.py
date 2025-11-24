"""
Test the fix for healthy preference - should exclude unhealthy foods
"""

import sys
import os
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_healthy_preference_fix():
    """Test if healthy preference now correctly excludes unhealthy foods"""
    print("=" * 70)
    print("TESTING HEALTHY PREFERENCE FIX")
    print("=" * 70)
    
    try:
        from app import _apply_preference_filtering
        
        # Foods that appeared in screenshot (unhealthy)
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
            "White Rice"
        ]
        
        # Load food_df for nutrition data
        food_df = None
        try:
            csv_path = "data/Filipino_Food_Nutrition_Dataset.csv"
            if os.path.exists(csv_path):
                food_df = pd.read_csv(csv_path, encoding='utf-8')
                print(f"[OK] Loaded {len(food_df)} foods from CSV")
        except Exception as e:
            print(f"[WARNING] Could not load CSV: {e}")
        
        print(f"\n[1] Testing with 'healthy' preference:")
        print(f"   Unhealthy foods to test: {len(unhealthy_foods)}")
        print(f"   Healthy foods to test: {len(healthy_foods)}")
        
        # Test unhealthy foods - should be excluded
        print(f"\n[2] Testing UNHEALTHY foods (should be EXCLUDED):")
        filtered_unhealthy = _apply_preference_filtering(unhealthy_foods, ['healthy'], food_df)
        
        excluded_count = 0
        for food in unhealthy_foods:
            if food not in filtered_unhealthy:
                excluded_count += 1
                print(f"   [OK] {food} - CORRECTLY EXCLUDED")
            else:
                print(f"   [FAIL] {food} - SHOULD BE EXCLUDED but is present")
        
        print(f"\n   Result: {excluded_count}/{len(unhealthy_foods)} unhealthy foods excluded")
        
        # Test healthy foods - should be included
        print(f"\n[3] Testing HEALTHY foods (should be INCLUDED):")
        filtered_healthy = _apply_preference_filtering(healthy_foods, ['healthy'], food_df)
        
        included_count = 0
        for food in healthy_foods:
            if food in filtered_healthy:
                included_count += 1
                print(f"   [OK] {food} - CORRECTLY INCLUDED")
            else:
                print(f"   [WARNING] {food} - Should be included but is excluded")
        
        print(f"\n   Result: {included_count}/{len(healthy_foods)} healthy foods included")
        
        # Combined test
        all_foods = unhealthy_foods + healthy_foods
        print(f"\n[4] Combined test (all foods together):")
        filtered_all = _apply_preference_filtering(all_foods, ['healthy'], food_df)
        
        print(f"   Input: {len(all_foods)} foods")
        print(f"   Output: {len(filtered_all)} foods")
        print(f"   Filtered foods: {filtered_all}")
        
        # Check results
        unhealthy_in_result = [f for f in unhealthy_foods if f in filtered_all]
        healthy_in_result = [f for f in healthy_foods if f in filtered_all]
        
        print(f"\n[5] Results:")
        print(f"   Unhealthy foods in result: {len(unhealthy_in_result)}")
        if unhealthy_in_result:
            print(f"   [FAIL] Unhealthy foods still present: {unhealthy_in_result}")
        else:
            print(f"   [PASS] No unhealthy foods in result")
        
        print(f"   Healthy foods in result: {len(healthy_in_result)}")
        if healthy_in_result:
            print(f"   [PASS] Healthy foods present: {healthy_in_result[:5]}")
        else:
            print(f"   [WARNING] No healthy foods in result")
        
        print(f"\n{'=' * 70}")
        if len(unhealthy_in_result) == 0 and len(healthy_in_result) > 0:
            print("FIX VERIFIED: Healthy preference now works correctly!")
        else:
            print("ISSUE: Healthy preference still needs adjustment")
        print('=' * 70)
        
        return len(unhealthy_in_result) == 0
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_healthy_preference_fix()
    exit(0 if success else 1)

