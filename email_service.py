"""Email service for sending verification emails via Gmail SMTP"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def send_verification_email(email: str, code: str, username: str = None) -> bool:
    """
    Send verification code email to user via Gmail SMTP.
    
    Args:
        email: Recipient email address
        code: 6-digit verification code
        username: Optional username for personalization
        
    Returns:
        True if email sent successfully, False otherwise
    """
    try:
        # Get email configuration from environment variables
        mail_server = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
        mail_port = int(os.environ.get('MAIL_PORT', '587'))
        mail_username = os.environ.get('GMAIL_USERNAME')
        mail_password = os.environ.get('GMAIL_APP_PASSWORD')
        
        # Check if email is configured
        if not mail_username or not mail_password:
            print("[ERROR] Gmail SMTP credentials not configured. Set GMAIL_USERNAME and GMAIL_APP_PASSWORD in .env")
            return False
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'Nutrition App - Email Verification Code'
        msg['From'] = mail_username
        msg['To'] = email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        
        text_body = f"""Hi {name},

Thank you for registering with Nutrition App!

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

If you didn't create an account, please ignore this email.

Need help? Contact our support team.

Best regards,
Nutrition App Team"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .code {{ background-color: #4CAF50; color: white; font-size: 32px; font-weight: bold; padding: 15px 30px; text-align: center; border-radius: 8px; margin: 20px 0; letter-spacing: 5px; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Nutrition App</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>Thank you for registering with Nutrition App!</p>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <p>If you didn't create an account, please ignore this email.</p>
            <div class="footer">
                <p>Need help? Contact our support team.</p>
                <p>Best regards,<br>Nutrition App Team</p>
            </div>
        </div>
    </div>
</body>
</html>"""
        
        # Attach both plain text and HTML versions
        part1 = MIMEText(text_body, 'plain')
        part2 = MIMEText(html_body, 'html')
        msg.attach(part1)
        msg.attach(part2)
        
        # Send email
        with smtplib.SMTP(mail_server, mail_port) as server:
            server.starttls()
            server.login(mail_username, mail_password)
            server.send_message(msg)
        
        print(f"[SUCCESS] Verification email sent to {email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send verification email to {email}: {e}")
        return False

def generate_verification_code() -> str:
    """Generate a random 6-digit verification code"""
    import random
    return str(random.randint(100000, 999999))

