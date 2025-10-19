#!/usr/bin/env python3
"""
Test script for calorie calculation API endpoints.
Tests the /calculate_daily_goal and /remaining endpoints.
"""

import requests
import json
import time

def test_calorie_calculation_api():
    """Test the calorie calculation API endpoints."""
    base_url = "http://localhost:5000"
    
    print("🧪 Testing Calorie Calculation API...")
    print("=" * 50)
    
    # Test cases for different user profiles
    test_cases = [
        {
            "name": "Male, 25, 70kg, 175cm, sedentary, maintain weight",
            "data": {
                "sex": "male",
                "age": 25,
                "weight_kg": 70.0,
                "height_cm": 175.0,
                "activity_level": "sedentary",
                "goal": "maintain weight"
            },
            "expected_range": (2200, 2500)
        },
        {
            "name": "Female, 30, 60kg, 165cm, active, lose weight",
            "data": {
                "sex": "female",
                "age": 30,
                "weight_kg": 60.0,
                "height_cm": 165.0,
                "activity_level": "active",
                "goal": "lose weight"
            },
            "expected_range": (1800, 2200)
        },
        {
            "name": "Male, 35, 80kg, 180cm, very active, gain muscle",
            "data": {
                "sex": "male",
                "age": 35,
                "weight_kg": 80.0,
                "height_cm": 180.0,
                "activity_level": "very active",
                "goal": "gain muscle"
            },
            "expected_range": (2800, 3200)
        },
        {
            "name": "Female, 22, 55kg, 160cm, lightly active, maintain weight",
            "data": {
                "sex": "female",
                "age": 22,
                "weight_kg": 55.0,
                "height_cm": 160.0,
                "activity_level": "lightly active",
                "goal": "maintain weight"
            },
            "expected_range": (1800, 2100)
        }
    ]
    
    # Test 1: Health check
    print("1. Testing health check...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            print("   ✅ API is running")
        else:
            print(f"   ❌ Health check failed: {response.status_code}")
            return
    except Exception as e:
        print(f"   ❌ Cannot connect to API: {e}")
        print("   💡 Make sure to start the server with: python app.py")
        return
    
    # Test 2: Daily calorie goal calculation
    print("\n2. Testing daily calorie goal calculation...")
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n   Test {i}: {test_case['name']}")
        try:
            response = requests.post(
                f"{base_url}/calculate/daily_goal",
                json=test_case['data'],
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                calories = result.get('daily_calorie_goal', 0)
                min_expected, max_expected = test_case['expected_range']
                
                print(f"   📊 Calculated: {calories} calories")
                print(f"   📈 Expected range: {min_expected}-{max_expected} calories")
                
                if min_expected <= calories <= max_expected:
                    print("   ✅ Result within expected range")
                else:
                    print("   ⚠️  Result outside expected range")
                
                # Show additional details if available
                if 'bmr' in result:
                    print(f"   🔥 BMR: {result['bmr']} calories")
                if 'tdee' in result:
                    print(f"   🏃 TDEE: {result['tdee']} calories")
                    
            else:
                print(f"   ❌ Request failed: {response.status_code}")
                print(f"   Error: {response.text}")
                
        except Exception as e:
            print(f"   ❌ Test failed: {e}")
    
    # Test 3: Edge cases
    print("\n3. Testing edge cases...")
    
    edge_cases = [
        {
            "name": "Very young user (18)",
            "data": {
                "sex": "male",
                "age": 18,
                "weight_kg": 65.0,
                "height_cm": 170.0,
                "activity_level": "active",
                "goal": "maintain weight"
            }
        },
        {
            "name": "Older user (65)",
            "data": {
                "sex": "female",
                "age": 65,
                "weight_kg": 70.0,
                "height_cm": 160.0,
                "activity_level": "sedentary",
                "goal": "maintain weight"
            }
        },
        {
            "name": "Light weight (45kg)",
            "data": {
                "sex": "female",
                "age": 25,
                "weight_kg": 45.0,
                "height_cm": 155.0,
                "activity_level": "lightly active",
                "goal": "maintain weight"
            }
        },
        {
            "name": "Heavy weight (120kg)",
            "data": {
                "sex": "male",
                "age": 30,
                "weight_kg": 120.0,
                "height_cm": 185.0,
                "activity_level": "active",
                "goal": "lose weight"
            }
        }
    ]
    
    for i, test_case in enumerate(edge_cases, 1):
        print(f"\n   Edge case {i}: {test_case['name']}")
        try:
            response = requests.post(
                f"{base_url}/calculate/daily_goal",
                json=test_case['data'],
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                calories = result.get('daily_calorie_goal', 0)
                print(f"   📊 Calculated: {calories} calories")
                
                if calories > 0:
                    print("   ✅ Valid positive result")
                else:
                    print("   ❌ Invalid result (zero or negative)")
                    
            else:
                print(f"   ❌ Request failed: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Test failed: {e}")
    
    # Test 4: Invalid inputs
    print("\n4. Testing invalid inputs...")
    
    invalid_cases = [
        {
            "name": "Missing required field (no age)",
            "data": {
                "sex": "male",
                "weight_kg": 70.0,
                "height_cm": 175.0,
                "activity_level": "active",
                "goal": "maintain weight"
            }
        },
        {
            "name": "Invalid weight (negative)",
            "data": {
                "sex": "male",
                "age": 25,
                "weight_kg": -70.0,
                "height_cm": 175.0,
                "activity_level": "active",
                "goal": "maintain weight"
            }
        },
        {
            "name": "Invalid age (too young)",
            "data": {
                "sex": "male",
                "age": 10,
                "weight_kg": 70.0,
                "height_cm": 175.0,
                "activity_level": "active",
                "goal": "maintain weight"
            }
        }
    ]
    
    for i, test_case in enumerate(invalid_cases, 1):
        print(f"\n   Invalid case {i}: {test_case['name']}")
        try:
            response = requests.post(
                f"{base_url}/calculate/daily_goal",
                json=test_case['data'],
                timeout=10
            )
            
            if response.status_code == 400:
                print("   ✅ Correctly rejected invalid input")
            elif response.status_code == 200:
                print("   ⚠️  Accepted invalid input (should be rejected)")
            else:
                print(f"   ❓ Unexpected status: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Test failed: {e}")
    
    print("\n" + "=" * 50)
    print("🎉 Calorie calculation API testing completed!")

def test_remaining_calories_api():
    """Test the remaining calories endpoint."""
    base_url = "http://localhost:5000"
    
    print("\n🧪 Testing Remaining Calories API...")
    print("=" * 50)
    
    # Test cases for remaining calories
    test_cases = [
        {
            "name": "User with no logged food",
            "username": "test_user_1",
            "expected_behavior": "Should return full daily goal"
        },
        {
            "name": "User with some logged food",
            "username": "test_user_2", 
            "expected_behavior": "Should return remaining calories"
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{i}. {test_case['name']}")
        try:
            response = requests.get(
                f"{base_url}/remaining?username={test_case['username']}",
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                remaining = result.get('remaining_calories', 0)
                daily_goal = result.get('daily_goal', 0)
                consumed = result.get('consumed_calories', 0)
                
                print(f"   📊 Daily goal: {daily_goal} calories")
                print(f"   🍽️  Consumed: {consumed} calories")
                print(f"   ⚖️  Remaining: {remaining} calories")
                
                if remaining >= 0:
                    print("   ✅ Valid remaining calories")
                else:
                    print("   ❌ Invalid remaining calories (negative)")
                    
            elif response.status_code == 404:
                print("   ℹ️  User not found (expected for test users)")
            else:
                print(f"   ❌ Request failed: {response.status_code}")
                print(f"   Error: {response.text}")
                
        except Exception as e:
            print(f"   ❌ Test failed: {e}")
    
    print("\n" + "=" * 50)
    print("🎉 Remaining calories API testing completed!")

if __name__ == "__main__":
    test_calorie_calculation_api()
    test_remaining_calories_api()
