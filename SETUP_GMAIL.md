# Gmail SMTP Setup Guide

## Quick Setup Steps

### Step 1: Enable 2-Step Verification
1. Go to https://myaccount.google.com/security
2. Find "2-Step Verification" and click it
3. Follow the prompts to enable it (you'll need your phone)

### Step 2: Generate App Password
1. Go to https://myaccount.google.com/apppasswords
   - If you don't see this link, make sure 2-Step Verification is enabled first
2. Under "Select app", choose **"Mail"**
3. Under "Select device", choose **"Other (Custom name)"**
4. Type: **"Nutrition App"**
5. Click **"Generate"**
6. **Copy the 16-character password** (it looks like: `abcd efgh ijkl mnop`)
   - ⚠️ You can only see this once! Save it immediately.

### Step 3: Add to .env File

Create a `.env` file in your project root (if it doesn't exist) and add:

```env
# Gmail SMTP Configuration
GMAIL_USERNAME=your-email@gmail.com
GMAIL_APP_PASSWORD=abcdefghijklmnop
```

**Important:**
- Replace `your-email@gmail.com` with your actual Gmail address
- Replace `abcdefghijklmnop` with the 16-character App Password (remove spaces if any)
- The `.env` file should be in the same directory as `app.py`

### Step 4: Test the Setup

Run the test script:
```bash
python test_email_verification.py
```

This will:
- Check if credentials are configured
- Send a test verification email
- Show you the verification code

## Troubleshooting

### "App passwords" option not showing
- Make sure 2-Step Verification is enabled first
- Wait a few minutes after enabling 2-Step Verification
- Try refreshing the page

### "Invalid credentials" error
- Make sure you're using the **App Password**, not your regular Gmail password
- Check that there are no extra spaces in the password
- Verify the email address is correct

### Email not sending
- Check your internet connection
- Verify the App Password is correct
- Make sure Gmail account is not locked or restricted
- Check server logs for detailed error messages

### Test email not received
- Check spam/junk folder
- Wait a minute or two (Gmail can be slow)
- Verify the email address is correct
- Check if Gmail has any security alerts

## Security Notes

- ✅ App Passwords are safer than using your main password
- ✅ You can revoke App Passwords anytime from Google Account settings
- ✅ Each App Password is unique and can be deleted independently
- ⚠️ Never commit `.env` file to git (it should be in `.gitignore`)

## Next Steps

Once the test email works:
1. ✅ Email verification is ready to use
2. Test the full registration flow in your app
3. Register a new user and check for the verification email

