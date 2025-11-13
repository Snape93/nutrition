import sqlite3

conn = sqlite3.connect('instance/nutrition.db')
cursor = conn.cursor()

# Get tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [row[0] for row in cursor.fetchall()]
print(f"Tables in database: {tables}")

# Check exercises
try:
    cursor.execute('SELECT COUNT(*) FROM exercises')
    count = cursor.fetchone()[0]
    print(f"\nTotal exercises in database: {count}")
    
    if count > 0:
        cursor.execute('SELECT name, category, difficulty, body_part FROM exercises LIMIT 10')
        print("\nFirst 10 exercises:")
        for row in cursor.fetchall():
            print(f"  - {row[0]}")
            print(f"    Category: {row[1]}, Difficulty: {row[2]}, Body Part: {row[3]}")
        
        # Category breakdown
        cursor.execute('SELECT category, COUNT(*) FROM exercises GROUP BY category')
        print("\nExercises by category:")
        for row in cursor.fetchall():
            print(f"  - {row[0]}: {row[1]} exercises")
    else:
        print("\n[INFO] Database is EMPTY")
        print("When you start the Flask app (python app.py), it will:")
        print("  1. Detect the database is empty")
        print("  2. Look for data/exercises.csv")
        print("  3. Import all 873 ExerciseDB exercises automatically")
        print("  4. You'll have access to all exercises immediately")
except Exception as e:
    print(f"Error: {e}")

conn.close()

