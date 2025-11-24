# 🚀 Deploy to Render - Complete Guide

This guide will walk you through deploying your Nutrition app to Render, a modern cloud platform that offers free hosting for web services.

## 📋 Prerequisites

Before you begin, make sure you have:
- ✅ A GitHub account
- ✅ Your code pushed to a GitHub repository
- ✅ A Neon PostgreSQL database (free tier available at https://neon.tech)
- ✅ Gmail App Password (for email functionality)
- ✅ ExerciseDB API key (optional, has default)

---

## 🎯 Step 1: Prepare Your Repository

1. **Push your code to GitHub** (if not already done):
   ```powershell
   git add .
   git commit -m "Prepare for Render deployment"
   git push origin main
   ```

2. **Verify these files exist in your repo**:
   - ✅ `app.py` (Flask application)
   - ✅ `requirements.txt` (Python dependencies)
   - ✅ `Procfile` (start command)
   - ✅ `runtime.txt` (Python version)

---

## 🔧 Step 2: Create a Render Account

1. Go to https://render.com
2. Click **"Get Started for Free"**
3. Sign up with your GitHub account (recommended) or email
4. Verify your email if required

---

## 🗄️ Step 3: Set Up Database (Neon PostgreSQL)

If you don't have a Neon database yet:

1. Go to https://neon.tech
2. Sign up for a free account
3. Create a new project
4. Copy your database connection string (it looks like):
   ```
   postgresql://username:password@ep-xxxxx.region.aws.neon.tech/dbname?sslmode=require
   ```
5. **Save this URL** - you'll need it in Step 5

---

## 🚀 Step 4: Create Web Service on Render

1. **Go to Render Dashboard**: https://dashboard.render.com
2. Click **"New +"** → **"Web Service"**
3. **Connect your repository**:
   - If using GitHub, click **"Connect GitHub"**
   - Authorize Render to access your repositories
   - Select your Nutrition app repository
   - Click **"Connect"**

4. **Configure the service**:
   - **Name**: `nutrition-app` (or your preferred name)
   - **Region**: Choose closest to your users (e.g., `Oregon (US West)`)
   - **Branch**: `main` (or your default branch)
   - **Root Directory**: Leave empty (or `.` if your app is in a subdirectory)
   - **Runtime**: `Python 3`
   - **Build Command**: 
     ```
     pip install -r requirements.txt
     ```
   - **Start Command**: 
     ```
     gunicorn app:app --bind 0.0.0.0:$PORT --timeout 120
     ```
   - **Instance Type**: `Free` (or upgrade for better performance)

5. **Click "Create Web Service"**

---

## 🔐 Step 5: Configure Environment Variables

After creating the service, go to the **Environment** tab:

1. Click on your service name in the dashboard
2. Go to **"Environment"** tab (left sidebar)
3. Click **"Add Environment Variable"** for each of these:

### Required Variables:

```bash
# Flask Configuration
FLASK_ENV=production
SECRET_KEY=<generate-a-random-secret-key>
```

**Generate SECRET_KEY** (run in PowerShell):
```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

```bash
# Database (from Step 3)
NEON_DATABASE_URL=postgresql://username:password@ep-xxxxx.region.aws.neon.tech/dbname?sslmode=require

# Email Configuration
GMAIL_USERNAME=your-email@gmail.com
GMAIL_APP_PASSWORD=your-16-character-app-password

# CORS (for web app - adjust as needed)
ALLOWED_ORIGINS=*

# Optional: ExerciseDB API Key (has default, but recommended to set your own)
EXERCISEDB_API_KEY=your-exercisedb-api-key

# Optional: Groq AI (for AI Coach features)
GROQ_API_KEY=your-groq-api-key
```

### How to Get Gmail App Password:

1. Go to https://myaccount.google.com/security
2. Enable **2-Step Verification** (if not already enabled)
3. Go to https://myaccount.google.com/apppasswords
4. Select **"Mail"** and **"Other (Custom name)"**
5. Enter "Render Deployment" as the name
6. Click **"Generate"**
7. Copy the 16-character password (no spaces)
8. Use this as your `GMAIL_APP_PASSWORD`

---

## 🚀 Step 6: Deploy

1. After adding all environment variables, Render will **automatically start deploying**
2. Go to the **"Logs"** tab to watch the deployment progress
3. Wait for the build to complete (usually 2-5 minutes)
4. Look for: `Your service is live at https://your-app-name.onrender.com`

---

## ✅ Step 7: Verify Deployment

1. **Check the service URL**: 
   - Your app will be available at: `https://your-app-name.onrender.com`
   - Render provides this URL automatically

2. **Test the API**:
   - Visit: `https://your-app-name.onrender.com/api/health`
   - Should return: `{"status": "healthy"}` or similar

3. **Check logs**:
   - Go to **"Logs"** tab
   - Look for: `[INFO] Using config: production (Platform=Render)`
   - No error messages should appear

---

## 🔧 Step 8: Update Your Flutter App

Update your Flutter app to use the new Render URL:

1. Open `nutrition_flutter/lib/config.dart`
2. Update the backend URL:
   ```dart
   static const String baseUrl = 'https://your-app-name.onrender.com';
   ```
3. Rebuild your app:
   ```powershell
   cd nutrition_flutter
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

---

## 🎯 Render-Specific Features

### Auto-Deploy
- Render automatically deploys when you push to your connected branch
- No manual deployment needed!

### Free Tier Limits
- **Free tier**: Service spins down after 15 minutes of inactivity
- **First request** after spin-down may take 30-60 seconds (cold start)
- **Upgrade to paid** ($7/month) for always-on service

### Custom Domain
1. Go to **Settings** → **Custom Domains**
2. Add your domain
3. Follow DNS configuration instructions

### Environment Variables
- All environment variables are encrypted
- Can be updated without redeploying (just restart service)

---

## 🐛 Troubleshooting

### Service Won't Start

**Check logs** for these common issues:

1. **Missing Environment Variables**:
   ```
   ERROR: Missing required environment variables for production!
   ```
   - **Fix**: Add all required variables in Environment tab

2. **Database Connection Failed**:
   ```
   CRITICAL ERROR: Database initialization failed!
   ```
   - **Fix**: Verify `NEON_DATABASE_URL` is correct
   - Test connection string locally first

3. **Port Already in Use**:
   ```
   Address already in use
   ```
   - **Fix**: Make sure Start Command uses `$PORT` (Render sets this automatically)

4. **Module Not Found**:
   ```
   ModuleNotFoundError: No module named 'xxx'
   ```
   - **Fix**: Check `requirements.txt` includes all dependencies

### Service Spins Down (Free Tier)

**Problem**: Service unavailable after 15 minutes of inactivity

**Solutions**:
1. **Upgrade to paid tier** ($7/month) for always-on
2. **Use a ping service** (free):
   - Set up UptimeRobot (https://uptimerobot.com)
   - Ping your service every 5 minutes
   - Keeps service awake (may violate free tier terms)

### Slow First Request

**Problem**: First request after spin-down takes 30-60 seconds

**Solution**: This is normal for free tier. Upgrade to paid for faster cold starts.

### Build Fails

**Check**:
1. **Python version**: Verify `runtime.txt` has `python-3.11` (or compatible)
2. **Dependencies**: All packages in `requirements.txt` must be installable
3. **Build logs**: Check for specific error messages

---

## 📊 Monitoring

### View Logs
- **Real-time logs**: Go to **Logs** tab
- **Download logs**: Click **"Download Logs"** button

### Metrics
- **Free tier**: Basic metrics available
- **Paid tier**: Advanced metrics and alerts

### Health Checks
- Render automatically checks service health
- Service restarts if unhealthy

---

## 🔄 Updating Your App

1. **Make changes** to your code
2. **Commit and push** to GitHub:
   ```powershell
   git add .
   git commit -m "Update app"
   git push origin main
   ```
3. **Render auto-deploys** (watch in Logs tab)
4. **Verify** deployment succeeded

---

## 💰 Pricing

### Free Tier
- ✅ 750 hours/month (enough for always-on if you upgrade)
- ✅ 100GB bandwidth/month
- ✅ Automatic HTTPS
- ⚠️ Spins down after 15 min inactivity

### Starter Plan ($7/month)
- ✅ Always-on service
- ✅ Faster cold starts
- ✅ Priority support
- ✅ 100GB bandwidth/month

### Professional Plan ($25/month)
- ✅ Everything in Starter
- ✅ More resources
- ✅ Better performance

---

## 🆚 Render vs Railway

| Feature | Render | Railway |
|---------|--------|---------|
| Free Tier | ✅ Yes (spins down) | ✅ Yes (spins down) |
| Always-On | $7/month | $5/month |
| Auto-Deploy | ✅ Yes | ✅ Yes |
| Custom Domain | ✅ Free | ✅ Free |
| Database | ❌ Separate | ✅ Included option |
| Ease of Use | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 📚 Additional Resources

- **Render Docs**: https://render.com/docs
- **Python on Render**: https://render.com/docs/deploy-flask
- **Environment Variables**: https://render.com/docs/environment-variables
- **Custom Domains**: https://render.com/docs/custom-domains

---

## ✅ Deployment Checklist

Before going live, verify:

- [ ] All environment variables set
- [ ] Database connection working
- [ ] Service starts successfully
- [ ] API endpoints responding
- [ ] Logs show no errors
- [ ] Flutter app updated with new URL
- [ ] Tested on mobile device
- [ ] CORS configured correctly (if using web app)

---

## 🎉 You're Live!

Your app is now deployed on Render! 

**Your Render URL**: `https://your-app-name.onrender.com`

**Next Steps**:
1. Test all features thoroughly
2. Update your Flutter app with the new backend URL
3. Share your app with users
4. Monitor logs for any issues
5. Consider upgrading to paid tier for better performance

---

**Need Help?**
- Check Render logs for error messages
- Review this guide again
- Check Render documentation
- Verify all environment variables are set correctly






