-- Migration: Create goal_history table for tracking historical daily calorie goals
-- Database: PostgreSQL (Neon)
-- Date: 2025-01-XX
-- Description: This table stores historical daily calorie goals so we can show
--              the correct goal when viewing old dates in the trackback feature.

-- Create goal_history table
CREATE TABLE IF NOT EXISTS goal_history (
    id SERIAL PRIMARY KEY,
    "user" VARCHAR(80) NOT NULL,
    date DATE NOT NULL,
    daily_calorie_goal INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_goal_history_user FOREIGN KEY ("user") REFERENCES users(username) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS ix_goal_history_user_date ON goal_history("user", date);
CREATE INDEX IF NOT EXISTS ix_goal_history_user ON goal_history("user");
CREATE INDEX IF NOT EXISTS ix_goal_history_date ON goal_history(date);

-- Optional: Backfill existing goals for current users
-- This will create an initial entry for each user with their current goal
-- Uncomment if you want to backfill:
/*
INSERT INTO goal_history ("user", date, daily_calorie_goal)
SELECT 
    username,
    CURRENT_DATE as date,
    COALESCE(daily_calorie_goal, 2000) as daily_calorie_goal
FROM users
WHERE daily_calorie_goal IS NOT NULL
ON CONFLICT DO NOTHING;
*/

