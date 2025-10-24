#!/usr/bin/env python3
"""
Debug script to identify why progress data isn't showing in Flutter app
"""

import requests
import json
from datetime import datetime, date, timedelta

def debug_progress_issue():
    print("Debugging Progress Data Issue")
    print("=" * 50)
    
    # Test different users and scenarios
    test_users = ['test_user', 'default', 'admin']
    
    for user in test_users:
        print(f"\nTesting user: {user}")
        
        # 1. Check if user has any food logs
        try:
            response = requests.get(f'http://localhost:5000/log/food?user={user}')
            if response.status_code == 200:
                data = response.json()
                logs = data.get('logs', [])
                totals = data.get('totals', {})
                print(f"   Food logs: {len(logs)} entries")
                print(f"   Total calories: {totals.get('calories', 0)}")
                
                if logs:
                    print(f"   Latest log: {logs[-1]}")
            else:
                print(f"   Error getting food logs: {response.status_code}")
        except Exception as e:
            print(f"   Exception: {e}")
        
        # 2. Check progress calories endpoint
        try:
            response = requests.get(f'http://localhost:5000/progress/calories?user={user}')
            if response.status_code == 200:
                data = response.json()
                print(f"   Progress calories: {len(data)} entries")
                if data:
                    print(f"   Latest: {data[-1]}")
            else:
                print(f"   Error getting progress calories: {response.status_code}")
        except Exception as e:
            print(f"   Exception: {e}")
        
        # 3. Check daily summary
        try:
            response = requests.get(f'http://localhost:5000/progress/daily-summary?user={user}')
            if response.status_code == 200:
                data = response.json()
                calories = data.get('calories', {})
                print(f"   Daily summary calories: {calories.get('current', 0)}/{calories.get('goal', 0)}")
            else:
                print(f"   Error getting daily summary: {response.status_code}")
        except Exception as e:
            print(f"   Exception: {e}")
    
    # 4. Test adding food for a specific user
    print(f"\nAdding test food for 'test_user'...")
    test_food = {
        'user': 'test_user',
        'food_name': 'Banana',
        'calories': 105,
        'meal_type': 'snack',
        'serving_size': '1 medium',
        'quantity': 1,
        'date': date.today().strftime('%Y-%m-%d')
    }
    
    try:
        response = requests.post('http://localhost:5000/log/food', json=test_food)
        print(f"   Food logging response: {response.status_code}")
        if response.status_code == 200:
            print("   Food logged successfully!")
            
            # Check if it appears in progress data
            response = requests.get('http://localhost:5000/progress/daily-summary?user=test_user')
            if response.status_code == 200:
                data = response.json()
                calories = data.get('calories', {})
                print(f"   Updated calories: {calories.get('current', 0)}/{calories.get('goal', 0)}")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # 5. Check database directly
    print(f"\nDatabase check...")
    try:
        # This would require database access, but we can check via API
        response = requests.get('http://localhost:5000/progress/summary?user=test_user')
        if response.status_code == 200:
            data = response.json()
            print(f"   Summary: {data}")
        else:
            print(f"   Error: {response.status_code}")
    except Exception as e:
        print(f"   Exception: {e}")

if __name__ == "__main__":
    debug_progress_issue()
