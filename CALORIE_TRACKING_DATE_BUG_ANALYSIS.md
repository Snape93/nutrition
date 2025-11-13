# Calorie & Exercise Tracking Date Bug Analysis

## Problem Description
User reports that when they exceed target calories 3 times, it appears to count as 3 days in the weekly calorie tracking view. They logged food tonight (one time) but the system might be showing it as multiple days.

## Investigation Findings

### 1. Backend Date Format (`/progress/all` endpoint)
**Location**: `app.py` line 3929
```python
'calories': [
    {'date': d.isoformat(), 'calories': c}
    for d, c in calories_rows
]
```
- Returns dates as ISO format strings (e.g., `"2025-03-11"`)
- Dates come directly from database `FoodLog.date` field
- **Potential Issue**: If food logs are stored with inconsistent dates due to timezone issues, they might appear as different days

### 2. Frontend Date Parsing (`_generateDailyBreakdown`)
**Location**: `progress_data_service.dart` line 607
```dart
final date = DateTime.parse(dateStr).toLocal();
final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
```

**Potential Issues**:
1. **Timezone Conversion**: `DateTime.parse(dateStr).toLocal()` converts to local timezone
   - If backend sends `"2025-03-11"` (no timezone), parsing creates midnight in local timezone
   - If user's device timezone differs from server timezone, dates might shift
   - Example: Server date `2025-03-11` → Device in different timezone → Could become `2025-03-10` or `2025-03-12`

2. **Date Grouping Logic** (line 610):
   ```dart
   dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + calValue;
   ```
   - Groups calories by dateKey (YYYY-MM-DD format)
   - If dates are parsed incorrectly, same-day entries might get different dateKeys
   - Result: One day's calories split across multiple "days" in the display

### 3. Food Logging Date Handling
**Location**: `app.py` lines 1151, 1208
- Food logs can be created with timestamps that get converted to dates
- If timestamps are in UTC but converted to dates without timezone consideration, dates might be wrong
- Multiple food logs on the same day could end up with different dates if timezone conversion is inconsistent

## Root Cause Hypothesis

**Most Likely Issue**: Timezone conversion problem

**Scenario**:
1. User logs food at night (e.g., 11:00 PM Philippines time)
2. Backend stores date as `2025-03-11` (correct PH date)
3. Frontend receives `"2025-03-11"` and parses with `DateTime.parse().toLocal()`
4. If device timezone differs or parsing is inconsistent:
   - Some entries might parse as `2025-03-11`
   - Others might parse as `2025-03-10` (if timezone shifts backward)
   - Or `2025-03-12` (if timezone shifts forward)
5. Result: One day's calories appear across multiple days

**Alternative Hypothesis**: Date storage inconsistency
- If food logs are stored with different date formats or timezone offsets
- Backend might return entries with slightly different date strings
- Frontend groups them as separate days

## Evidence from Code

### Backend Date Storage
- `FoodLog.date` is a `date` column in database
- When logging food, dates are set from timestamps or user input
- Line 1151: `date=datetime.fromisoformat(food.get('timestamp', ...))` - converts timestamp to date
- **Issue**: If timestamp is UTC but date extraction doesn't account for PH timezone, wrong date might be stored

### Frontend Date Grouping
- Line 607: `DateTime.parse(dateStr).toLocal()` - converts to local timezone
- Line 608: Creates dateKey from parsed date
- **Issue**: If date strings are inconsistent or timezone conversion varies, grouping fails

## Recommended Fixes

### 1. Normalize Dates on Backend
- Ensure all dates are stored in Philippines timezone
- Convert timestamps to PH date before storing
- Return dates consistently as ISO strings without timezone

### 2. Fix Frontend Date Parsing
- Don't use `.toLocal()` on date-only strings
- Parse dates as date-only (no time component)
- Use consistent date formatting for grouping

### 3. Add Date Validation
- Verify dates are within expected range
- Log warnings if dates seem inconsistent
- Group dates more defensively (normalize before grouping)

## Testing Scenarios

1. **Same day, multiple logs**: All should group into one day ✓
2. **Night logging (11 PM)**: Should stay on same day, not shift to next day ✓
3. **Timezone edge cases**: Midnight UTC vs PH time should work correctly ✓
4. **Multiple exceeds same day**: Should show as one day with total calories ✓

## Files to Check/Modify

1. **Backend**: `app.py`
   - Food logging date handling (lines 1151, 1208)
   - `/progress/all` endpoint date formatting (line 3929)

2. **Frontend**: `progress_data_service.dart`
   - `_generateDailyBreakdown()` date parsing (line 607)
   - Date grouping logic (line 610)


