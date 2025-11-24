# Plan: Remove Feet Support, Keep Only CM for Height

## Overview
Remove all feet/inches (ft) support for height input and keep only centimeters (cm) throughout the application.

## Current State
- Height can be entered in either cm or ft/inches
- Unit selector dropdown allows switching between 'cm' and 'ft'
- Conversion logic exists to convert between units
- Backend already stores height in `height_cm` (no changes needed)

## Changes Required

### 1. Flutter Frontend - `enhanced_onboarding_physical.dart`

#### Variables to Remove/Modify:
- `String _heightUnit = 'cm'` → Remove (always use cm)
- `int? _heightFeet` → Remove
- `double? _heightInches` → Remove
- Keep `double? _height` (always in cm)

#### Methods to Remove:
- `_buildHeightFtInInput()` → Remove entire method (lines ~778-959)

#### Methods to Simplify:
- `_convertHeightToMetric()` → Simplify (no conversion needed, height already in cm)
- `_updateDisplayValuesForUnitChange()` → Remove height unit conversion logic
- `_canContinue()` → Simplify height validation (only check `_height != null`)
- `_buildHeightWeightInputs()` → Always use `_buildHeightCmInput()`

#### UI Changes:
- Remove unit selector dropdown from height input field
- Remove 'ft' option from unit selector
- Keep only 'cm' label (or remove label entirely since it's the only option)

### 2. Input Formatters - `input_formatters.dart`
- `FeetInputFormatter` → Can be removed (no longer used)
- `InchesInputFormatter` → Can be removed (no longer used)
- Keep `DecimalInputFormatter` (still used for cm input)

### 3. Unit Converter - `unit_converter.dart`
- Keep conversion functions (may be used for weight conversions)
- No changes needed

### 4. Backend - `app.py`
- ✅ No changes needed - already uses `height_cm` column
- ✅ Validation already expects cm (100-250 cm range)

### 5. Profile View - `profile_view.dart`
- ✅ No changes needed - only displays height, doesn't allow editing in feet

## Implementation Steps

1. ✅ Remove feet/inches variables and logic from `enhanced_onboarding_physical.dart`
2. ✅ Simplify height input to only show cm field
3. ✅ Remove unit selector from height input
4. ✅ Clean up conversion methods
5. ✅ Remove unused input formatters (optional - can keep for future use)
6. ✅ Test height input works correctly

## Testing Checklist
- [ ] Height input accepts only numeric values (50-250 cm)
- [ ] Validation works correctly
- [ ] Height is saved correctly to backend
- [ ] No errors when submitting form
- [ ] UI looks clean without unit selector




