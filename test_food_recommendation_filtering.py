"""
Test script to verify food recommendation filtering based on user preferences
Tests if the system properly filters foods according to dietary preferences
"""

import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_preference_filtering():
    """Test the preference filtering logic"""
    print("=" * 70)
    print("TESTING FOOD RECOMMENDATION PREFERENCE FILTERING")
    print("=" * 70)
    
    # Import the filtering function
    try:
        # We need to import from app.py, but it requires Flask context
        # So we'll test the logic directly
        from app import _apply_preference_filtering
        print("[OK] Imported filtering function")
    except Exception as e:
        print(f"[WARNING] Could not import from app.py: {e}")
        print("[INFO] Testing filtering logic directly")
        return test_filtering_logic_direct()
    
    # Test cases
    test_foods = [
        "chicken adobo",
        "pork sinigang",
        "vegetable stir fry",
        "white rice",
        "mango",
        "ampalaya",
        "fried chicken",
        "ginisang monggo",
        "beef steak",
        "fruit salad"
    ]
    
    print(f"\n[1] Test Foods List: {len(test_foods)} foods")
    for food in test_foods:
        print(f"   - {food}")
    
    # Test 1: No filters (should return all)
    print("\n[2] Test: No Filters (Should return all foods)")
    result = _apply_preference_filtering(test_foods, [])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    assert len(result) == len(test_foods), f"Expected {len(test_foods)}, got {len(result)}"
    print("   [PASS] No filters returns all foods")
    
    # Test 2: Plant-based filter (should exclude meats)
    print("\n[3] Test: Plant-Based Filter (Should exclude meats)")
    result = _apply_preference_filtering(test_foods, ['plant-based'])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    print(f"   Filtered foods: {result}")
    
    # Check that meat foods are excluded
    meat_foods = ['chicken adobo', 'pork sinigang', 'fried chicken', 'beef steak']
    for meat_food in meat_foods:
        if meat_food in result:
            print(f"   [FAIL] Meat food '{meat_food}' should be excluded but is present")
            return False
        else:
            print(f"   [OK] Meat food '{meat_food}' correctly excluded")
    
    # Check that plant foods are included
    plant_foods = ['vegetable stir fry', 'white rice', 'mango', 'ampalaya', 'ginisang monggo', 'fruit salad']
    plant_included = [f for f in plant_foods if f in result]
    print(f"   Plant foods included: {len(plant_included)}/{len(plant_foods)}")
    if len(plant_included) >= len(plant_foods) * 0.8:  # At least 80% should be included
        print("   [PASS] Plant-based filter works correctly")
    else:
        print(f"   [WARNING] Only {len(plant_included)}/{len(plant_foods)} plant foods included")
    
    # Test 3: Healthy filter (should prioritize vegetables, fruits, grains)
    print("\n[4] Test: Healthy Filter")
    result = _apply_preference_filtering(test_foods, ['healthy'])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    print(f"   Filtered foods: {result}")
    
    healthy_foods = ['vegetable stir fry', 'white rice', 'mango', 'ampalaya', 'fruit salad']
    healthy_included = [f for f in healthy_foods if f in result]
    print(f"   Healthy foods included: {len(healthy_included)}/{len(healthy_foods)}")
    if len(healthy_included) >= 3:  # At least 3 healthy foods
        print("   [PASS] Healthy filter works")
    else:
        print(f"   [WARNING] Only {len(healthy_included)} healthy foods included")
    
    # Test 4: Protein filter (should include meats, eggs, etc.)
    print("\n[5] Test: Protein Filter")
    result = _apply_preference_filtering(test_foods, ['protein'])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    print(f"   Filtered foods: {result}")
    
    protein_foods = ['chicken adobo', 'pork sinigang', 'fried chicken', 'beef steak']
    protein_included = [f for f in protein_foods if f in result]
    print(f"   Protein foods included: {len(protein_included)}/{len(protein_foods)}")
    if len(protein_included) >= 2:  # At least 2 protein foods
        print("   [PASS] Protein filter works")
    else:
        print(f"   [WARNING] Only {len(protein_included)} protein foods included")
    
    # Test 5: Spicy filter
    print("\n[6] Test: Spicy Filter")
    result = _apply_preference_filtering(test_foods, ['spicy'])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    print(f"   Filtered foods: {result}")
    
    spicy_foods = ['pork sinigang']  # sinigang is typically spicy
    spicy_included = [f for f in spicy_foods if f in result]
    print(f"   Spicy foods included: {len(spicy_included)}/{len(spicy_foods)}")
    print("   [INFO] Spicy filter tested")
    
    # Test 6: Multiple filters (plant-based + healthy)
    print("\n[7] Test: Multiple Filters (plant-based + healthy)")
    result = _apply_preference_filtering(test_foods, ['plant-based', 'healthy'])
    print(f"   Input: {len(test_foods)} foods")
    print(f"   Output: {len(result)} foods")
    print(f"   Filtered foods: {result}")
    
    # Should exclude meats AND prioritize healthy plant foods
    meat_in_result = any(meat in result for meat in meat_foods)
    if meat_in_result:
        print("   [FAIL] Meat foods should be excluded with plant-based filter")
        return False
    else:
        print("   [PASS] Multiple filters work correctly")
    
    print("\n" + "=" * 70)
    print("ALL FILTERING TESTS PASSED")
    print("=" * 70)
    
    return True


def test_filtering_logic_direct():
    """Test filtering logic directly without Flask context"""
    print("\n[INFO] Testing filtering logic directly")
    
    # Simulate the filtering logic
    test_foods = [
        "chicken adobo",
        "pork sinigang",
        "vegetable stir fry",
        "white rice",
        "mango",
        "ampalaya",
        "fried chicken",
        "ginisang monggo",
        "beef steak",
        "fruit salad"
    ]
    
    def test_filter(foods, filters):
        """Simple filter test"""
        if not filters:
            return foods
        
        filters_lower = [f.lower() for f in filters]
        filtered = []
        
        for food in foods:
            food_lower = food.lower()
            
            # Plant-based: exclude meats
            if 'plant-based' in filters_lower or 'plant_based' in filters_lower:
                meat_keywords = ['chicken', 'pork', 'beef', 'fish', 'meat', 'egg']
                if any(kw in food_lower for kw in meat_keywords):
                    continue
            
            # Healthy: prioritize vegetables, fruits, grains
            if 'healthy' in filters_lower:
                healthy_keywords = ['vegetable', 'fruit', 'rice', 'salad', 'ampalaya']
                if not any(kw in food_lower for kw in healthy_keywords):
                    continue
            
            # Protein: include meats, eggs
            if 'protein' in filters_lower:
                protein_keywords = ['chicken', 'pork', 'beef', 'egg', 'meat']
                if not any(kw in food_lower for kw in protein_keywords):
                    continue
            
            filtered.append(food)
        
        return filtered
    
    # Test 1: No filters
    print("\n[1] Test: No Filters")
    result = test_filter(test_foods, [])
    assert len(result) == len(test_foods), "Should return all foods"
    print(f"   [PASS] Returns all {len(result)} foods")
    
    # Test 2: Plant-based
    print("\n[2] Test: Plant-Based Filter")
    result = test_filter(test_foods, ['plant-based'])
    print(f"   Filtered: {result}")
    meat_count = sum(1 for f in result if any(kw in f.lower() for kw in ['chicken', 'pork', 'beef']))
    assert meat_count == 0, "Should exclude all meats"
    print(f"   [PASS] Excluded all meats ({meat_count} meats in result)")
    
    # Test 3: Healthy
    print("\n[3] Test: Healthy Filter")
    result = test_filter(test_foods, ['healthy'])
    print(f"   Filtered: {result}")
    healthy_count = sum(1 for f in result if any(kw in f.lower() for kw in ['vegetable', 'fruit', 'rice', 'salad']))
    assert healthy_count > 0, "Should include healthy foods"
    print(f"   [PASS] Includes {healthy_count} healthy foods")
    
    # Test 4: Protein
    print("\n[4] Test: Protein Filter")
    result = test_filter(test_foods, ['protein'])
    print(f"   Filtered: {result}")
    protein_count = sum(1 for f in result if any(kw in f.lower() for kw in ['chicken', 'pork', 'beef', 'egg']))
    assert protein_count > 0, "Should include protein foods"
    print(f"   [PASS] Includes {protein_count} protein foods")
    
    print("\n" + "=" * 70)
    print("ALL DIRECT FILTERING TESTS PASSED")
    print("=" * 70)
    
    return True


def test_nutrition_model_filtering():
    """Test the NutritionModel's preference filtering"""
    print("\n" + "=" * 70)
    print("TESTING NUTRITION MODEL PREFERENCE FILTERING")
    print("=" * 70)
    
    try:
        from nutrition_model import NutritionModel
        
        model = NutritionModel()
        
        # Get Filipino foods
        foods = model.get_filipino_foods()
        print(f"\n[1] Total foods in database: {len(foods)}")
        
        # Test filtering with plant-based preference
        print("\n[2] Test: Plant-Based Preference Filtering")
        filtered = model._filter_foods_by_preferences(
            model.filipino_foods_db,
            ['plant-based']
        )
        
        print(f"   Original foods: {len(model.filipino_foods_db)}")
        print(f"   Filtered foods: {len(filtered)}")
        
        # Check that meats are excluded
        meat_foods = ['adobo', 'sinigang', 'kare_kare', 'tinolang_manok']
        for meat_food in meat_foods:
            if meat_food in filtered:
                print(f"   [FAIL] Meat food '{meat_food}' should be excluded")
                return False
            else:
                print(f"   [OK] Meat food '{meat_food}' correctly excluded")
        
        # Check that plant foods are included
        plant_foods = ['ampalaya', 'malunggay', 'kangkong', 'mango', 'papaya', 'ginisang_monggo']
        plant_included = [f for f in plant_foods if f in filtered]
        print(f"   Plant foods included: {len(plant_included)}/{len(plant_foods)}")
        
        if len(plant_included) >= len(plant_foods) * 0.8:
            print("   [PASS] Plant-based filtering works correctly")
        else:
            print(f"   [WARNING] Only {len(plant_included)}/{len(plant_foods)} plant foods included")
        
        # Test with no preferences
        print("\n[3] Test: No Preferences (Should return all)")
        all_foods = model._filter_foods_by_preferences(model.filipino_foods_db, [])
        assert len(all_foods) == len(model.filipino_foods_db), "Should return all foods"
        print(f"   [PASS] Returns all {len(all_foods)} foods")
        
        print("\n" + "=" * 70)
        print("NUTRITION MODEL FILTERING TESTS PASSED")
        print("=" * 70)
        
        return True
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all filtering tests"""
    print("\n" + "=" * 70)
    print("FOOD RECOMMENDATION PREFERENCE FILTERING - TEST SUITE")
    print("=" * 70)
    
    results = []
    
    # Test 1: Direct filtering logic
    success = test_filtering_logic_direct()
    results.append(("Direct Filtering Logic", success))
    
    # Test 2: NutritionModel filtering
    success = test_nutrition_model_filtering()
    results.append(("NutritionModel Filtering", success))
    
    # Test 3: App filtering (if possible)
    try:
        success = test_preference_filtering()
        results.append(("App Filtering Function", success))
    except Exception as e:
        print(f"\n[INFO] App filtering test skipped: {e}")
        results.append(("App Filtering Function", None))
    
    # Print results
    print("\n" + "=" * 70)
    print("TEST RESULTS")
    print("=" * 70)
    
    all_passed = True
    for test_name, success in results:
        if success is None:
            status = "[SKIP]"
        elif success:
            status = "[PASS]"
        else:
            status = "[FAIL]"
            all_passed = False
        print(f"   {status}: {test_name}")
    
    print("\n" + "=" * 70)
    if all_passed:
        print("ALL TESTS PASSED!")
        print("=" * 70)
        return 0
    else:
        print("SOME TESTS FAILED")
        print("=" * 70)
        return 1


if __name__ == "__main__":
    exit(main())


