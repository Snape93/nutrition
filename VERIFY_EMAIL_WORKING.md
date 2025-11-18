# ✅ Email Verification Verification Guide

## Step 1: Verify Railway Deployment is Working

### 1.1 Check Railway URL
1. Go to **Railway Dashboard** → Your Service → **Settings** → **Domains**
2. Copy your actual Railway URL (should look like: `https://web-production-xxxx.up.railway.app`)
3. **Important**: Replace `your-railway-url.railway.app` with your actual URL

### 1.2 Test Health Endpoint
Try these URLs in your browser (replace with your actual Railway URL):

**Option 1:**
```
https://YOUR-ACTUAL-RAILWAY-URL.railway.app/health
```

**Option 2:**
```
https://YOUR-ACTUAL-RAILWAY-URL.railway.app/api/health
```

**Expected Response:**
```json
{
  "ok": true,
  "db": true,
  "model": true
}
```
OR
```json
{
  "status": "healthy",
  "message": "Nutrition API is running",
  "model_loaded": true
}
```

**If you get "Not Found":**
- Railway deployment might not be active
- Check Railway Dashboard → Deployments tab
- Make sure deployment shows "Active" or "Success"

---

## Step 2: Verify Environment Variables

Go to **Railway Dashboard** → Your Service → **Variables** tab

### Required Variables Checklist:
- [ ] `SECRET_KEY` - Set
- [ ] `NEON_DATABASE_URL` - Set (PostgreSQL connection string)
- [ ] `GMAIL_USERNAME` - Set (e.g., `team.nutritionapp@gmail.com`)
- [ ] `GMAIL_APP_PASSWORD` - Set (16-character app password, no spaces)
- [ ] `FLASK_ENV=production` - Set
- [ ] `ALLOWED_ORIGINS=*` - Set

### Test Email Configuration:
Visit this URL (replace with your Railway URL):
```
https://YOUR-RAILWAY-URL.railway.app/user/test/email/check-config
```

**Expected Response:**
```json
{
  "email_service_configured": true,
  "gmail_username_set": true,
  "gmail_password_set": true,
  "message": "Email service is configured"
}
```

**If `email_service_configured: false`:**
- Check `GMAIL_USERNAME` and `GMAIL_APP_PASSWORD` are set correctly
- Make sure there are no spaces in the app password
- Verify the Gmail app password is still valid

---

## Step 3: Test Registration Flow

### 3.1 Test Registration Endpoint
Use Postman, curl, or your browser's developer console:

**POST Request:**
```
URL: https://YOUR-RAILWAY-URL.railway.app/register
Method: POST
Headers: Content-Type: application/json
Body:
{
  "username": "testuser123",
  "email": "your-test-email@gmail.com",
  "password": "TestPassword123!",
  "age": 25
}
```

**Expected Response (201):**
```json
{
  "success": true,
  "message": "Registration pending. Please check your email for verification code.",
  "verification_required": true,
  "email": "your-test-email@gmail.com",
  "username": "testuser123",
  "expires_at": "2025-11-18T12:30:00"
}
```

**Check Railway Logs:**
1. Go to Railway Dashboard → Deployments → Latest → View Logs
2. Look for:
   - `[SUCCESS] Pending registration created`
   - `[SUCCESS] Verification email sent to ...`
   - OR `[ERROR] Failed to send verification email`

---

## Step 4: Verify Email is Sent

### 4.1 Check Your Email
1. Check the inbox of the email you used for registration
2. Look for email from `team.nutritionapp@gmail.com`
3. Subject: "Nutritionist App - Email Verification Code"
4. Should contain a 6-digit verification code

### 4.2 If Email Not Received:
1. **Check Spam/Junk folder**
2. **Check Railway Logs** for email errors:
   - `[ERROR] Failed to send verification email`
   - `[WARN] Verification email dispatch failed`
3. **Verify Gmail App Password:**
   - Go to https://myaccount.google.com/apppasswords
   - Make sure the app password is still valid
   - Generate a new one if needed
   - Update `GMAIL_APP_PASSWORD` in Railway Variables

---

## Step 5: Test Verification Code Endpoint

### 5.1 Verify Code
**POST Request:**
```
URL: https://YOUR-RAILWAY-URL.railway.app/auth/verify-code
Method: POST
Headers: Content-Type: application/json
Body:
{
  "email": "your-test-email@gmail.com",
  "code": "123456"
}
```

**Expected Response (200):**
```json
{
  "success": true,
  "message": "Email verified successfully. Account created.",
  "user": {
    "username": "testuser123",
    "email": "your-test-email@gmail.com"
  }
}
```

**If Code Invalid:**
- Make sure you're using the code from the email
- Check if code expired (15 minutes)
- Verify email matches the one used for registration

---

## Step 6: Test from Flutter App

### 6.1 Update Flutter Config
If your Railway URL changed, update `nutrition_flutter/lib/config.dart`:

```dart
defaultValue: 'https://YOUR-ACTUAL-RAILWAY-URL.railway.app',
```

### 6.2 Rebuild Flutter App
```bash
cd nutrition_flutter
flutter clean
flutter build apk
```

### 6.3 Test Registration
1. Open your Flutter app
2. Try to register a new account
3. Check if verification email is received
4. Enter verification code
5. Verify account is created

---

## Troubleshooting

### Problem: "Application not found"
**Solution:**
- Railway service is not deployed
- Go to Railway Dashboard → Deploy → Deploy the repo
- Wait for deployment to complete

### Problem: Health endpoint returns "Not Found"
**Solution:**
- Check Railway URL is correct
- Verify deployment is active
- Check Railway logs for errors

### Problem: Email not sending
**Solution:**
1. Check `GMAIL_USERNAME` and `GMAIL_APP_PASSWORD` in Railway Variables
2. Verify Gmail app password is valid
3. Check Railway logs for SMTP errors
4. Test email config endpoint: `/user/test/email/check-config`

### Problem: "Invalid verification code"
**Solution:**
- Code expires after 15 minutes
- Make sure you're using the latest code
- Check email matches registration email

### Problem: Registration succeeds but no email
**Solution:**
- Email is sent asynchronously (background thread)
- Check Railway logs for email errors
- Verify Gmail credentials are correct
- Check spam folder

---

## Quick Test Checklist

- [ ] Railway deployment is active
- [ ] Health endpoint works: `/health`
- [ ] Email config endpoint shows configured: `/user/test/email/check-config`
- [ ] Registration endpoint works: `/register`
- [ ] Railway logs show "Verification email sent"
- [ ] Email received in inbox
- [ ] Verification code endpoint works: `/auth/verify-code`
- [ ] Flutter app can register and verify

---

## Next Steps

Once all checks pass:
1. Test full registration flow in Flutter app
2. Test password change email verification
3. Test email change verification
4. Monitor Railway logs for any errors

