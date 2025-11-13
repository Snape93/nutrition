#!/usr/bin/env python3
"""
Test script to verify API response types are correct
"""

import requests
import json

# Configuration
API_BASE = "http://localhost:5000"
TEST_USER = "test_user_types"

def test_api_types():
    """Test API response types"""
    print("Testing API Response Types")
    print("=" * 30)
    
    # Test 1: Log a food item
    print("\n1. Logging a test food item...")
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
        if response.status_code != 200:
            print(f"ERROR: Failed to log food: {response.text}")
            return False
        print("SUCCESS: Food logged successfully")
    except Exception as e:
        print(f"ERROR: Request failed: {e}")
        return False
    
    # Test 2: Get food logs and check types
    print("\n2. Checking API response types...")
    try:
        response = requests.get(f"{API_BASE}/log/food?user={TEST_USER}", timeout=10)
        if response.status_code != 200:
            print(f"ERROR: Failed to get logs: {response.text}")
            return False
        
        data = response.json()
        logs = data.get('logs', [])
        
        if not logs:
            print("ERROR: No logs found")
            return False
        
        log = logs[0]
        print("Checking field types:")
        
        # Check numeric fields
        numeric_fields = ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sodium', 'quantity']
        for field in numeric_fields:
            value = log.get(field)
            if value is not None:
                if isinstance(value, (int, float)):
                    print(f"  {field}: {type(value).__name__} = {value}")
                else:
                    print(f"  ERROR: {field} is {type(value).__name__}, expected int/float")
                    return False
        
        # Check other fields
        other_fields = ['time_remaining', 'progress_percentage']
        for field in other_fields:
            value = log.get(field)
            if value is not None:
                if isinstance(value, (int, float)):
                    print(f"  {field}: {type(value).__name__} = {value}")
                else:
                    print(f"  ERROR: {field} is {type(value).__name__}, expected int/float")
                    return False
        
        print("SUCCESS: All numeric fields have correct types")
        
    except Exception as e:
        print(f"ERROR: Request failed: {e}")
        return False
    
    print("\n" + "=" * 30)
    print("SUCCESS: API response types are correct!")
    print("The Flutter app should now work without type casting errors.")
    
    return True

if __name__ == "__main__":
    test_api_types()














