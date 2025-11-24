# Model Retraining Guide - Using 41 Enhanced Features

## Overview

This guide explains how to retrain the ML model using the new 41 enhanced features (instead of the current 13 features) to improve prediction accuracy.

**Current Model**: 13 features, R² = 0.9349 (93.49%)  
**Target Model**: 41 features, Expected R² = 0.95+ (95%+)

---

## Prerequisites

### 1. Check Current Setup
- ✅ Dataset: `data/Filipino_Food_Nutrition_Dataset.csv` exists
- ✅ Training script: `train_calorie_model.py` exists
- ✅ Enhanced features: Already implemented in `nutrition_model.py`
- ✅ Model file: `model/best_regression_model.joblib` (will be replaced)

### 2. Backup Current Model
**IMPORTANT**: Backup your current model before retraining!

```bash
# Backup current model
copy model\best_regression_model.joblib model\best_regression_model_backup.joblib
```

---

## Step-by-Step Process

### Step 1: Update Training Script

**File to modify**: `train_calorie_model.py`

**What to change**: The `prepare_features()` method in `CalorieModelTrainer` class

**Current code** (lines 202-264):
- Creates 13 features
- Uses basic feature preparation

**What needs to change**:
1. Import `NutritionModel` to use enhanced feature methods
2. Replace feature preparation logic to use `_prepare_enhanced_features()`
3. Update feature count from 13 to 41

**Specific changes needed**:

1. **Add import** (at top of file):
   ```python
   from nutrition_model import NutritionModel
   ```

2. **Initialize NutritionModel** in `__init__`:
   ```python
   def __init__(self, csv_path: str = "data/Filipino_Food_Nutrition_Dataset.csv"):
       # ... existing code ...
       self.nutrition_model = NutritionModel()  # For enhanced features
   ```

3. **Update `prepare_features()` method**:
   - Instead of manually building 13 features
   - Use `self.nutrition_model._prepare_enhanced_features()`
   - Extract ingredients from food names
   - Detect preparation methods
   - Use semantic analysis

**Key changes in `prepare_features()`**:
```python
# OLD (13 features):
features = [
    len(food_name),
    serving_size_g,
    1.0 if category else 0.0,
    1.0 if preparation else 0.0,
    0.0,  # ingredients
]
# + 8 category flags = 13 total

# NEW (41 features):
# Use enhanced feature preparation
features = self.nutrition_model._prepare_enhanced_features(
    food_name=food_name,
    food_category=mapped_category,
    serving_size=serving_size_g,
    preparation_method=preparation,
    ingredients=[]  # Extract from name if needed
)
# Returns 41 features automatically
```

---

### Step 2: Update Feature Count References

**What to update**:
- Any comments mentioning "13 features" → "41 features"
- Feature shape validation
- Documentation strings

**Files to check**:
- `train_calorie_model.py` - Update comments and docstrings
- Any test files that check feature count

---

### Step 3: Run Training

**Command**:
```bash
python train_calorie_model.py
```

**What happens**:
1. Loads dataset from CSV
2. Prepares 41 features for each food item
3. Trains multiple models (Linear Regression, Random Forest, Decision Tree, XGBoost, KNN)
4. Compares model performance
5. Selects best model
6. Saves to `model/best_regression_model.joblib`
7. Generates visualizations and reports

**Expected output**:
- Feature shape: `(N, 41)` instead of `(N, 13)`
- Training time: Slightly longer (more features)
- Model performance: Should improve (R² 0.93 → 0.95+)

---

### Step 4: Update NutritionModel to Use Enhanced Features

**File to modify**: `nutrition_model.py`

**What to change**: Update `predict_calories()` method to use enhanced features

**Current code** (line ~454):
```python
features = self._prepare_features(...)  # 13 features
```

**Change to**:
```python
features = self._prepare_enhanced_features(...)  # 41 features
```

**OR** add a flag to switch between modes:
```python
# Option 1: Always use enhanced (after retraining)
features = self._prepare_enhanced_features(...)

# Option 2: Add flag for backward compatibility
use_enhanced = True  # Set to True after retraining
if use_enhanced:
    features = self._prepare_enhanced_features(...)
else:
    features = self._prepare_features(...)  # Old 13 features
```

---

### Step 5: Test New Model

**Create test script** or use existing:
```bash
python test_ml_improvements.py
```

**What to verify**:
1. ✅ Model loads successfully
2. ✅ Predictions work with 41 features
3. ✅ Accuracy improved (check R² score)
4. ✅ No errors in predictions

---

### Step 6: Compare Results

**Compare old vs new model**:

| Metric | Old Model (13 features) | New Model (41 features) | Improvement |
|--------|------------------------|-------------------------|-------------|
| R² Score | 0.9349 | Expected: 0.95+ | +1-2% |
| Test MAE | ~1834 | Expected: Lower | Better |
| Test RMSE | ~3321 | Expected: Lower | Better |
| Feature Count | 13 | 41 | +215% |

**Check training report**:
- File: `ML_TRAINING_REPORT.md` (generated after training)
- Compare metrics with previous training

---

## Detailed Code Changes

### Change 1: Import NutritionModel

**Location**: Top of `train_calorie_model.py`

**Add**:
```python
from nutrition_model import NutritionModel
```

---

### Change 2: Initialize in CalorieModelTrainer

**Location**: `CalorieModelTrainer.__init__()`

**Add**:
```python
def __init__(self, csv_path: str = "data/Filipino_Food_Nutrition_Dataset.csv"):
    # ... existing initialization ...
    self.nutrition_model = NutritionModel()  # For enhanced features
    # Note: Model file doesn't need to exist for feature extraction
```

---

### Change 3: Update prepare_features() Method

**Location**: `CalorieModelTrainer.prepare_features()` (lines 202-264)

**Replace the feature building section**:

**OLD CODE** (lines 235-246):
```python
# Build feature vector (13 features)
features = [
    len(food_name),  # Name length
    serving_size_g,  # Serving size in grams
    1.0 if category else 0.0,  # Has category
    1.0 if preparation else 0.0,  # Has preparation method
    0.0,  # Number of ingredients (not available in dataset)
]

# Add category flags (8 categories)
for cat in self.model_categories:
    features.append(1.0 if mapped_category == cat else 0.0)
```

**NEW CODE**:
```python
# Build feature vector using enhanced features (41 features)
# Extract ingredients from food name if possible
ingredients = []  # Can be extracted from food_name if needed

# Use enhanced feature preparation
features = self.nutrition_model._prepare_enhanced_features(
    food_name=food_name,
    food_category=mapped_category,
    serving_size=serving_size_g,
    preparation_method=preparation,
    ingredients=ingredients
)
# Returns 41 features: basic (5) + prep (10) + ingredients (10) + semantics (8) + categories (8)
```

---

### Change 4: Update Feature Count Comments

**Location**: Throughout `train_calorie_model.py`

**Find and replace**:
- "13 features" → "41 features"
- "Feature shape: (N, 13)" → "Feature shape: (N, 41)"

---

### Change 5: Update NutritionModel.predict_calories()

**Location**: `nutrition_model.py`, `predict_calories()` method (around line 454)

**Find**:
```python
features = self._prepare_features(
    food_name, food_category, serving_size, preparation_method, ingredients
)
```

**Replace with**:
```python
# Use enhanced features (41) after model retraining
features = self._prepare_enhanced_features(
    food_name, food_category, serving_size, preparation_method, ingredients
)
```

**OR** add conditional:
```python
# Check if enhanced model is available (you can add a flag or check model version)
USE_ENHANCED_FEATURES = True  # Set to True after retraining

if USE_ENHANCED_FEATURES:
    features = self._prepare_enhanced_features(
        food_name, food_category, serving_size, preparation_method, ingredients
    )
else:
    features = self._prepare_features(
        food_name, food_category, serving_size, preparation_method, ingredients
    )
```

---

## Expected Training Output

### Console Output
```
======================================================================
ML MODEL TRAINING WITH EXPERIMENTATION
======================================================================

LOADING DATA
======================================================================
Loaded 500 food items

PREPARING FEATURES
======================================================================
Prepared 500 samples
Feature shape: (500, 41)  ← Should show 41, not 13
Target shape: (500,)
Calories range: 20.0 - 500.0 kcal/100g
Mean calories: 180.5 kcal/100g

SPLITTING DATA
======================================================================
Training set: 400 samples
Testing set: 100 samples

TRAINING AND EVALUATING MODELS
======================================================================
...
[Model comparison results]
...

SELECTING BEST MODEL
======================================================================
Best Model: Random Forest
  Test R²:  0.9523  ← Should be higher than 0.9349
  Test MAE: 1650 kcal/100g
  Test RMSE: 3100 kcal/100g
```

---

## Rollback Plan (If Needed)

If the new model doesn't perform well:

1. **Restore backup model**:
   ```bash
   copy model\best_regression_model_backup.joblib model\best_regression_model.joblib
   ```

2. **Revert code changes**:
   - Change `USE_ENHANCED_FEATURES = False` in `nutrition_model.py`
   - Or revert `predict_calories()` to use `_prepare_features()`

3. **Keep enhanced features**:
   - Enhanced features are still available
   - Can retry training later with more data or different parameters

---

## Troubleshooting

### Issue 1: "Model expects 13 features but got 41"
**Cause**: Model file wasn't updated, still using old model  
**Solution**: Make sure new model was saved correctly, check file timestamp

### Issue 2: "AttributeError: NutritionModel has no attribute _prepare_enhanced_features"
**Cause**: Enhanced features not implemented  
**Solution**: Make sure Phase 2 was completed, check `nutrition_model.py`

### Issue 3: Training takes too long
**Cause**: More features = longer training time  
**Solution**: Normal, be patient. Can reduce dataset size for testing.

### Issue 4: Accuracy didn't improve
**Cause**: Various reasons (not enough data, overfitting, etc.)  
**Solution**: 
- Check training report
- Try hyperparameter tuning
- Collect more training data
- Try different models

---

## Success Criteria

✅ **Training completes successfully**  
✅ **Feature count is 41** (not 13)  
✅ **R² score improves** (0.93 → 0.95+)  
✅ **New model file created** (`model/best_regression_model.joblib`)  
✅ **Predictions work** with new model  
✅ **No errors** in production

---

## Timeline Estimate

- **Code changes**: 30-60 minutes
- **Training time**: 5-15 minutes (depends on dataset size)
- **Testing**: 15-30 minutes
- **Total**: 1-2 hours

---

## Next Steps After Retraining

1. ✅ **Deploy new model** to production
2. ✅ **Monitor performance** via `/ml/stats` endpoint
3. ✅ **Compare metrics** with old model
4. ✅ **Collect user feedback** on predictions
5. ✅ **Document improvements** in training report

---

## Summary

**To retrain with 41 features**:

1. ✅ Backup current model
2. ✅ Update `train_calorie_model.py` to use `_prepare_enhanced_features()`
3. ✅ Run training script
4. ✅ Update `nutrition_model.py` to use enhanced features
5. ✅ Test new model
6. ✅ Compare results
7. ✅ Deploy if improved

**Key files to modify**:
- `train_calorie_model.py` - Update feature preparation
- `nutrition_model.py` - Update prediction to use enhanced features

**Expected improvement**: R² 0.93 → 0.95+ (2%+ accuracy improvement)

---

*Ready to proceed? Let me know when you want me to implement these changes!*


