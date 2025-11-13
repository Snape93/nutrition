#!/usr/bin/env python3
"""
Quick fix: Add created_at column to exercise_sessions table
Run this script: python fix_exercise_sessions.py
"""

import os
import sys

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def fix_exercise_sessions():
    """Add created_at column if it doesn't exist"""
    with app.app_context():
        try:
            print("🔧 Checking exercise_sessions table...")
            
            # Check if column exists (PostgreSQL)
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'exercise_sessions' 
                AND column_name = 'created_at'
            """))
            
            if result.fetchone():
                print("✅ created_at column already exists!")
                return True
            
            print("➕ Adding created_at column...")
            db.session.execute(text("""
                ALTER TABLE exercise_sessions 
                ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            """))
            
            db.session.commit()
            print("✅ Successfully added created_at column!")
            print("✅ You can now save exercises!")
            return True
            
        except Exception as e:
            print(f"❌ Error: {e}")
            db.session.rollback()
            print("\n💡 Alternative: Run this SQL directly in your database:")
            print("   ALTER TABLE exercise_sessions ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;")
            return False

if __name__ == "__main__":
    print("=" * 50)
    print("Fix Exercise Sessions Table")
    print("=" * 50)
    fix_exercise_sessions()
    print("=" * 50)

