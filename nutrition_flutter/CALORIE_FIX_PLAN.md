# Calorie Tracking Fix Plan

## Issues Identified

### 1. Type Error: `type 'int' is not a subtype of type 'double'`
**Location**: `progress_data_service.dart` - Error occurs when parsing backend data
**Root Cause**: 
- Backend API (`/progress/all` and `/progress/goals`) returns integer values
- Dart code expects `double` types in several places
- The `.toDouble()` method is being called on values that might already be ints, but the issue is in type casting during JSON parsing

**Affected Areas**:
- `_fetchUserGoals()` - returns `goals['calories']` as int (2000)
- `_aggregateCaloriesData()` - expects `goals['calories']?.toDouble()` but might fail if value is int
- `CaloriesData.fromJson()` - when parsing cached JSON, values might be ints
- Backend response parsing in `_fetchBackendData()`

### 2. Negative Remaining Calories Not Supported
**Current Behavior**: Remaining calories are clamped to minimum 0
**Desired Behavior**: Show negative values when user exceeds goal (like MyFitnessPal)
- Example: If goal is 2000 and user consumes 2200, show "-200 left" instead of "0 left"

**Affected Areas**:
- `_aggregateCaloriesData()` - line 419: `remaining: (goal - totalCalories).clamp(0, double.infinity)`
- `home.dart` - line 510: Display logic for remaining calories
- `professional_home_screen.dart` - line 183: Progress calculation clamps to 0-1
- UI components that display "left" calories

## Solution Plan

### Phase 1: Fix Type Error

#### Step 1.1: Fix `_fetchUserGoals()` method
**File**: `nutrition_flutter/lib/services/progress_data_service.dart`
- Ensure all numeric values from goals API are converted to double
- Handle both int and double types from JSON response
- Use safe conversion: `(value is int ? value.toDouble() : (value as num).toDouble())`

#### Step 1.2: Fix `_aggregateCaloriesData()` method
**File**: `nutrition_flutter/lib/services/progress_data_service.dart`
- Line 414: Safely convert goal value: `final goal = (goals['calories'] is int ? goals['calories'].toDouble() : (goals['calories'] as num?)?.toDouble() ?? 2000.0)`
- Line 412: Ensure calories from backend are properly converted to double

#### Step 1.3: Fix `CaloriesData.fromJson()` method
**File**: `nutrition_flutter/lib/services/progress_data_service.dart`
- Lines 684-687: Use safe type conversion for all numeric fields
- Handle both int and double types from JSON

#### Step 1.4: Fix `_aggregateExerciseData()` method
**File**: `nutrition_flutter/lib/services/progress_data_service.dart`
- Line 453: Ensure `calories_burned` is properly converted to double
- Handle cases where backend returns int values

### Phase 2: Implement Negative Remaining Calories

#### Step 2.1: Update `_aggregateCaloriesData()` calculation
**File**: `nutrition_flutter/lib/services/progress_data_service.dart`
- **Current**: `remaining: (goal - totalCalories).clamp(0, double.infinity)`
- **New**: `remaining: goal - totalCalories` (remove clamp to allow negatives)
- **Include Exercise**: The calculation should be: `goal - foodCalories + exerciseCalories`
- **Note**: Need to check if exercise calories are already included in the calculation or need to be added

#### Step 2.2: Update UI Display in `home.dart`
**File**: `nutrition_flutter/lib/home.dart`
- Line 510: Update display to show negative values properly
- Format: If negative, show "-200 left" instead of "200 left"
- Update text color/style for negative values (e.g., red/orange when exceeded)

#### Step 2.3: Update Progress Indicator in `home.dart`
**File**: `nutrition_flutter/lib/home.dart`
- Lines 491-498: Update CircularProgressIndicator to handle negative values
- When exceeded, show full circle (100%) with different color (red/orange)
- Or show progress beyond 100% if possible

#### Step 2.4: Update `professional_home_screen.dart`
**File**: `nutrition_flutter/lib/screens/professional_home_screen.dart`
- Line 181: Update `remainingCalories` calculation to allow negatives
- Line 183: Update progress calculation to handle values > 1.0 (exceeded goal)
- Update UI to display negative values with appropriate styling

#### Step 2.5: Verify Exercise Calories Integration
**Check**: Ensure exercise calories are properly included in remaining calculation
- Formula should be: `remaining = goal - food + exercise`
- Verify in `_loadRemainingFromBackend()` method in `home.dart`
- Verify in `ProgressDataService._aggregateCaloriesData()`

### Phase 3: Testing & Verification

#### Step 3.1: Test Type Conversions
- Test with backend returning int values
- Test with backend returning double values
- Test with cached JSON data (from `ProgressData.fromJson()`)

#### Step 3.2: Test Negative Calorie Display
- Test with goal = 2000, food = 2200, exercise = 0 → should show "-200 left"
- Test with goal = 2000, food = 2200, exercise = 100 → should show "-100 left"
- Test with goal = 2000, food = 1800, exercise = 0 → should show "200 left"
- Test with goal = 2000, food = 2000, exercise = 0 → should show "0 left"

#### Step 3.3: Test UI Updates
- Verify progress indicator shows correctly when exceeded
- Verify text color changes for negative values
- Verify all calorie displays are consistent across screens

## Implementation Order

1. **Fix Type Error First** (Phase 1) - This is blocking the app from working
2. **Implement Negative Calories** (Phase 2) - This is the feature request
3. **Test Everything** (Phase 3) - Ensure both fixes work together

## Files to Modify

1. `nutrition_flutter/lib/services/progress_data_service.dart`
   - Fix type conversions in multiple methods
   - Update remaining calories calculation
   - Remove clamp on remaining calories

2. `nutrition_flutter/lib/home.dart`
   - Update display logic for negative values
   - Update progress indicator
   - Update text styling

3. `nutrition_flutter/lib/screens/professional_home_screen.dart`
   - Update remaining calories calculation
   - Update progress display

## Notes

- The calculation formula should be: `remaining = goal - food + exercise`
- This matches MyFitnessPal's approach where exercise calories "add back" to your budget
- Negative values should be displayed clearly to indicate over-consumption
- Consider using red/orange color for negative values to indicate warning


