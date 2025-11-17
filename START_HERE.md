# 🚀 START HERE - Your Publishing Journey Begins Now!

## ⚡ Quick Start: What to Do RIGHT NOW

### Step 1: Prepare Your Credentials (15 minutes)

Before deploying, you need these ready:

1. **Neon Database URL** ✅ or ⬜
   - Sign up: https://neon.tech
   - Create project → Copy connection string
   - Format: `postgresql://user:pass@host/db?sslmode=require`

2. **Gmail App Password** ✅ or ⬜
   - Enable 2FA: https://myaccount.google.com/security
   - Get app password: https://myaccount.google.com/apppasswords
   - Save the 16-character password

3. **Flask Secret Key** ✅ or ⬜
   - Run this command:
   ```powershell
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
   - Copy the output (you'll need it)

4. **RapidAPI Key** ✅ or ⬜
   - Sign up: https://rapidapi.com
   - Subscribe to ExerciseDB API
   - Copy your API key

---

### Step 2: Deploy Backend to Railway (20 minutes) ⭐ PRIORITY

**This is the most important step!**

1. **Go to Railway**: https://railway.app
   - Sign up with GitHub

2. **Create Project**:
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose: `Snape93/nutrition`

3. **Add Environment Variables** (in Railway → Variables):
   ```
   SECRET_KEY=<paste-your-secret-key>
   NEON_DATABASE_URL=<paste-your-neon-url>
   GMAIL_USERNAME=<your-email@gmail.com>
   GMAIL_APP_PASSWORD=<your-16-char-password>
   EXERCISEDB_API_KEY=<your-rapidapi-key>
   FLASK_ENV=production
   ALLOWED_ORIGINS=*
   ```

4. **Set Start Command** (Settings → Deploy):
   ```
   gunicorn app:app --bind 0.0.0.0:$PORT
   ```

5. **Wait for Deployment** (2-5 minutes)
   - Check logs for errors
   - Get your URL from Settings → Domains

6. **Test It**:
   - Visit: `https://your-app-name.railway.app/api/health`
   - Should see a response ✅

**🎉 Congratulations! Your backend is now live!**

---

### Step 3: Deploy Web App (10 minutes)

**Option A: Firebase (Easiest)**

```powershell
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (in nutrition_flutter folder)
cd nutrition_flutter
firebase init hosting
# Select: build/web, Yes to single-page app

# Deploy (from root folder)
cd ..
.\deploy_web.ps1 -BackendUrl "https://your-app-name.railway.app" -Platform "firebase"
```

**Your web app will be live at**: `https://your-app-name.web.app`

---

### Step 4: Build Android APK (5 minutes)

```powershell
.\build_android.ps1 -BackendUrl "https://your-app-name.railway.app" -BuildType "apk"
```

**Your APK will be at**: `app-release.apk` (in root folder)

---

## 📋 Quick Checklist

- [ ] Neon database set up
- [ ] Gmail app password ready
- [ ] Secret key generated
- [ ] RapidAPI key ready
- [ ] **Backend deployed to Railway** ⭐
- [ ] Backend URL tested
- [ ] Web app deployed
- [ ] Android APK built
- [ ] Everything tested

---

## 🎯 Your Goal

**Get your backend live on Railway** - that's the #1 priority!

Once that's done, everything else is easy.

---

## 📚 Need More Details?

- **Full Action Plan**: See `PUBLISHING_ACTION_PLAN.md`
- **Railway Guide**: See `railway_deploy.md`
- **Quick Deploy**: See `QUICK_DEPLOY.md`
- **Complete Guide**: See `FREE_PUBLISHING_GUIDE.md`

---

## ⏱️ Time Estimate

- **Phase 1 (Credentials)**: 15 minutes
- **Phase 2 (Backend)**: 20 minutes
- **Phase 3 (Web App)**: 10 minutes
- **Phase 4 (Android)**: 5 minutes

**Total: ~50 minutes to get everything live!**

---

**🚀 Ready? Start with Step 1 above!**

