"""
Test script to verify email verification setup
Run this after configuring Gmail credentials in .env
"""
import os
from dotenv import load_dotenv
from email_service import send_verification_email, generate_verification_code

# Load environment variables
load_dotenv()

def test_email_setup():
    """Test if email configuration is set up correctly"""
    print("=" * 60)
    print("Email Verification Setup Test")
    print("=" * 60)
    
    # Check if credentials are configured
    gmail_username = os.environ.get('GMAIL_USERNAME')
    gmail_password = os.environ.get('GMAIL_APP_PASSWORD')
    
    print(f"\n1. Checking Gmail credentials...")
    if not gmail_username:
        print("   ❌ GMAIL_USERNAME not found in .env file")
        print("   → Add: GMAIL_USERNAME=your-email@gmail.com")
        return False
    else:
        print(f"   ✅ GMAIL_USERNAME found: {gmail_username}")
    
    if not gmail_password:
        print("   ❌ GMAIL_APP_PASSWORD not found in .env file")
        print("   → Add: GMAIL_APP_PASSWORD=your-16-char-app-password")
        return False
    else:
        print(f"   ✅ GMAIL_APP_PASSWORD found: {'*' * len(gmail_password)}")
    
    # Test email sending
    print(f"\n2. Testing email sending...")
    test_email = input("   Enter your email address to send a test verification code: ").strip()
    
    if not test_email:
        print("   ⚠️  No email provided, skipping email test")
        return True
    
    test_code = generate_verification_code()
    print(f"   Generated test code: {test_code}")
    print(f"   Sending test email to {test_email}...")
    
    success = send_verification_email(test_email, test_code, "TestUser")
    
    if success:
        print(f"   ✅ Test email sent successfully!")
        print(f"   → Check your inbox at {test_email}")
        print(f"   → The verification code should be: {test_code}")
        return True
    else:
        print(f"   ❌ Failed to send test email")
        print(f"   → Check your Gmail credentials and App Password")
        print(f"   → Make sure 2-Step Verification is enabled")
        return False

if __name__ == "__main__":
    try:
        success = test_email_setup()
        print("\n" + "=" * 60)
        if success:
            print("✅ Email verification setup is ready!")
        else:
            print("❌ Please fix the issues above and try again")
        print("=" * 60)
    except KeyboardInterrupt:
        print("\n\nTest cancelled by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

