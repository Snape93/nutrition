-- Goal History Feature - SQL Test Script
-- Run this in your Neon Console SQL Editor to test the database functionality

-- ============================================
-- TEST 1: Check if goal_history table exists
-- ============================================
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'goal_history'
ORDER BY ordinal_position;

-- ============================================
-- TEST 2: View all goal history entries
-- ============================================
SELECT 
    id,
    "user",
    date,
    daily_calorie_goal,
    created_at
FROM goal_history
ORDER BY "user", date DESC
LIMIT 20;

-- ============================================
-- TEST 3: Count entries per user
-- ============================================
SELECT 
    "user",
    COUNT(*) as entry_count,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    MAX(daily_calorie_goal) as max_goal,
    MIN(daily_calorie_goal) as min_goal
FROM goal_history
GROUP BY "user"
ORDER BY entry_count DESC;

-- ============================================
-- TEST 4: Test query for specific date (simulate API call)
-- Replace 'your_username' with an actual username
-- ============================================
-- Example: Get goal for a specific user on a specific date
SELECT 
    "user",
    date,
    daily_calorie_goal
FROM goal_history
WHERE "user" = 'your_username'  -- Replace with actual username
  AND date <= CURRENT_DATE  -- Most recent goal on or before today
ORDER BY date DESC
LIMIT 1;

-- ============================================
-- TEST 5: Check for users with multiple goal changes
-- ============================================
SELECT 
    "user",
    COUNT(DISTINCT daily_calorie_goal) as unique_goals,
    COUNT(*) as total_entries
FROM goal_history
GROUP BY "user"
HAVING COUNT(*) > 1
ORDER BY total_entries DESC;

-- ============================================
-- TEST 6: View goal history timeline for a specific user
-- Replace 'your_username' with an actual username
-- ============================================
SELECT 
    date,
    daily_calorie_goal,
    created_at,
    LAG(daily_calorie_goal) OVER (ORDER BY date) as previous_goal,
    daily_calorie_goal - LAG(daily_calorie_goal) OVER (ORDER BY date) as goal_change
FROM goal_history
WHERE "user" = 'your_username'  -- Replace with actual username
ORDER BY date DESC;

-- ============================================
-- TEST 7: Verify foreign key relationship
-- ============================================
SELECT 
    gh."user",
    gh.date,
    gh.daily_calorie_goal,
    u.username,
    u.daily_calorie_goal as current_goal
FROM goal_history gh
LEFT JOIN users u ON gh."user" = u.username
ORDER BY gh."user", gh.date DESC
LIMIT 20;

-- ============================================
-- TEST 8: Check for orphaned entries (users that don't exist)
-- ============================================
SELECT 
    gh."user",
    gh.date,
    gh.daily_calorie_goal
FROM goal_history gh
LEFT JOIN users u ON gh."user" = u.username
WHERE u.username IS NULL;

-- ============================================
-- TEST 9: Find most recent goal for each user
-- ============================================
SELECT DISTINCT ON ("user")
    "user",
    date,
    daily_calorie_goal,
    created_at
FROM goal_history
ORDER BY "user", date DESC;

-- ============================================
-- TEST 10: Test date range queries (for old dates)
-- ============================================
-- Get goal for a user 30 days ago
SELECT 
    "user",
    date,
    daily_calorie_goal
FROM goal_history
WHERE "user" = 'your_username'  -- Replace with actual username
  AND date <= (CURRENT_DATE - INTERVAL '30 days')
ORDER BY date DESC
LIMIT 1;

