# Streak Bug Analysis: Double Exceed Counting as 2 Days

## Problem Description
When user exceeds target calories, it counts as 1 day. When they double exceed (consume 2x the goal), it incorrectly counts as 2 days instead of still being 1 day.

## Root Cause Analysis

### Current Logic Flow (app.py lines 3984-4038)

1. **`update_streak()` function** is called after each food log
2. **`already_updated_today` check** (line 4001):
   ```python
   already_updated_today = (streak.last_activity_date == activity_date and streak.current_streak > 0)
   ```
3. **If `already_updated_today` is True**, function returns early (line 4008) - prevents double counting ✓

### The Bug: Race Condition & Logic Flaw

**Critical Issue at Line 4019:**
```python
else:
    # Increment existing streak (only once per day based on PH time)
    streak.current_streak += 1
```

**Problem Scenario:**

1. **Day 1 - First food log (exceeds goal):**
   - `last_activity_date` = None (first time)
   - `can_continue` = False (no previous activity)
   - `already_updated_today` = False
   - Goes to line 4027: `current_streak = 1`, `last_activity_date = Day 1` ✓

2. **Day 1 - Second food log (double exceeds goal) - RACE CONDITION:**
   - If two requests come in **before the first commit**:
     - Request A: Reads `last_activity_date = None`, sets `current_streak = 1`
     - Request B: Reads `last_activity_date = None` (hasn't committed yet!), sets `current_streak = 1`
     - Both commit: `current_streak` could be 1 or 2 depending on timing
   
3. **Day 1 - Second food log (double exceeds goal) - LOGIC FLAW:**
   - `last_activity_date` = Day 1 (from first log)
   - `activity_date` = Day 1 (current log)
   - `can_continue` = True (line 3977: `days_since_last == 0`)
   - `already_updated_today` = (Day 1 == Day 1) AND (1 > 0) = True ✓
   - Should return early... BUT...

**THE ACTUAL BUG:**
The `already_updated_today` check happens AFTER `get_or_create_streak()` which loads from database. If multiple food logs happen in quick succession:
- Food log 1: Exceeds goal → Updates streak to 1, commits
- Food log 2: Double exceeds → Checks `already_updated_today`, but if there's any delay or the database hasn't refreshed, it might see stale data

**However, there's a more subtle issue:**

Looking at line 4016-4019, when `can_continue` is True and `current_streak > 0`, it increments. But the `already_updated_today` check should prevent this. 

**The real bug might be:**
- If `last_activity_date` is None initially, and you log food twice on the same day before the first update commits
- OR if there's a timezone issue where the dates don't match exactly
- OR if the check `streak.current_streak > 0` fails when streak is exactly 0

### Additional Issue: No Database Locking

The code doesn't use any database locking mechanism (like `with_for_update()` in SQLAlchemy) to prevent race conditions when multiple food logs happen simultaneously.

## Evidence from Code

1. **No transaction isolation** - Multiple concurrent requests can read stale data
2. **No row-level locking** - `get_or_create_streak()` doesn't lock the row
3. **Race condition window** - Between reading streak and committing update

## Most Likely Bug: Date Comparison Issue

**Critical Bug at Line 4001:**
```python
already_updated_today = (streak.last_activity_date == activity_date and streak.current_streak > 0)
```

**The Problem:**
If `streak.last_activity_date` is a `datetime.date` object and `activity_date` is also a `date`, the comparison should work. However, if there's any timezone or type mismatch, the comparison could fail, allowing the streak to increment twice on the same day.

**Example Bug Scenario:**
1. Day 1, 10:00 AM: Log food, exceed goal
   - `update_streak()` called with `activity_date = date(2025, 1, 15)` (from `get_philippines_date()`)
   - Sets `last_activity_date = date(2025, 1, 15)`, `current_streak = 1`
   - Commits ✓

2. Day 1, 2:00 PM: Log more food, double exceed goal
   - `update_streak()` called with `activity_date = date(2025, 1, 15)` (from food log timestamp converted to date)
   - Checks: `last_activity_date == activity_date` → Should be True
   - BUT: If there's a timezone issue or the dates are slightly different (e.g., one is UTC date, one is PH date), comparison fails
   - `already_updated_today` = False
   - `can_continue` = True (days_since_last == 0)
   - Increments `current_streak` to 2 ❌ **BUG!**

**Additional Issue: The `current_streak > 0` Check**
If for some reason `current_streak` is 0 when it shouldn't be (e.g., after a failed transaction or error), the `already_updated_today` check would fail even if `last_activity_date` matches.

## Recommended Fixes

1. **Add database row locking to prevent race conditions:**
   ```python
   streak = Streak.query.filter_by(user=user, streak_type=streak_type).with_for_update().first()
   ```

2. **Improve `already_updated_today` check with better date normalization:**
   ```python
   # Normalize both dates to ensure comparison works
   if streak.last_activity_date:
       last_date = streak.last_activity_date
       if isinstance(last_date, datetime):
           last_date = last_date.date()
       current_date = activity_date
       if isinstance(current_date, datetime):
           current_date = current_date.date()
       already_updated_today = (last_date == current_date and streak.current_streak > 0)
   else:
       already_updated_today = False
   ```

3. **Add explicit check for same-day updates:**
   ```python
   # Check if we already processed this exact date
   if streak.last_activity_date == activity_date:
       if met_goal and streak.current_streak > 0:
           # Already counted today, skip
           return streak
   ```

4. **Use database-level constraint or unique index** to prevent duplicate streak updates per day

5. **Add logging** to track when `already_updated_today` fails:
   ```python
   if met_goal and not already_updated_today and streak.last_activity_date == activity_date:
       print(f"WARNING: Potential double-count bug! last_date={streak.last_activity_date}, current_date={activity_date}, streak={streak.current_streak}")
   ```

## Testing Scenarios

1. **Same day, single exceed** → Should count as 1 day ✓
2. **Same day, double exceed** → Should still count as 1 day ❌ (currently counts as 2)
3. **Consecutive days** → Should count as 2 days ✓
4. **Multiple rapid logs** → Should only count once per day ❌ (race condition)

