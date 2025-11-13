#!/usr/bin/env python3
"""
Simple test to verify food logging works
"""

import requests
import json

# Configuration
API_BASE = "http://localhost:5000"
TEST_USER = "test_user_simple"

def test_food_logging():
    """Test food logging functionality"""
    print("Testing Food Logging")
    print("=" * 30)
    
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
            print("SUCCESS: Single food logging works!")
            print(f"   Response: {result}")
        else:
            print(f"ERROR: Single food logging failed: {response.text}")
            return False
    except Exception as e:
        print(f"ERROR: Request failed: {e}")
        return False
    
    # Test 2: Get food logs
    print("\n2. Testing food logs retrieval...")
    try:
        response = requests.get(f"{API_BASE}/log/food?user={TEST_USER}", timeout=10)
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            logs = data.get('logs', [])
            print(f"SUCCESS: Retrieved {len(logs)} food logs")
            
            if logs:
                log = logs[0]
                print(f"   Food: {log.get('food_name')}")
                print(f"   Calories: {log.get('calories')}")
                print(f"   Phase: {log.get('phase')}")
                print(f"   Can delete: {log.get('can_delete')}")
        else:
            print(f"ERROR: Failed to get logs: {response.text}")
            return False
    except Exception as e:
        print(f"ERROR: Request failed: {e}")
        return False
    
    print("\n" + "=" * 30)
    print("SUCCESS: Food logging is working!")
    print("\nThe app should now work properly.")
    
    return True

if __name__ == "__main__":
    test_food_logging()














