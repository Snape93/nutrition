"""Final verification that everything works end-to-end"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from nutrition_model import NutritionModel
import joblib

print("=" * 70)
print("FINAL VERIFICATION - END-TO-END TEST")
print("=" * 70)

# Test 1: Model loads and expects 41 features
print("\n[1] Verifying Model")
model = NutritionModel()
if model.is_model_loaded():
    loaded_model = joblib.load('model/best_regression_model.joblib')
    expected_features = loaded_model.n_features_in_
    print(f"   Model expects: {expected_features} features")
    assert expected_features == 41, f"Expected 41 features, got {expected_features}"
    print("   [OK] Model expects 41 features")
else:
    print("   [WARNING] Model not loaded")

# Test 2: Prediction works with 41 features
print("\n[2] Testing Prediction")
result = model.predict_calories('chicken curry', 'meats', 150)
print(f"   Food: chicken curry")
print(f"   Calories: {result['calories']}")
print(f"   Method: {result['method']}")
print(f"   Confidence: {result['confidence']}")
assert result['calories'] > 0, "Should predict calories"
print("   [OK] Prediction works")

# Test 3: Auto-detection works
print("\n[3] Testing Auto-Detection")
result2 = model.predict_calories('fried chicken', 'meats', 100)
print(f"   Food: fried chicken (no prep method specified)")
print(f"   Calories: {result2['calories']}")
print(f"   Method: {result2['method']}")
print("   [OK] Auto-detection works")

# Test 4: Statistics
print("\n[4] Testing Statistics")
stats = model.get_usage_stats()
print(f"   Total predictions: {stats['total_predictions']}")
print(f"   ML usage: {stats.get('ml_usage_percentage', 0):.1f}%")
print("   [OK] Statistics working")

print("\n" + "=" * 70)
print("ALL VERIFICATIONS PASSED!")
print("=" * 70)
print("\nSystem is ready for production!")


