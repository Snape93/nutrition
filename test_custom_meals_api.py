#!/usr/bin/env python3
"""
Test script for Custom Meals API endpoints
"""
import requests
import json
import time

def test_custom_meals_api():
    base_url = "http://localhost:5000"
    
    print("=== Testing Custom Meals API ===")
    
    # Test 1: Health check
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"[SUCCESS] Health check: {response.status_code}")
    except Exception as e:
        print(f"[ERROR] Health check failed: {e}")
        return
    
    # Test 2: Log a custom meal
    test_user = "test_user_custom_meals"
    meal_data = {
        "user": test_user,
        "meal_name": "Mom's Homemade Burger",
        "calories": 450.0,
        "carbs": 30.0,
        "fat": 20.0,
        "description": "Homemade with love",
        "meal_type": "Lunch",
        "date": "2024-01-15"
    }
    
    try:
        response = requests.post(f"{base_url}/log/custom-meal", json=meal_data, timeout=10)
        print(f"\n[SUCCESS] Custom meal logging: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Custom meal logged successfully! ID: {result.get('id')}")
        else:
            print(f"   Error: {response.text}")
            return
    except Exception as e:
        print(f"[ERROR] Custom meal logging failed: {e}")
        return
    
    # Test 3: Get custom meals
    try:
        response = requests.get(f"{base_url}/custom-meals?user={test_user}", timeout=10)
        print(f"\n[SUCCESS] Get custom meals: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            meals = result.get('custom_meals', [])
            print(f"   Found {len(meals)} custom meals")
            for meal in meals:
                print(f"   - {meal['name']}: {meal['calories']} cal")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"[ERROR] Get custom meals failed: {e}")
    
    # Test 4: Log another custom meal
    meal_data2 = {
        "user": test_user,
        "meal_name": "Grandma's Fish Ball Soup",
        "calories": 200.0,
        "carbs": 15.0,
        "fat": 8.0,
        "description": "Traditional Filipino soup",
        "meal_type": "Dinner"
    }
    
    try:
        response = requests.post(f"{base_url}/log/custom-meal", json=meal_data2, timeout=10)
        print(f"\n[SUCCESS] Second custom meal logging: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Second custom meal logged! ID: {result.get('id')}")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"[ERROR] Second custom meal logging failed: {e}")
    
    # Test 5: Get updated custom meals list
    try:
        response = requests.get(f"{base_url}/custom-meals?user={test_user}", timeout=10)
        print(f"\n[SUCCESS] Updated custom meals list: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            meals = result.get('custom_meals', [])
            print(f"   Now found {len(meals)} custom meals")
            for meal in meals:
                print(f"   - {meal['name']}: {meal['calories']} cal, {meal['carbs']}g carbs, {meal['fat']}g fat")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"[ERROR] Updated custom meals list failed: {e}")
    
    print("\n=== Custom Meals API Test Complete ===")

if __name__ == "__main__":
    test_custom_meals_api()













