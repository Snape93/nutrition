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
        msg['Subject'] = 'Nutritionist App - Email Verification Code'
        msg['From'] = mail_username
        msg['To'] = email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        
        text_body = f"""Hi {name},

Thank you for registering with Nutritionist App!

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

If you didn't create an account, please ignore this email.

Need help? Contact our support team.

Best regards,
Nutritionist App Team"""

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
            <h1>Nutritionist App</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>Thank you for registering with Nutritionist App!</p>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <p>If you didn't create an account, please ignore this email.</p>
            <div class="footer">
                <p>Need help? Contact our support team.</p>
                <p>Best regards,<br>Nutritionist App Team</p>
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

def send_email_change_verification(new_email: str, code: str, old_email: str = None, username: str = None) -> bool:
    """
    Send email change verification code to the new email address.
    
    Args:
        new_email: New email address to verify
        code: 6-digit verification code
        old_email: Current email address (for context)
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
        msg['Subject'] = 'Nutritionist App - Verify Your New Email Address'
        msg['From'] = mail_username
        msg['To'] = new_email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        old_email_text = f"\nCurrent email: {old_email}\n" if old_email else ""
        
        text_body = f"""Hi {name},

You requested to change your email address for your Nutritionist App account.

{old_email_text}New email address: {new_email}

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

If you didn't request this email change, please ignore this email and secure your account immediately.

Need help? Contact our support team.

Best regards,
Nutritionist App Team"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .code {{ background-color: #4CAF50; color: white; font-size: 32px; font-weight: bold; padding: 15px 30px; text-align: center; border-radius: 8px; margin: 20px 0; letter-spacing: 5px; }}
        .warning {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 20px 0; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Nutritionist App</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>You requested to change your email address for your Nutritionist App account.</p>
            {f'<p><strong>Current email:</strong> {old_email}</p>' if old_email else ''}
            <p><strong>New email address:</strong> {new_email}</p>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <div class="warning">
                <p><strong>⚠️ Security Notice:</strong> If you didn't request this email change, please ignore this email and secure your account immediately.</p>
            </div>
            <div class="footer">
                <p>Need help? Contact our support team.</p>
                <p>Best regards,<br>Nutritionist App Team</p>
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
        
        print(f"[SUCCESS] Email change verification email sent to {new_email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send email change verification email to {new_email}: {e}")
        return False

def send_account_deletion_verification(email: str, code: str, username: str = None) -> bool:
    """
    Send account deletion verification code to the current email address.
    
    Args:
        email: Current email address
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
        msg['Subject'] = 'Nutritionist App - Confirm Account Deletion'
        msg['From'] = mail_username
        msg['To'] = email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        
        text_body = f"""Hi {name},

⚠️ WARNING: Account Deletion Request

You requested to permanently delete your Nutritionist App account.

This action will permanently delete ALL your data:
• Food logs
• Exercise logs
• Weight logs
• Workout logs
• Custom recipes
• All personal data

This action CANNOT be undone.

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

⚠️ IMPORTANT: If you didn't request this account deletion, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.

Best regards,
Nutritionist App Team"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #dc3545; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .code {{ background-color: #dc3545; color: white; font-size: 32px; font-weight: bold; padding: 15px 30px; text-align: center; border-radius: 8px; margin: 20px 0; letter-spacing: 5px; }}
        .warning {{ background-color: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 20px 0; }}
        .data-list {{ background-color: #fff; border: 1px solid #ddd; padding: 15px; margin: 15px 0; border-radius: 4px; }}
        .data-list ul {{ margin: 10px 0; padding-left: 20px; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ Account Deletion Request</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <div class="warning">
                <p><strong>⚠️ WARNING: Account Deletion Request</strong></p>
                <p>You requested to permanently delete your Nutritionist App account.</p>
            </div>
            <div class="data-list">
                <p><strong>This action will permanently delete ALL your data:</strong></p>
                <ul>
                    <li>Food logs</li>
                    <li>Exercise logs</li>
                    <li>Weight logs</li>
                    <li>Workout logs</li>
                    <li>Custom recipes</li>
                    <li>All personal data</li>
                </ul>
                <p><strong>This action CANNOT be undone.</strong></p>
            </div>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <div class="warning">
                <p><strong>⚠️ IMPORTANT:</strong> If you didn't request this account deletion, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.</p>
            </div>
            <div class="footer">
                <p>Best regards,<br>Nutritionist App Team</p>
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
        
        print(f"[SUCCESS] Account deletion verification email sent to {email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send account deletion verification email to {email}: {e}")
        return False

def send_email_change_notification(old_email: str, new_email: str, username: str = None, timestamp: str = None) -> bool:
    """
    Send security notification to old email address when email change is requested.
    This is informational only - no verification code is included.
    
    Args:
        old_email: Current email address (receives notification)
        new_email: New email address being requested
        username: Optional username for personalization
        timestamp: Optional timestamp of the request
        
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
        msg['Subject'] = '🔒 Security Alert: Email Change Requested for Your Account'
        msg['From'] = mail_username
        msg['To'] = old_email
        
        # Email body
        name = username or 'there'
        request_time = timestamp or datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')
        
        text_body = f"""Security Alert: Email Change Requested

Hi {name},

We received a request to change the email address for your Nutritionist App account.

Current Email: {old_email}
New Email Requested: {new_email}
Request Time: {request_time}

If you requested this change:
→ Verify your new email address to complete the change
→ A verification code has been sent to {new_email}
→ No action is needed from this email

If you did NOT request this change:
→ Your account may be compromised
→ Cancel the email change immediately
→ Change your password
→ Contact support if needed

To cancel this email change:
→ Log into your account
→ Go to Account Settings
→ Cancel the pending email change

Need help? Contact our support team.

Best regards,
Nutritionist App Team

---
This is a security notification. No verification code is required from this email address.
The verification code has been sent to your new email address: {new_email}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #ff9800; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .alert-box {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }}
        .security-box {{ background-color: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 20px 0; }}
        .info-box {{ background-color: #d1ecf1; border-left: 4px solid #0c5460; padding: 15px; margin: 20px 0; }}
        .details {{ background-color: #fff; border: 1px solid #ddd; padding: 15px; margin: 15px 0; border-radius: 4px; }}
        .details p {{ margin: 8px 0; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
        .button {{ display: inline-block; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; margin: 10px 5px; }}
        .button-danger {{ background-color: #dc3545; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Security Alert</h1>
            <p>Email Change Requested</p>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>We received a request to change the email address for your Nutritionist App account.</p>
            
            <div class="details">
                <p><strong>Current Email:</strong> {old_email}</p>
                <p><strong>New Email Requested:</strong> {new_email}</p>
                <p><strong>Request Time:</strong> {request_time}</p>
            </div>
            
            <div class="alert-box">
                <p><strong>If you requested this change:</strong></p>
                <ul>
                    <li>Verify your new email address to complete the change</li>
                    <li>A verification code has been sent to <strong>{new_email}</strong></li>
                    <li><strong>No action is needed from this email</strong></li>
                </ul>
            </div>
            
            <div class="security-box">
                <p><strong>⚠️ If you did NOT request this change:</strong></p>
                <ul>
                    <li>Your account may be compromised</li>
                    <li>Cancel the email change immediately</li>
                    <li>Change your password</li>
                    <li>Contact support if needed</li>
                </ul>
            </div>
            
            <div class="info-box">
                <p><strong>To cancel this email change:</strong></p>
                <ol>
                    <li>Log into your account</li>
                    <li>Go to Account Settings</li>
                    <li>Cancel the pending email change</li>
                </ol>
            </div>
            
            <div class="footer">
                <p><strong>Important:</strong> This is a security notification. No verification code is required from this email address.</p>
                <p>The verification code has been sent to your new email address: <strong>{new_email}</strong></p>
                <p>Need help? Contact our support team.</p>
                <p>Best regards,<br>Nutritionist App Team</p>
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
        
        print(f"[SUCCESS] Email change notification sent to {old_email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send email change notification to {old_email}: {e}")
        return False

def send_password_change_verification(email: str, code: str, username: str = None) -> bool:
    """
    Send password change verification code to user's registered email address.
    
    Args:
        email: User's registered email address
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
        msg['Subject'] = 'Nutritionist App - Verify Your Password Change'
        msg['From'] = mail_username
        msg['To'] = email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        
        text_body = f"""Hi {name},

You requested to change your password for your Nutritionist App account.

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

⚠️ IMPORTANT: If you didn't request this password change, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.

Best regards,
Nutritionist App Team"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .code {{ background-color: #4CAF50; color: white; font-size: 32px; font-weight: bold; padding: 15px 30px; text-align: center; border-radius: 8px; margin: 20px 0; letter-spacing: 5px; }}
        .warning {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Password Change Verification</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>You requested to change your password for your Nutritionist App account.</p>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <div class="warning">
                <p><strong>⚠️ IMPORTANT:</strong> If you didn't request this password change, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.</p>
            </div>
            <div class="footer">
                <p>Best regards,<br>Nutritionist App Team</p>
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
        
        print(f"[SUCCESS] Password change verification email sent to {email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send password change verification email to {email}: {e}")
        return False

def send_password_reset_verification(email: str, code: str, username: str = None) -> bool:
    """
    Send password reset verification code to user's registered email address.
    
    Args:
        email: User's registered email address
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
        msg['Subject'] = 'Nutritionist App - Reset Your Password'
        msg['From'] = mail_username
        msg['To'] = email
        
        # Email body
        name = username or 'there'
        expiration_minutes = 15
        
        text_body = f"""Hi {name},

You requested to reset your password for your Nutritionist App account.

Your verification code is: {code}

This code will expire in {expiration_minutes} minutes.

After resetting your password, all your active sessions will be invalidated and you'll need to log in again with your new password.

⚠️ IMPORTANT: If you didn't request this password reset, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.

Best regards,
Nutritionist App Team"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }}
        .code {{ background-color: #4CAF50; color: white; font-size: 32px; font-weight: bold; padding: 15px 30px; text-align: center; border-radius: 8px; margin: 20px 0; letter-spacing: 5px; }}
        .warning {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }}
        .info {{ background-color: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin: 20px 0; }}
        .footer {{ margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Password Reset</h1>
        </div>
        <div class="content">
            <p>Hi {name},</p>
            <p>You requested to reset your password for your Nutritionist App account.</p>
            <p>Your verification code is:</p>
            <div class="code">{code}</div>
            <p>This code will expire in <strong>{expiration_minutes} minutes</strong>.</p>
            <div class="info">
                <p><strong>ℹ️ Note:</strong> After resetting your password, all your active sessions will be invalidated and you'll need to log in again with your new password.</p>
            </div>
            <div class="warning">
                <p><strong>⚠️ IMPORTANT:</strong> If you didn't request this password reset, please ignore this email and secure your account immediately. Contact our support team if you believe your account has been compromised.</p>
            </div>
            <div class="footer">
                <p>Best regards,<br>Nutritionist App Team</p>
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
        
        print(f"[SUCCESS] Password reset verification email sent to {email}")
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to send password reset verification email to {email}: {e}")
        return False

