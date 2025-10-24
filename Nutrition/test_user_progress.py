#!/usr/bin/env python3
"""
Test script to verify progress data for a specific user
"""

import requests
import json
from datetime import datetime, date

def test_user_progress(username):
    print(f"Testing progress data for user: {username}")
    print("=" * 50)
    
    # 1. Add some test food for this user
    print(f"\n1. Adding test food for {username}...")
    test_foods = [
        {
            'user': username,
            'food_name': 'Apple',
            'calories': 95,
            'meal_type': 'breakfast',
            'serving_size': '1 medium',
            'quantity': 1,
            'date': date.today().strftime('%Y-%m-%d')
        },
        {
            'user': username,
            'food_name': 'Sandwich',
            'calories': 300,
            'meal_type': 'lunch',
            'serving_size': '1 sandwich',
            'quantity': 1,
            'date': date.today().strftime('%Y-%m-%d')
        }
    ]
    
    for food in test_foods:
        try:
            response = requests.post('http://localhost:5000/log/food', json=food)
            print(f"   {food['food_name']}: {response.status_code}")
        except Exception as e:
            print(f"   Error: {e}")
    
    # 2. Check food logs
    print(f"\n2. Checking food logs for {username}...")
    try:
        response = requests.get(f'http://localhost:5000/log/food?user={username}')
        if response.status_code == 200:
            data = response.json()
            logs = data.get('logs', [])
            totals = data.get('totals', {})
            print(f"   Food logs: {len(logs)} entries")
            print(f"   Total calories: {totals.get('calories', 0)}")
        else:
            print(f"   Error: {response.status_code}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # 3. Check progress calories
    print(f"\n3. Checking progress calories for {username}...")
    try:
        response = requests.get(f'http://localhost:5000/progress/calories?user={username}')
        if response.status_code == 200:
            data = response.json()
            print(f"   Progress calories: {len(data)} entries")
            if data:
                total_calories = sum(entry['calories'] for entry in data)
                print(f"   Total calories: {total_calories}")
        else:
            print(f"   Error: {response.status_code}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # 4. Check daily summary
    print(f"\n4. Checking daily summary for {username}...")
    try:
        response = requests.get(f'http://localhost:5000/progress/daily-summary?user={username}')
        if response.status_code == 200:
            data = response.json()
            calories = data.get('calories', {})
            print(f"   Daily summary:")
            print(f"     Current: {calories.get('current', 0)}")
            print(f"     Goal: {calories.get('goal', 0)}")
            print(f"     Percentage: {calories.get('percentage', 0):.1%}")
            print(f"     Remaining: {calories.get('remaining', 0)}")
            
            achievements = data.get('achievements', [])
            if achievements:
                print(f"   Achievements: {achievements}")
            else:
                print(f"   No achievements yet")
                
        else:
            print(f"   Error: {response.status_code}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    print(f"\n✅ Test completed for {username}")
    print("=" * 50)

if __name__ == "__main__":
    # Test with different usernames
    test_usernames = ['test_user', 'default', 'admin']
    
    for username in test_usernames:
        test_user_progress(username)
        print()

