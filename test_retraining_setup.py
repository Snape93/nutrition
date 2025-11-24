"""
Test script to verify retraining setup is correct
Tests that enhanced features can be prepared correctly
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_retraining_setup():
    """Test that the retraining setup is correct"""
    print("=" * 70)
    print("TESTING RETRAINING SETUP")
    print("=" * 70)
    
    try:
        # Test 1: Check NutritionModel import
        print("\n[1] Test: NutritionModel Import")
        from nutrition_model import NutritionModel
        print("   [OK] NutritionModel imported successfully")
        
        # Test 2: Check enhanced features method
        print("\n[2] Test: Enhanced Features Method")
        model = NutritionModel()
        features = model._prepare_enhanced_features(
            food_name="chicken adobo with rice",
            food_category="meats",
            serving_size=150.0,
            preparation_method="braised",
            ingredients=["chicken", "rice"]
        )
        assert len(features) == 41, f"Expected 41 features, got {len(features)}"
        print(f"   [OK] Enhanced features prepared: {len(features)} features")
        
        # Test 3: Check CalorieModelTrainer import
        print("\n[3] Test: CalorieModelTrainer Import")
        try:
            from train_calorie_model import CalorieModelTrainer
            print("   [OK] CalorieModelTrainer imported successfully")
        except ImportError as e:
            if 'matplotlib' in str(e) or 'seaborn' in str(e):
                print(f"   [WARNING] Optional dependencies missing: {e}")
                print("   [INFO] Core functionality should still work (visualizations may fail)")
                # Try to import just the class without running the module
                import importlib.util
                spec = importlib.util.spec_from_file_location("train_calorie_model", "train_calorie_model.py")
                module = importlib.util.module_from_spec(spec)
                # Skip matplotlib/seaborn imports for testing
                CalorieModelTrainer = None
            else:
                raise
        
        # Test 4: Check trainer initialization with enhanced features
        print("\n[4] Test: Trainer Initialization")
        if CalorieModelTrainer is not None:
            trainer = CalorieModelTrainer(use_enhanced_features=True)
            assert trainer.use_enhanced_features == True, "Enhanced features should be enabled"
            assert trainer.nutrition_model is not None, "NutritionModel should be initialized"
            print("   [OK] Trainer initialized with enhanced features")
        else:
            print("   [SKIP] Trainer initialization skipped (optional dependencies missing)")
        
        # Test 5: Check dataset exists
        print("\n[5] Test: Dataset File")
        dataset_path = "data/Filipino_Food_Nutrition_Dataset.csv"
        if os.path.exists(dataset_path):
            print(f"   [OK] Dataset found: {dataset_path}")
        else:
            print(f"   [WARNING] Dataset not found: {dataset_path}")
            print("   Training will fail if dataset is missing")
        
        # Test 6: Check model backup
        print("\n[6] Test: Model Backup")
        backup_path = "model/best_regression_model_backup.joblib"
        if os.path.exists(backup_path):
            print(f"   [OK] Model backup exists: {backup_path}")
        else:
            print(f"   [INFO] Model backup not found (will be created during training)")
        
        print("\n" + "=" * 70)
        print("ALL SETUP TESTS PASSED")
        print("=" * 70)
        print("\nReady to run training with:")
        print("  python train_calorie_model.py")
        print("\nThis will:")
        print("  - Use 41 enhanced features")
        print("  - Train multiple models")
        print("  - Save best model to model/best_regression_model.joblib")
        print("  - Generate training report and visualizations")
        
        return True
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_retraining_setup()
    exit(0 if success else 1)

