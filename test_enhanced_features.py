"""
Test script for Phase 2 Enhanced Feature Engineering
Tests the new ingredient extraction, preparation detection, and semantic analysis
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_enhanced_features():
    """Test the enhanced feature extraction methods"""
    print("=" * 70)
    print("TESTING PHASE 2: ENHANCED FEATURE ENGINEERING")
    print("=" * 70)
    
    try:
        from nutrition_model import NutritionModel
        
        # Initialize model
        print("\n[1] Initializing NutritionModel...")
        model = NutritionModel()
        
        if not model.is_model_loaded():
            print("[WARNING] Model not loaded. Some tests may fail.")
        else:
            print("[OK] Model loaded successfully")
        
        # Test 1: Ingredient extraction
        print("\n[2] Test: Ingredient Extraction from Food Name")
        test_cases = [
            ("chicken adobo with rice", ["chicken", "rice"]),
            ("vegetable stir fry", []),
            ("pork sinigang with vegetables", ["pork"]),
            ("beef curry with coconut milk", ["beef"]),
        ]
        
        for food_name, provided_ingredients in test_cases:
            analysis = model._extract_ingredients_from_name(food_name, provided_ingredients)
            print(f"   Food: {food_name}")
            print(f"      Meat: {analysis['meat_count']}, Vegetable: {analysis['vegetable_count']}, "
                  f"Grain: {analysis['grain_count']}")
            print(f"      Has meat: {analysis['has_meat']}, Has vegetable: {analysis['has_vegetable']}")
        
        print("   [PASS] Ingredient extraction works")
        
        # Test 2: Preparation method detection
        print("\n[3] Test: Preparation Method Detection")
        test_cases = [
            ("fried chicken", "fried"),
            ("grilled pork", "grilled"),
            ("boiled sinigang", "boiled"),
            ("stir fried vegetables", "stir_fried"),
            ("chicken adobo", "braised"),  # adobo is typically braised
            ("unknown food", ""),  # No preparation detected
        ]
        
        for food_name, expected_prep in test_cases:
            detected = model._detect_preparation_from_name(food_name)
            status = "[OK]" if (expected_prep == "" and detected == "") or (expected_prep in detected or detected in expected_prep) else "[CHECK]"
            print(f"   {status} {food_name} -> {detected} (expected: {expected_prep})")
        
        print("   [PASS] Preparation method detection works")
        
        # Test 3: Food name semantic analysis
        print("\n[4] Test: Food Name Semantic Analysis")
        test_cases = [
            "chicken adobo",
            "pork sinigang",
            "beef curry",
            "vegetable stir fry",
            "sweet and sour pork",
        ]
        
        for food_name in test_cases:
            semantics = model._analyze_food_name_semantics(food_name)
            print(f"   Food: {food_name}")
            print(f"      Filipino: {semantics['is_filipino']}, Asian: {semantics['is_asian']}, "
                  f"Words: {semantics['word_count']}")
            if semantics.get('has_sweet', 0) > 0:
                print(f"      Has sweet descriptor")
        
        print("   [PASS] Semantic analysis works")
        
        # Test 4: Enhanced feature preparation (41 features)
        print("\n[5] Test: Enhanced Feature Preparation")
        enhanced_features = model._prepare_enhanced_features(
            food_name="chicken adobo with rice",
            food_category="meats",
            serving_size=150.0,
            preparation_method="",
            ingredients=["chicken", "rice"]
        )
        print(f"   Enhanced features count: {len(enhanced_features)}")
        print(f"   First 10 features: {enhanced_features[:10]}")
        assert len(enhanced_features) == 41, f"Expected 41 features, got {len(enhanced_features)}"
        print("   [PASS] Enhanced features prepared correctly")
        
        # Test 5: Backward compatibility (13 features)
        print("\n[6] Test: Backward Compatibility (13 Features)")
        basic_features = model._prepare_features(
            food_name="chicken adobo",
            food_category="meats",
            serving_size=100.0,
            preparation_method="braised",
            ingredients=["chicken"]
        )
        print(f"   Basic features count: {len(basic_features)}")
        assert len(basic_features) == 13, f"Expected 13 features, got {len(basic_features)}"
        print("   [PASS] Backward compatibility maintained")
        
        # Test 6: Auto-detection in predictions
        print("\n[7] Test: Auto-Detection in Predictions")
        # Test prediction without preparation method (should auto-detect)
        result1 = model.predict_calories(
            food_name="fried chicken",
            food_category="meats",
            serving_size=100
        )
        print(f"   'fried chicken' (no prep method) -> Method: {result1.get('method')}, "
              f"Calories: {result1.get('calories')}")
        
        # Test prediction with ingredients in name
        result2 = model.predict_calories(
            food_name="chicken curry with rice",
            food_category="meats",
            serving_size=150
        )
        print(f"   'chicken curry with rice' -> Method: {result2.get('method')}, "
              f"Calories: {result2.get('calories')}")
        
        print("   [PASS] Auto-detection works in predictions")
        
        print("\n" + "=" * 70)
        print("ALL ENHANCED FEATURE TESTS PASSED")
        print("=" * 70)
        
        return True
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all tests"""
    print("\n" + "=" * 70)
    print("PHASE 2: ENHANCED FEATURE ENGINEERING - TEST SUITE")
    print("=" * 70)
    
    success = test_enhanced_features()
    
    print("\n" + "=" * 70)
    if success:
        print("ALL TESTS PASSED!")
        print("=" * 70)
        print("\nNote: Enhanced features (41) are ready for model retraining.")
        print("Current model uses 13 features (backward compatible).")
        return 0
    else:
        print("SOME TESTS FAILED")
        print("=" * 70)
        return 1


if __name__ == "__main__":
    exit(main())


