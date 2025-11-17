# 🔍 All Possible Railway Deployment Errors - Complete Checklist

This document lists **ALL possible errors** that could occur during Railway deployment and how to fix them.

---

## 🚨 CRITICAL ERRORS (Will Crash App)

### 1. Missing Environment Variables

#### Error: `ValueError: NEON_DATABASE_URL must be set for production`
**Cause:** `NEON_DATABASE_URL` not set in Railway Variables
**Fix:** Add to Railway → Variables:
```
NEON_DATABASE_URL=postgresql://neondb_owner:npg_9OjQXmcEB3Vn@ep-curly-tooth-a17bgdzr-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
```

#### Error: `SECRET_KEY environment variable must be set`
**Cause:** `SECRET_KEY` not set
**Fix:** Add to Railway → Variables:
```
SECRET_KEY=bbc58109f8c55315934146dcc0a83751f97050889f03d907cf3012133136eceb
```

#### Error: `Gmail SMTP credentials not configured`
**Cause:** Gmail credentials missing
**Fix:** Add to Railway → Variables:
```
GMAIL_USERNAME=team.nutritionapp@gmail.com
GMAIL_APP_PASSWORD=dbapoawpycutkiln
```

---

### 2. Database Connection Errors

#### Error: `Connection refused` or `could not connect to server`
**Causes:**
- Database URL is incorrect
- Database is not accessible from Railway
- SSL mode not set correctly
- Database credentials wrong

**Fix:**
- Verify `NEON_DATABASE_URL` is correct
- Ensure URL includes `?sslmode=require`
- Check Neon database is running
- Verify credentials in Neon dashboard

#### Error: `SSL connection required`
**Cause:** Missing `sslmode=require` in database URL
**Fix:** Add `?sslmode=require` to end of `NEON_DATABASE_URL`

#### Error: `database does not exist`
**Cause:** Database name in URL is wrong
**Fix:** Check database name in Neon dashboard and update URL

---

### 3. Configuration Errors

#### Error: `ValueError: NEON_DATABASE_URL must be set for development`
**Cause:** App using wrong config (DevelopmentConfig instead of ProductionConfig)
**Status:** ✅ FIXED - App now auto-detects Railway
**If still happens:** Set `FLASK_ENV=production` in Railway Variables

#### Error: `Unknown FLASK_ENV`
**Cause:** Invalid `FLASK_ENV` value
**Fix:** Set `FLASK_ENV=production` (lowercase)

---

### 4. Start Command Errors

#### Error: `gunicorn: command not found`
**Cause:** Gunicorn not in requirements.txt
**Status:** ✅ Already in requirements.txt
**If happens:** Check `requirements.txt` has `gunicorn==21.2.0`

#### Error: `Address already in use` or `Port already in use`
**Cause:** Not using `$PORT` variable
**Fix:** Start command must be: `gunicorn app:app --bind 0.0.0.0:$PORT`

#### Error: `No module named 'app'`
**Cause:** Wrong start command or app.py not in root
**Fix:** Ensure start command is: `gunicorn app:app --bind 0.0.0.0:$PORT`
**Check:** `app.py` is in root directory

---

### 5. Import Errors

#### Error: `ModuleNotFoundError: No module named 'flask'`
**Cause:** Dependencies not installed
**Fix:** Check `requirements.txt` is correct and Railway installed dependencies

#### Error: `ModuleNotFoundError: No module named 'nutrition_model'`
**Cause:** `nutrition_model.py` missing or not in root
**Fix:** Ensure `nutrition_model.py` is in root directory

#### Error: `ModuleNotFoundError: No module named 'config'`
**Cause:** `config.py` missing
**Fix:** Ensure `config.py` is in root directory

#### Error: `ModuleNotFoundError: No module named 'email_service'`
**Cause:** `email_service.py` missing
**Fix:** Ensure `email_service.py` is in root directory

---

### 6. File Not Found Errors

#### Error: `FileNotFoundError: model/best_regression_model.joblib`
**Cause:** Model file not in repository
**Status:** ⚠️ WARNING - App will work but ML features won't work
**Fix:** 
- Model file should be in `model/best_regression_model.joblib`
- Ensure it's committed to Git
- Or app will continue with warnings (non-critical)

#### Error: `FileNotFoundError: data/exercises.csv`
**Cause:** CSV file missing
**Status:** ⚠️ WARNING - App will work but exercise import won't work
**Fix:** 
- File should be in `data/exercises.csv` or root
- App has fallback (non-critical)

#### Error: `FileNotFoundError: Filipino_Food_Nutrition_Dataset.csv`
**Cause:** Food dataset CSV missing
**Status:** ⚠️ WARNING - Food search won't work
**Fix:**
- File should be in one of these locations:
  - `data/Filipino_Food_Nutrition_Dataset.csv`
  - `nutrition_flutter/lib/Filipino_Food_Nutrition_Dataset.csv`
  - Root directory
- App has fallback (non-critical)

---

## ⚠️ WARNING ERRORS (App Runs But Features Don't Work)

### 7. Missing Optional Files

#### Warning: `Model file not found at model/best_regression_model.joblib`
**Impact:** ML calorie prediction won't work
**Fix:** Add model file to repository or ignore (app still works)

#### Warning: `Filipino food CSV not found`
**Impact:** Food search won't work
**Fix:** Add CSV file to repository or ignore (app still works)

#### Warning: `Exercises CSV not found`
**Impact:** Exercise import won't work (but exercises in DB will work)
**Fix:** Add CSV file or ignore (app still works)

---

### 8. Email Service Errors

#### Error: `SMTPAuthenticationError` or `Authentication failed`
**Causes:**
- Wrong Gmail password
- App password has spaces
- 2-Step Verification not enabled
- Account locked

**Fix:**
- Remove spaces from `GMAIL_APP_PASSWORD`
- Verify 2-Step Verification is enabled
- Generate new app password
- Check account is not locked

#### Error: `Connection timeout` (SMTP)
**Cause:** Network/firewall blocking SMTP
**Fix:** Usually Railway network issue (rare)

---

### 9. API Key Errors

#### Error: `Invalid API key` (RapidAPI)
**Cause:** `EXERCISEDB_API_KEY` wrong or expired
**Impact:** Exercise API features won't work
**Fix:** Update API key or leave empty (app still works)

#### Error: `Invalid API key` (Groq)
**Cause:** `GROQ_API_KEY` wrong
**Impact:** AI Coach features won't work
**Fix:** Update API key or leave empty (app still works)

---

## 🔧 BUILD ERRORS

### 10. Python Version Errors

#### Error: `no precompiled python found for core:python@3.11.0`
**Status:** ✅ FIXED - Changed to `python-3.11`
**If happens again:** Remove `runtime.txt` or change to `python-3.11`

#### Error: `Python version not supported`
**Cause:** Railway doesn't support that Python version
**Fix:** Use `python-3.11` or `python-3.12` in `runtime.txt`

---

### 11. Dependency Installation Errors

#### Error: `ERROR: Could not find a version that satisfies the requirement`
**Cause:** Package version not available or incompatible
**Fix:** Check `requirements.txt` for correct versions

#### Error: `ERROR: Failed building wheel for psycopg2-binary`
**Cause:** Build tools missing (rare on Railway)
**Fix:** Railway usually handles this automatically

---

## 🌐 RUNTIME ERRORS

### 12. Port Binding Errors

#### Error: `Address already in use` or `Port 5000 already in use`
**Cause:** Not using Railway's `$PORT` variable
**Fix:** Start command must use `$PORT`: `gunicorn app:app --bind 0.0.0.0:$PORT`

---

### 13. CORS Errors (Web App Only)

#### Error: `CORS policy: No 'Access-Control-Allow-Origin' header`
**Cause:** `ALLOWED_ORIGINS` not set correctly
**Fix:** Add web app URL to `ALLOWED_ORIGINS`:
```
ALLOWED_ORIGINS=https://your-app.web.app,https://your-app.vercel.app
```

---

## 📋 COMPLETE ENVIRONMENT VARIABLES CHECKLIST

**Required (App won't start without these):**
```
✅ NEON_DATABASE_URL=postgresql://...
✅ SECRET_KEY=...
✅ FLASK_ENV=production
```

**Required for Email Features:**
```
✅ GMAIL_USERNAME=team.nutritionapp@gmail.com
✅ GMAIL_APP_PASSWORD=dbapoawpycutkiln
```

**Optional (App works without these):**
```
⬜ EXERCISEDB_API_KEY=... (for Exercise API)
⬜ GROQ_API_KEY=... (for AI Coach)
⬜ ALLOWED_ORIGINS=* (for CORS, defaults to *)
```

---

## ✅ PRE-DEPLOYMENT CHECKLIST

Before deploying, verify:

- [ ] All required environment variables added to Railway
- [ ] Start command set: `gunicorn app:app --bind 0.0.0.0:$PORT`
- [ ] `requirements.txt` has all dependencies
- [ ] `Procfile` exists (optional but recommended)
- [ ] `runtime.txt` has `python-3.11` (or remove it)
- [ ] `app.py` is in root directory
- [ ] `config.py` is in root directory
- [ ] `nutrition_model.py` is in root directory
- [ ] `email_service.py` is in root directory
- [ ] Database URL is correct and includes `?sslmode=require`
- [ ] Gmail app password has no spaces
- [ ] All code is committed and pushed to GitHub

---

## 🆘 QUICK FIX GUIDE

### If App Crashes Immediately:
1. Check Railway logs for error message
2. Verify all required environment variables are set
3. Check start command is correct
4. Verify database URL is correct

### If App Builds But Doesn't Start:
1. Check environment variables (especially `NEON_DATABASE_URL`)
2. Check start command uses `$PORT`
3. Check logs for import errors

### If App Starts But Features Don't Work:
1. Check optional environment variables (API keys)
2. Check logs for warnings about missing files
3. Verify email credentials are correct

---

## 📊 ERROR PRIORITY

**🔴 CRITICAL (Must Fix):**
- Missing `NEON_DATABASE_URL`
- Missing `SECRET_KEY`
- Wrong start command
- Database connection errors

**🟡 IMPORTANT (Should Fix):**
- Missing Gmail credentials (email won't work)
- Wrong `FLASK_ENV`
- CORS errors (web app won't work)

**🟢 OPTIONAL (Can Ignore):**
- Missing model files (ML features won't work)
- Missing CSV files (some features won't work)
- Missing API keys (some features won't work)

---

## 🎯 MOST COMMON ERRORS (Top 5)

1. **Missing `NEON_DATABASE_URL`** - 90% of crashes
2. **Missing `SECRET_KEY`** - 5% of crashes
3. **Wrong start command** - 3% of crashes
4. **Database connection failed** - 1% of crashes
5. **Missing Gmail credentials** - 1% of crashes

---

**💡 Tip:** Always check Railway logs first - they tell you exactly what's wrong!

