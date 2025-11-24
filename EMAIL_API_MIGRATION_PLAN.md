# 📧 Email API Migration Plan

## Goal
Switch from Gmail SMTP (blocked on Railway) to an Email API service (works on Railway free tier).

---

## Step 1: Choose Email API Service

### Comparison of Free Tier Options:

#### Option A: Resend (RECOMMENDED ⭐)
- **Free Tier:** 3,000 emails/month
- **Credit Card:** Not required
- **API:** Simple REST API
- **Setup:** Easy (5 minutes)
- **Sign up:** https://resend.com
- **Best for:** Quick setup, no credit card needed

#### Option B: Brevo (Sendinblue)
- **Free Tier:** 300 emails/day (9,000/month)
- **Credit Card:** Not required
- **API:** REST API
- **Setup:** Medium (10 minutes)
- **Sign up:** https://www.brevo.com
- **Best for:** Higher volume needs

#### Option C: SendGrid
- **Free Tier:** 100 emails/day (3,000/month)
- **Credit Card:** Required (but won't charge on free tier)
- **API:** REST API
- **Setup:** Medium (10 minutes)
- **Sign up:** https://sendgrid.com
- **Best for:** Established service, good documentation

#### Option D: Mailgun
- **Free Tier:** 5,000 emails/month (first 3 months), then 1,000/month
- **Credit Card:** Required (but won't charge on free tier)
- **API:** REST API
- **Setup:** Medium (10 minutes)
- **Sign up:** https://www.mailgun.com
- **Best for:** Developer-friendly

### **Recommendation: Resend**
- ✅ No credit card required
- ✅ 3,000 emails/month (plenty for testing)
- ✅ Simple API
- ✅ Good documentation
- ✅ Works perfectly on Railway

---

## Step 2: Sign Up & Get API Key

### For Resend:
1. Go to https://resend.com
2. Click "Sign Up" (can use GitHub/Google)
3. Verify email if needed
4. Go to "API Keys" section
5. Click "Create API Key"
6. Name it: "Nutrition App Production"
7. **Copy the API key** (you'll only see it once!)
8. Save it securely

### For Other Services:
- Similar process - sign up, verify email, create API key
- Each service has slightly different interface
- All will give you an API key to use

---

## Step 3: Update Railway Environment Variables

### Add to Railway Variables:
1. Go to Railway Dashboard → Your Service → Variables
2. Add new variable:
   - **Name:** `RESEND_API_KEY` (or `BREVO_API_KEY`, `SENDGRID_API_KEY`, etc.)
   - **Value:** Your API key from Step 2
3. Add variable to choose service:
   - **Name:** `EMAIL_SERVICE` 
   - **Value:** `resend` (or `brevo`, `sendgrid`, `mailgun`)
4. Keep existing variables:
   - `GMAIL_USERNAME` (for "From" email address)
   - Other variables stay the same

---

## Step 4: Code Changes Required

### Files to Modify:

#### A. `email_service.py`
**Current:** Uses `smtplib.SMTP()` to send emails
**New:** Use HTTP requests to email API

**Changes needed:**
1. Add new function: `send_email_via_api()`
   - Takes email content, recipient, subject
   - Makes POST request to email API
   - Handles authentication with API key
   - Returns success/failure

2. Update all email functions:
   - `send_verification_email()` → use API instead of SMTP
   - `send_email_change_verification()` → use API
   - `send_account_deletion_verification()` → use API
   - `send_email_change_notification()` → use API
   - `send_password_change_verification()` → use API
   - `send_password_reset_verification()` → use API

3. Keep same function signatures (no changes to `app.py` needed)

#### B. `requirements.txt`
**Add new dependency:**
- `requests` (if not already there) - for HTTP API calls

#### C. `app.py`
**No changes needed!** 
- All email functions keep same interface
- Just calls different backend (API instead of SMTP)

---

## Step 5: Implementation Details

### Email API Request Format (Resend Example):

**Endpoint:** `https://api.resend.com/emails`
**Method:** POST
**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```
**Body:**
```json
{
  "from": "Nutrition App <team.nutritionapp@gmail.com>",
  "to": ["user@example.com"],
  "subject": "Nutritionist App - Email Verification Code",
  "html": "<html>...</html>",
  "text": "Plain text version..."
}
```

### Error Handling:
- Network errors (timeout, connection failed)
- API errors (invalid key, rate limit, etc.)
- Parse response to check success/failure
- Log errors for debugging

### Fallback Strategy:
- If API fails, log error and return False
- Registration still succeeds (email sent async)
- User can request resend if email not received

---

## Step 6: Testing Plan

### Test Checklist:
1. ✅ Sign up for email API service
2. ✅ Add API key to Railway Variables
3. ✅ Deploy updated code
4. ✅ Test registration → check if email sent
5. ✅ Check email inbox for verification code
6. ✅ Test verification code works
7. ✅ Test all email types (registration, password reset, etc.)
8. ✅ Check Railway logs for API errors
9. ✅ Verify email API dashboard shows sent emails

### Test Scenarios:
- **Happy path:** Registration → Email sent → Code works
- **Error handling:** Invalid API key → Error logged → Registration still succeeds
- **Rate limiting:** Send many emails → Check if rate limit handled
- **Email format:** HTML and plain text both work

---

## Step 7: Migration Steps

### Phase 1: Setup (5 minutes)
1. Sign up for Resend
2. Get API key
3. Add to Railway Variables

### Phase 2: Code Update (30 minutes)
1. Update `email_service.py` to use API
2. Add `requests` to `requirements.txt` if needed
3. Test locally (optional)

### Phase 3: Deploy (5 minutes)
1. Commit changes
2. Push to GitHub
3. Railway auto-deploys
4. Monitor logs

### Phase 4: Verify (5 minutes)
1. Test registration
2. Check email received
3. Verify code works
4. Check Railway logs

**Total Time: ~45 minutes**

---

## Step 8: Rollback Plan

### If Something Goes Wrong:
1. **Keep old SMTP code** (don't delete, just comment out)
2. **Add feature flag:** `USE_EMAIL_API` environment variable
3. **If API fails:** Can switch back to SMTP (for local testing)
4. **Monitor logs:** Watch for API errors

### Quick Rollback:
- Set `USE_EMAIL_API=false` in Railway
- Redeploy
- Falls back to SMTP (won't work on Railway, but code still there)

---

## Step 9: Cost Analysis

### Free Tier Limits:
- **Resend:** 3,000 emails/month
- **Brevo:** 9,000 emails/month
- **SendGrid:** 3,000 emails/month

### Your App Usage:
- Registration emails: ~10-50/month (testing)
- Password resets: ~5-20/month
- Email changes: ~1-5/month
- **Total:** Well under 100 emails/month

### Conclusion:
✅ **Free tier is MORE than enough** for your needs
✅ **No cost** for foreseeable future
✅ **Can upgrade later** if needed (but unlikely)

---

## Step 10: Benefits of Email API

### Advantages:
1. ✅ **Works on Railway** (no SMTP blocking)
2. ✅ **More reliable** (dedicated email service)
3. ✅ **Better deliverability** (less likely to go to spam)
4. ✅ **Analytics** (see if emails delivered, opened, etc.)
5. ✅ **No Gmail dependency** (don't need Gmail app password)
6. ✅ **Scalable** (can handle more emails easily)

### Disadvantages:
1. ❌ **External dependency** (need internet connection)
2. ❌ **API key management** (need to keep secure)
3. ❌ **Rate limits** (but free tier is plenty)

---

## Step 11: Security Considerations

### API Key Security:
- ✅ Store in Railway Variables (encrypted)
- ✅ Never commit to Git
- ✅ Rotate keys periodically
- ✅ Use different keys for dev/prod (if needed)

### Email Content:
- ✅ Keep same email templates
- ✅ No sensitive data in emails
- ✅ Verification codes only (already secure)

---

## Step 12: Documentation Updates

### Files to Update:
1. `RAILWAY_ENV_VARIABLES.txt` - Add new variables
2. `SETUP_GMAIL.md` - Update or create `SETUP_EMAIL_API.md`
3. `README.md` - Update email setup instructions

### New Documentation:
- How to get Resend API key
- How to add to Railway
- How to test email sending

---

## Summary

### What We're Doing:
- Switching from SMTP (blocked) to Email API (works)
- Using Resend (free, no credit card, 3,000 emails/month)
- Minimal code changes (just `email_service.py`)
- No changes to `app.py` (same interface)

### Timeline:
- **Setup:** 5 minutes
- **Code:** 30 minutes
- **Deploy:** 5 minutes
- **Test:** 5 minutes
- **Total:** ~45 minutes

### Risk Level:
- **Low** - Email API is standard practice
- **Reversible** - Can rollback if needed
- **Tested** - Many apps use this approach

### Next Steps:
1. Choose service (Resend recommended)
2. Sign up and get API key
3. Add to Railway Variables
4. Update `email_service.py`
5. Deploy and test

---

## Questions to Answer Before Coding:

1. **Which service?** → Resend (recommended)
2. **Keep Gmail?** → Yes, use Gmail address as "From" (but send via API)
3. **Test locally?** → Optional, can test directly on Railway
4. **Feature flag?** → Optional, but good for safety
5. **Error handling?** → Yes, log errors, don't block registration

---

**Status:** Ready to implement
**Priority:** High (blocking email verification)
**Estimated Time:** 45 minutes
**Risk:** Low











