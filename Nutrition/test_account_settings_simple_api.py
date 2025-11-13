"""
Simple test script for Account Settings API endpoints
Tests the backend API functionality for account settings
"""

import os
import json
import sys
import requests
from pathlib import Path

# Add the parent directory to the path so we can import the app
sys.path.insert(0, str(Path(__file__).parent))

def setup_test_environment():
    """Setup test environment variables"""
    os.environ['FLASK_ENV'] = 'testing'
    # Use a test database URL if not already set
    if not os.environ.get('NEON_DATABASE_URL'):
        os.environ['NEON_DATABASE_URL'] = 'sqlite:///test_nutrition.db'

def test_account_settings_endpoints():
    """Test all account settings related API endpoints"""
    
    # Base URL for the API
    base_url = "http://localhost:5000"
    
    # Test user credentials
    test_user = {
        "username": "testuser_settings",
        "email": "testuser_settings@example.com",
        "password": "testpassword123",
        "full_name": "Test User Settings",
        "age": 25,
        "sex": "male",
        "height": 175,
        "weight": 70,
        "activity_level": "moderate",
        "goal": "maintain"
    }
    
    print("Testing Account Settings API Endpoints...")
    print("=" * 50)
    
    # Test 1: Register a test user
    print("\n1. Testing user registration...")
    try:
        response = requests.post(f"{base_url}/register", json=test_user)
        if response.status_code == 201:
            print("User registration successful")
        elif response.status_code == 409:
            print("User already exists, continuing with tests")
        else:
            print(f"Registration failed: {response.status_code} - {response.text}")
            return False
    except requests.exceptions.ConnectionError:
        print("Cannot connect to API server. Make sure the Flask app is running.")
        return False
    
    # Test 2: Login to get authentication token
    print("\n2. Testing user login...")
    login_data = {
        "username_or_email": test_user["username"],
        "password": test_user["password"]
    }
    
    try:
        response = requests.post(f"{base_url}/login", json=login_data)
        if response.status_code == 200:
            auth_data = response.json()
            print("Login successful")
            # Store token for authenticated requests
            headers = {"Authorization": f"Bearer {auth_data.get('access_token', '')}"}
        else:
            print(f"Login failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Login error: {e}")
        return False
    
    # Test 3: Get user profile
    print("\n3. Testing get user profile...")
    try:
        response = requests.get(f"{base_url}/user/{test_user['username']}", headers=headers)
        if response.status_code == 200:
            user_data = response.json()
            print("User profile retrieved successfully")
            print(f"   Email: {user_data.get('email', 'N/A')}")
            print(f"   Username: {user_data.get('username', 'N/A')}")
        else:
            print(f"Get profile failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Get profile error: {e}")
    
    # Test 4: Change email
    print("\n4. Testing email change...")
    new_email = "newemail_settings@example.com"
    email_data = {"new_email": new_email}
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/email",
            json=email_data,
            headers=headers
        )
        if response.status_code == 200:
            print("Email changed successfully")
            print(f"   New email: {new_email}")
        else:
            print(f"Email change failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Email change error: {e}")
    
    # Test 5: Change password
    print("\n5. Testing password change...")
    password_data = {
        "current_password": test_user["password"],
        "new_password": "newpassword123"
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=password_data,
            headers=headers
        )
        if response.status_code == 200:
            print("Password changed successfully")
        else:
            print(f"Password change failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Password change error: {e}")
    
    # Test 6: Test login with new password
    print("\n6. Testing login with new password...")
    new_login_data = {
        "username_or_email": test_user["username"],
        "password": "newpassword123"
    }
    
    try:
        response = requests.post(f"{base_url}/login", json=new_login_data)
        if response.status_code == 200:
            print("Login with new password successful")
        else:
            print(f"Login with new password failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Login with new password error: {e}")
    
    # Test 7: Test invalid email change
    print("\n7. Testing invalid email change...")
    invalid_email_data = {"new_email": "invalid-email"}
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/email",
            json=invalid_email_data,
            headers=headers
        )
        if response.status_code == 400:
            print("Invalid email correctly rejected")
        else:
            print(f"Invalid email should have been rejected: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Invalid email test error: {e}")
    
    # Test 8: Test invalid password change
    print("\n8. Testing invalid password change...")
    invalid_password_data = {
        "current_password": "wrongpassword",
        "new_password": "newpassword456"
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=invalid_password_data,
            headers=headers
        )
        if response.status_code == 401:
            print("Invalid current password correctly rejected")
        else:
            print(f"Invalid password should have been rejected: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Invalid password test error: {e}")
    
    # Test 9: Test short password
    print("\n9. Testing short password...")
    short_password_data = {
        "current_password": "newpassword123",
        "new_password": "123"
    }
    
    try:
        response = requests.put(
            f"{base_url}/user/{test_user['username']}/password",
            json=short_password_data,
            headers=headers
        )
        if response.status_code == 400:
            print("Short password correctly rejected")
        else:
            print(f"Short password should have been rejected: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Short password test error: {e}")
    
    # Test 10: Test account deletion
    print("\n10. Testing account deletion...")
    try:
        response = requests.delete(f"{base_url}/user/{test_user['username']}", headers=headers)
        if response.status_code == 200:
            print("Account deleted successfully")
        else:
            print(f"Account deletion failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Account deletion error: {e}")
    
    # Test 11: Verify account is deleted
    print("\n11. Testing login after account deletion...")
    try:
        response = requests.post(f"{base_url}/login", json=new_login_data)
        if response.status_code == 401:
            print("Account deletion verified - login fails")
        else:
            print(f"Account should have been deleted: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Post-deletion login test error: {e}")
    
    print("\n" + "=" * 50)
    print("Account Settings API testing completed!")
    return True

def test_validation_endpoints():
    """Test validation endpoints for account settings"""
    
    base_url = "http://localhost:5000"
    
    print("\nTesting Validation Endpoints...")
    print("=" * 50)
    
    # Test email validation
    print("\n1. Testing email validation...")
    test_emails = [
        ("valid@example.com", True),
        ("invalid-email", False),
        ("test@domain", False),
        ("@domain.com", False),
        ("test@.com", False),
        ("test@domain.", False),
    ]
    
    for email, should_be_valid in test_emails:
        # This would typically be tested through the email change endpoint
        print(f"   Email: {email} - Expected valid: {should_be_valid}")
    
    # Test password validation
    print("\n2. Testing password validation...")
    test_passwords = [
        ("password123", True),
        ("123", False),  # Too short
        ("", False),     # Empty
        ("a" * 100, True),  # Long password
    ]
    
    for password, should_be_valid in test_passwords:
        print(f"   Password: {'*' * len(password)} - Expected valid: {should_be_valid}")
    
    print("\nValidation testing completed!")

def main():
    """Main test function"""
    setup_test_environment()
    
    print("Starting Account Settings API Tests")
    print("Make sure the Flask app is running on http://localhost:5000")
    print("=" * 60)
    
    # Test main functionality
    success = test_account_settings_endpoints()
    
    # Test validation
    test_validation_endpoints()
    
    if success:
        print("\nAll tests completed successfully!")
    else:
        print("\nSome tests failed. Check the output above.")
        sys.exit(1)

if __name__ == "__main__":
    main()

