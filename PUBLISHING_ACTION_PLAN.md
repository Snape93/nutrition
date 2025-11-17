# 📋 Publishing Action Plan - Next Steps

This is your step-by-step checklist to get your app published and live.

## ✅ Phase 1: Prerequisites (Do This First)

### 1.1 Set Up Required Accounts & Services

- [ ] **Neon Database** (if not already set up)
  - Sign up: https://neon.tech
  - Create a new project
  - Copy your database connection string
  - Format: `postgresql://user:password@host/database?sslmode=require`

- [ ] **Gmail App Password** (for email verification)
  - Go to: https://myaccount.google.com/security
  - Enable 2-Step Verification (if not already enabled)
  - Go to: https://myaccount.google.com/apppasswords
  - Generate an app password for "Mail"
  - Save the 16-character password

- [ ] **RapidAPI Key** (for ExerciseDB)
  - Sign up: https://rapidapi.com
  - Subscribe to ExerciseDB API (free tier available)
  - Copy your API key

- [ ] **Groq API Key** (optional, for AI Coach)
  - Sign up: https://console.groq.com
  - Get your API key from the dashboard
  - Free tier: ~14,400 requests/day

### 1.2 Generate Secret Key

- [ ] Generate a strong secret key for Flask:
  ```powershell
  python -c "import secrets; print(secrets.token_hex(32))"
  ```
  - Save this key securely (you'll need it for Railway)

---

## 🚀 Phase 2: Deploy Backend (Priority #1)

### 2.1 Deploy to Railway

- [ ] **Sign up for Railway**
  - Go to: https://railway.app
  - Sign up with GitHub (recommended)

- [ ] **Create New Project**
  - Click "New Project"
  - Select "Deploy from GitHub repo"
  - Choose: `Snape93/nutrition`
  - Railway will auto-detect Python

- [ ] **Configure Environment Variables**
  - Go to your project → **Variables** tab
  - Add these variables (use values from Phase 1):
    ```
    SECRET_KEY=<your-generated-secret-key>
    NEON_DATABASE_URL=<your-neon-connection-string>
    GMAIL_USERNAME=<your-email@gmail.com>
    GMAIL_APP_PASSWORD=<your-16-char-app-password>
    EXERCISEDB_API_KEY=<your-rapidapi-key>
    GROQ_API_KEY=<your-groq-key> (optional)
    FLASK_ENV=production
    ALLOWED_ORIGINS=* (we'll update this after web deployment)
    ```

- [ ] **Set Start Command**
  - Go to **Settings** → **Deploy**
  - Set Start Command: `gunicorn app:app --bind 0.0.0.0:$PORT`

- [ ] **Wait for Deployment**
  - Railway will automatically deploy
  - Check deployment logs for errors
  - Wait for "Deployment successful" message

- [ ] **Get Your Backend URL**
  - Go to **Settings** → **Domains**
  - Copy your Railway URL: `https://your-app-name.railway.app`
  - Test it: Visit `https://your-app-name.railway.app/api/health`
  - Should return a response

### 2.2 Test Backend

- [ ] **Test API Endpoints**
  - Open browser: `https://your-app-name.railway.app/api/health`
  - Should see a response
  - Check Railway logs for any errors

- [ ] **Keep Backend Awake** (Optional but Recommended)
  - Sign up for UptimeRobot (free): https://uptimerobot.com
  - Add monitor: `https://your-app-name.railway.app/api/health`
  - Set interval: 5 minutes
  - This prevents Railway from sleeping your app

---

## 🌐 Phase 3: Deploy Web App

### 3.1 Choose Platform

**Option A: Firebase Hosting (Recommended - Easiest)**

- [ ] **Install Firebase CLI**
  ```powershell
  npm install -g firebase-tools
  ```

- [ ] **Login to Firebase**
  ```powershell
  firebase login
  ```

- [ ] **Initialize Firebase**
  ```powershell
  cd nutrition_flutter
  firebase init hosting
  ```
  - Select: Use existing project or create new
  - Public directory: `build/web`
  - Single-page app: **Yes**
  - Overwrite index.html: **No**

- [ ] **Build and Deploy**
  ```powershell
  cd ..
  .\deploy_web.ps1 -BackendUrl "https://your-app-name.railway.app" -Platform "firebase"
  ```

- [ ] **Get Web App URL**
  - Firebase will provide: `https://your-app-name.web.app`
  - Test it in browser

**Option B: Vercel (Alternative)**

- [ ] **Install Vercel CLI**
  ```powershell
  npm install -g vercel
  ```

- [ ] **Deploy**
  ```powershell
  .\deploy_web.ps1 -BackendUrl "https://your-app-name.railway.app" -Platform "vercel"
  ```

### 3.2 Update CORS Settings

- [ ] **Update Railway Environment Variables**
  - Go back to Railway → Variables
  - Update `ALLOWED_ORIGINS`:
    ```
    ALLOWED_ORIGINS=https://your-app-name.web.app,https://your-app-name.vercel.app
    ```
  - Railway will redeploy automatically

---

## 📱 Phase 4: Build Mobile Apps

### 4.1 Build Android APK

- [ ] **Build APK**
  ```powershell
  .\build_android.ps1 -BackendUrl "https://your-app-name.railway.app" -BuildType "apk"
  ```

- [ ] **Find Your APK**
  - Location: `nutrition_flutter\build\app\outputs\flutter-apk\app-release.apk`
  - Also copied to root directory: `app-release.apk`

- [ ] **Test APK**
  - Install on Android device
  - Test login, registration, and main features
  - Verify it connects to your Railway backend

### 4.2 Build Android App Bundle (For Play Store)

- [ ] **Build App Bundle**
  ```powershell
  .\build_android.ps1 -BackendUrl "https://your-app-name.railway.app" -BuildType "appbundle"
  ```

- [ ] **Find Your AAB**
  - Location: `nutrition_flutter\build\app\outputs\bundle\release\app-release.aab`

### 4.3 iOS App (If Needed)

- [ ] **Note**: Requires Apple Developer account ($99/year)
- [ ] **Build iOS** (when ready):
  ```powershell
  cd nutrition_flutter
  flutter build ios --release --dart-define=API_BASE_URL=https://your-app-name.railway.app
  ```

---

## 📦 Phase 5: Distribute Your App

### 5.1 Web App Distribution

- [ ] **Share Your Web App**
  - URL: `https://your-app-name.web.app`
  - Share link with users
  - Add to your website/social media

### 5.2 Android App Distribution

**Option 1: Direct APK Distribution (Free)**

- [ ] **Upload APK to GitHub Releases**
  - Go to: https://github.com/Snape93/nutrition/releases
  - Click "Create a new release"
  - Upload `app-release.apk`
  - Users can download and install

- [ ] **Or Host on Your Website**
  - Upload APK to your web hosting
  - Create download link
  - Users install directly

**Option 2: Google Play Store ($25 one-time)**

- [ ] **Create Google Play Developer Account**
  - Go to: https://play.google.com/console
  - Pay $25 registration fee (one-time)

- [ ] **Prepare Store Listing**
  - App name, description, screenshots
  - Privacy policy URL (required)
  - App icon, feature graphic

- [ ] **Upload App Bundle**
  - Upload `app-release.aab` to Play Console
  - Fill out store listing
  - Submit for review

### 5.3 iOS App Distribution (If Applicable)

- [ ] **Apple Developer Account** ($99/year)
- [ ] **Upload to App Store Connect**
- [ ] **Submit for Review**

---

## 🔍 Phase 6: Testing & Quality Assurance

### 6.1 Test All Platforms

- [ ] **Test Web App**
  - [ ] Login/Registration
  - [ ] Food logging
  - [ ] Exercise tracking
  - [ ] Progress tracking
  - [ ] All features work correctly

- [ ] **Test Android App**
  - [ ] Install APK on device
  - [ ] Test all features
  - [ ] Check connectivity
  - [ ] Verify data syncs with backend

- [ ] **Test Backend API**
  - [ ] All endpoints respond correctly
  - [ ] Database connections work
  - [ ] Email sending works
  - [ ] Error handling works

### 6.2 Monitor & Debug

- [ ] **Set Up Error Tracking** (Optional)
  - Sign up for Sentry (free tier): https://sentry.io
  - Add to Flutter app
  - Monitor errors in production

- [ ] **Set Up Analytics** (Optional)
  - Firebase Analytics (free)
  - Track user behavior
  - Monitor app performance

---

## 📄 Phase 7: Legal & Documentation

### 7.1 Required Documents

- [ ] **Privacy Policy** (Required for app stores)
  - Create privacy policy document
  - Host it on your website
  - Link from app and store listings

- [ ] **Terms of Service** (Recommended)
  - Create terms of service
  - Host on your website

- [ ] **App Description**
  - Write compelling app description
  - List key features
  - Add screenshots

### 7.2 App Store Assets

- [ ] **App Icon** (1024x1024 for stores)
- [ ] **Screenshots** (various sizes)
- [ ] **Feature Graphic** (for Play Store)
- [ ] **Promotional Images**

---

## 🎯 Current Status Checklist

### Immediate Next Steps (Do These Now):

1. [ ] **Set up Neon Database** (if not done)
2. [ ] **Get Gmail App Password**
3. [ ] **Generate Flask Secret Key**
4. [ ] **Deploy to Railway** (most important!)
5. [ ] **Test backend URL**
6. [ ] **Deploy web app**
7. [ ] **Build Android APK**
8. [ ] **Test everything**

---

## 🆘 Need Help?

- **Backend Issues**: Check `railway_deploy.md`
- **Web Deployment**: Check `QUICK_DEPLOY.md`
- **Mobile App**: Check `MOBILE_APP_ACCESS_GUIDE.md`
- **Complete Guide**: Check `FREE_PUBLISHING_GUIDE.md`

---

## 📊 Progress Tracker

**Phase 1 (Prerequisites)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 2 (Backend)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 3 (Web App)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 4 (Mobile Apps)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 5 (Distribution)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 6 (Testing)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete
**Phase 7 (Legal)**: ⬜ Not Started / ⬜ In Progress / ⬜ Complete

---

**🎉 Once you complete Phase 2 (Backend Deployment), your app will be live and accessible!**

**Start with Phase 1, then move to Phase 2 - that's your priority!**

