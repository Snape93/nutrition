"""
Reset exercises database and import new ExerciseDB data
"""
import sqlite3
import os

db_path = 'instance/nutrition.db'

if os.path.exists(db_path):
    print(f"Connecting to database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check current count
    cursor.execute('SELECT COUNT(*) FROM exercises')
    old_count = cursor.fetchone()[0]
    print(f"Current exercises in database: {old_count}")
    
    # Delete all exercises
    cursor.execute('DELETE FROM exercises')
    conn.commit()
    print(f"[OK] Deleted all {old_count} old exercises")
    
    # Verify
    cursor.execute('SELECT COUNT(*) FROM exercises')
    new_count = cursor.fetchone()[0]
    print(f"Exercises remaining: {new_count}")
    
    conn.close()
    
    print("\n" + "="*60)
    print("SUCCESS! Database is now empty.")
    print("="*60)
    print("\nNext steps:")
    print("  1. Start your Flask app: python app.py")
    print("  2. The app will automatically import all 873 ExerciseDB exercises")
    print("  3. You'll see this message: 'Imported exercises from CSV (added=873)'")
else:
    print(f"Database not found: {db_path}")

