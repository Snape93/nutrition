# Goal History Feature - Testing Guide

This guide provides comprehensive testing instructions for the goal history tracking feature.

## Prerequisites

1. ✅ Database migration completed (`goal_history` table created)
2. ✅ Backend server running
3. ✅ At least one test user in the database
4. ✅ Frontend app accessible (for UI testing)

---

## Part 1: Database Testing (SQL)

### Quick Test in Neon Console

1. **Open Neon Console SQL Editor**
2. **Run the test script**: Copy and paste `test_goal_history.sql`
3. **Update username**: Replace `'your_username'` with an actual username from your database
4. **Review results**: Check that:
   - Table structure is correct
   - Entries exist (from backfill)
   - Queries return expected results

### Expected Results

- ✅ Table exists with correct columns
- ✅ At least one entry per user (from backfill)
- ✅ Queries execute without errors
- ✅ Foreign key relationships are valid

---

## Part 2: Backend API Testing

### Option A: Python Test Script (Automated)

1. **Install dependencies** (if not already installed):
   ```bash
   pip install requests
   ```

2. **Update test configuration**:
   - Open `test_goal_history.py`
   - Update `API_BASE` with your backend URL (e.g., `http://localhost:5000`)
   - Update `TEST_USERNAME` with an actual username

3. **Run the test**:
   ```bash
   python test_goal_history.py
   ```

### Option B: Manual API Testing (Using curl or Postman)

#### Test 1: Get Current Goal
```bash
curl "http://localhost:5000/progress/goals?user=YOUR_USERNAME"
```

**Expected**: Returns current goal
```json
{
  "calories": 2280,
  "steps": 10000,
  "water": 2000,
  "exercise": 30,
  "sleep": 8
}
```

#### Test 2: Get Historical Goal (Today)
```bash
curl "http://localhost:5000/progress/goals?user=YOUR_USERNAME&date=2025-01-15"
```

**Expected**: Returns goal for that date (should match current goal if no changes)

#### Test 3: Get Historical Goal (Old Date)
```bash
curl "http://localhost:5000/progress/goals?user=YOUR_USERNAME&date=2024-12-01"
```

**Expected**: Returns most recent goal on or before that date

#### Test 4: Update User Profile (Trigger Goal Logging)
```bash
curl -X PUT "http://localhost:5000/user/YOUR_USERNAME" \
  -H "Content-Type: application/json" \
  -d '{"weight_kg": 75}'
```

**Expected**: 
- Profile updated successfully
- New goal calculated
- Entry logged to `goal_history` table

#### Test 5: Verify Goal Was Logged
```bash
# Check goal_history table in database
SELECT * FROM goal_history WHERE "user" = 'YOUR_USERNAME' ORDER BY date DESC;
```

**Expected**: New entry with today's date and new goal

---

## Part 3: Frontend Testing

### Test Scenario 1: View Current Date

1. **Open the app** and navigate to Progress/Trackback screen
2. **Select "Custom" time range**
3. **Select today's date**
4. **Verify**:
   - ✅ Bar graph displays meal breakdown
   - ✅ Goal line shows current goal
   - ✅ Summary cards show: TOTAL, GOAL (current goal), REMAINING/OVER

### Test Scenario 2: View Old Date (Before Goal Change)

1. **Select a date from before you updated the profile** (e.g., yesterday)
2. **Verify**:
   - ✅ Goal line shows the goal that was active on that date
   - ✅ Summary cards show the historical goal
   - ✅ Goal subtitle shows "current goal" (indicating it's not the date's actual goal)

### Test Scenario 3: View Date After Goal Change

1. **Update user profile** (change weight/activity level) to trigger goal change
2. **Wait a moment** for the goal to be logged
3. **Select today's date** in trackback
4. **Verify**:
   - ✅ Goal line shows the NEW goal
   - ✅ Summary cards show the NEW goal
   - ✅ Goal subtitle shows "daily target" (for recent dates)

### Test Scenario 4: Multiple Goal Changes

1. **Update profile multiple times** (e.g., change weight 3 times)
2. **Check database**: Verify multiple entries in `goal_history`
3. **Select different dates** around the goal change dates
4. **Verify**: Each date shows the correct goal that was active at that time

---

## Part 4: Edge Cases Testing

### Test 1: User with No Goal History
- **Action**: View old date for a new user (no history)
- **Expected**: Falls back to current goal

### Test 2: Invalid Date Format
- **Action**: Call API with invalid date format
- **Expected**: Returns current goal (graceful fallback)

### Test 3: Date Before User Started Tracking
- **Action**: Select date before user's first log
- **Expected**: Shows current goal (no history available)

### Test 4: Multiple Goal Changes on Same Day
- **Action**: Update profile multiple times in one day
- **Expected**: Latest goal is used (most recent entry)

---

## Part 5: Performance Testing

### Test Query Performance

Run in Neon Console:
```sql
-- Test query performance with EXPLAIN
EXPLAIN ANALYZE
SELECT daily_calorie_goal
FROM goal_history
WHERE "user" = 'YOUR_USERNAME'
  AND date <= '2025-01-15'
ORDER BY date DESC
LIMIT 1;
```

**Expected**: Query uses indexes (should be fast, < 10ms)

---

## Troubleshooting

### Issue: Goal not logging when profile updated

**Check**:
1. Backend logs for errors
2. Database connection
3. `_log_goal_change()` function is being called
4. Goal actually changed (not same as before)

**Fix**: Check `app.py` line 3866 - ensure `_log_goal_change()` is called

### Issue: Historical goal not showing in frontend

**Check**:
1. API endpoint returns correct goal
2. Frontend is calling `fetchGoalForDate()`
3. `_historicalGoal` state is being set
4. Date format matches (YYYY-MM-DD)

**Fix**: Check browser console for errors, verify API response

### Issue: Goal shows as "current goal" for old dates

**Expected behavior**: If no history exists for that date, it shows current goal with "current goal" subtitle. This is correct - history only exists from when goals are changed.

---

## Success Criteria

✅ **Database**:
- Table created successfully
- Indexes working
- Foreign keys valid

✅ **Backend**:
- Goal changes are logged automatically
- Historical goals can be retrieved
- API endpoints return correct data

✅ **Frontend**:
- Old dates show historical goals (when available)
- Recent dates show current goals
- Goal line displays correctly
- Summary cards show correct values

---

## Next Steps After Testing

1. ✅ All tests pass → Feature is ready for production
2. ❌ Issues found → Fix and retest
3. 📊 Monitor in production → Check logs for any errors

---

## Quick Test Checklist

- [ ] Database table exists
- [ ] Backfill completed (optional)
- [ ] API returns current goal
- [ ] API returns historical goal
- [ ] Profile update triggers goal logging
- [ ] Frontend displays current goal correctly
- [ ] Frontend displays historical goal correctly
- [ ] Goal line shows in bar graph
- [ ] Summary cards show correct values
- [ ] Edge cases handled gracefully

