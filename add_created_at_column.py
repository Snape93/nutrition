#!/usr/bin/env python3
"""
Database migration script to add created_at column to food_logs table
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def add_created_at_column():
    """Add created_at column to food_logs table"""
    with app.app_context():
        try:
            # Check if column already exists
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'food_logs' 
                AND column_name = 'created_at'
            """))
            
            if result.fetchone():
                print("✅ created_at column already exists")
                return True
            
            # Add the created_at column
            print("Adding created_at column to food_logs table...")
            db.session.execute(text("""
                ALTER TABLE food_logs 
                ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            """))
            
            # Update existing records to have created_at = current timestamp
            print("Updating existing records...")
            db.session.execute(text("""
                UPDATE food_logs 
                SET created_at = CURRENT_TIMESTAMP 
                WHERE created_at IS NULL
            """))
            
            # Commit the changes
            db.session.commit()
            print("✅ Successfully added created_at column to food_logs table")
            print("✅ Updated existing records with current timestamp")
            
            return True
            
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            db.session.rollback()
            return False

if __name__ == "__main__":
    success = add_created_at_column()
    if success:
        print("\n🎉 Database migration completed successfully!")
        print("Food logging should now work properly.")
    else:
        print("\n❌ Database migration failed!")
        print("Please check the error message above.")














