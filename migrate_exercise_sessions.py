#!/usr/bin/env python3
"""
Migrate exercise_sessions table to add created_at column
"""

import os
import sys

# Set environment before importing
os.environ.setdefault('FLASK_ENV', 'development')

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def migrate():
    """Add created_at column to exercise_sessions table"""
    with app.app_context():
        try:
            print("🔧 Checking exercise_sessions table...")
            
            # Check if column exists
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'exercise_sessions' 
                AND column_name = 'created_at'
            """))
            
            if result.fetchone():
                print("✅ created_at column already exists!")
                return True
            
            print("➕ Adding created_at column to exercise_sessions...")
            db.session.execute(text("""
                ALTER TABLE exercise_sessions 
                ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            """))
            
            db.session.commit()
            print("✅ Successfully added created_at column!")
            print("✅ Migration completed!")
            print("\n📝 Next steps:")
            print("   1. Restart your Flask backend server")
            print("   2. Try adding an exercise again - it should work now!")
            return True
            
        except Exception as e:
            print(f"❌ Error: {e}")
            db.session.rollback()
            import traceback
            traceback.print_exc()
            return False

if __name__ == "__main__":
    print("=" * 60)
    print("Exercise Sessions Migration")
    print("=" * 60)
    success = migrate()
    print("=" * 60)
    if success:
        print("✅ Migration successful!")
    else:
        print("❌ Migration failed!")

