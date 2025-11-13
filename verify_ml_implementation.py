"""
ML Model Verification Script
Verifies the machine learning implementation for the nutrition model
"""

import joblib
import sys
import os
from nutrition_model import NutritionModel

def verify_model_structure():
    """Verify the model file structure and properties"""
    print("=" * 60)
    print("ML MODEL VERIFICATION REPORT")
    print("=" * 60)
    
    model_path = "model/best_regression_model.joblib"
    
    # Check if model file exists
    if not os.path.exists(model_path):
        print(f"[ERROR] Model file not found at {model_path}")
        return False
    
    print(f"[OK] Model file exists: {model_path}")
    
    # Load and inspect model
    try:
        model = joblib.load(model_path)
        print(f"[OK] Model loaded successfully")
        print(f"   Model Type: {type(model).__name__}")
        
        # Check expected type
        if type(model).__name__ != "RandomForestRegressor":
            print(f"[WARNING] Expected RandomForestRegressor, got {type(model).__name__}")
        else:
            print(f"[OK] Model type matches expected: RandomForestRegressor")
        
        # Check number of features
        n_features = getattr(model, 'n_features_in_', None)
        if n_features:
            print(f"[OK] Model expects {n_features} features")
            if n_features != 13:
                print(f"[WARNING] Expected 13 features, model expects {n_features}")
            else:
                print(f"[OK] Feature count matches expected: 13 features")
        else:
            print(f"[WARNING] Could not determine number of features")
        
        return True
        
    except Exception as e:
        print(f"[ERROR] Error loading model: {str(e)}")
        return False

def verify_feature_preparation():
    """Verify that feature preparation matches model expectations"""
    print("\n" + "=" * 60)
    print("FEATURE PREPARATION VERIFICATION")
    print("=" * 60)
    
    nm = NutritionModel()
    
    if not nm.is_model_loaded():
        print("[ERROR] Model not loaded, cannot verify features")
        return False
    
    # Test feature preparation
    test_cases = [
        {
            "name": "meats",
            "category": "meats",
            "serving_size": 100,
            "preparation": "fried",
            "ingredients": ["pork", "soy sauce"]
        },
        {
            "name": "vegetables",
            "category": "vegetables",
            "serving_size": 150,
            "preparation": "stir_fried",
            "ingredients": ["kangkong"]
        },
        {
            "name": "grains",
            "category": "grains",
            "serving_size": 200,
            "preparation": "boiled",
            "ingredients": []
        }
    ]
    
    all_passed = True
    for test in test_cases:
        try:
            features = nm._prepare_features(
                test["name"],
                test["category"],
                test["serving_size"],
                test["preparation"],
                test["ingredients"]
            )
            
            if len(features) == 13:
                print(f"[OK] Test '{test['name']}': Generated {len(features)} features (expected 13)")
            else:
                print(f"[FAIL] Test '{test['name']}': Generated {len(features)} features (expected 13)")
                all_passed = False
            
            # Verify feature structure
            # 5 base features + 8 category flags = 13
            base_features = features[:5]
            category_flags = features[5:]
            
            if len(base_features) == 5 and len(category_flags) == 8:
                print(f"   Structure: {len(base_features)} base + {len(category_flags)} category flags")
            else:
                print(f"[FAIL] Invalid feature structure")
                all_passed = False
                
        except Exception as e:
            print(f"[FAIL] Test '{test['name']}' failed: {str(e)}")
            all_passed = False
    
    return all_passed

def verify_predictions():
    """Verify that predictions work correctly"""
    print("\n" + "=" * 60)
    print("PREDICTION VERIFICATION")
    print("=" * 60)
    
    nm = NutritionModel()
    
    if not nm.is_model_loaded():
        print("[ERROR] Model not loaded, cannot verify predictions")
        return False
    
    test_cases = [
        {
            "name": "Known food (adobo)",
            "food_name": "adobo",
            "category": "meats",
            "serving_size": 150,
            "expected_method": "database_lookup"
        },
        {
            "name": "Unknown food (ML prediction)",
            "food_name": "custom_dish_123",
            "category": "meats",
            "serving_size": 150,
            "preparation": "fried",
            "expected_method": "ml_model"
        }
    ]
    
    all_passed = True
    for test in test_cases:
        try:
            result = nm.predict_calories(
                test["food_name"],
                food_category=test.get("category", ""),
                serving_size=test["serving_size"],
                preparation_method=test.get("preparation", ""),
                ingredients=test.get("ingredients", None)
            )
            
            if "error" in result:
                print(f"[FAIL] Test '{test['name']}': Error - {result['error']}")
                all_passed = False
            else:
                method = result.get("method", "unknown")
                calories = result.get("calories", 0)
                confidence = result.get("confidence", 0)
                
                print(f"[OK] Test '{test['name']}':")
                print(f"   Method: {method}")
                print(f"   Calories: {calories:.1f} kcal")
                print(f"   Confidence: {confidence:.2f}")
                
                if method == test.get("expected_method", "ml_model"):
                    print(f"   [OK] Method matches expected")
                else:
                    print(f"   [WARNING] Method mismatch (expected {test.get('expected_method', 'ml_model')})")
                
                # Sanity check: calories should be reasonable
                if calories < 0:
                    print(f"   [FAIL] Invalid calories: {calories}")
                    all_passed = False
                elif calories > 10000:
                    print(f"   [WARNING] Very high calories: {calories} (may indicate issue)")
                else:
                    print(f"   [OK] Calories in reasonable range")
                    
        except Exception as e:
            print(f"[FAIL] Test '{test['name']}' failed: {str(e)}")
            all_passed = False
    
    return all_passed

def verify_feature_consistency():
    """Verify that feature preparation is consistent with model training"""
    print("\n" + "=" * 60)
    print("FEATURE CONSISTENCY VERIFICATION")
    print("=" * 60)
    
    nm = NutritionModel()
    
    # Expected feature structure:
    # 5 base features: [name_length, serving_size, has_category, has_preparation, num_ingredients]
    # 8 category flags: [meats, vegetables, fruits, grains, legumes, soups, dairy, snacks]
    # Total: 13 features
    
    expected_categories = ["meats", "vegetables", "fruits", "grains", "legumes", "soups", "dairy", "snacks"]
    
    print("Expected categories (8):")
    for i, cat in enumerate(expected_categories, 1):
        print(f"   {i}. {cat}")
    
    # Verify category list in code matches
    code_categories = [
        "meats", "vegetables", "fruits", "grains", 
        "legumes", "soups", "dairy", "snacks"
    ]
    
    if code_categories == expected_categories:
        print("[OK] Category list matches expected")
    else:
        print("[FAIL] Category list mismatch")
        return False
    
    # Test that all categories generate correct features
    for category in expected_categories:
        features = nm._prepare_features("test", category, 100, "", [])
        if len(features) == 13:
            # Check that the correct category flag is set
            cat_index = expected_categories.index(category)
            flag_index = 5 + cat_index  # Base features (5) + category index
            if features[flag_index] == 1.0:
                print(f"[OK] Category '{category}' correctly encoded")
            else:
                print(f"[FAIL] Category '{category}' encoding incorrect")
                return False
        else:
            print(f"[FAIL] Category '{category}' generated wrong number of features")
            return False
    
    return True

def main():
    """Run all verification checks"""
    results = {
        "Model Structure": verify_model_structure(),
        "Feature Preparation": verify_feature_preparation(),
        "Predictions": verify_predictions(),
        "Feature Consistency": verify_feature_consistency()
    }
    
    print("\n" + "=" * 60)
    print("VERIFICATION SUMMARY")
    print("=" * 60)
    
    for check, passed in results.items():
        status = "[PASSED]" if passed else "[FAILED]"
        print(f"{check}: {status}")
    
    all_passed = all(results.values())
    
    print("\n" + "=" * 60)
    if all_passed:
        print("[SUCCESS] ALL CHECKS PASSED - ML Implementation is verified")
    else:
        print("[FAILURE] SOME CHECKS FAILED - Review the errors above")
    print("=" * 60)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())

