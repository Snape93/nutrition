import requests
import json

def test_food_search():
    base_url = "http://localhost:5000"
    
    # Test 1: Filipino food search
    print("=== Testing Filipino Food Search ===")
    response = requests.get(f"{base_url}/foods/search?query=adobo")
    if response.status_code == 200:
        data = response.json()
        print(f"Found {len(data.get('foods', []))} Filipino foods for 'adobo'")
        for food in data.get('foods', [])[:3]:  # Show first 3
            print(f"  - {food.get('Food Name', 'Unknown')} ({food.get('Calories', 0)} cal)")
    else:
        print(f"Error: {response.status_code}")
    
    print("\n=== Testing International Food Search ===")
    # Test 2: International food search (should use Open Food Facts)
    response = requests.get(f"{base_url}/foods/search?query=chocolate")
    if response.status_code == 200:
        data = response.json()
        print(f"Found {len(data.get('foods', []))} foods for 'chocolate'")
        for food in data.get('foods', [])[:3]:  # Show first 3
            source = food.get('Source', 'Local')
            print(f"  - {food.get('Food Name', 'Unknown')} ({food.get('Calories', 0)} cal) [{source}]")
    else:
        print(f"Error: {response.status_code}")
    
    print("\n=== Testing Food Logging ===")
    # Test 3: Log a food item
    log_data = {
        "user": "test_user",
        "food_name": "Chicken Adobo",
        "calories": 250,
        "meal_type": "Lunch"
    }
    response = requests.post(f"{base_url}/log/food", json=log_data)
    if response.status_code == 200:
        print("✅ Food logged successfully")
    else:
        print(f"❌ Food logging failed: {response.status_code}")
    
    # Test 4: Get food logs
    response = requests.get(f"{base_url}/log/food?user=test_user")
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Retrieved {len(data.get('logs', []))} food logs")
    else:
        print(f"❌ Failed to get food logs: {response.status_code}")

if __name__ == "__main__":
    test_food_search() 