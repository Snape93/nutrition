#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test script for forgot password functionality
Tests both email verification and password reset endpoints
"""
import requests
import json
import sys
import os
from datetime import datetime

# Fix Windows console encoding for emoji characters
if sys.platform == 'win32':
    os.system('chcp 65001 >nul 2>&1')

# Configuration
API_BASE = "http://192.168.1.5:5000"
TEST_EMAIL = "Markdle42@gmail.com"
TEST_NEW_PASSWORD = "TestPassword123!"

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60)

def test_email_check(email):
    """Test the /auth/check-email endpoint"""
    print_section("TEST 1: Email Verification")
    print(f"Testing email: {email}")
    print(f"Endpoint: {API_BASE}/auth/check-email")
    
    try:
        response = requests.get(
            f"{API_BASE}/auth/check-email",
            params={"email": email},
            timeout=10
        )
        
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response Body: {json.dumps(data, indent=2)}")
            
            if data.get('exists') == True:
                print("\n[SUCCESS] Email exists in database")
                return True
            else:
                print("\n[FAILED] Email does not exist in database")
                return False
        else:
            print(f"\n[FAILED] Unexpected status code")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"\n[ERROR] Cannot connect to {API_BASE}")
        print("   Make sure the Flask server is running")
        return None
    except requests.exceptions.Timeout:
        print(f"\n[ERROR] Request timed out")
        return None
    except Exception as e:
        print(f"\n[ERROR] {type(e).__name__}: {e}")
        return None

def test_reset_password(email, new_password):
    """Test the /auth/reset-password endpoint"""
    print_section("TEST 2: Password Reset")
    print(f"Testing email: {email}")
    print(f"New password: {new_password}")
    print(f"Endpoint: {API_BASE}/auth/reset-password")
    
    try:
        payload = {
            "email": email,
            "new_password": new_password
        }
        
        print(f"\nRequest Payload: {json.dumps(payload, indent=2)}")
        
        response = requests.post(
            f"{API_BASE}/auth/reset-password",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response Body: {json.dumps(data, indent=2)}")
            
            if data.get('success') == True:
                print("\n[SUCCESS] Password reset successful")
                return True
            else:
                print(f"\n[FAILED] {data.get('message', 'Unknown error')}")
                return False
        else:
            print(f"\n[FAILED] Unexpected status code")
            try:
                error_data = response.json()
                print(f"Response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"\n[ERROR] Cannot connect to {API_BASE}")
        print("   Make sure the Flask server is running")
        return None
    except requests.exceptions.Timeout:
        print(f"\n[ERROR] Request timed out")
        return None
    except Exception as e:
        print(f"\n[ERROR] {type(e).__name__}: {e}")
        return None

def test_invalid_email():
    """Test with a non-existent email"""
    print_section("TEST 3: Invalid Email Check")
    invalid_email = "nonexistent@example.com"
    print(f"Testing email: {invalid_email}")
    
    try:
        response = requests.get(
            f"{API_BASE}/auth/check-email",
            params={"email": invalid_email},
            timeout=10
        )
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response Body: {json.dumps(data, indent=2)}")
            
            if data.get('exists') == False:
                print("\n[SUCCESS] Correctly identified non-existent email")
                return True
            else:
                print("\n[FAILED] Should return exists=False for invalid email")
                return False
        else:
            print(f"\n[FAILED] Unexpected status code")
            return False
            
    except Exception as e:
        print(f"\n[ERROR] {type(e).__name__}: {e}")
        return None

def test_weak_password(email):
    """Test password reset with weak password (should fail)"""
    print_section("TEST 4: Weak Password Validation")
    weak_password = "123"  # Too short
    print(f"Testing with weak password: {weak_password}")
    
    try:
        payload = {
            "email": email,
            "new_password": weak_password
        }
        
        response = requests.post(
            f"{API_BASE}/auth/reset-password",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 400:
            data = response.json()
            print(f"Response Body: {json.dumps(data, indent=2)}")
            print("\n[SUCCESS] Correctly rejected weak password")
            return True
        else:
            print(f"\n[FAILED] Should reject weak password with 400 status")
            return False
            
    except Exception as e:
        print(f"\n[ERROR] {type(e).__name__}: {e}")
        return None

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("  FORGOT PASSWORD FUNCTIONALITY TEST")
    print("="*60)
    print(f"API Base URL: {API_BASE}")
    print(f"Test Email: {TEST_EMAIL}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    results = {}
    
    # Test 1: Check if email exists
    results['email_check'] = test_email_check(TEST_EMAIL)
    
    # Test 2: Reset password (only if email exists)
    if results['email_check'] == True:
        results['password_reset'] = test_reset_password(TEST_EMAIL, TEST_NEW_PASSWORD)
    else:
        print("\n[SKIP] Skipping password reset test (email check failed)")
        results['password_reset'] = None
    
    # Test 3: Invalid email check
    results['invalid_email'] = test_invalid_email()
    
    # Test 4: Weak password validation
    if results['email_check'] == True:
        results['weak_password'] = test_weak_password(TEST_EMAIL)
    else:
        print("\n[SKIP] Skipping weak password test (email check failed)")
        results['weak_password'] = None
    
    # Summary
    print_section("TEST SUMMARY")
    for test_name, result in results.items():
        status = "[PASS]" if result == True else "[FAIL]" if result == False else "[SKIP]"
        print(f"{test_name:20s}: {status}")
    
    # Overall result
    passed = sum(1 for r in results.values() if r == True)
    total = sum(1 for r in results.values() if r is not None)
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total and total > 0:
        print("\n[SUCCESS] All tests passed!")
        return 0
    else:
        print("\n[WARNING] Some tests failed or were skipped")
        return 1

if __name__ == "__main__":
    sys.exit(main())

