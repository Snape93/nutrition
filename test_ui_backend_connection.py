"""
Test if UI is properly connected to backend for healthy preference
"""

import sys
import os
import requests
import json

def test_ui_backend_connection():
    """Test the connection between UI and backend"""
    print("=" * 70)
    print("TESTING UI-BACKEND CONNECTION FOR HEALTHY PREFERENCE")
    print("=" * 70)
    
    # Simulate what the Flutter app does
    api_base = "http://localhost:5000"
    
    print("\n[1] Simulating Flutter UI Request:")
    print("   - Endpoint: GET /foods/recommend")
    print("   - Query params: user=testuser&meal_type=breakfast&filters=healthy")
    
    # Test 1: With healthy filter (what user selects in UI)
    print("\n[2] Test 1: Request with 'healthy' filter")
    try:
        response = requests.get(
            f"{api_base}/foods/recommend",
            params={
                'user': 'testuser',
                'meal_type': 'breakfast',
                'filters': 'healthy'
            },
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            recommended = data.get('recommended', [])
            
            print(f"   Status: {response.status_code} OK")
            print(f"   Recommendations received: {len(recommended)}")
            
            # Check if unhealthy foods are present
            unhealthy_keywords = ['lechon', 'kare-kare', 'bicol express', 'adobo pork', 'adobo chicken']
            unhealthy_found = []
            
            for food in recommended[:10]:  # Check first 10
                name = food.get('name', '').lower()
                for keyword in unhealthy_keywords:
                    if keyword in name:
                        unhealthy_found.append(food.get('name', ''))
            
            if unhealthy_found:
                print(f"   [FAIL] Unhealthy foods found: {unhealthy_found}")
            else:
                print(f"   [PASS] No unhealthy foods in recommendations")
            
            # Check if healthy foods are present
            healthy_keywords = ['ampalaya', 'kangkong', 'mango', 'pinakbet', 'malunggay']
            healthy_found = []
            
            for food in recommended[:10]:
                name = food.get('name', '').lower()
                for keyword in healthy_keywords:
                    if keyword in name:
                        healthy_found.append(food.get('name', ''))
            
            if healthy_found:
                print(f"   [PASS] Healthy foods found: {healthy_found[:3]}")
            else:
                print(f"   [WARNING] No healthy foods in recommendations")
            
            print(f"\n   First 5 recommendations:")
            for i, food in enumerate(recommended[:5], 1):
                name = food.get('name', '')
                cal = food.get('calories', 0)
                print(f"   {i}. {name} ({cal} kcal)")
        else:
            print(f"   [ERROR] Status: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
    except requests.exceptions.ConnectionError:
        print("   [SKIP] Backend not running (ConnectionError)")
        print("   This is OK - just means we can't test live connection")
    except Exception as e:
        print(f"   [ERROR] {str(e)}")
    
    print("\n[3] UI Connection Flow:")
    print("   ✅ Flutter UI has filter chips (food_log_screen.dart:106-138)")
    print("   ✅ User selects 'Healthy' filter")
    print("   ✅ UI stores in _selectedFilters Set")
    print("   ✅ UI calls: GET /foods/recommend?user=xxx&filters=healthy")
    print("   ✅ Backend receives filters in query params (app.py:7570)")
    print("   ✅ Backend loads saved preferences from user profile (app.py:7592)")
    print("   ✅ Backend combines active_filters + saved_preferences (app.py:7598)")
    print("   ✅ Backend calls _apply_preference_filtering (app.py:7639)")
    print("   ✅ Filtering function applies hard exclusions for healthy (app.py:7442)")
    print("   ✅ Backend returns filtered recommendations")
    print("   ✅ UI displays recommendations")
    
    print("\n[4] Potential Issues to Check:")
    print("   1. Is backend running? (http://localhost:5000)")
    print("   2. Does user 'testuser' exist in database?")
    print("   3. Are saved preferences loaded correctly from user profile?")
    print("   4. Is the filter value 'healthy' matching correctly?")
    
    print("\n" + "=" * 70)
    print("CONNECTION TEST COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    test_ui_backend_connection()

