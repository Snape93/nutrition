#!/usr/bin/env python3
"""
Test script to verify the database migration worked
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db, FoodLog
from sqlalchemy import text

def test_migration():
    """Test if the migration was successful"""
    print("🧪 Testing Database Migration")
    print("=" * 40)
    
    with app.app_context():
        try:
            # Test 1: Check if created_at column exists
            print("\n1. Checking if created_at column exists...")
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'food_logs' 
                AND column_name = 'created_at'
            """))
            
            if result.fetchone():
                print("✅ created_at column exists")
            else:
                print("❌ created_at column missing")
                return False
            
            # Test 2: Try to create a new FoodLog entry
            print("\n2. Testing FoodLog creation...")
            test_log = FoodLog(
                user='test_migration',
                food_name='Test Food',
                calories=100.0,
                meal_type='Test',
                serving_size='100g',
                quantity=1.0
            )
            
            db.session.add(test_log)
            db.session.commit()
            print("✅ FoodLog creation successful")
            print(f"   Created log ID: {test_log.id}")
            print(f"   Created at: {test_log.created_at}")
            
            # Test 3: Query the created log
            print("\n3. Testing FoodLog query...")
            retrieved_log = FoodLog.query.filter_by(id=test_log.id).first()
            if retrieved_log and retrieved_log.created_at:
                print("✅ FoodLog query successful")
                print(f"   Retrieved created_at: {retrieved_log.created_at}")
            else:
                print("❌ FoodLog query failed or created_at is null")
                return False
            
            # Test 4: Clean up test data
            print("\n4. Cleaning up test data...")
            db.session.delete(test_log)
            db.session.commit()
            print("✅ Test data cleaned up")
            
            print("\n" + "=" * 40)
            print("🎉 Migration test completed successfully!")
            print("\n✅ Database migration is working correctly")
            print("✅ Food logging should now work in the app")
            
            return True
            
        except Exception as e:
            print(f"❌ Migration test failed: {e}")
            db.session.rollback()
            return False

if __name__ == "__main__":
    test_migration()














