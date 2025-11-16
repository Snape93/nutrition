"""
Comprehensive test script for Change Password functionality
Tests all scenarios for the password change endpoint
"""

import os
import sys
import requests
import time
from pathlib import Path

# Add the parent directory to the path so we can import the app
sys.path.insert(0, str(Path(__file__).parent))

# Try to import database models for verification code retrieval
DB_AVAILABLE = False
app = None
PendingRegistration = None

try:
    # Set environment variable before importing app
    os.environ.setdefault('FLASK_ENV', 'development')
    from app import app, db, PendingRegistration
    from datetime import datetime
    DB_AVAILABLE = True
except (ImportError, KeyError, Exception) as e:
    DB_AVAILABLE = False
    print(f"[WARNING] Could not import database models: {e}")
    print("[WARNING] Verification code retrieval will be skipped. Test will try to use existing users.")

def setup_test_environment():
    """Setup test environment variables"""
    os.environ['FLASK_ENV'] = 'testing'

def print_test_header(test_num, description):
    """Print formatted test header"""
    print(f"\n{'='*60}")
    print(f"TEST {test_num}: {description}")
    print('='*60)

def print_result(success, message):
    """Print formatted test result"""
    status = "[PASS]" if success else "[FAIL]"
    print(f"{status}: {message}")

def test_change_password():
    """Comprehensive test for change password functionality"""
    
    base_url = "http://localhost:5000"
    
    # Test user credentials
    test_user = {
        "username": "testuser_password_change",
        "email": "testuser_password_change@example.com",
        "password": "originalpass123",
        "full_name": "Test User Password",
        "age": 25,
        "sex": "male",
        "height": 175,
        "weight": 70,
        "activity_level": "moderate",
        "goal": "maintain"
    }
    
    print("\n" + "="*60)
    print("CHANGE PASSWORD FUNCTIONALITY TEST")
    print("="*60)
    print(f"\nBase URL: {base_url}")
    print(f"Test User: {test_user['username']}")
    
    # Track test results
    test_results = []
    headers = {}  # Initialize headers variable
    
    # ===== SETUP: Register and Login =====
    print_test_header("SETUP", "User Registration and Login")
    
    # First, try to login with existing user
    login_data = {
        "username_or_email": test_user["username"],
        "password": test_user["password"]
    }
    
    try:
        response = requests.post(f"{base_url}/login", json=login_data, timeout=10)
        if response.status_code == 200:
            auth_data = response.json()
            headers = {"Authorization": f"Bearer {auth_data.get('access_token', '')}"}
            print_result(True, "Login successful with existing user")
            test_results.append(True)
        else:
            # User doesn't exist or not verified, need to register and verify
            print_result(False, f"Login failed (user may not exist): {response.status_code} - {response.text}")
            print("   Attempting to register and verify user...")
            
            # Register user
            try:
                response = requests.post(f"{base_url}/register", json=test_user, timeout=10)
                if response.status_code == 201:
                    print_result(True, "User registered successfully")
                    test_results.append(True)
                elif response.status_code == 409:
                    print_result(True, "User already exists in pending registration")
                    test_results.append(True)
                else:
                    print_result(False, f"Registration failed: {response.status_code} - {response.text}")
                    test_results.append(False)
                    return test_results
            except Exception as e:
                print_result(False, f"Registration error: {e}")
                return test_results
            
            # Get verification code from database
            verification_code = None
            if DB_AVAILABLE and app is not None and PendingRegistration is not None:
                try:
                    with app.app_context():
                        pending_reg = PendingRegistration.query.filter_by(
                            email=test_user["email"]
                        ).first()
                        if pending_reg:
                            verification_code = pending_reg.verification_code
                            print(f"   Found verification code in database: {verification_code}")
                except Exception as e:
                    print(f"   Could not retrieve verification code from database: {e}")
            
            if not verification_code:
                print_result(False, "Could not retrieve verification code. Please verify email manually or check database.")
                print("   You can query the database for the verification code:")
                print(f"   SELECT verification_code FROM pending_registrations WHERE email = '{test_user['email']}';")
                return test_results
            
            # Verify email with code
            verify_data = {
                "email": test_user["email"],
                "code": verification_code
            }
            
            try:
                response = requests.post(f"{base_url}/auth/verify-code", json=verify_data, timeout=10)
                if response.status_code == 200:
                    print_result(True, "Email verified successfully")
                    test_results.append(True)
                else:
                    print_result(False, f"Email verification failed: {response.status_code} - {response.text}")
                    test_results.append(False)
                    return test_results
            except Exception as e:
                print_result(False, f"Verification error: {e}")
                return test_results
            
            # Now try to login again
            try:
                response = requests.post(f"{base_url}/login", json=login_data, timeout=10)
                if response.status_code == 200:
                    auth_data = response.json()
                    headers = {"Authorization": f"Bearer {auth_data.get('access_token', '')}"}
                    print_result(True, "Login successful after verification")
                    test_results.append(True)
                else:
                    print_result(False, f"Login failed after verification: {response.status_code} - {response.text}")
                    test_results.append(False)
                    return test_results
            except Exception as e:
                print_result(False, f"Login error: {e}")
                return test_results
                
    except requests.exceptions.ConnectionError:
        print_result(False, "Cannot connect to API server. Make sure Flask app is running on http://localhost:5000")
        return test_results
    except Exception as e:
        print_result(False, f"Setup error: {e}")
        return test_results
    
    # ===== TEST 1: Successful Password Change =====
    print_test_header(1, "Successful Password Change")
    
    new_password = "newpassword456"
    password_data = {
        "current_password": test_user["password"],
        "new_password": new_password
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=password_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success') and 'Password changed successfully' in result.get('message', ''):
                print_result(True, "Password changed successfully")
                print(f"   Response: {result}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected response format: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Password change failed: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Password change error: {e}")
        test_results.append(False)
    
    # ===== TEST 2: Verify Login with New Password =====
    print_test_header(2, "Verify Login with New Password")
    
    new_login_data = {
        "username_or_email": test_user["username"],
        "password": new_password
    }
    
    try:
        response = requests.post(f"{base_url}/login", json=new_login_data, timeout=10)
        if response.status_code == 200:
            print_result(True, "Login successful with new password")
            test_results.append(True)
        else:
            print_result(False, f"Login with new password failed: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Login error: {e}")
        test_results.append(False)
    
    # ===== TEST 3: Verify Old Password No Longer Works =====
    print_test_header(3, "Verify Old Password No Longer Works")
    
    old_login_data = {
        "username_or_email": test_user["username"],
        "password": test_user["password"]  # Original password
    }
    
    try:
        response = requests.post(f"{base_url}/login", json=old_login_data, timeout=10)
        if response.status_code == 401:
            print_result(True, "Old password correctly rejected")
            test_results.append(True)
        else:
            print_result(False, f"Old password should have been rejected: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Login test error: {e}")
        test_results.append(False)
    
    # ===== TEST 4: Wrong Current Password =====
    print_test_header(4, "Wrong Current Password Rejection")
    
    wrong_password_data = {
        "current_password": "wrongpassword123",
        "new_password": "anothernewpass789"
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=wrong_password_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 401:
            result = response.json()
            if 'incorrect' in result.get('error', '').lower():
                print_result(True, "Wrong current password correctly rejected")
                print(f"   Error message: {result.get('error')}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected error message: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Should have returned 401: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 5: Short Password Validation =====
    print_test_header(5, "Short Password Validation")
    
    short_password_data = {
        "current_password": new_password,
        "new_password": "123"  # Too short
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=short_password_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 400:
            result = response.json()
            if '6 characters' in result.get('error', '').lower():
                print_result(True, "Short password correctly rejected")
                print(f"   Error message: {result.get('error')}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected error message: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Should have returned 400: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 6: Missing Current Password =====
    print_test_header(6, "Missing Current Password")
    
    missing_current_data = {
        "new_password": "newpassword999"
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=missing_current_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 400:
            result = response.json()
            if 'required' in result.get('error', '').lower():
                print_result(True, "Missing current password correctly rejected")
                print(f"   Error message: {result.get('error')}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected error message: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Should have returned 400: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 7: Missing New Password =====
    print_test_header(7, "Missing New Password")
    
    missing_new_data = {
        "current_password": new_password
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=missing_new_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 400:
            result = response.json()
            if 'required' in result.get('error', '').lower():
                print_result(True, "Missing new password correctly rejected")
                print(f"   Error message: {result.get('error')}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected error message: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Should have returned 400: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 8: Empty Request Body =====
    print_test_header(8, "Empty Request Body")
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json={},
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 400:
            result = response.json()
            print_result(True, "Empty request body correctly rejected")
            print(f"   Error message: {result.get('error')}")
            test_results.append(True)
        else:
            print_result(False, f"Should have returned 400: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 9: Non-existent User =====
    print_test_header(9, "Non-existent User")
    
    try:
        response = requests.put(
            f"{base_url}/user/nonexistentuser12345/password",
            json={
                "current_password": "somepass",
                "new_password": "newpass123"
            },
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 404:
            result = response.json()
            if 'not found' in result.get('error', '').lower():
                print_result(True, "Non-existent user correctly rejected")
                print(f"   Error message: {result.get('error')}")
                test_results.append(True)
            else:
                print_result(False, f"Unexpected error message: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Should have returned 404: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== TEST 10: Change Password Again (Verify Multiple Changes) =====
    print_test_header(10, "Change Password Again (Multiple Changes)")
    
    final_password = "finalpassword789"
    final_password_data = {
        "current_password": new_password,
        "new_password": final_password
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=final_password_data,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print_result(True, "Second password change successful")
                
                # Verify login with final password
                final_login = {
                    "username_or_email": test_user["username"],
                    "password": final_password
                }
                login_response = requests.post(f"{base_url}/login", json=final_login, timeout=10)
                if login_response.status_code == 200:
                    print_result(True, "Login with final password successful")
                    test_results.append(True)
                else:
                    print_result(False, f"Login with final password failed: {login_response.status_code}")
                    test_results.append(False)
            else:
                print_result(False, f"Unexpected response: {result}")
                test_results.append(False)
        else:
            print_result(False, f"Second password change failed: {response.status_code} - {response.text}")
            test_results.append(False)
    except Exception as e:
        print_result(False, f"Test error: {e}")
        test_results.append(False)
    
    # ===== CLEANUP =====
    print_test_header("CLEANUP", "Delete Test User")
    
    try:
        # Login with final password to get fresh token
        final_login = {
            "username_or_email": test_user["username"],
            "password": final_password
        }
        login_response = requests.post(f"{base_url}/login", json=final_login, timeout=10)
        if login_response.status_code == 200:
            auth_data = login_response.json()
            cleanup_headers = {"Authorization": f"Bearer {auth_data.get('access_token', '')}"}
            
            # Delete user
            delete_response = requests.delete(
                f"{base_url}/user/{test_user['username']}",
                headers=cleanup_headers,
                timeout=10
            )
            if delete_response.status_code == 200:
                print_result(True, "Test user deleted successfully")
            else:
                print_result(False, f"Failed to delete user: {delete_response.status_code}")
        else:
            print_result(False, "Could not login to delete user")
    except Exception as e:
        print_result(False, f"Cleanup error: {e}")
    
    # ===== SUMMARY =====
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    total_tests = len(test_results)
    passed_tests = sum(test_results)
    failed_tests = total_tests - passed_tests
    
    print(f"\nTotal Tests: {total_tests}")
    print(f"[PASS] Passed: {passed_tests}")
    print(f"[FAIL] Failed: {failed_tests}")
    print(f"Success Rate: {(passed_tests/total_tests*100):.1f}%")
    
    if all(test_results):
        print("\n[SUCCESS] All tests passed!")
        return True
    else:
        print("\n[WARNING] Some tests failed. Review the output above.")
        return False

def main():
    """Main test function"""
    setup_test_environment()
    
    print("\n" + "="*60)
    print("CHANGE PASSWORD FUNCTIONALITY TEST SUITE")
    print("="*60)
    print("\n[!] Make sure the Flask app is running on http://localhost:5000")
    print("Press Ctrl+C to cancel, or wait 3 seconds to continue...")
    
    try:
        time.sleep(3)
    except KeyboardInterrupt:
        print("\n\nTest cancelled by user.")
        sys.exit(0)
    
    success = test_change_password()
    
    if success:
        print("\n[SUCCESS] All change password tests completed successfully!")
        sys.exit(0)
    else:
        print("\n[FAILED] Some tests failed. Check the output above.")
        sys.exit(1)

if __name__ == "__main__":
    main()

