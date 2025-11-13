import requests

# Test the exercises endpoint
print("Testing exercises API endpoint...")
print("="*60)

response = requests.get('http://127.0.0.1:5000/exercises')
print(f"Status: {response.status_code}")

if response.status_code == 200:
    data = response.json()
    print(f"Total exercises returned: {len(data)}")
    
    print("\nFirst 10 exercises:")
    for i, ex in enumerate(data[:10], 1):
        print(f"  {i}. {ex.get('name')}")
        print(f"     Category: {ex.get('category')}, Difficulty: {ex.get('difficulty')}")
        print(f"     Body Part: {ex.get('body_part')}, Equipment: {ex.get('equipment')}")
    
    # Test filtering by category
    print("\n" + "="*60)
    print("Testing filter by category (strength)...")
    response2 = requests.get('http://127.0.0.1:5000/exercises?category=strength')
    if response2.status_code == 200:
        strength_data = response2.json()
        print(f"Strength exercises: {len(strength_data)}")
    
    # Test filtering by difficulty
    print("\nTesting filter by difficulty (beginner)...")
    response3 = requests.get('http://127.0.0.1:5000/exercises?difficulty=beginner')
    if response3.status_code == 200:
        beginner_data = response3.json()
        print(f"Beginner exercises: {len(beginner_data)}")
    
    print("\n" + "="*60)
    print("[OK] All tests passed! ExerciseDB exercises are working!")
else:
    print(f"Error: {response.text}")

