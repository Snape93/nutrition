"""
Migration script to convert existing estimated_calories_per_minute to MET values.

This script:
1. Reads all exercises from the database
2. Converts calories_per_minute to MET values (assuming 70kg person)
3. Updates the met_value field in the database

Formula: MET = (calories_per_minute × 60) / 70
(Assuming 70kg is the standard reference weight)
"""

import sys
import os
from dotenv import load_dotenv

# Load environment variables from .env file FIRST
load_dotenv()

# Force set FLASK_ENV to 'development' (override any .env setting)
os.environ['FLASK_ENV'] = 'development'

# Add the app directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, db, Exercise
from sqlalchemy import text

def migrate_calories_to_met():
    """Convert all existing calories_per_minute values to MET values"""
    try:
        with app.app_context():
            # Test database connection first
            try:
                db.session.execute(text("SELECT 1"))
            except Exception as e:
                print(f"[ERROR] Database connection failed: {e}")
                print("Please check your NEON_DATABASE_URL in .env file")
                return 0
            
            exercises = Exercise.query.all()
            updated_count = 0
            
            print(f"Found {len(exercises)} exercises to process...")
            
            for exercise in exercises:
                if exercise.met_value is None or exercise.met_value == 0:
                    # Derive MET from calories_per_minute (assuming 70kg person)
                    cpm = exercise.estimated_calories_per_minute or 5
                    met_value = (float(cpm) * 60) / 70.0
                    exercise.met_value = round(met_value, 1)
                    updated_count += 1
                    print(f"Updated {exercise.name}: {cpm} cal/min -> MET {exercise.met_value}")
            
            if updated_count > 0:
                db.session.commit()
                print(f"\n[SUCCESS] Successfully updated {updated_count} exercises with MET values!")
            else:
                print("\n[SUCCESS] All exercises already have MET values.")
            
            return updated_count
    except Exception as e:
        print(f"[ERROR] Error during migration: {e}")
        import traceback
        traceback.print_exc()
        return 0

if __name__ == '__main__':
    print("Starting migration: calories_per_minute -> MET values")
    print("=" * 60)
    try:
        count = migrate_calories_to_met()
        print("=" * 60)
        print(f"Migration completed! Updated {count} exercises.")
    except Exception as e:
        print(f"[ERROR] Error during migration: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

