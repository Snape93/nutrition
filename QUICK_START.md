# Email Verification - Quick Start Guide

## ✅ Step 1: Database Migration - COMPLETE!
Your database has been updated with the email verification fields.

## 🔧 Step 2: Set Up Gmail SMTP (5 minutes)

### A. Enable 2-Step Verification
1. Visit: https://myaccount.google.com/security
2. Enable "2-Step Verification"
3. Complete the setup

### B. Generate App Password
1. Visit: https://myaccount.google.com/apppasswords
2. Select "Mail" → "Other (Custom name)" → Type "Nutrition App"
3. Click "Generate"
4. **Copy the 16-character password** (save it now - you can only see it once!)

### C. Create .env File
Create a file named `.env` in your project root (same folder as `app.py`) with:

```env
GMAIL_USERNAME=your-email@gmail.com
GMAIL_APP_PASSWORD=your-16-char-app-password-here
```

**Replace:**
- `your-email@gmail.com` with your actual Gmail
- `your-16-char-app-password-here` with the App Password from step B

## 🧪 Step 3: Test Email Setup

Run this command:
```bash
python test_email_verification.py
```

This will:
- ✅ Check if credentials are configured
- ✅ Send a test verification email
- ✅ Show you the verification code

## 🚀 Step 4: Test Full Flow

1. **Start your Flask server:**
   ```bash
   python app.py
   ```

2. **Start your Flutter app:**
   ```bash
   cd nutrition_flutter
   flutter run
   ```

3. **Test registration:**
   - Register a new user
   - Check your email for the 6-digit code
   - Enter the code in the app
   - Verify you can log in

## 📋 Checklist

- [x] Database migration complete
- [ ] Gmail 2-Step Verification enabled
- [ ] App Password generated
- [ ] `.env` file created with credentials
- [ ] Test email script runs successfully
- [ ] Registration sends verification email
- [ ] Verification code works
- [ ] Login works after verification

## 🆘 Need Help?

- **Detailed Gmail setup:** See `SETUP_GMAIL.md`
- **Full implementation details:** See `EMAIL_VERIFICATION_IMPLEMENTATION.md`
- **Troubleshooting:** Check the troubleshooting section in `SETUP_GMAIL.md`

## 🎯 What's Next?

Once email verification is working:
1. Test with real users
2. Monitor email delivery
3. Consider production email service (SendGrid/AWS SES) for higher volume

---

**Ready to test!** Start with Step 2 above. 🚀

