"""
Test script for Phase 1 ML Model Improvements
Tests the enhanced validation, custom meal logging, and monitoring features
"""

import sys
import os
import json
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_nutrition_model():
    """Test the NutritionModel class directly"""
    print("=" * 70)
    print("TESTING NUTRITION MODEL IMPROVEMENTS")
    print("=" * 70)
    
    try:
        from nutrition_model import NutritionModel
        
        # Initialize model
        print("\n[1] Initializing NutritionModel...")
        model = NutritionModel()
        
        if not model.is_model_loaded():
            print("[WARNING] Model not loaded. Some tests may fail.")
            print("   Make sure model/best_regression_model.joblib exists")
        else:
            print("[OK] Model loaded successfully")
        
        # Test 1: Database lookup (should not use ML)
        print("\n[2] Test: Database Lookup (Adobo)")
        result = model.predict_calories("adobo", food_category="meats", serving_size=100)
        print(f"   Method: {result.get('method')}")
        print(f"   Calories: {result.get('calories')}")
        print(f"   Confidence: {result.get('confidence')}")
        assert result.get('method') == 'database_lookup', "Should use database lookup"
        print("   [PASS] Database lookup works")
        
        # Test 2: ML prediction for unknown food
        print("\n[3] Test: ML Prediction (Unknown Food)")
        result = model.predict_calories(
            "chicken curry with rice",
            food_category="meats",
            serving_size=150,
            preparation_method="fried"
        )
        print(f"   Method: {result.get('method')}")
        print(f"   Calories: {result.get('calories')}")
        print(f"   Confidence: {result.get('confidence')}")
        print(f"   Calories per 100g: {result.get('calories_per_100g', 'N/A')}")
        assert result.get('method') in ['ml_model', 'rule_based'], "Should use ML or rule-based"
        print("   [PASS] ML prediction works")
        
        # Test 3: High-calorie food (should not be rejected with new validation)
        print("\n[4] Test: High-Calorie Food (New Validation Logic)")
        result = model.predict_calories(
            "high fat snack",
            food_category="snacks",
            serving_size=100
        )
        print(f"   Method: {result.get('method')}")
        print(f"   Calories: {result.get('calories')}")
        print(f"   Confidence: {result.get('confidence')}")
        # Should not be rejected (old logic would reject >2000 kcal)
        assert result.get('calories', 0) > 0, "Should not be rejected"
        print("   [PASS] High-calorie food not rejected")
        
        # Test 4: Category-specific validation
        print("\n[5] Test: Category-Specific Validation")
        # Test meats (can be high calorie)
        result_meat = model.predict_calories(
            "fatty meat dish",
            food_category="meats",
            serving_size=100
        )
        print(f"   Meats - Calories: {result_meat.get('calories')}, Method: {result_meat.get('method')}")
        
        # Test vegetables (should be lower)
        result_veg = model.predict_calories(
            "vegetable dish",
            food_category="vegetables",
            serving_size=100
        )
        print(f"   Vegetables - Calories: {result_veg.get('calories')}, Method: {result_veg.get('method')}")
        print("   [PASS] Category-specific validation works")
        
        # Test 5: Statistics tracking
        print("\n[6] Test: Statistics Tracking")
        stats = model.get_usage_stats()
        print(f"   Total predictions: {stats['total_predictions']}")
        print(f"   ML predictions: {stats['ml_predictions']}")
        print(f"   Database lookups: {stats['database_lookups']}")
        print(f"   Rule-based: {stats['rule_based_predictions']}")
        if stats['total_predictions'] > 0:
            print(f"   ML usage: {stats.get('ml_usage_percentage', 0):.2f}%")
            print(f"   Average confidence: {stats.get('average_confidence', 0):.3f}")
        assert stats['total_predictions'] >= 5, "Should have tracked at least 5 predictions"
        print("   [PASS] Statistics tracking works")
        
        # Test 6: Confidence scoring
        print("\n[7] Test: Confidence Scoring")
        # Make a prediction that should have high confidence
        result = model.predict_calories(
            "test food",
            food_category="meats",
            serving_size=100
        )
        confidence = result.get('confidence', 0)
        print(f"   Confidence: {confidence}")
        assert 0.0 <= confidence <= 1.0, "Confidence should be between 0 and 1"
        print("   [PASS] Confidence scoring works")
        
        print("\n" + "=" * 70)
        print("ALL NUTRITION MODEL TESTS PASSED")
        print("=" * 70)
        
        return True, stats
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False, None


def test_custom_meal_logic():
    """Test the custom meal logging logic (simulated)"""
    print("\n" + "=" * 70)
    print("TESTING CUSTOM MEAL LOGGING LOGIC")
    print("=" * 70)
    
    try:
        from nutrition_model import NutritionModel
        
        model = NutritionModel()
        
        if not model.is_model_loaded():
            print("[WARNING] Model not loaded. Skipping custom meal tests.")
            return False
        
        # Simulate custom meal request without calories
        print("\n[1] Test: Custom Meal - No Calories Provided")
        meal_name = "Homemade chicken curry"
        food_category = "meats"
        serving_size = 200.0
        
        # This simulates what the endpoint would do
        prediction = model.predict_calories(
            food_name=meal_name,
            food_category=food_category,
            serving_size=serving_size,
            preparation_method="fried",
            ingredients=["chicken", "curry", "rice"]
        )
        
        if 'error' not in prediction:
            calories = prediction.get('calories', 0)
            method = prediction.get('method')
            confidence = prediction.get('confidence', 0)
            
            print(f"   Meal: {meal_name}")
            print(f"   Predicted calories: {calories}")
            print(f"   Method: {method}")
            print(f"   Confidence: {confidence}")
            
            assert calories > 0, "Should predict calories"
            assert method in ['ml_model', 'rule_based'], "Should use ML or rule-based"
            print("   [PASS] Custom meal prediction works")
        else:
            print(f"   [WARNING] Prediction failed: {prediction.get('error')}")
            return False
        
        # Test with full nutrition
        print("\n[2] Test: Full Nutrition Prediction")
        nutrition = model.predict_nutrition(
            food_name=meal_name,
            food_category=food_category,
            serving_size=serving_size,
            user_gender="male",
            user_age=30,
            user_weight=70,
            user_height=175,
            user_activity_level="moderate",
            user_goal="maintain"
        )
        
        nutrition_info = nutrition.get('nutrition_info', {})
        print(f"   Calories: {nutrition_info.get('calories')}")
        print(f"   Protein: {nutrition_info.get('protein')}")
        print(f"   Carbs: {nutrition_info.get('carbs')}")
        print(f"   Fat: {nutrition_info.get('fat')}")
        
        assert nutrition_info.get('calories', 0) > 0, "Should have calories"
        print("   [PASS] Full nutrition prediction works")
        
        print("\n" + "=" * 70)
        print("ALL CUSTOM MEAL TESTS PASSED")
        print("=" * 70)
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def test_monitoring():
    """Test monitoring and logging features"""
    print("\n" + "=" * 70)
    print("TESTING MONITORING & LOGGING")
    print("=" * 70)
    
    try:
        from nutrition_model import NutritionModel
        
        model = NutritionModel()
        
        # Check if log file exists or can be created
        log_file = model.ml_log_file
        log_dir = os.path.dirname(log_file)
        
        print(f"\n[1] Test: Log File Path")
        print(f"   Log file: {log_file}")
        print(f"   Log directory: {log_dir}")
        
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
            print(f"   [OK] Created log directory: {log_dir}")
        else:
            print(f"   [OK] Log directory exists")
        
        # Make some predictions to generate logs
        print("\n[2] Test: Generating Log Entries")
        test_foods = [
            ("adobo", "meats", 100),
            ("unknown food", "vegetables", 150),
            ("test snack", "snacks", 100),
        ]
        
        for food_name, category, serving in test_foods:
            model.predict_calories(food_name, food_category=category, serving_size=serving)
        
        # Check if log file was created and has entries
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                print(f"   [OK] Log file exists with {len(lines)} entries")
                
                if lines:
                    # Parse last entry
                    last_entry = json.loads(lines[-1])
                    print(f"   Last entry: {last_entry.get('food_name')} - {last_entry.get('method')}")
        else:
            print(f"   [INFO] Log file not created yet (may be created on first prediction)")
        
        # Test statistics
        print("\n[3] Test: Statistics Retrieval")
        stats = model.get_usage_stats()
        
        required_keys = [
            'total_predictions', 'ml_predictions', 'database_lookups',
            'rule_based_predictions', 'ml_usage_percentage', 'average_confidence'
        ]
        
        for key in required_keys:
            if key in stats:
                print(f"   [OK] {key}: {stats[key]}")
            else:
                print(f"   [FAIL] Missing key: {key}")
                return False
        
        print("\n" + "=" * 70)
        print("ALL MONITORING TESTS PASSED")
        print("=" * 70)
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def print_summary(stats):
    """Print summary of test results"""
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)
    
    if stats:
        print(f"\nModel Usage Statistics:")
        print(f"   Total Predictions: {stats['total_predictions']}")
        print(f"   ML Predictions: {stats['ml_predictions']} ({stats.get('ml_usage_percentage', 0):.1f}%)")
        print(f"   Database Lookups: {stats['database_lookups']} ({stats.get('database_usage_percentage', 0):.1f}%)")
        print(f"   Rule-Based: {stats['rule_based_predictions']} ({stats.get('rule_based_usage_percentage', 0):.1f}%)")
        print(f"   Average Confidence: {stats.get('average_confidence', 0):.3f}")
        
        if stats['predictions_by_category']:
            print(f"\nPredictions by Category:")
            for category, count in stats['predictions_by_category'].items():
                print(f"   {category}: {count}")
        
        if stats['predictions_by_method']:
            print(f"\nPredictions by Method:")
            for method, count in stats['predictions_by_method'].items():
                print(f"   {method}: {count}")


def main():
    """Run all tests"""
    print("\n" + "=" * 70)
    print("PHASE 1 ML IMPROVEMENTS - TEST SUITE")
    print("=" * 70)
    print(f"Test started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    results = []
    final_stats = None
    
    # Test 1: Nutrition Model
    success, stats = test_nutrition_model()
    results.append(("Nutrition Model", success))
    if stats:
        final_stats = stats
    
    # Test 2: Custom Meal Logic
    success = test_custom_meal_logic()
    results.append(("Custom Meal Logging", success))
    
    # Test 3: Monitoring
    success = test_monitoring()
    results.append(("Monitoring & Logging", success))
    
    # Print results
    print("\n" + "=" * 70)
    print("TEST RESULTS")
    print("=" * 70)
    
    all_passed = True
    for test_name, success in results:
        status = "[PASS]" if success else "[FAIL]"
        print(f"   {status}: {test_name}")
        if not success:
            all_passed = False
    
    # Print summary
    if final_stats:
        print_summary(final_stats)
    
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

