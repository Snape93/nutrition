# Profile Progress Feature Analysis

## Current Implementation

### Profile View Progress Card
**Location**: `nutrition_flutter/lib/profile_view.dart` - `_buildProgressChart()`

**Data Sources**:
1. **Current Weight**: `userData['weight_kg']` from `User` table (static profile field)
   - Loaded via `_loadProfile()` → `UserDatabase().getUserData()`
   - Source: Backend `/user/{username}` endpoint → `User.weight_kg` field

2. **Target Weight**: `userData['target_weight']` from `User` table
   - Loaded via `_loadProfile()` → `UserDatabase().getUserData()`
   - Source: Backend `/user/{username}` endpoint → `User.target_weight` field

3. **Weight History Chart**: `_recentWeights` from `WeightLog` table
   - Loaded via `_loadRecentWeightLogs()` → `UserDatabase().getWeightLogs()`
   - Source: Backend `/log/weight?user={username}&limit=30` → `WeightLog` table

**Progress Calculation** (lines 472-475):
```dart
final progress = effectiveTarget > currentWeight
    ? (currentWeight / effectiveTarget).clamp(0.0, 1.0)
    : (effectiveTarget / currentWeight).clamp(0.0, 1.0);
```

### Dashboard/Progress Screen
**Location**: `nutrition_flutter/lib/screens/progress_screen.dart`

**Data Sources**:
1. **Current Weight**: `progressData.weight.current` from `ProgressDataService`
   - Loaded via `ProgressDataService.getProgressData()`
   - Source: Backend `/progress/all` → `WeightLog` table (latest entry)
   - Implementation: `_aggregateWeightData()` gets latest from `WeightLog` table

2. **Target Weight**: Not displayed in progress screen

## The Problem: Data Source Mismatch

### Issue #1: Different Data Sources for Current Weight
- **Profile**: Uses `User.weight_kg` (static profile field)
- **Dashboard**: Uses latest `WeightLog` entry (historical weight log)

**Why This Is a Problem**:
- These can be **out of sync**:
  - User updates weight in profile → Updates `User.weight_kg` but may not create `WeightLog` entry
  - User logs weight via weight logging → Creates `WeightLog` entry but may not update `User.weight_kg`
  - Result: Profile shows different current weight than Dashboard

### Issue #2: Weight Update Doesn't Create WeightLog Entry
**Location**: `profile_view.dart` - `_updateWeight()` (lines 198-240)

**Current Behavior**:
- Updates `User.weight_kg` via `PUT /user/{username}` endpoint
- Does **NOT** create/update `WeightLog` entry
- Only updates the static profile field

**Impact**:
- Profile progress uses updated `User.weight_kg`
- Dashboard still shows old weight from `WeightLog` (if no recent log exists)
- Progress calculations are inconsistent

### Issue #3: Progress Calculation Uses Static Field
- Profile progress calculation uses `User.weight_kg` which may not reflect actual logged weight
- Should use latest `WeightLog` entry for consistency with dashboard

## What Should Be Connected

### Recommended Solution: Use WeightLog as Single Source of Truth

**For Profile Progress Card**:
1. **Current Weight**: Should use **latest `WeightLog` entry** (same as dashboard)
   - Get from `_recentWeights.last` (already loaded for chart)
   - OR fetch latest from `WeightLog` table
   - This ensures consistency with dashboard

2. **Target Weight**: Can continue using `User.target_weight` (this is a goal, not historical data)

3. **Weight Update**: Should **create/update `WeightLog` entry** when weight is updated
   - When user updates weight in profile, call `POST /log/weight` to create WeightLog entry
   - This ensures both `User.weight_kg` and `WeightLog` stay in sync

### Alternative Solution: Sync Both Sources

**When Weight is Updated**:
1. Update `User.weight_kg` (for profile display)
2. Create/update `WeightLog` entry for today (for dashboard/history)
3. Both sources stay synchronized

## Where to Connect

### Option 1: Use WeightLog for Current Weight (Recommended)
**File**: `nutrition_flutter/lib/profile_view.dart`
**Function**: `_buildProgressChart()`
**Change**: 
- Instead of `userData['weight_kg']`, use `_recentWeights.isNotEmpty ? _recentWeights.last : userData['weight_kg']`
- This uses latest logged weight if available, falls back to profile weight

### Option 2: Create WeightLog Entry on Update
**File**: `nutrition_flutter/lib/profile_view.dart`
**Function**: `_updateWeight()`
**Change**:
- After updating `User.weight_kg`, also call `POST /log/weight` to create WeightLog entry
- This ensures both sources are synchronized

### Option 3: Use ProgressDataService (Best for Consistency)
**File**: `nutrition_flutter/lib/profile_view.dart`
**Change**:
- Use `ProgressDataService.getProgressData()` to get weight data (same as dashboard)
- This ensures 100% consistency between profile and dashboard

## Current State Summary

✅ **What Works**:
- Profile loads weight history from WeightLog (for chart)
- Dashboard loads current weight from WeightLog (latest entry)
- Both can display weight data

❌ **What's Broken**:
- Profile progress uses `User.weight_kg` (static field)
- Dashboard uses `WeightLog` (latest entry)
- These can be different values
- Weight update doesn't sync to WeightLog
- Progress calculation may be inaccurate if sources don't match

## Recommendation

**Best Approach**: Use `WeightLog` as single source of truth for current weight
- Profile progress should use latest `WeightLog` entry (already loaded in `_recentWeights`)
- When updating weight, create `WeightLog` entry to keep both in sync
- This ensures profile and dashboard show the same current weight

**Implementation Priority**:
1. **High**: Change profile progress to use `_recentWeights.last` instead of `userData['weight_kg']`
2. **High**: Update `_updateWeight()` to also create WeightLog entry
3. **Medium**: Add fallback logic if no WeightLog exists, use `User.weight_kg`


