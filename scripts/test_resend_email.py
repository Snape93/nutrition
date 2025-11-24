"""
Quick manual test to verify Resend email delivery.

Usage:
    python scripts/test_resend_email.py recipient@example.com

Requirements:
    - RESEND_API_KEY must be set in environment or .env file.
    - Optional: RESEND_FROM_EMAIL to override default sender.
"""
import os
import sys
from datetime import datetime

import requests
from dotenv import load_dotenv


def send_test_email(to_email: str) -> None:
    load_dotenv()
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key:
        raise SystemExit("RESEND_API_KEY not configured.")

    from_email = os.environ.get("RESEND_FROM_EMAIL", "onboarding@resend.dev")
    payload = {
        "from": f"Nutrition App Test <{from_email}>",
        "to": [to_email],
        "subject": f"Resend Test {datetime.utcnow():%Y-%m-%d %H:%M:%S UTC}",
        "html": "<h1>Resend test email</h1><p>This is a manual delivery test.</p>",
        "text": "Resend test email. This is a manual delivery test.",
    }

    response = requests.post(
        "https://api.resend.com/emails",
        json=payload,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        timeout=15,
    )

    response.raise_for_status()
    result = response.json()
    print(f"Success! Email ID: {result.get('id')}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/test_resend_email.py recipient@example.com")
    send_test_email(sys.argv[1])










