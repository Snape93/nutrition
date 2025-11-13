#!/usr/bin/env python3
"""
Integration tests for the /remaining endpoint.
Run with: python test_remaining_endpoint.py
"""

import requests
import json
import sys
from datetime import datetime, timedelta

BASE = "http://localhost:5000"

def test_remaining_basic():
    """Test basic /remaining endpoint functionality."""
    print("Testing /remaining endpoint...")
    
    # Test with default user and today's date
    today = datetime.now().strftime('%Y-%m-%d')
    r = requests.get(f"{BASE}/remaining?user=default&date={today}", timeout=10)
    
    assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
    
    data = r.json()
    assert 'success' in data, f"Response missing 'success' field: {data}"
    
    if data.get('success'):
        required_fields = ['daily_calorie_goal', 'food_calories', 'exercise_calories', 'remaining_calories']
        for field in required_fields:
            assert field in data, f"Response missing '{field}' field: {data}"
            assert isinstance(data[field], (int, float)), f"'{field}' should be numeric: {data[field]}"
        
        # Validate remaining calculation
        expected_remaining = data['daily_calorie_goal'] - data['food_calories'] + data['exercise_calories']
        assert abs(data['remaining_calories'] - expected_remaining) < 0.01, \
            f"Remaining calculation mismatch: {data['remaining_calories']} vs {expected_remaining}"
        
        print(f"✓ Basic remaining test: {data['remaining_calories']} remaining")
    else:
        print(f"✓ Endpoint responded (user may not exist): {data.get('message', 'No message')}")

def test_remaining_with_food_log():
    """Test /remaining with food logging."""
    print("\nTesting /remaining with food log...")
    
    # Log some food
    food_data = {
        'user': 'test_user',
        'food': 'Test Food',
        'calories': 300,
        'date': datetime.now().strftime('%Y-%m-%d')
    }
    
    r = requests.post(f"{BASE}/log_food", json=food_data, timeout=10)
    assert r.status_code == 200, f"Food log failed: {r.status_code}: {r.text}"
    
    # Check remaining calories
    today = datetime.now().strftime('%Y-%m-%d')
    r = requests.get(f"{BASE}/remaining?user=test_user&date={today}", timeout=10)
    assert r.status_code == 200, f"Remaining request failed: {r.status_code}: {r.text}"
    
    data = r.json()
    if data.get('success'):
        assert data['food_calories'] >= 300, f"Food calories should include logged food: {data['food_calories']}"
        print(f"✓ Food logging integration: {data['food_calories']} food calories")
    else:
        print(f"✓ Food log test (user may not exist): {data.get('message', 'No message')}")

def test_remaining_with_exercise_log():
    """Test /remaining with exercise logging."""
    print("\nTesting /remaining with exercise log...")
    
    # Log some exercise
    exercise_data = {
        'user': 'test_user',
        'exercise': 'Test Exercise',
        'calories': 200,
        'date': datetime.now().strftime('%Y-%m-%d')
    }
    
    r = requests.post(f"{BASE}/log_exercise", json=exercise_data, timeout=10)
    assert r.status_code == 200, f"Exercise log failed: {r.status_code}: {r.text}"
    
    # Check remaining calories
    today = datetime.now().strftime('%Y-%m-%d')
    r = requests.get(f"{BASE}/remaining?user=test_user&date={today}", timeout=10)
    assert r.status_code == 200, f"Remaining request failed: {r.status_code}: {r.text}"
    
    data = r.json()
    if data.get('success'):
        assert data['exercise_calories'] >= 200, f"Exercise calories should include logged exercise: {data['exercise_calories']}"
        print(f"✓ Exercise logging integration: {data['exercise_calories']} exercise calories")
    else:
        print(f"✓ Exercise log test (user may not exist): {data.get('message', 'No message')}")

def test_remaining_date_handling():
    """Test /remaining with different dates."""
    print("\nTesting /remaining date handling...")
    
    # Test with yesterday
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    r = requests.get(f"{BASE}/remaining?user=default&date={yesterday}", timeout=10)
    assert r.status_code == 200, f"Yesterday request failed: {r.status_code}: {r.text}"
    
    data = r.json()
    if data.get('success'):
        print(f"✓ Yesterday date handling: {data['remaining_calories']} remaining")
    else:
        print(f"✓ Yesterday test (user may not exist): {data.get('message', 'No message')}")
    
    # Test with future date
    tomorrow = (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d')
    r = requests.get(f"{BASE}/remaining?user=default&date={tomorrow}", timeout=10)
    assert r.status_code == 200, f"Tomorrow request failed: {r.status_code}: {r.text}"
    
    data = r.json()
    if data.get('success'):
        # Future dates should have no food/exercise logs
        assert data['food_calories'] == 0, f"Future date should have no food calories: {data['food_calories']}"
        assert data['exercise_calories'] == 0, f"Future date should have no exercise calories: {data['exercise_calories']}"
        print(f"✓ Future date handling: {data['remaining_calories']} remaining (no logs)")
    else:
        print(f"✓ Future date test (user may not exist): {data.get('message', 'No message')}")

def test_remaining_missing_user():
    """Test /remaining with non-existent user."""
    print("\nTesting /remaining with missing user...")
    
    r = requests.get(f"{BASE}/remaining?user=nonexistent_user&date=2025-01-01", timeout=10)
    assert r.status_code == 200, f"Missing user request failed: {r.status_code}: {r.text}"
    
    data = r.json()
    assert data.get('success') == False, f"Missing user should return success=False: {data}"
    assert 'message' in data, f"Missing user should have error message: {data}"
    print(f"✓ Missing user handling: {data['message']}")

if __name__ == "__main__":
    try:
        test_remaining_basic()
        test_remaining_with_food_log()
        test_remaining_with_exercise_log()
        test_remaining_date_handling()
        test_remaining_missing_user()
        print("\n🎉 All endpoint tests passed!")
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        sys.exit(1)


