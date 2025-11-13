#!/usr/bin/env python3
"""
Simple database migration script that directly connects to the database
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_database_url():
    """Get database URL from environment"""
    return os.environ.get('NEON_DATABASE_URL', '')

def run_migration():
    """Run the database migration"""
    print("🔧 Starting Simple Database Migration")
    print("=" * 50)
    
    db_url = get_database_url()
    if not db_url:
        print("❌ No database URL found in environment variables")
        print("Please set NEON_DATABASE_URL environment variable")
        return False
    
    print(f"Database URL: {db_url[:50]}...")
    
    try:
        if 'postgresql' in db_url or 'postgres' in db_url:
            print("\n📊 Detected PostgreSQL database")
            return migrate_postgresql(db_url)
        elif 'sqlite' in db_url:
            print("\n📊 Detected SQLite database")
            return migrate_sqlite(db_url)
        else:
            print(f"❌ Unsupported database type in URL: {db_url}")
            return False
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

def migrate_postgresql(db_url):
    """Migrate PostgreSQL database"""
    try:
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        
        # Parse database URL
        # postgresql://user:password@host:port/database
        import urllib.parse as urlparse
        parsed = urlparse.urlparse(db_url)
        
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            database=parsed.path[1:],  # Remove leading slash
            user=parsed.username,
            password=parsed.password
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Check if column exists
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'food_logs' 
            AND column_name = 'created_at'
        """)
        
        if cursor.fetchone():
            print("✅ created_at column already exists")
            return True
        
        # Add the created_at column
        print("Adding created_at column to food_logs table...")
        cursor.execute("""
            ALTER TABLE food_logs 
            ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        """)
        
        # Update existing records
        print("Updating existing records...")
        cursor.execute("""
            UPDATE food_logs 
            SET created_at = CURRENT_TIMESTAMP 
            WHERE created_at IS NULL
        """)
        
        cursor.close()
        conn.close()
        
        print("✅ PostgreSQL migration completed successfully")
        return True
        
    except ImportError:
        print("❌ psycopg2 not installed. Please install it with: pip install psycopg2-binary")
        return False
    except Exception as e:
        print(f"❌ PostgreSQL migration failed: {e}")
        return False

def migrate_sqlite(db_url):
    """Migrate SQLite database"""
    try:
        import sqlite3
        
        # Extract database file path from URL
        db_path = db_url.replace('sqlite:///', '')
        if not os.path.exists(db_path):
            print(f"❌ SQLite database file not found: {db_path}")
            return False
        
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if column exists
        cursor.execute("PRAGMA table_info(food_logs)")
        columns = [row[1] for row in cursor.fetchall()]
        
        if 'created_at' in columns:
            print("✅ created_at column already exists")
            return True
        
        # Create new table with created_at column
        print("Creating new table with created_at column...")
        cursor.execute("""
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
        """)
        
        # Copy data from old table
        print("Copying existing data...")
        cursor.execute("""
            INSERT INTO food_logs_new 
            (id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, created_at)
            SELECT id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, CURRENT_TIMESTAMP
            FROM food_logs
        """)
        
        # Replace old table
        print("Replacing old table...")
        cursor.execute("DROP TABLE food_logs")
        cursor.execute("ALTER TABLE food_logs_new RENAME TO food_logs")
        
        # Recreate indexes
        print("Recreating indexes...")
        cursor.execute("""
            CREATE INDEX ix_food_logs_user_date ON food_logs ("user", date)
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print("✅ SQLite migration completed successfully")
        return True
        
    except Exception as e:
        print(f"❌ SQLite migration failed: {e}")
        return False

if __name__ == "__main__":
    success = run_migration()
    if success:
        print("\n🎉 Database migration completed successfully!")
        print("Food logging should now work properly.")
        print("\nNext steps:")
        print("1. Restart your Flask server")
        print("2. Test food logging in the app")
    else:
        print("\n❌ Database migration failed!")
        print("Please check the error messages above.")














