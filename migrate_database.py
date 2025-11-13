#!/usr/bin/env python3
"""
Universal database migration script to add created_at column
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text, inspect

def detect_database_type():
    """Detect the database type"""
    with app.app_context():
        try:
            # Get database URL
            db_url = str(db.engine.url)
            print(f"Database URL: {db_url}")
            
            if 'postgresql' in db_url or 'postgres' in db_url:
                return 'postgresql'
            elif 'sqlite' in db_url:
                return 'sqlite'
            elif 'mysql' in db_url:
                return 'mysql'
            else:
                return 'unknown'
        except Exception as e:
            print(f"Error detecting database type: {e}")
            return 'unknown'

def migrate_postgresql():
    """Migrate PostgreSQL database"""
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
        
        # Update existing records
        print("Updating existing records...")
        db.session.execute(text("""
            UPDATE food_logs 
            SET created_at = CURRENT_TIMESTAMP 
            WHERE created_at IS NULL
        """))
        
        db.session.commit()
        print("✅ PostgreSQL migration completed successfully")
        return True
        
    except Exception as e:
        print(f"❌ PostgreSQL migration failed: {e}")
        db.session.rollback()
        return False

def migrate_sqlite():
    """Migrate SQLite database"""
    try:
        # Check if column already exists
        result = db.session.execute(text("PRAGMA table_info(food_logs)"))
        columns = [row[1] for row in result.fetchall()]
        
        if 'created_at' in columns:
            print("✅ created_at column already exists")
            return True
        
        # Create new table with created_at column
        print("Creating new table with created_at column...")
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
        
        # Copy data from old table
        print("Copying existing data...")
        db.session.execute(text("""
            INSERT INTO food_logs_new 
            (id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, created_at)
            SELECT id, "user", food_name, calories, meal_type, serving_size, quantity, protein, carbs, fat, fiber, sodium, date, CURRENT_TIMESTAMP
            FROM food_logs
        """))
        
        # Replace old table
        print("Replacing old table...")
        db.session.execute(text("DROP TABLE food_logs"))
        db.session.execute(text("ALTER TABLE food_logs_new RENAME TO food_logs"))
        
        # Recreate indexes
        print("Recreating indexes...")
        db.session.execute(text("""
            CREATE INDEX ix_food_logs_user_date ON food_logs ("user", date)
        """))
        
        db.session.commit()
        print("✅ SQLite migration completed successfully")
        return True
        
    except Exception as e:
        print(f"❌ SQLite migration failed: {e}")
        db.session.rollback()
        return False

def migrate_database():
    """Main migration function"""
    print("🔧 Starting Database Migration")
    print("=" * 40)
    
    with app.app_context():
        # Detect database type
        db_type = detect_database_type()
        print(f"Detected database type: {db_type}")
        
        if db_type == 'postgresql':
            success = migrate_postgresql()
        elif db_type == 'sqlite':
            success = migrate_sqlite()
        else:
            print(f"❌ Unsupported database type: {db_type}")
            print("Please run the appropriate migration script manually:")
            print("- For PostgreSQL: python add_created_at_column.py")
            print("- For SQLite: python add_created_at_sqlite.py")
            return False
        
        if success:
            print("\n🎉 Database migration completed successfully!")
            print("Food logging should now work properly.")
            print("\nNext steps:")
            print("1. Restart your Flask server")
            print("2. Test food logging in the app")
            print("3. Check the history screen for the new 3-phase system")
        else:
            print("\n❌ Database migration failed!")
            print("Please check the error messages above.")
        
        return success

if __name__ == "__main__":
    migrate_database()














