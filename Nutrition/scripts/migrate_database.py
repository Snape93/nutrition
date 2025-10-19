"""
Migrate database to increase exercise_id column size
"""
import sqlite3
import os

db_path = 'instance/nutrition.db'

if not os.path.exists(db_path):
    print(f"Database not found: {db_path}")
    exit(1)

print(f"Migrating database: {db_path}")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # SQLite doesn't support ALTER COLUMN, so we need to:
    # 1. Create a new table with the correct schema
    # 2. Copy data from old table
    # 3. Drop old table
    # 4. Rename new table
    
    print("Creating new exercises table with larger exercise_id column...")
    cursor.execute('''
        CREATE TABLE exercises_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercise_id VARCHAR(100) UNIQUE,
            name VARCHAR(200) NOT NULL,
            body_part VARCHAR(100),
            equipment VARCHAR(100),
            target VARCHAR(100),
            gif_url VARCHAR(500),
            instructions TEXT,
            category VARCHAR(50),
            difficulty VARCHAR(20),
            estimated_calories_per_minute INTEGER DEFAULT 5,
            created_at TIMESTAMP
        )
    ''')
    
    # Copy data from old table if it exists and has data
    cursor.execute("SELECT COUNT(*) FROM exercises")
    count = cursor.fetchone()[0]
    
    if count > 0:
        print(f"Copying {count} exercises to new table...")
        cursor.execute('''
            INSERT INTO exercises_new 
            SELECT * FROM exercises
        ''')
    
    # Drop old table
    print("Dropping old table...")
    cursor.execute('DROP TABLE exercises')
    
    # Rename new table
    print("Renaming new table...")
    cursor.execute('ALTER TABLE exercises_new RENAME TO exercises')
    
    # Recreate indexes
    print("Creating indexes...")
    cursor.execute('CREATE INDEX ix_exercises_name ON exercises(name)')
    cursor.execute('CREATE INDEX ix_exercises_category ON exercises(category)')
    
    conn.commit()
    print("\n[OK] Database migration completed successfully!")
    print(f"   - exercise_id column size increased from VARCHAR(50) to VARCHAR(100)")
    print(f"   - Indexes recreated")
    
except Exception as e:
    print(f"\n[ERROR] Migration failed: {e}")
    conn.rollback()
finally:
    conn.close()

