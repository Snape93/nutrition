# ML Model Feature Explanation

## Overview
The `best_regression_model` expects exactly **13 features** as input. These features are numerical values that describe a food item.

## The 13 Features Breakdown

### Features 1-5: Basic Information

1. **Name length** (integer)
   - The number of characters in the food name
   - Example: "chicken adobo" = 13

2. **Serving size in grams** (float)
   - The weight of the serving
   - Example: 150.0 grams

3. **Has category** (binary: 1.0 or 0.0)
   - 1.0 if a category was provided, 0.0 if not
   - Example: If category="meats" → 1.0, if category="" → 0.0

4. **Has preparation method** (binary: 1.0 or 0.0)
   - 1.0 if a preparation method was provided, 0.0 if not
   - Example: If preparation_method="fried" → 1.0, if preparation_method="" → 0.0

5. **Number of ingredients** (integer)
   - Count of ingredients in the list
   - Example: ["chicken", "soy sauce", "vinegar"] = 3

### Features 6-13: Category Flags (One-Hot Encoding)

These are **binary flags** (1.0 or 0.0) that indicate which category the food belongs to. Only ONE of these will be 1.0, the rest will be 0.0.

6. **meats** flag
7. **vegetables** flag
8. **fruits** flag
9. **grains** flag
10. **legumes** flag
11. **soups** flag
12. **dairy** flag
13. **snacks** flag

## Example: Building the Feature Vector

### Example 1: "Chicken Adobo"

**Input:**
- food_name: "chicken adobo"
- food_category: "meats"
- serving_size: 150.0
- preparation_method: "fried"
- ingredients: ["chicken", "soy sauce", "vinegar"]

**Feature Vector (13 values):**
```
[13,           # Name length: "chicken adobo" = 13 characters
 150.0,        # Serving size: 150 grams
 1.0,          # Has category: Yes (1.0)
 1.0,          # Has preparation: Yes (1.0)
 3.0,          # Number of ingredients: 3
 1.0,          # meats: YES (this is a meat dish)
 0.0,          # vegetables: NO
 0.0,          # fruits: NO
 0.0,          # grains: NO
 0.0,          # legumes: NO
 0.0,          # soups: NO
 0.0,          # dairy: NO
 0.0]          # snacks: NO
```

### Example 2: "Mango"

**Input:**
- food_name: "mango"
- food_category: "fruits"
- serving_size: 200.0
- preparation_method: "" (empty)
- ingredients: [] (empty)

**Feature Vector (13 values):**
```
[5,            # Name length: "mango" = 5 characters
 200.0,        # Serving size: 200 grams
 1.0,          # Has category: Yes (1.0)
 0.0,          # Has preparation: No (0.0)
 0.0,          # Number of ingredients: 0
 0.0,          # meats: NO
 0.0,          # vegetables: NO
 1.0,          # fruits: YES (this is a fruit)
 0.0,          # grains: NO
 0.0,          # legumes: NO
 0.0,          # soups: NO
 0.0,          # dairy: NO
 0.0]          # snacks: NO
```

### Example 3: "Sinigang"

**Input:**
- food_name: "sinigang"
- food_category: "soups"
- serving_size: 250.0
- preparation_method: "boiled"
- ingredients: ["pork", "tamarind", "vegetables"]

**Feature Vector (13 values):**
```
[8,            # Name length: "sinigang" = 8 characters
 250.0,        # Serving size: 250 grams
 1.0,          # Has category: Yes (1.0)
 1.0,          # Has preparation: Yes (1.0)
 3.0,          # Number of ingredients: 3
 0.0,          # meats: NO
 0.0,          # vegetables: NO
 0.0,          # fruits: NO
 0.0,          # grains: NO
 0.0,          # legumes: NO
 1.0,          # soups: YES (this is a soup)
 0.0,          # dairy: NO
 0.0]          # snacks: NO
```

## Why These Features?

The model was trained on Filipino food data, and these features help it learn patterns:

- **Name length**: Longer names might indicate more complex dishes (which could have more calories)
- **Serving size**: Directly affects total calories
- **Category flags**: Different food categories have different calorie densities (meats are higher than vegetables)
- **Preparation method**: Affects calories (fried foods have more calories than steamed)
- **Number of ingredients**: More ingredients might mean more complex, potentially higher-calorie dishes

## One-Hot Encoding Explained

**One-hot encoding** means only ONE category flag can be 1.0 at a time. This tells the model:
- "This food belongs to exactly ONE category"
- The model learns that "meats" typically have different calorie patterns than "vegetables"

Think of it like a multiple-choice question where you can only select ONE answer.

## Code Implementation

Here's how it's done in the code:

```python
def _prepare_features(self, food_name, food_category, serving_size, 
                     preparation_method, ingredients):
    # Start with 5 basic features
    features = [
        len(food_name),                    # Feature 1
        serving_size,                      # Feature 2
        1.0 if food_category else 0.0,     # Feature 3
        1.0 if preparation_method else 0.0, # Feature 4
        len(ingredients) if ingredients else 0.0  # Feature 5
    ]
    
    # Add 8 category flags (one-hot encoding)
    categories = ["meats", "vegetables", "fruits", "grains", 
                  "legumes", "soups", "dairy", "snacks"]
    
    for cat in categories:
        # Set to 1.0 if this food matches the category, 0.0 otherwise
        features.append(1.0 if food_category.lower() == cat else 0.0)
    
    return features  # Returns list of 13 numbers
```

## Important Notes

1. **Order matters**: The features must be in this exact order
2. **Total must be 13**: The model expects exactly 13 features
3. **Category flags are mutually exclusive**: Only one category flag should be 1.0
4. **All values are numbers**: Even binary flags are 1.0 or 0.0 (not True/False)

## What the Model Does With These Features

The model takes these 13 numbers and predicts:
- **Calories per 100 grams** of the food
- Then the code scales this by serving size: `total_calories = (prediction * serving_size) / 100`

Example:
- Model predicts: 250 kcal/100g
- Serving size: 150g
- Total calories: (250 × 150) / 100 = 375 calories









