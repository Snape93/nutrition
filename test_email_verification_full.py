"""
Comprehensive test script for email verification system
Tests the complete flow: registration -> email -> verification -> login
"""
import requests
import json
import time
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
BASE_URL = os.environ.get('API_BASE_URL', 'http://127.0.0.1:5000')
TEST_EMAIL = os.environ.get('TEST_EMAIL', 'markdle42@gmail.com')  # Change this to test email

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def print_result(test_name, success, message=""):
    """Print test result"""
    status = "[PASS]" if success else "[FAIL]"
    print(f"{status} - {test_name}")
    if message:
        print(f"      {message}")

def test_connection():
    """Test 1: Check if backend is accessible"""
    print_section("Test 1: Backend Connection")
    try:
        response = requests.get(f"{BASE_URL}/auth/ping", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_result("Backend is accessible", True, f"Response: {data}")
            return True
        else:
            print_result("Backend is accessible", False, f"Status: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print_result("Backend is accessible", False, "Cannot connect to backend. Is Flask server running?")
        return False
    except Exception as e:
        print_result("Backend is accessible", False, f"Error: {e}")
        return False

def test_registration():
    """Test 2: Register a new user"""
    print_section("Test 2: User Registration")
    
    # Generate unique username and email
    timestamp = int(time.time())
    test_username = f"testuser_{timestamp}"
    test_email = f"test_{timestamp}@example.com"
    
    try:
        payload = {
            "username": test_username,
            "email": test_email,
            "password": "TestPassword123!",
            "full_name": "Test User"
        }
        
        response = requests.post(
            f"{BASE_URL}/register",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            data = response.json()
            if data.get('success') and data.get('verification_required'):
                print_result("User registration", True, f"User: {test_username}, Email: {test_email}")
                print(f"      Response: {json.dumps(data, indent=2)}")
                return True, test_username, test_email
            else:
                print_result("User registration", False, f"Missing verification_required flag")
                print(f"      Response: {json.dumps(data, indent=2)}")
                return False, None, None
        else:
            print_result("User registration", False, f"Status: {response.status_code}")
            print(f"      Response: {response.text}")
            return False, None, None
    except Exception as e:
        print_result("User registration", False, f"Error: {e}")
        return False, None, None

def test_email_config():
    """Test 3: Check if email configuration is set"""
    print_section("Test 3: Email Configuration")
    
    gmail_username = os.environ.get('GMAIL_USERNAME')
    gmail_password = os.environ.get('GMAIL_APP_PASSWORD')
    
    has_username = bool(gmail_username)
    has_password = bool(gmail_password)
    
    print_result("GMAIL_USERNAME configured", has_username, 
                 f"Value: {gmail_username if has_username else 'NOT SET'}")
    print_result("GMAIL_APP_PASSWORD configured", has_password,
                 f"Value: {'*' * 16 if has_password else 'NOT SET'}")
    
    return has_username and has_password

def test_verify_code_invalid():
    """Test 4: Try to verify with invalid code"""
    print_section("Test 4: Invalid Verification Code")
    
    # First register a user
    success, username, email = test_registration()
    if not success:
        print_result("Invalid code test", False, "Could not register test user")
        return False
    
    try:
        payload = {
            "email": email,
            "code": "000000"  # Invalid code
        }
        
        response = requests.post(
            f"{BASE_URL}/auth/verify-code",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 400:
            data = response.json()
            if 'Invalid verification code' in data.get('error', ''):
                print_result("Invalid code rejection", True, "Correctly rejected invalid code")
                return True
            else:
                print_result("Invalid code rejection", False, f"Unexpected error: {data.get('error')}")
                return False
        else:
            print_result("Invalid code rejection", False, f"Expected 400, got {response.status_code}")
            return False
    except Exception as e:
        print_result("Invalid code test", False, f"Error: {e}")
        return False

def test_resend_code():
    """Test 5: Resend verification code"""
    print_section("Test 5: Resend Verification Code")
    
    # First register a user
    success, username, email = test_registration()
    if not success:
        print_result("Resend code test", False, "Could not register test user")
        return False
    
    try:
        payload = {
            "email": email
        }
        
        response = requests.post(
            f"{BASE_URL}/auth/resend-code",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print_result("Resend code", True, f"Code resent to {email}")
                print(f"      Note: Check email inbox for verification code")
                return True
            else:
                print_result("Resend code", False, "Response not successful")
                return False
        else:
            print_result("Resend code", False, f"Status: {response.status_code}, Response: {response.text}")
            return False
    except Exception as e:
        print_result("Resend code test", False, f"Error: {e}")
        return False

def test_login_unverified():
    """Test 6: Try to login with unverified email"""
    print_section("Test 6: Login with Unverified Email")
    
    # First register a user
    success, username, email = test_registration()
    if not success:
        print_result("Unverified login test", False, "Could not register test user")
        return False
    
    try:
        payload = {
            "username_or_email": username,
            "password": "TestPassword123!"
        }
        
        response = requests.post(
            f"{BASE_URL}/login",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 403:
            data = response.json()
            if data.get('email_verification_required'):
                print_result("Unverified login blocked", True, "Correctly blocked unverified user")
                print(f"      Message: {data.get('message')}")
                return True
            else:
                print_result("Unverified login blocked", False, "Missing email_verification_required flag")
                return False
        else:
            print_result("Unverified login blocked", False, 
                        f"Expected 403, got {response.status_code}. Response: {response.text}")
            return False
    except Exception as e:
        print_result("Unverified login test", False, f"Error: {e}")
        return False

def test_verify_code_manual():
    """Test 7: Manual verification code entry (requires user input)"""
    print_section("Test 7: Manual Verification (Requires Email Check)")
    
    # First register a user
    success, username, email = test_registration()
    if not success:
        print_result("Manual verification test", False, "Could not register test user")
        return False
    
    print(f"\n      [EMAIL] A verification code has been sent to: {email}")
    print(f"      [USER] Username: {username}")
    print(f"      [WAIT] Please check your email and enter the 6-digit code below")
    
    code = input("      Enter verification code: ").strip()
    
    if not code or len(code) != 6:
        print_result("Manual verification", False, "Invalid code format")
        return False
    
    try:
        payload = {
            "email": email,
            "code": code
        }
        
        response = requests.post(
            f"{BASE_URL}/auth/verify-code",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print_result("Manual verification", True, "Email verified successfully!")
                return True, username, email
            else:
                print_result("Manual verification", False, f"Response: {data}")
                return False, None, None
        else:
            data = response.json()
            print_result("Manual verification", False, f"Status: {response.status_code}, Error: {data.get('error')}")
            return False, None, None
    except Exception as e:
        print_result("Manual verification", False, f"Error: {e}")
        return False, None, None

def test_login_verified(username, password="TestPassword123!"):
    """Test 8: Login after verification"""
    print_section("Test 8: Login After Verification")
    
    if not username:
        print_result("Verified login test", False, "No verified username provided")
        return False
    
    try:
        payload = {
            "username_or_email": username,
            "password": password
        }
        
        response = requests.post(
            f"{BASE_URL}/login",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print_result("Verified login", True, f"Successfully logged in as {username}")
                return True
            else:
                print_result("Verified login", False, f"Response: {data}")
                return False
        else:
            print_result("Verified login", False, f"Status: {response.status_code}, Response: {response.text}")
            return False
    except Exception as e:
        print_result("Verified login test", False, f"Error: {e}")
        return False

def main():
    """Run all tests"""
    print("\n" + "=" * 70)
    print("  EMAIL VERIFICATION SYSTEM - COMPREHENSIVE TEST")
    print("=" * 70)
    print(f"\nTesting against: {BASE_URL}")
    print(f"Test email: {TEST_EMAIL}")
    
    results = []
    
    # Test 1: Connection
    results.append(("Backend Connection", test_connection()))
    if not results[-1][1]:
        print("\n[ERROR] Cannot connect to backend. Please start Flask server first.")
        return
    
    # Test 2: Email Config
    results.append(("Email Configuration", test_email_config()))
    
    # Test 3: Registration
    results.append(("User Registration", test_registration()[0]))
    
    # Test 4: Invalid Code
    results.append(("Invalid Code Rejection", test_verify_code_invalid()))
    
    # Test 5: Resend Code
    results.append(("Resend Code", test_resend_code()))
    
    # Test 6: Unverified Login
    results.append(("Unverified Login Block", test_login_unverified()))
    
    # Test 7: Manual Verification (optional)
    print("\n" + "=" * 70)
    print("  OPTIONAL: Manual Verification Test")
    print("=" * 70)
    manual = input("\nDo you want to test manual verification? (y/n): ").strip().lower()
    if manual == 'y':
        result = test_verify_code_manual()
        if isinstance(result, tuple) and len(result) == 3:
            verified, username, email = result
            results.append(("Manual Verification", verified))
            if verified:
                # Test 8: Verified Login
                results.append(("Verified Login", test_login_verified(username)))
        else:
            results.append(("Manual Verification", False))
    
    # Summary
    print_section("TEST SUMMARY")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "[PASS]" if result else "[FAIL]"
        print(f"  {status} {test_name}")
    
    print(f"\n  Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n  [SUCCESS] All tests passed! Email verification system is working correctly.")
    else:
        print(f"\n  [WARNING] {total - passed} test(s) failed. Please review the errors above.")
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nTest cancelled by user")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        import traceback
        traceback.print_exc()

