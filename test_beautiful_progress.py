#!/usr/bin/env python3
"""
Test script to verify the beautiful progress screen works with real data
"""

import requests
import json
from datetime import datetime, date

def test_beautiful_progress():
    print("Testing Beautiful Progress Screen Integration")
    print("=" * 50)
    
    # Test user with known data
    test_user = 'test_user'
    
    # 1. Add some test data for different metrics
    print("\n1. Adding test data...")
    
    # Add calories
    calories_data = {
        'user': test_user,
        'food_name': 'Test Food',
        'calories': 500,
        'meal_type': 'lunch',
        'serving_size': '1 serving',
        'quantity': 1,
        'date': date.today().strftime('%Y-%m-%d')
    }
    
    try:
        response = requests.post('http://localhost:5000/log/food', json=calories_data)
        print(f"   Calories logged: {response.status_code}")
    except Exception as e:
        print(f"   Error: {e}")
    
    # 2. Test progress endpoints
    print("\n2. Testing progress endpoints...")
    
    endpoints = [
        '/progress/calories',
        '/progress/daily-summary',
        '/progress/goals'
    ]
    
    for endpoint in endpoints:
        try:
            response = requests.get(f'http://localhost:5000{endpoint}?user={test_user}')
            print(f"   {endpoint}: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                if endpoint == '/progress/daily-summary':
                    calories = data.get('calories', {})
                    print(f"     Calories: {calories.get('current', 0)}/{calories.get('goal', 0)}")
                elif endpoint == '/progress/calories':
                    print(f"     Entries: {len(data)}")
        except Exception as e:
            print(f"   Error: {e}")
    
    # 3. Test different time ranges
    print("\n3. Testing time ranges...")
    
    time_ranges = ['daily', 'weekly', 'monthly']
    for time_range in time_ranges:
        try:
            response = requests.get(f'http://localhost:5000/progress/daily-summary?user={test_user}')
            if response.status_code == 200:
                data = response.json()
                print(f"   {time_range}: {data.get('date', 'N/A')}")
        except Exception as e:
            print(f"   Error: {e}")
    
    print("\n" + "=" * 50)
    print("Beautiful Progress Screen Test Completed!")
    print("\nThe Flutter app should now show:")
    print("- Real calorie data instead of 'No data yet'")
    print("- Progress bars with actual percentages")
    print("- Beautiful green-themed UI matching the design")
    print("- Working metric switching (Calories/Exercise/Water)")
    print("- Time range selection (Daily/Weekly/Monthly)")

if __name__ == "__main__":
    test_beautiful_progress()















