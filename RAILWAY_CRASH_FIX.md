# 🔧 Railway Crash - Troubleshooting Guide

## Your Service Crashed - Let's Fix It!

The deployment built successfully but the service crashed when trying to start. This usually means:

1. **Missing environment variables** (most common)
2. **Start command not set correctly**
3. **Database connection issue**
4. **Missing dependencies**

---

## ✅ Quick Fix Steps

### Step 1: Check Environment Variables

Go to Railway → Your Project → **Variables** tab

**Make sure you have ALL these variables:**

```
✅ SECRET_KEY=bbc58109f8c55315934146dcc0a83751f97050889f03d907cf3012133136eceb
✅ NEON_DATABASE_URL=postgresql://neondb_owner:npg_9OjQXmcEB3Vn@ep-curly-tooth-a17bgdzr-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
✅ GMAIL_USERNAME=team.nutritionapp@gmail.com
✅ GMAIL_APP_PASSWORD=dbapoawpycutkiln
✅ FLASK_ENV=production
✅ ALLOWED_ORIGINS=*
```

**If any are missing, add them now!**

---

### Step 2: Set Start Command

Go to Railway → Your Project → **Settings** → **Deploy** section

**Make sure Start Command is set to:**
```
gunicorn app:app --bind 0.0.0.0:$PORT
```

**If it's not set, add it now!**

---

### Step 3: Check Logs

1. Click **"View logs"** button in Railway
2. Look for error messages at the bottom
3. Common errors:
   - "SECRET_KEY not set"
   - "Database connection failed"
   - "Module not found"
   - "Port already in use"

---

### Step 4: Restart Service

After fixing environment variables and start command:

1. Click the **"Restart"** button
2. Wait for deployment to complete
3. Check if it's running

---

## 🔍 Common Crash Reasons

### 1. Missing SECRET_KEY
**Error:** "SECRET_KEY environment variable must be set"
**Fix:** Add SECRET_KEY to Variables

### 2. Missing Database URL
**Error:** "NEON_DATABASE_URL must be set for production"
**Fix:** Add NEON_DATABASE_URL to Variables

### 3. Start Command Not Set
**Error:** Service starts but immediately crashes
**Fix:** Set start command to `gunicorn app:app --bind 0.0.0.0:$PORT`

### 4. Database Connection Failed
**Error:** "Connection refused" or "SSL required"
**Fix:** Check NEON_DATABASE_URL is correct, ensure SSL mode is set

### 5. Port Issue
**Error:** "Address already in use"
**Fix:** Make sure start command uses `$PORT` (Railway sets this automatically)

---

## 📋 Checklist

- [ ] All environment variables added
- [ ] Start command set correctly
- [ ] Checked logs for specific errors
- [ ] Restarted service after fixes
- [ ] Service is now running

---

## 🆘 Still Not Working?

1. **Check the logs** - They'll tell you exactly what's wrong
2. **Verify all variables** - Make sure no typos
3. **Test database connection** - Make sure Neon database is accessible
4. **Check requirements.txt** - Make sure all dependencies are listed

---

**Most likely issue: Missing environment variables or start command not set!**

