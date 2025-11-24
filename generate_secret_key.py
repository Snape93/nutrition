#!/usr/bin/env python3
"""Generate a secure SECRET_KEY for Flask application"""
import secrets

if __name__ == "__main__":
    secret_key = secrets.token_hex(32)
    print("\n" + "="*60)
    print("SECRET_KEY for Render Deployment:")
    print("="*60)
    print(secret_key)
    print("="*60)
    print("\nCopy this value and use it as SECRET_KEY in Render environment variables.")
    print()






