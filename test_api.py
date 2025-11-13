import requests
import json
import time

def test_food_search():
    base_url = "http://localhost:5000"
    
    print("Testing Food Search API...")
    
    # Test 1: Health check
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"✅ Health check: {response.status_code}")
        if response.status_code == 200:
            print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return
    
    # Test 2: Filipino food search
    try:
        response = requests.get(f"{base_url}/foods/search?query=adobo", timeout=10)
        print(f"\n✅ Filipino food search: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            foods = data.get('foods', [])
            print(f"   Found {len(foods)} Filipino foods for 'adobo'")
            for i, food in enumerate(foods[:3]):
                print(f"   {i+1}. {food.get('Food Name', 'Unknown')} ({food.get('Calories', 0)} cal)")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"❌ Filipino food search failed: {e}")
    
    # Test 3: International food search (should use Open Food Facts)
    try:
        response = requests.get(f"{base_url}/foods/search?query=chocolate", timeout=10)
        print(f"\n✅ International food search: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            foods = data.get('foods', [])
            print(f"   Found {len(foods)} foods for 'chocolate'")
            for i, food in enumerate(foods[:3]):
                source = food.get('Source', 'Local')
                print(f"   {i+1}. {food.get('Food Name', 'Unknown')} ({food.get('Calories', 0)} cal) [{source}]")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"❌ International food search failed: {e}")
    
    # Test 4: Food logging
    try:
        log_data = {
            "user": "test_user",
            "food_name": "Chicken Adobo",
            "calories": 250,
            "meal_type": "Lunch"
        }
        response = requests.post(f"{base_url}/log/food", json=log_data, timeout=10)
        print(f"\n✅ Food logging: {response.status_code}")
        if response.status_code == 200:
            print("   Food logged successfully!")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"❌ Food logging failed: {e}")

if __name__ == "__main__":
    test_food_search() 