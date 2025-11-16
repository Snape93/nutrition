"""
Test script for Goal History Tracking Feature
Tests the complete flow: logging, retrieval, and API endpoints
"""

import requests
import json
from datetime import date, datetime, timedelta
import sys

# Configuration - Update these with your actual API base URL
API_BASE = "http://localhost:5000"  # Change to your API URL
TEST_USERNAME = "dle"  # Change to an existing test user (options: dle, CJ, Jay, Markdle10, christian, curry, goku, jayjay, jayron, joemari)

def print_test(name):
    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print(f"{'='*60}")

def print_success(message):
    print(f"✅ {message}")

def print_error(message):
    print(f"❌ {message}")

def print_info(message):
    print(f"ℹ️  {message}")

def test_get_current_goal():
    """Test 1: Get current goal for a user"""
    print_test("Get Current Goal")
    
    try:
        response = requests.get(
            f"{API_BASE}/progress/goals",
            params={"user": TEST_USERNAME}
        )
        
        if response.status_code == 200:
            data = response.json()
            current_goal = data.get('calories')
            print_success(f"Current goal retrieved: {current_goal} calories")
            return current_goal
        else:
            print_error(f"Failed to get current goal: {response.status_code}")
            print_error(response.text)
            return None
    except Exception as e:
        print_error(f"Error: {e}")
        return None

def test_get_historical_goal():
    """Test 2: Get historical goal for a specific date"""
    print_test("Get Historical Goal for Specific Date")
    
    # Test with today's date
    today = date.today().isoformat()
    
    try:
        response = requests.get(
            f"{API_BASE}/progress/goals",
            params={"user": TEST_USERNAME, "date": today}
        )
        
        if response.status_code == 200:
            data = response.json()
            historical_goal = data.get('calories')
            print_success(f"Historical goal for {today}: {historical_goal} calories")
            return historical_goal
        else:
            print_error(f"Failed to get historical goal: {response.status_code}")
            print_error(response.text)
            return None
    except Exception as e:
        print_error(f"Error: {e}")
        return None

def test_get_old_date_goal():
    """Test 3: Get goal for an old date (should return most recent goal on or before that date)"""
    print_test("Get Goal for Old Date")
    
    # Test with a date 30 days ago
    old_date = (date.today() - timedelta(days=30)).isoformat()
    
    try:
        response = requests.get(
            f"{API_BASE}/progress/goals",
            params={"user": TEST_USERNAME, "date": old_date}
        )
        
        if response.status_code == 200:
            data = response.json()
            old_goal = data.get('calories')
            print_success(f"Goal for {old_date}: {old_goal} calories")
            print_info("This should return the most recent goal on or before that date")
            return old_goal
        else:
            print_error(f"Failed to get old date goal: {response.status_code}")
            print_error(response.text)
            return None
    except Exception as e:
        print_error(f"Error: {e}")
        return None

def test_update_user_profile():
    """Test 4: Update user profile to trigger goal logging"""
    print_test("Update User Profile (Trigger Goal Logging)")
    
    # Get current weight first
    try:
        user_response = requests.get(f"{API_BASE}/user/{TEST_USERNAME}")
        if user_response.status_code != 200:
            print_error(f"Failed to get user data: {user_response.status_code}")
            return False
        
        user_data = user_response.json().get('user', {})
        current_weight = user_data.get('weight_kg', 70)
        new_weight = current_weight + 1  # Increase weight by 1kg to trigger goal recalculation
        
        print_info(f"Current weight: {current_weight} kg")
        print_info(f"Updating to: {new_weight} kg (this should trigger goal logging)")
        
        # Update user profile
        update_data = {
            "weight_kg": new_weight
        }
        
        response = requests.put(
            f"{API_BASE}/user/{TEST_USERNAME}",
            json=update_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            new_goal = result.get('daily_calorie_goal')
            print_success(f"Profile updated successfully")
            print_success(f"New goal calculated: {new_goal} calories")
            print_info("A new entry should have been logged to goal_history table")
            return True, new_goal
        else:
            print_error(f"Failed to update profile: {response.status_code}")
            print_error(response.text)
            return False, None
    except Exception as e:
        print_error(f"Error: {e}")
        return False, None

def test_verify_goal_logged():
    """Test 5: Verify that goal was logged to goal_history"""
    print_test("Verify Goal Was Logged to Database")
    
    today = date.today().isoformat()
    
    try:
        # Get goal for today - should match the newly calculated goal
        response = requests.get(
            f"{API_BASE}/progress/goals",
            params={"user": TEST_USERNAME, "date": today}
        )
        
        if response.status_code == 200:
            data = response.json()
            logged_goal = data.get('calories')
            print_success(f"Goal retrieved from history: {logged_goal} calories")
            print_info("If this matches the new goal from Test 4, the logging worked!")
            return logged_goal
        else:
            print_error(f"Failed to verify logged goal: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Error: {e}")
        return None

def test_multiple_date_goals():
    """Test 6: Test goal retrieval for multiple dates"""
    print_test("Test Goal Retrieval for Multiple Dates")
    
    dates_to_test = [
        date.today().isoformat(),
        (date.today() - timedelta(days=1)).isoformat(),
        (date.today() - timedelta(days=7)).isoformat(),
        (date.today() - timedelta(days=30)).isoformat(),
    ]
    
    results = {}
    for test_date in dates_to_test:
        try:
            response = requests.get(
                f"{API_BASE}/progress/goals",
                params={"user": TEST_USERNAME, "date": test_date}
            )
            
            if response.status_code == 200:
                data = response.json()
                goal = data.get('calories')
                results[test_date] = goal
                print_info(f"  {test_date}: {goal} calories")
            else:
                print_error(f"  {test_date}: Failed ({response.status_code})")
                results[test_date] = None
        except Exception as e:
            print_error(f"  {test_date}: Error - {e}")
            results[test_date] = None
    
    print_success("Multiple date test completed")
    return results

def main():
    print("\n" + "="*60)
    print("GOAL HISTORY TRACKING - COMPREHENSIVE TEST SUITE")
    print("="*60)
    print(f"\nTesting with user: {TEST_USERNAME}")
    print(f"API Base URL: {API_BASE}")
    print("\n⚠️  Make sure your backend server is running!")
    print("⚠️  Update TEST_USERNAME and API_BASE if needed")
    
    input("\nPress Enter to start testing...")
    
    # Run tests
    current_goal = test_get_current_goal()
    
    if current_goal:
        historical_goal = test_get_historical_goal()
        old_goal = test_get_old_date_goal()
        
        # Test profile update (this should trigger goal logging)
        update_result = test_update_user_profile()
        
        if update_result[0]:
            new_goal = update_result[1]
            logged_goal = test_verify_goal_logged()
            
            if logged_goal and new_goal:
                if logged_goal == new_goal:
                    print_success("\n🎉 Goal logging is working correctly!")
                else:
                    print_error(f"\n⚠️  Goal mismatch: Expected {new_goal}, got {logged_goal}")
        
        # Test multiple dates
        test_multiple_date_goals()
    
    print("\n" + "="*60)
    print("TEST SUITE COMPLETED")
    print("="*60)
    print("\nNext steps:")
    print("1. Check the goal_history table in your database")
    print("2. Verify entries were created with correct dates and goals")
    print("3. Test the frontend trackback feature with an old date")

if __name__ == "__main__":
    main()

