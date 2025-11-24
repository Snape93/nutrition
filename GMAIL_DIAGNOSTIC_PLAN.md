# 🔍 Gmail Email Service Diagnostic Plan

## Problem
Gmail email sending is causing worker timeouts. Registration succeeds but email never sends.

## Possible Causes

### 1. **Gmail App Password Issues** (MOST LIKELY)
**Symptoms:**
- SMTP authentication fails
- "Invalid credentials" error
- Connection refused

**Possible Reasons:**
- App Password expired or revoked
- Wrong App Password in Railway
- App Password has spaces (should be removed)
- 2-Step Verification disabled

**Check:**
- Verify App Password is still valid: https://myaccount.google.com/apppasswords
- Check Railway Variables: `GMAIL_APP_PASSWORD` value
- Ensure no spaces in password

---

### 2. **Gmail Security Restrictions** (COMMON)
**Symptoms:**
- Connection timeout
- "Access denied" error
- SMTP connection hangs

**Possible Reasons:**
- Gmail blocking "less secure apps" (even with App Password)
- Account security alert triggered
- IP-based blocking (Railway IP flagged)
- Rate limiting (too many emails)

**Check:**
- Check Gmail account for security alerts
- Verify account is not locked
- Check if Railway IP is blocked

---

### 3. **SMTP Connection Timeout** (CURRENT ISSUE)
**Symptoms:**
- Worker timeout (30 seconds)
- No error logged
- Connection hangs

**Possible Reasons:**
- No timeout set on SMTP connection
- Gmail SMTP server slow to respond
- Network latency from Railway to Gmail
- Firewall blocking port 587

**Check:**
- Railway logs show timeout but no email error
- SMTP connection has no timeout parameter

---

### 4. **Gmail Account Issues**
**Symptoms:**
- Authentication works but sending fails
- "Account disabled" error

**Possible Reasons:**
- Account suspended
- Daily sending limit exceeded
- Account flagged for spam

**Check:**
- Verify Gmail account is active
- Check sending limits (500 emails/day for free accounts)

---

### 5. **Network/Firewall Issues**
**Symptoms:**
- Connection refused
- Timeout on connection

**Possible Reasons:**
- Railway network blocking SMTP
- Gmail blocking Railway IP range
- Port 587 blocked

**Check:**
- Test SMTP connection from Railway
- Check if alternative port (465) works

---

## 🔧 Diagnostic Steps

### Step 1: Check Railway Environment Variables
**Action:** Verify Gmail credentials are set correctly
**Location:** Railway Dashboard → Variables
**Check:**
- `GMAIL_USERNAME` = `team.nutritionapp@gmail.com` ✓
- `GMAIL_APP_PASSWORD` = `dbapoawpycutkiln` (verify this is correct)

---

### Step 2: Verify Gmail App Password
**Action:** Check if App Password is still valid
**Steps:**
1. Go to: https://myaccount.google.com/apppasswords
2. Check if "Nutrition App" (or similar) app password exists
3. If not, generate a new one
4. Update Railway Variables with new password

---

### Step 3: Check Gmail Account Status
**Action:** Verify account is not locked/restricted
**Steps:**
1. Log into: https://myaccount.google.com/security
2. Check for security alerts
3. Verify 2-Step Verification is enabled
4. Check account activity for suspicious activity

---

### Step 4: Test SMTP Connection
**Action:** Add diagnostic logging to email service
**What to check:**
- Can we connect to smtp.gmail.com:587?
- Does authentication succeed?
- Does email sending work?
- What's the exact error?

---

### Step 5: Check Railway Logs for Email Errors
**Action:** Look for specific Gmail/SMTP errors
**What to look for:**
- `[ERROR] Failed to send verification email`
- SMTP authentication errors
- Connection timeout errors
- Gmail-specific error messages

---

## 🎯 Most Likely Issues (Priority Order)

### 1. **No SMTP Timeout** (HIGH PROBABILITY)
- SMTP connection hangs indefinitely
- Gunicorn kills worker after 30s
- No error logged because connection never completes

**Fix:** Add timeout to SMTP connection

### 2. **Gmail App Password Invalid** (MEDIUM PROBABILITY)
- Password expired or revoked
- Wrong password in Railway
- Authentication fails silently

**Fix:** Regenerate App Password and update Railway

### 3. **Gmail Blocking Railway IP** (LOW-MEDIUM PROBABILITY)
- Gmail security system flags Railway IP
- Connection refused or delayed
- Requires Gmail account review

**Fix:** Check Gmail security alerts, may need to whitelist

### 4. **Network/Firewall Issues** (LOW PROBABILITY)
- Railway network blocking SMTP
- Port 587 blocked
- DNS resolution issues

**Fix:** Test connection, try alternative port (465 with SSL)

---

## 🔧 Recommended Fixes

### Fix 1: Add SMTP Timeout (IMMEDIATE)
Add timeout to prevent hanging:
```python
server = smtplib.SMTP(mail_server, mail_port, timeout=10)
```

### Fix 2: Make Email Non-Blocking (BEST)
Send email in background thread so it doesn't block response

### Fix 3: Improve Error Logging
Log detailed SMTP errors to diagnose issues

### Fix 4: Add Retry Logic
Retry email sending if it fails (with exponential backoff)

---

## 📋 Action Items

1. ⏳ **Check Railway Variables** - Verify Gmail credentials
2. ⏳ **Verify App Password** - Check if still valid
3. ⏳ **Add SMTP Timeout** - Prevent hanging connections
4. ⏳ **Make Email Non-Blocking** - Don't block registration response
5. ⏳ **Improve Error Logging** - See exact Gmail errors
6. ⏳ **Test Email Sending** - Verify it works after fixes

---

## 🚨 Quick Checks

**In Railway Dashboard:**
- Variables → Check `GMAIL_USERNAME` and `GMAIL_APP_PASSWORD`
- Logs → Search for "Failed to send verification email"
- Logs → Search for "SMTP" or "Gmail" errors

**In Gmail Account:**
- Security → Check for alerts
- App Passwords → Verify password exists
- Activity → Check for blocked login attempts

---

**Status:** Investigation needed
**Priority:** HIGH - Blocking user registration











