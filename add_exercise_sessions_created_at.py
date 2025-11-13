#!/usr/bin/env python3
"""
Database migration script to add created_at column to exercise_sessions table
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def add_created_at_to_exercise_sessions():
    """Add created_at column to exercise_sessions table"""
    with app.app_context():
        try:
            # Detect database type
            db_url = str(db.engine.url)
            print(f"Database URL: {db_url}")
            
            if 'postgresql' in db_url or 'postgres' in db_url:
                # PostgreSQL migration
                result = db.session.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'exercise_sessions' 
                    AND column_name = 'created_at'
                """))
                
                if result.fetchone():
                    print("✅ created_at column already exists in exercise_sessions")
                    return True
                
                print("Adding created_at column to exercise_sessions table...")
                db.session.execute(text("""
                    ALTER TABLE exercise_sessions 
                    ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                """))
                
                print("Updating existing records...")
                db.session.execute(text("""
                    UPDATE exercise_sessions 
                    SET created_at = CURRENT_TIMESTAMP 
                    WHERE created_at IS NULL
                """))
                
                db.session.commit()
                print("✅ PostgreSQL migration completed successfully")
                return True
                
            elif 'sqlite' in db_url:
                # SQLite migration
                result = db.session.execute(text("""
                    PRAGMA table_info(exercise_sessions)
                """))
                columns = [row[1] for row in result.fetchall()]
                
                if 'created_at' in columns:
                    print("✅ created_at column already exists in exercise_sessions")
                    return True
                
                print("Adding created_at column to exercise_sessions table...")
                db.session.execute(text("""
                    ALTER TABLE exercise_sessions 
                    ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                """))
                
                print("Updating existing records...")
                db.session.execute(text("""
                    UPDATE exercise_sessions 
                    SET created_at = CURRENT_TIMESTAMP 
                    WHERE created_at IS NULL
                """))
                
                db.session.commit()
                print("✅ SQLite migration completed successfully")
                return True
            else:
                print(f"❌ Unsupported database type: {db_url}")
                return False
                
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            db.session.rollback()
            return False

if __name__ == "__main__":
    print("🔧 Adding created_at column to exercise_sessions table...")
    print("=" * 50)
    success = add_created_at_to_exercise_sessions()
    if success:
        print("\n🎉 Migration completed successfully!")
        print("You can now save exercises without errors.")
    else:
        print("\n❌ Migration failed!")
        print("Please check the error messages above.")

