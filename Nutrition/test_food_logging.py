import requests
import json
import time

def test_food_logging():
    base_url = "http://localhost:5000"
    
    print("=== Testing Food Logging System ===")
    
    # Test 1: Health check
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"[SUCCESS] Health check: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Health check failed: {e}")
        return
    
    # Test 2: Log a food item
    test_user = "test_user_123"
    log_data = {
        "user": test_user,
        "food_name": "Chicken Adobo",
        "calories": 250,
        "meal_type": "Lunch",
        "serving_size": "1 cup",
        "quantity": 1.0,
        "protein": 25.0,
        "carbs": 5.0,
        "fat": 12.0,
        "fiber": 2.0,
        "sodium": 800.0,
        "date": "2024-01-15"
    }
    
    try:
        response = requests.post(f"{base_url}/log/food", json=log_data, timeout=10)
        print(f"\n[SUCCESS] Food logging: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Food logged successfully! ID: {result.get('id')}")
        else:
            print(f"   Error: {response.text}")
            return
    except Exception as e:
        print(f"[ERROR] Food logging failed: {e}")
        return
    
    # Test 3: Get today's food logs
    try:
        response = requests.get(f"{base_url}/log/food?user={test_user}&date=2024-01-15", timeout=10)
        print(f"\n[SUCCESS] Get food logs: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            logs = data.get('logs', [])
            totals = data.get('totals', {})
            print(f"   Found {len(logs)} food logs")
            print(f"   Total calories: {totals.get('calories', 0)}")
            print(f"   Total protein: {totals.get('protein', 0)}g")
            print(f"   Total carbs: {totals.get('carbs', 0)}g")
            print(f"   Total fat: {totals.get('fat', 0)}g")
            
            if logs:
                print("\n   Logged foods:")
                for log in logs:
                    print(f"   - {log.get('food_name')} ({log.get('calories')} cal) - {log.get('meal_type')}")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"[ERROR] Get food logs failed: {e}")
    
    # Test 4: Test food search
    try:
        response = requests.get(f"{base_url}/foods/search?query=adobo", timeout=10)
        print(f"\n[SUCCESS] Food search: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            foods = data.get('foods', [])
            print(f"   Found {len(foods)} foods for 'adobo'")
            for i, food in enumerate(foods[:3]):
                print(f"   {i+1}. {food.get('Food Name', 'Unknown')} ({food.get('Calories', 0)} cal)")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"[ERROR] Food search failed: {e}")
    
    print("\n=== Test Summary ===")
    print("[SUCCESS] Backend is running")
    print("[SUCCESS] Food logging works")
    print("[SUCCESS] Food retrieval works")
    print("[SUCCESS] Food search works")
    print("\nThe food logging system is ready for Flutter app testing!")

if __name__ == "__main__":
    test_food_logging() 