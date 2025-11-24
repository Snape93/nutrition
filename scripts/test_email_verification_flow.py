"""
Script to exercise the email verification flow end-to-end using Flask's test client.

Steps:
1. Create a pending registration via POST /register.
2. Trigger /auth/resend-code to ensure resend endpoint works.
3. Complete verification via /auth/verify-code.

The script runs with EMAIL_TEST_MODE=1 by default so no real emails are sent. Instead,
codes are written to instance/email_test_log.jsonl for inspection.
"""
import os
import random
import string
import sys
import time
from pathlib import Path
from typing import Tuple

# Ensure parent directory (project root) is importable when script is run directly.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Ensure emails are logged instead of delivered if SMTP is not available.
os.environ.setdefault('EMAIL_TEST_MODE', '1')

from app import app, db, PendingRegistration, User  # noqa: E402  pylint: disable=wrong-import-position


def _random_suffix(length: int = 6) -> str:
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))


def _build_registration_payload(email: str, username: str, password: str) -> dict:
    return {
        "username": username,
        "email": email,
        "password": password,
        "full_name": "Test User",
        "age": 28,
        "sex": "female",
        "weight_kg": 60,
        "height_cm": 165,
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


def _fetch_pending_code(email: str) -> Tuple[str, int]:
    pending_reg = PendingRegistration.query.filter(
        PendingRegistration.email.ilike(email)
    ).first()
    if not pending_reg:
        raise RuntimeError("Pending registration not found.")
    return pending_reg.verification_code, pending_reg.resend_count


def run_flow():
    with app.app_context():
        client = app.test_client()
        suffix = f"{int(time.time())}{_random_suffix()}"
        email = f"devtest+{suffix}@example.com"
        username = f"tester_{suffix}"
        password = "Test1234!"

        payload = _build_registration_payload(email, username, password)

        print(f"[STEP 1] Registering user {username} / {email}")
        resp = client.post('/register', json=payload)
        assert resp.status_code == 201, resp.get_json()
        print(f"        Response: {resp.get_json()}")

        code, resend_count = _fetch_pending_code(email)
        print(f"        Pending verification code: {code} (resend_count={resend_count})")

        print("[STEP 2] Requesting code resend")
        resp = client.post('/auth/resend-code', json={'email': email})
        assert resp.status_code == 200, resp.get_json()
        print(f"        Response: {resp.get_json()}")
        new_code, resend_count = _fetch_pending_code(email)
        print(f"        Updated verification code: {new_code} (resend_count={resend_count})")

        print("[STEP 3] Verifying code")
        resp = client.post('/auth/verify-code', json={'email': email, 'code': new_code})
        assert resp.status_code == 200, resp.get_json()
        print(f"        Response: {resp.get_json()}")

        user = User.query.filter(User.email.ilike(email)).first()
        assert user and user.email_verified, "User not created or not verified."
        print(f"[SUCCESS] User {user.username} verified. Cleaning up test user.")

        # Cleanup to keep database tidy.
        try:
            db.session.delete(user)
            db.session.commit()
            print("[CLEANUP] Test user removed from database.")
        except Exception as err:
            db.session.rollback()
            print(f"[WARN] Failed to clean up test user: {err}")


if __name__ == '__main__':
    run_flow()

