"""Email service for sending verification emails via SMTP"""
import smtplib
import secrets
import logging
import re
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from typing import Optional
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logger = logging.getLogger(__name__)

# Constants
VERIFICATION_CODE_LENGTH = 6
VERIFICATION_CODE_MIN = 100000
VERIFICATION_CODE_MAX = 999999
VERIFICATION_CODE_EXPIRATION_MINUTES = 15
DEFAULT_SMTP_TIMEOUT = 15.0
DEFAULT_MAIL_SERVER = 'smtp.gmail.com'
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')


def _truthy(value: Optional[str]) -> bool:
    """Check if a value is truthy (1, true, yes, on)."""
    if value is None:
        return False
    return str(value).strip().lower() in {'1', 'true', 'yes', 'on'}


def _get_smtp_timeout() -> float:
    """Resolve SMTP timeout (seconds) with safe fallback."""
    try:
        timeout = os.environ.get('SMTP_TIMEOUT_SECONDS', str(DEFAULT_SMTP_TIMEOUT))
        return float(timeout)
    except (TypeError, ValueError):
        logger.warning(f"Invalid SMTP_TIMEOUT_SECONDS, using default: {DEFAULT_SMTP_TIMEOUT}")
        return DEFAULT_SMTP_TIMEOUT


def _validate_email(email: str) -> bool:
    """Validate email address format."""
    if not email or not isinstance(email, str):
        return False
    return bool(EMAIL_REGEX.match(email.strip()))


def _get_mail_username() -> str:
    """Get mail username from environment, fail if not configured."""
    mail_username = os.environ.get('GMAIL_USERNAME')
    if not mail_username:
        error_msg = "GMAIL_USERNAME environment variable is required for email service"
        logger.error(error_msg)
        if not EMAIL_TEST_MODE:
            raise ValueError(error_msg)
        logger.warning("EMAIL_TEST_MODE enabled, continuing without GMAIL_USERNAME")
        return ''
    return mail_username


SMTP_TIMEOUT = _get_smtp_timeout()
EMAIL_TEST_MODE = _truthy(os.environ.get('EMAIL_TEST_MODE'))
EMAIL_TEST_LOG = os.environ.get(
    'EMAIL_TEST_LOG',
    os.path.join(os.path.dirname(__file__), 'instance', 'email_test_log.jsonl')
)

def _send_email_via_smtp(msg: MIMEMultipart, mail_server: str, mail_username: str, mail_password: str) -> bool:
    """
    Send email via SMTP with fallback to port 465 (SSL) if port 587 (TLS) fails.
    
    Args:
        msg: MIMEMultipart message object
        mail_server: SMTP server address
        mail_username: SMTP username
        mail_password: SMTP password
        
    Returns:
        True if email sent successfully, False otherwise
    """
    # Try port 587 (TLS) first
    try:
        logger.info(f"Attempting SMTP connection to {mail_server}:587 (TLS)...")
        with smtplib.SMTP(mail_server, 587, timeout=SMTP_TIMEOUT) as server:
            server.starttls()
            server.login(mail_username, mail_password)
            server.send_message(msg)
        logger.info(f"Email sent successfully via port 587 (TLS)")
        return True
    except (OSError, ConnectionError, smtplib.SMTPException) as e:
        error_msg = str(e)
        error_code = getattr(e, 'errno', None)
        
        # Check if it's a network error (port 587 blocked)
        if error_code == 101 or 'Network is unreachable' in error_msg or 'Connection refused' in error_msg:
            logger.warning(f"Port 587 (TLS) failed: {error_msg}. Trying port 465 (SSL) as fallback...")
            
            # Try port 465 (SSL) as fallback
            try:
                logger.info(f"Attempting SMTP connection to {mail_server}:465 (SSL)...")
                import ssl
                context = ssl.create_default_context()
                with smtplib.SMTP_SSL(mail_server, 465, timeout=SMTP_TIMEOUT, context=context) as server:
                    server.login(mail_username, mail_password)
                    server.send_message(msg)
                logger.info(f"Email sent successfully via port 465 (SSL)")
                return True
            except Exception as ssl_error:
                logger.error(f"Port 465 (SSL) also failed: {ssl_error}")
                logger.error("Both SMTP ports (587 and 465) failed. Network may be blocking SMTP connections.")
                return False
        else:
            # Other errors (authentication, etc.)
            logger.error(f"SMTP connection failed: {error_msg}")
            return False
    except Exception as e:
        logger.exception(f"Unexpected error sending email: {e}")
        return False

def send_verification_email(email: str, code: str, username: Optional[str] = None) -> bool:
    """
    Send verification code email via SMTP.
    
    Args:
        email: Recipient email address
        code: 6-digit verification code
        username: Optional username for personalization
        
    Returns:
        True if email sent successfully, False otherwise
    """
    try:
        # Validate email address
        if not _validate_email(email):
            logger.error(f"Invalid email address format: {email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        # Email body
        name = username or 'there'
        expiration_minutes = VERIFICATION_CODE_EXPIRATION_MINUTES
        
        subject = 'Nutritionist App - Email Verification Code'
        
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, email, subject, html_body, text_body)
        if success:
            logger.info(f"Verification email sent successfully to {email}")
        else:
            logger.error(f"Failed to send verification email to {email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send verification email to {email}: {e}")
        return False

def _record_test_email(to_email: str, subject: str, text_body: str, html_body: str) -> None:
    """Save email contents to a log file when EMAIL_TEST_MODE is enabled."""
    if not EMAIL_TEST_MODE:
        return
    try:
        log_dir = os.path.dirname(EMAIL_TEST_LOG)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        payload = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'to': to_email,
            'subject': subject,
            'text': text_body,
            'html': html_body,
        }
        with open(EMAIL_TEST_LOG, 'a', encoding='utf-8') as fp:
            fp.write(json.dumps(payload) + '\n')
        logger.debug(f"Test email logged to {EMAIL_TEST_LOG}")
    except Exception as err:
        logger.warning(f"Failed to log test email: {err}")


def _send_email_with_fallback(from_email: str, to_email: str, subject: str, html_body: str, text_body: str) -> bool:
    """
    Send email via SMTP using TLS first, then SSL if needed.
    
    Args:
        from_email: Sender email address
        to_email: Recipient email address
        subject: Email subject
        html_body: HTML email content
        text_body: Plain text email content
        
    Returns:
        True if email sent successfully, False otherwise
    """
    # Validate recipient email
    if not _validate_email(to_email):
        logger.error(f"Invalid recipient email address format: {to_email}")
        return False
    
    mail_server = os.environ.get('MAIL_SERVER', DEFAULT_MAIL_SERVER)
    mail_password = os.environ.get('GMAIL_APP_PASSWORD')
    
    if not from_email or not mail_password:
        error_msg = "Email not configured. Set GMAIL_USERNAME and GMAIL_APP_PASSWORD environment variables."
        logger.error(error_msg)
        if EMAIL_TEST_MODE:
            logger.info("EMAIL_TEST_MODE=1, simulating email delivery.")
            _record_test_email(to_email, subject, text_body, html_body)
            return True
        return False
    
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = from_email
    msg['To'] = to_email
    
    part1 = MIMEText(text_body, 'plain')
    part2 = MIMEText(html_body, 'html')
    msg.attach(part1)
    msg.attach(part2)
    
    sent = _send_email_via_smtp(msg, mail_server, from_email, mail_password)
    if sent:
        _record_test_email(to_email, subject, text_body, html_body)
        return True
    
    if EMAIL_TEST_MODE:
        logger.warning("SMTP failed but EMAIL_TEST_MODE is enabled. Recording email and continuing.")
        _record_test_email(to_email, subject, text_body, html_body)
        return True
    
    return False


def generate_verification_code() -> str:
    """
    Generate a cryptographically secure 6-digit verification code.
    
    Returns:
        A 6-digit string code (100000-999999)
    """
    code = secrets.randbelow(VERIFICATION_CODE_MAX - VERIFICATION_CODE_MIN + 1) + VERIFICATION_CODE_MIN
    return str(code)

def send_email_change_verification(new_email: str, code: str, old_email: Optional[str] = None, username: Optional[str] = None) -> bool:
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
        # Validate email address
        if not _validate_email(new_email):
            logger.error(f"Invalid new email address format: {new_email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        subject = 'Nutritionist App - Verify Your New Email Address'
        
        # Email body
        name = username or 'there'
        expiration_minutes = VERIFICATION_CODE_EXPIRATION_MINUTES
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, new_email, subject, html_body, text_body)
        if success:
            logger.info(f"Email change verification email sent successfully to {new_email}")
        else:
            logger.error(f"Failed to send email change verification email to {new_email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send email change verification email to {new_email}: {e}")
        return False

def send_account_deletion_verification(email: str, code: str, username: Optional[str] = None) -> bool:
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
        # Validate email address
        if not _validate_email(email):
            logger.error(f"Invalid email address format: {email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        subject = 'Nutritionist App - Confirm Account Deletion'
        
        # Email body
        name = username or 'there'
        expiration_minutes = VERIFICATION_CODE_EXPIRATION_MINUTES
        
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, email, subject, html_body, text_body)
        if success:
            logger.info(f"Account deletion verification email sent successfully to {email}")
        else:
            logger.error(f"Failed to send account deletion verification email to {email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send account deletion verification email to {email}: {e}")
        return False

def send_email_change_notification(old_email: str, new_email: str, username: Optional[str] = None, timestamp: Optional[str] = None) -> bool:
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
        # Validate email addresses
        if not _validate_email(old_email):
            logger.error(f"Invalid old email address format: {old_email}")
            return False
        if not _validate_email(new_email):
            logger.error(f"Invalid new email address format: {new_email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        subject = '🔒 Security Alert: Email Change Requested for Your Account'
        
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, old_email, subject, html_body, text_body)
        if success:
            logger.info(f"Email change notification sent successfully to {old_email}")
        else:
            logger.error(f"Failed to send email change notification to {old_email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send email change notification to {old_email}: {e}")
        return False

def send_password_change_verification(email: str, code: str, username: Optional[str] = None) -> bool:
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
        # Validate email address
        if not _validate_email(email):
            logger.error(f"Invalid email address format: {email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        subject = 'Nutritionist App - Verify Your Password Change'
        
        # Email body
        name = username or 'there'
        expiration_minutes = VERIFICATION_CODE_EXPIRATION_MINUTES
        
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, email, subject, html_body, text_body)
        if success:
            logger.info(f"Password change verification email sent successfully to {email}")
        else:
            logger.error(f"Failed to send password change verification email to {email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send password change verification email to {email}: {e}")
        return False

def send_password_reset_verification(email: str, code: str, username: Optional[str] = None) -> bool:
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
        # Validate email address
        if not _validate_email(email):
            logger.error(f"Invalid email address format: {email}")
            return False
        
        # Get email configuration
        mail_username = _get_mail_username()
        if not mail_username and not EMAIL_TEST_MODE:
            return False
        
        subject = 'Nutritionist App - Reset Your Password'
        
        # Email body
        name = username or 'there'
        expiration_minutes = VERIFICATION_CODE_EXPIRATION_MINUTES
        
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
        
        # Send email via SMTP
        success = _send_email_with_fallback(mail_username, email, subject, html_body, text_body)
        if success:
            logger.info(f"Password reset verification email sent successfully to {email}")
        else:
            logger.error(f"Failed to send password reset verification email to {email}")
        return success
        
    except Exception as e:
        logger.exception(f"Failed to send password reset verification email to {email}: {e}")
        return False

