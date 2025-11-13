# Plan: Serving Size & Quantity Input Improvements

## Overview
Simplify the serving size input by adding a unit selector dropdown and enforce number-only input for both serving size and quantity fields.

## Research Summary: Units Used in Established Food Tracking Apps

After researching major food tracking apps (MyFitnessPal, Lose It!, Cronometer, Noom, WeightWatchers), the following units are standard across the industry:

**✅ Confirmed Standard Units:**
- **Weight**: g, oz, lb, kg
- **Volume**: ml, cup, tbsp, tsp  
- **Portion**: serving, piece

These units accommodate both metric and US customary systems, which is essential for a global user base. The "serving" unit is particularly important as it's the most common unit in food databases.

## Current State Analysis

### Current Implementation:
1. **Serving Size Field** (`food_log_screen.dart` & `professional_food_log_screen.dart`):
   - Free text input field
   - Users can type anything (e.g., "1 cup", "100g", "2 oz")
   - Uses `_parseGrams()` function that only extracts grams using regex pattern `r'(\d+(\.\d+)?)\s*g'`
   - Default fallback: 100g if no grams found

2. **Quantity Field**:
   - Has `keyboardType: TextInputType.number` but no input formatter
   - Users can still paste non-numeric text
   - Currently defaults to "1"

3. **Existing Patterns in Codebase**:
   - `DecimalInputFormatter` class exists in `utils/input_formatters.dart` for decimal numbers
   - `IntegerInputFormatter` class exists for integers only
   - Unit selector pattern exists in `enhanced_onboarding_physical.dart` using `_buildUnitSelectorInField()` with PopupMenuButton

## Proposed Changes

### 1. Unit Selection System

#### Research Findings:
Based on research of established food tracking apps (MyFitnessPal, Lose It!, Cronometer, Noom, WeightWatchers):
- These apps use standardized units that accommodate both metric and US customary systems
- Units are designed to handle both weight and volume measurements
- "Serving" is a very common unit used across all major apps

#### Units to Support (Research-Backed):
**Weight Units:**
- **g** (grams) - default, most precise
- **oz** (ounces) - US customary, very common
- **lb** (pounds) - for larger quantities
- **kg** (kilograms) - metric system

**Volume Units:**
- **ml** (milliliters) - metric liquid volume
- **cup** (cups) - standard in recipes, very common
- **tbsp** (tablespoons) - common for smaller amounts
- **tsp** (teaspoons) - smallest volume unit

**Serving/Portion Units:**
- **serving** - most common in food databases (e.g., "1 serving")
- **piece** - for individual items (apple, slice of bread, etc.)

**Final Unit List:**
1. **g** (grams) - default
2. **oz** (ounces)
3. **cup** (cups)
4. **ml** (milliliters)
5. **tbsp** (tablespoons)
6. **tsp** (teaspoons)
7. **lb** (pounds)
8. **kg** (kilograms)
9. **serving** (servings - most common in food databases)
10. **piece** (pieces/items)

#### UI Design:
- Split the serving size input into two parts:
  - **Left side**: Number input field (numbers only, allows decimals)
  - **Right side**: Unit selector dropdown (similar to the "g" shown in the image)
- The unit selector should be inside the input field as a suffix icon (like in the onboarding screen)
- Visual design should match the existing pink/maroon color scheme

### 2. Input Validation

#### Serving Size Field:
- **Input Type**: Numbers only (with decimal support)
- **Formatter**: Use `DecimalInputFormatter` (already exists)
- **Keyboard**: `TextInputType.numberWithOptions(decimal: true)`
- **Validation**: Ensure only numeric input is accepted

#### Quantity Field:
- **Input Type**: Numbers only (with decimal support for fractional quantities)
- **Formatter**: Use `DecimalInputFormatter` 
- **Keyboard**: `TextInputType.numberWithOptions(decimal: true)`
- **Validation**: Ensure only numeric input is accepted

### 3. Conversion Logic

#### New Function Required: `_convertToGrams()`
Replace the current `_parseGrams()` function with a more robust conversion system:

```dart
double _convertToGrams(double value, String unit) {
  // Conversion factors to grams
  // Note: Volume-to-weight conversions are approximations (based on water density)
  // For accurate nutrition, food-specific conversions may be needed later
  switch (unit.toLowerCase()) {
    case 'g':
      return value;
    case 'oz':
      return value * 28.3495; // 1 oz = 28.3495 g (exact)
    case 'cup':
      return value * 240.0; // 1 US cup = 240 ml ≈ 240g (for water/liquids)
    case 'ml':
      return value * 1.0; // 1 ml ≈ 1g (for water/liquids at 4°C)
    case 'tbsp':
      return value * 15.0; // 1 tbsp = 15 ml ≈ 15g
    case 'tsp':
      return value * 5.0; // 1 tsp = 5 ml ≈ 5g
    case 'lb':
      return value * 453.592; // 1 lb = 453.592 g (exact)
    case 'kg':
      return value * 1000.0; // 1 kg = 1000 g (exact)
    case 'serving':
      // "Serving" is typically defined per food item in the database
      // For now, use 100g as default (1 serving = 100g)
      // TODO: This should ideally reference the food's actual serving size from database
      return value * 100.0;
    case 'piece':
      // For pieces, use a default (e.g., 100g per piece)
      // This will need food-specific logic later (e.g., 1 apple ≈ 182g)
      return value * 100.0;
    default:
      return value; // Default to grams
  }
}
```

**Important Notes:**
- **Weight units (g, oz, lb, kg)**: Exact conversions
- **Volume units (cup, ml, tbsp, tsp)**: Approximations based on water density (1ml ≈ 1g)
  - These are reasonable for liquids but may vary for solids (e.g., 1 cup flour ≠ 240g)
  - Future enhancement: Food-specific volume-to-weight conversions
- **Serving/Piece units**: Use default values (100g) but should ideally reference:
  - Food database serving sizes
  - Food-specific piece weights (e.g., average apple weight)

### 4. State Management

#### New State Variables Needed:
```dart
String _selectedServingUnit = 'g'; // Default unit
```

#### Controller Updates:
- Keep `_servingController` for the numeric value only
- Store the selected unit separately in `_selectedServingUnit`

### 5. UI Component Structure

#### Sticky "Add to Log" Button (UX Improvement):
- **Requirement**: The "+ Add to Log" button must always be visible at the bottom of the screen
- **Implementation**: Use `Stack` with `Positioned` or `Scaffold` with `bottomNavigationBar`/`floatingActionButton`
- **Rationale**: Users shouldn't have to scroll down to find the button after selecting foods - this improves usability
- **Visual**: Large, rounded button with maroon/pink color scheme, centered at bottom

#### Serving Size Input Widget:
```
Row(
  children: [
    Icon(Icons.scale, color: _primaryColor),
    SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: _servingController,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
        decoration: InputDecoration(
          labelText: 'Serving Size',
          suffixIcon: _buildUnitSelector(), // Unit dropdown
          // ... other decoration
        ),
      ),
    ),
  ],
)
```

#### Unit Selector Widget:
- **Smart Dropdown Approach**: Show 4-5 common units first (g, oz, cup, ml, piece)
- Add "More..." option that expands to show all 9 units
- Use PopupMenuButton (similar to onboarding screen)
- Display current unit (e.g., "g", "oz", "cup")
- Group units logically (Weight, Volume, Portion) in the expanded view
- Update `_selectedServingUnit` when changed
- Trigger recalculation when unit changes
- **Default**: "g" (grams)

### 6. Files to Modify

**Note:** Only `ProfessionalFoodLogScreen` is currently in use. `FoodLogScreen` appears to be legacy code and will not be updated.

1. **`nutrition_flutter/lib/screens/professional_food_log_screen.dart`** (ONLY THIS ONE):
   - Add `_selectedServingUnit` state variable
   - Update serving size TextField with unit selector
   - Add input formatter to serving size field
   - Update `_parseGrams()` to `_convertToGrams()`
   - Add `_buildUnitSelector()` method
   - Update quantity field with input formatter
   - **Make "Add to Log" button sticky/fixed at bottom** (always visible when scrolling)

2. **`nutrition_flutter/lib/utils/input_formatters.dart`**:
   - Already has `DecimalInputFormatter` - verify it's suitable
   - May need to import this in the food log screen

### 7. Calculation Updates

#### Where Calculations Happen:
- In `professional_food_log_screen.dart`: Find all instances of `_parseGrams()` calls
- Update to use new `_convertToGrams()` function with unit parameter

#### Update Logic:
```dart
// Old:
double grams = _parseGrams(_servingController.text);

// New:
double servingValue = double.tryParse(_servingController.text) ?? 100.0;
double grams = _convertToGrams(servingValue, _selectedServingUnit);
```

### 8. User Experience Flow

1. User sees serving size field with "g" displayed on the right
2. User types a number (e.g., "100")
3. User can tap the "g" to change unit (e.g., to "oz", "cup")
4. When unit changes, the number stays the same (no auto-conversion)
5. System converts to grams internally for calculations
6. Quantity field only accepts numbers (with decimals)

### 9. Edge Cases to Handle

- Empty serving size: Default to 100g or show validation error
- Invalid number input: Prevented by formatter
- Unit change with empty value: Allow, but handle gracefully in calculations
- Very large numbers: Consider adding max value validation
- Decimal precision: Limit to 2 decimal places for serving size

### 10. Testing Considerations

- Test all unit conversions
- Test number-only input enforcement
- Test decimal input (e.g., 1.5 cups)
- Test empty field handling
- Test unit switching
- Test calculation accuracy with different units
- Test sticky "Add to Log" button (stays visible when scrolling)
- Test smart dropdown (common units first, "More..." expands to all)

## Implementation Order

1. ✅ **Plan Phase** (Current)
2. Add state variable for selected unit (`_selectedServingUnit = 'g'`)
3. Create smart unit selector widget method (common units + "More..." option)
4. Update serving size TextField with formatter and unit selector
5. Update quantity TextField with formatter
6. Replace `_parseGrams()` with `_convertToGrams()`
7. Update all calculation points to use new conversion function
8. Make "Add to Log" button sticky/fixed at bottom (always visible)
9. Test thoroughly

## Notes

- The unit selector should match the visual style shown in the image (pink/maroon color scheme)
- Keep the existing icon (Icons.scale) for consistency
- Consider adding tooltips or help text for unit conversions
- Future enhancement: Food-specific unit conversions (e.g., 1 cup of rice ≠ 1 cup of water)

