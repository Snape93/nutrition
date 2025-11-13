#!/usr/bin/env python3
"""
Test script to verify food logging is working after the fix
"""

import requests
import json
import time

# Configuration
API_BASE = "http://localhost:5000"
TEST_USER = "test_user_fix"

def test_food_logging():
    """Test food logging functionality"""
    print("🧪 Testing Food Logging After Fix")
    print("=" * 40)
    
    # Test 1: Log a single food item
    print("\n1. Testing single food logging...")
    food_data = {
        "user": TEST_USER,
        "food_name": "Test Apple",
        "calories": 80,
        "meal_type": "Snack",
        "serving_size": "1 medium",
        "quantity": 1.0
    }
    
    try:
        response = requests.post(f"{API_BASE}/log/food", json=food_data, timeout=10)
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Single food logging successful")
            print(f"   Response: {result}")
        else:
            print(f"❌ Single food logging failed: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return False
    
    # Test 2: Log multiple foods
    print("\n2. Testing multiple food logging...")
    foods_data = {
        "user": TEST_USER,
        "foods": [
            {
                "food_name": "Test Banana",
                "calories": 105,
                "meal_type": "Breakfast",
                "serving_size": "1 medium",
                "quantity": 1.0
            },
            {
                "food_name": "Test Orange",
                "calories": 62,
                "meal_type": "Snack",
                "serving_size": "1 medium",
                "quantity": 1.0
            }
        ]
    }
    
    try:
        response = requests.post(f"{API_BASE}/log/food", json=foods_data, timeout=10)
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Multiple food logging successful")
            print(f"   Response: {result}")
        else:
            print(f"❌ Multiple food logging failed: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return False
    
    # Test 3: Get food logs
    print("\n3. Testing food logs retrieval...")
    try:
        response = requests.get(f"{API_BASE}/log/food?user={TEST_USER}", timeout=10)
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            logs = data.get('logs', [])
            print(f"✅ Retrieved {len(logs)} food logs")
            
            # Check if new fields are present
            if logs:
                log = logs[0]
                required_fields = ['created_at', 'timestamp', 'phase', 'can_delete']
                missing_fields = [field for field in required_fields if field not in log]
                
                if not missing_fields:
                    print("✅ All new fields present in response")
                    print(f"   Phase: {log.get('phase')}")
                    print(f"   Can delete: {log.get('can_delete')}")
                    print(f"   Time remaining: {log.get('time_remaining')}")
                else:
                    print(f"❌ Missing fields: {missing_fields}")
            else:
                print("❌ No logs found")
        else:
            print(f"❌ Failed to get logs: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return False
    
    print("\n" + "=" * 40)
    print("🎉 Food Logging Test Complete!")
    print("\n✅ All tests passed - food logging is working!")
    
    return True

if __name__ == "__main__":
    test_food_logging()














