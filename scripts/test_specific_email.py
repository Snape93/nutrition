"""
Test email verification flow with a specific email address.
This will attempt to send a real email if SMTP credentials are configured.
"""
import os
import sys
from pathlib import Path

# Ensure parent directory (project root) is importable
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Enable EMAIL_TEST_MODE to log emails even if SMTP fails
# This allows us to see the verification code in the log file
os.environ.setdefault('EMAIL_TEST_MODE', '1')

from app import app, db, PendingRegistration, User
from datetime import datetime

def test_email_verification(email: str):
    """Test email verification flow with a specific email address."""
    with app.app_context():
        client = app.test_client()
        
        # Clean up any existing pending registration for this email
        existing_pending = PendingRegistration.query.filter(
            PendingRegistration.email.ilike(email)
        ).first()
        if existing_pending:
            print(f"[CLEANUP] Removing existing pending registration for {email}")
            db.session.delete(existing_pending)
            db.session.commit()
        
        # Clean up any existing user for this email (for testing)
        existing_user = User.query.filter(User.email.ilike(email)).first()
        if existing_user:
            print(f"[CLEANUP] Removing existing user for {email}")
            db.session.delete(existing_user)
            db.session.commit()
        
        # Registration payload
        username = email.split('@')[0].replace('.', '_') + '_test'
        payload = {
            "username": username,
            "email": email,
            "password": "Test1234!",
            "full_name": "Test User",
            "age": 28,
            "sex": "male",
            "weight_kg": 70,
            "height_cm": 175,
            "activity_level": "active",
            "goal": "maintain",
            "diet_type": "balanced",
            "restrictions": [],
            "allergies": [],
            "exercise_types": ["cardio"],
            "exercise_equipment": [],
            "used_apps": [],
            "is_metric": True,
        }
        
        print(f"\n{'='*60}")
        print(f"TESTING EMAIL VERIFICATION FOR: {email}")
        print(f"{'='*60}\n")
        
        # Step 1: Register
        print("[STEP 1] Registering user...")
        resp = client.post('/register', json=payload)
        print(f"        Status Code: {resp.status_code}")
        response_data = resp.get_json()
        print(f"        Response: {response_data}")
        
        if resp.status_code != 201:
            print(f"\n[ERROR] Registration failed!")
            return
        
        # Get verification code from database
        pending_reg = PendingRegistration.query.filter(
            PendingRegistration.email.ilike(email)
        ).first()
        
        if not pending_reg:
            print("\n[ERROR] Pending registration not found in database!")
            return
        
        verification_code = pending_reg.verification_code
        expires_at = pending_reg.verification_expires_at
        
        print(f"\n[INFO] Verification Code from Database: {verification_code}")
        print(f"[INFO] Code expires at: {expires_at}")
        print(f"[INFO] Resend count: {pending_reg.resend_count}/5")
        
        # Check email log file if EMAIL_TEST_MODE is enabled
        email_test_log = os.path.join(PROJECT_ROOT, 'instance', 'email_test_log.jsonl')
        if os.path.exists(email_test_log):
            print(f"\n[INFO] Checking email log file: {email_test_log}")
            try:
                with open(email_test_log, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    if lines:
                        import json
                        last_email = json.loads(lines[-1])
                        if last_email.get('to', '').lower() == email.lower():
                            # Extract code from email body
                            text_body = last_email.get('text', '')
                            if 'verification code is:' in text_body:
                                import re
                                code_match = re.search(r'verification code is:\s*(\d{6})', text_body, re.IGNORECASE)
                                if code_match:
                                    logged_code = code_match.group(1)
                                    print(f"[INFO] Verification code from email log: {logged_code}")
            except Exception as e:
                print(f"[WARN] Could not read email log: {e}")
        
        # Check if email was sent
        mail_username = os.environ.get('GMAIL_USERNAME')
        mail_password = os.environ.get('GMAIL_APP_PASSWORD')
        
        if mail_username and mail_password:
            print(f"\n[INFO] Gmail credentials configured: {mail_username}")
            if os.environ.get('EMAIL_TEST_MODE'):
                print(f"[INFO] EMAIL_TEST_MODE enabled - email logged to file instead of sent")
            else:
                print(f"[INFO] Email should be sent to: {email}")
                print(f"[INFO] Check your inbox for the verification code!")
        else:
            print(f"\n[WARN] Gmail credentials NOT configured")
            print(f"[WARN] Set GMAIL_USERNAME and GMAIL_APP_PASSWORD to send real emails")
            print(f"[INFO] Verification code (from database): {verification_code}")
        
        # Step 2: Test resend
        print(f"\n[STEP 2] Testing resend code...")
        resp = client.post('/auth/resend-code', json={'email': email})
        print(f"        Status Code: {resp.status_code}")
        response_data = resp.get_json()
        print(f"        Response: {response_data}")
        
        if resp.status_code == 200:
            # Get updated code
            db.session.refresh(pending_reg)
            new_code = pending_reg.verification_code
            print(f"[INFO] New verification code: {new_code}")
            print(f"[INFO] Resend count: {pending_reg.resend_count}/5")
            verification_code = new_code
        
        # Refresh pending registration to get latest code
        db.session.refresh(pending_reg)
        current_code = pending_reg.verification_code
        if current_code != verification_code:
            print(f"[INFO] Code was updated. Using latest code: {current_code}")
            verification_code = current_code
        
        # Step 3: Verify code
        print(f"\n[STEP 3] Verifying code: {verification_code}")
        resp = client.post('/auth/verify-code', json={
            'email': email,
            'code': verification_code
        })
        print(f"        Status Code: {resp.status_code}")
        response_data = resp.get_json()
        print(f"        Response: {response_data}")
        
        if resp.status_code == 200:
            # Verify user was created
            user = User.query.filter(User.email.ilike(email)).first()
            if user and user.email_verified:
                print(f"\n[SUCCESS] User account created and verified!")
                print(f"[SUCCESS] Username: {user.username}")
                print(f"[SUCCESS] Email: {user.email}")
                print(f"[SUCCESS] Email Verified: {user.email_verified}")
                
                # Ask if user wants to clean up
                print(f"\n[INFO] Test user created. Remove it? (y/n): ", end='')
                # For automated testing, we'll just show the info
                print("(Run cleanup manually if needed)")
            else:
                print(f"\n[ERROR] User not found or not verified!")
        else:
            print(f"\n[ERROR] Verification failed!")
        
        print(f"\n{'='*60}")
        print("TEST COMPLETE")
        print(f"{'='*60}\n")

if __name__ == '__main__':
    test_email = 'dle.dacillo@gmail.com'
    test_email_verification(test_email)

