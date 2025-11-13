# Calorie Calculation Logic Documentation

## Current Implementation

### Formula
```
remaining = daily_goal - food_consumed + exercise_burned
```

### Example Calculation
**Scenario:**
- Daily Goal (Target): 2000 calories
- Food Consumed: 2227 calories  
- Exercise Burned: 86 calories

**Calculation:**
```
remaining = 2000 - 2227 + 86
remaining = -141 calories
```

**Result:** The user has exceeded their target by 141 calories (net).

---

## How Target Calories Are Calculated

The daily calorie goal is calculated using the **Mifflin-St Jeor Equation** with activity multipliers:

1. **BMR (Basal Metabolic Rate)** - Calories burned at rest
   - Female: `BMR = 10 × weight_kg + 6.25 × height_cm - 5 × age - 161`
   - Male: `BMR = 10 × weight_kg + 6.25 × height_cm - 5 × age + 5`

2. **TDEE (Total Daily Energy Expenditure)** - BMR × Activity Multiplier
   - Sedentary: × 1.2
   - Lightly Active: × 1.375
   - Active: × 1.55
   - Very Active: × 1.725

3. **Goal Adjustments** (applied to TDEE)
   - Lose Weight: -300 calories
   - Gain Muscle: +200 calories
   - Gain Weight: +300 calories
   - Body Recomposition: -100 calories
   - Athletic Performance: +150 calories

**Important:** The TDEE already accounts for your general activity level, but **does NOT include specific exercise sessions**. This is why exercise calories are added separately.

---

## How Other Apps Handle Exercise Calories

### 1. **MyFitnessPal** (Similar to Current Implementation)
- **Approach:** Exercise calories are added to your daily budget
- **Formula:** `remaining = goal - food + exercise`
- **Philosophy:** "Eat back" your exercise calories
- **Pros:** Rewards exercise, encourages activity
- **Cons:** Can lead to overeating if exercise calories are overestimated

### 2. **Lose It!**
- **Approach:** "Calorie Bonus" system
- **Logic:** Sets a "Target Burn" based on BMR + activity level
- **Behavior:** Only adds calories as bonus AFTER exceeding Target Burn
- **Formula:** `bonus = max(0, exercise_burned - target_burn)`
- **Philosophy:** Exercise calories are extra credit, not automatic additions

### 3. **MacroFactor**
- **Approach:** Ignores exercise calories entirely
- **Logic:** Calculates TDEE based on nutrition logs and weight changes
- **Philosophy:** Exercise calorie estimates are unreliable; better to track actual results
- **Pros:** More accurate long-term, avoids overeating
- **Cons:** Doesn't reward exercise with extra calories

### 4. **Noom**
- **Approach:** Uses "calorie budget" that adjusts based on activity
- **Logic:** Tracks steps and exercise, adds calories gradually
- **Philosophy:** Encourages consistent activity for sustainable weight loss

### 5. **Cronometer**
- **Approach:** Shows exercise calories separately
- **Logic:** Net calories = consumed - burned
- **Display:** Shows both gross and net calories
- **Philosophy:** Educational approach - shows full picture

---

## Current Implementation Analysis

### ✅ What Works Well
1. **Consistent Logic:** The formula is clear and matches MyFitnessPal's approach
2. **User-Friendly:** Exercise feels rewarding (you can eat more)
3. **Common Practice:** This is the most widely used approach

### ⚠️ Potential Issues
1. **Exercise Calorie Accuracy:** Exercise calorie estimates can be inaccurate
   - Overestimation leads to overeating
   - Underestimation discourages users
   
2. **Double Counting Risk:** If activity level is set too high AND exercise is logged, could overestimate needs

3. **Negative Remaining:** Current implementation allows negative remaining calories
   - Example: -141 calories shown as "remaining"
   - Some apps clamp this to 0 or show it differently

---

## Recommendations

### Option 1: Keep Current Logic (MyFitnessPal Style) ✅ Recommended
**Keep as-is** with minor improvements:
- ✅ Add warning when exercise calories seem unusually high
- ✅ Allow users to toggle "eat back exercise calories" setting
- ✅ Show net calories more prominently

**Code Location:** `Nutrition/app.py` line 2708
```python
remaining = round(float(daily_goal) - food_totals['calories'] + exercise_totals['calories'], 1)
```

### Option 2: Add "Exercise Calorie Bonus" Threshold (Lose It! Style)
Only add exercise calories above a certain threshold:
```python
target_burn = daily_goal * 0.1  # 10% of goal as "target burn"
bonus_calories = max(0, exercise_totals['calories'] - target_burn)
remaining = round(float(daily_goal) - food_totals['calories'] + bonus_calories, 1)
```

### Option 3: Show Both Gross and Net (Cronometer Style)
Display multiple metrics:
- **Gross Consumed:** Food calories only
- **Net Consumed:** Food - Exercise
- **Remaining (with exercise):** Goal - Food + Exercise
- **Remaining (without exercise):** Goal - Food

### Option 4: Clamp Negative Values
Prevent negative remaining calories:
```python
remaining = max(0, round(float(daily_goal) - food_totals['calories'] + exercise_totals['calories'], 1))
```

---

## Example Scenarios

### Scenario 1: Under Target
- Goal: 2000
- Food: 1800
- Exercise: 100
- **Remaining:** 2000 - 1800 + 100 = **300 calories**
- **Interpretation:** User can eat 300 more calories today

### Scenario 2: Over Target (Your Example)
- Goal: 2000
- Food: 2227
- Exercise: 86
- **Remaining:** 2000 - 2227 + 86 = **-141 calories**
- **Interpretation:** User exceeded by 141 calories (net)

### Scenario 3: Exercise Heavy Day
- Goal: 2000
- Food: 2000
- Exercise: 500
- **Remaining:** 2000 - 2000 + 500 = **500 calories**
- **Interpretation:** User burned 500 extra calories, can eat 500 more

---

## Implementation Details

### Backend Endpoint
**File:** `Nutrition/app.py`
**Endpoint:** `/remaining`
**Line:** 2708

```python
remaining = round(float(daily_goal) - food_totals['calories'] + exercise_totals['calories'], 1)
```

### Frontend Display
**File:** `Nutrition/nutrition_flutter/lib/home.dart`
**Line:** 510

```dart
'${baseGoal - foodCalories + exerciseCalories}'
```

**File:** `Nutrition/nutrition_flutter/lib/screens/professional_home_screen.dart`
**Line:** 181

```dart
final remainingCalories = baseGoal - foodCalories + exerciseCalories;
```

---

## ⚠️ INCONSISTENCY FOUND

There are **inconsistencies** in how remaining calories are calculated across different endpoints:

### 1. `/remaining` Endpoint (Line 2708) ✅ Includes Exercise
```python
remaining = round(float(daily_goal) - food_totals['calories'] + exercise_totals['calories'], 1)
```

### 2. `/progress/daily-summary` Endpoint (Line 2336) ❌ Excludes Exercise
```python
'remaining': max(0, calorie_goal - daily_calories),
```
**Note:** This endpoint calculates `total_calories_burned` but doesn't include it in remaining calculation!

### 3. `progress_data_service.dart` (Line 419) ❌ Excludes Exercise
```dart
remaining: (goal - totalCalories).clamp(0, double.infinity),
```

**Impact:** Users may see different "remaining calories" values in different parts of the app!

### Recommendation: Fix Inconsistency
Update `/progress/daily-summary` to include exercise calories:
```python
remaining = max(0, round(float(calorie_goal) - daily_calories + total_calories_burned, 1))
```

---

## Conclusion

Your current implementation follows the **MyFitnessPal approach**, which is:
- ✅ Industry standard
- ✅ User-friendly
- ✅ Encourages exercise
- ⚠️ Requires accurate exercise calorie tracking
- ⚠️ **INCONSISTENT** across endpoints

The logic is **correct** for this approach. The example calculation (-141 remaining) correctly shows that even with 86 calories burned, the user still exceeded their goal by 141 calories net.

**Immediate Action Required:**
1. ⚠️ **Fix inconsistency** - Make all endpoints use the same formula
2. Consider adding user setting to toggle exercise calorie counting
3. Better visualization of net vs gross calories
4. Warnings for unusual exercise calorie values
5. Option to clamp negative values or show them differently

