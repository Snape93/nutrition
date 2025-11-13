#!/usr/bin/env python3
"""
Database migration script for SQLite to add created_at column to food_logs table
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def add_created_at_column_sqlite():
    """Add created_at column to food_logs table for SQLite"""
    with app.app_context():
        try:
            # Check if column already exists
            result = db.session.execute(text("""
                PRAGMA table_info(food_logs)
            """))
            
            columns = [row[1] for row in result.fetchall()]
            if 'created_at' in columns:
                print("✅ created_at column already exists")
                return True
            
            # For SQLite, we need to create a new table with the new column
            print("Creating new table with created_at column...")
            
            # Create new table with created_at column
            db.session.execute(text("""
                CREATE TABLE food_logs_new (
                    id INTEGER PRIMARY KEY,
                    "user" VARCHAR(80) NOT NULL,
                    food_name VARCHAR(200) NOT NULL,
                    calories FLOAT NOT NULL,
                    meal_type VARCHAR(50),
                    serving_size VARCHAR(100),
                    quantity FLOAT DEFAULT 1.0,
                    protein FLOAT DEFAULT 0.0,
                    carbs FLOAT DEFAULT 0.0,
                    fat FLOAT DEFAULT 0.0,
                    fiber FLOAT DEFAULT 0.0,
                    sodium FLOAT DEFAULT 0.0,
                    date DATE NOT NULL DEFAULT CURRENT_DATE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            # Copy data from old table to new table
            print("Copying existing data...")
            db.session.execute(text("""
                INSERT INTO food_logs_new 
                (id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, created_at)
                SELECT id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, CURRENT_TIMESTAMP
                FROM food_logs
            """))
            
            # Drop old table
            print("Replacing old table...")
            db.session.execute(text("DROP TABLE food_logs"))
            
            # Rename new table
            db.session.execute(text("ALTER TABLE food_logs_new RENAME TO food_logs"))
            
            # Recreate indexes
            print("Recreating indexes...")
            db.session.execute(text("""
                CREATE INDEX ix_food_logs_user_date ON food_logs ("user", date)
            """))
            
            # Commit the changes
            db.session.commit()
            print("✅ Successfully added created_at column to food_logs table")
            print("✅ Migrated existing data with current timestamp")
            
            return True
            
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            db.session.rollback()
            return False

if __name__ == "__main__":
    success = add_created_at_column_sqlite()
    if success:
        print("\n🎉 SQLite database migration completed successfully!")
        print("Food logging should now work properly.")
    else:
        print("\n❌ SQLite database migration failed!")
        print("Please check the error message above.")














