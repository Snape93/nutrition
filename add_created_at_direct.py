#!/usr/bin/env python3
"""
Add created_at column to exercise_sessions table using direct connection
"""

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# Your Neon database connection string
DATABASE_URL = 'postgresql://neondb_owner:npg_9OjQXmcEB3Vn@ep-curly-tooth-a17bgdzr-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require'

def add_created_at_column():
    """Add created_at column to exercise_sessions table"""
    try:
        print("Connecting to database...")
        conn = psycopg2.connect(DATABASE_URL)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        print("Checking if created_at column exists...")
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'exercise_sessions' 
            AND column_name = 'created_at'
        """)
        
        if cursor.fetchone():
            print("[OK] created_at column already exists!")
            cursor.close()
            conn.close()
            return True
        
        print("Adding created_at column to exercise_sessions table...")
        cursor.execute("""
            ALTER TABLE exercise_sessions 
            ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        """)
        
        print("[OK] Successfully added created_at column!")
        print("[OK] Migration completed!")
        print("\nNext steps:")
        print("   1. Restart your Flask backend server")
        print("   2. Try adding an exercise again - it should work now!")
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Exercise Sessions Migration - Direct Connection")
    print("=" * 60)
    success = add_created_at_column()
    print("=" * 60)
    if success:
        print("[OK] Migration successful!")
    else:
        print("[ERROR] Migration failed!")

