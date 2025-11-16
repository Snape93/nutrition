# Goal History Migration Guide

## Overview
This migration adds goal history tracking to enable showing the correct daily calorie goal when viewing old dates in the trackback feature.

## What This Does
1. Creates a `goal_history` table to store historical daily calorie goals
2. Automatically logs goal changes when users update their profile
3. Allows querying the goal that was active on a specific date

## Database Changes

### New Table: `goal_history`
- `id`: Primary key
- `user`: Username (foreign key to users table)
- `date`: Date when this goal was active
- `daily_calorie_goal`: The daily calorie goal value
- `created_at`: Timestamp when the entry was created

### Indexes
- `ix_goal_history_user_date`: Composite index on (user, date) for fast lookups
- `ix_goal_history_user`: Index on user for user-specific queries
- `ix_goal_history_date`: Index on date for date-based queries

## Migration Steps

### Option 1: Using SQLite (Development)
```bash
# Navigate to your project directory
cd /path/to/Nutrition

# Run the migration script
sqlite3 nutrition.db < migrations/create_goal_history_table.sql
```

### Option 2: Using Flask-Migrate (Recommended for Production)
```bash
# If you're using Flask-Migrate
flask db migrate -m "Add goal_history table"
flask db upgrade
```

### Option 3: Manual SQL Execution
1. Open your database management tool (e.g., DB Browser for SQLite, pgAdmin, etc.)
2. Execute the SQL script: `migrations/create_goal_history_table.sql`

## Backfilling Existing Data (Optional)

If you want to create initial goal history entries for existing users:

```sql
INSERT INTO goal_history (user, date, daily_calorie_goal)
SELECT 
    username,
    DATE('now') as date,
    COALESCE(daily_calorie_goal, 2000) as daily_calorie_goal
FROM users
WHERE daily_calorie_goal IS NOT NULL
ON CONFLICT DO NOTHING;
```

**Note:** This is optional. The system will automatically create entries when users update their goals going forward.

## How It Works

### Automatic Goal Logging
When a user updates their profile (age, weight, height, activity level, or goal), the system:
1. Calculates the new daily calorie goal
2. Compares it to the old goal
3. If different, logs the new goal to `goal_history` with today's date

### Querying Historical Goals
When viewing an old date:
1. The system queries `goal_history` for the most recent goal on or before that date
2. If found, uses that goal
3. If not found, falls back to the user's current goal

## Testing

After migration, test the feature:
1. Update a user's profile (change weight, activity level, etc.)
2. Check that a new entry appears in `goal_history`
3. View an old date in the trackback feature
4. Verify the correct historical goal is displayed

## Rollback (If Needed)

To rollback this migration:

```sql
DROP INDEX IF EXISTS ix_goal_history_date;
DROP INDEX IF EXISTS ix_goal_history_user;
DROP INDEX IF EXISTS ix_goal_history_user_date;
DROP TABLE IF EXISTS goal_history;
```

## Notes
- The system automatically handles goal changes going forward
- No manual intervention needed after migration
- Historical goals are queried efficiently using indexes
- Falls back gracefully if no history exists for a date

