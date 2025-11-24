# 🎯 Next Steps: Deploy to Render - Step by Step

Follow these steps in order to deploy your app to Render.

---

## ✅ Step 1: Generate SECRET_KEY (Do This First!)

Open PowerShell in your project folder and run:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

**Copy the output** - you'll need it in Step 5!

**Example output:**
```
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

---

## 🌐 Step 2: Sign Up for Render

1. **Open your browser** and go to: https://render.com
2. Click the **"Get Started for Free"** button (top right)
3. **Sign up with GitHub** (recommended):
   - Click **"Sign up with GitHub"**
   - Authorize Render to access your GitHub account
   - This makes connecting your repo easier later

**OR** sign up with email if you prefer.

---

## 🔗 Step 3: Connect Your GitHub Repository

1. After signing up, you'll see the Render Dashboard
2. Click the **"New +"** button (top right, blue button)
3. Select **"Web Service"** from the dropdown menu
4. You'll see a page to connect your repository:
   - If you signed up with GitHub, you'll see a list of your repositories
   - **Find and click on**: `Snape93/nutrition`
   - Click **"Connect"** next to it

**If you don't see your repo:**
- Click **"Configure account"** to grant more permissions
- Or click **"Connect GitHub"** to authorize Render

---

## ⚙️ Step 4: Configure Your Web Service

After connecting your repository, you'll see a configuration form. Fill it out like this:

### Basic Settings:
- **Name**: `nutrition-app` (or any name you like)
- **Region**: Choose the closest to your users:
  - `Oregon (US West)` - for US West Coast
  - `Frankfurt (EU Central)` - for Europe
  - `Singapore (AP Southeast)` - for Asia
- **Branch**: `main` (should be selected by default)
- **Root Directory**: Leave **empty** (your app is in the root)

### Build & Start Settings:
- **Runtime**: Select **`Python 3`** from dropdown
- **Build Command**: 
  ```
  pip install -r requirements.txt
  ```
- **Start Command**: 
  ```
  gunicorn app:app --bind 0.0.0.0:$PORT --timeout 120
  ```

### Instance Type:
- Select **`Free`** (you can upgrade later if needed)

### Click "Create Web Service"

**⚠️ Don't worry if it fails initially** - we need to add environment variables first!

---

## 🔐 Step 5: Add Environment Variables

After creating the service, you'll be on the service dashboard. 

1. **Click on the "Environment" tab** (left sidebar)
2. **Click "Add Environment Variable"** button
3. Add each variable one by one:

### Variable 1: FLASK_ENV
- **Key**: `FLASK_ENV`
- **Value**: `production`
- Click **"Save Changes"**

### Variable 2: SECRET_KEY
- **Key**: `SECRET_KEY`
- **Value**: Paste the SECRET_KEY you generated in Step 1
- Click **"Save Changes"**

### Variable 3: NEON_DATABASE_URL
- **Key**: `NEON_DATABASE_URL`
- **Value**: Your Neon database connection string
  - If you already have one from Railway, use that
  - If not, go to https://neon.tech and create a free database
  - Copy the connection string (looks like: `postgresql://user:pass@ep-xxx.region.aws.neon.tech/dbname?sslmode=require`)
- Click **"Save Changes"**

### Variable 4: GMAIL_USERNAME
- **Key**: `GMAIL_USERNAME`
- **Value**: Your Gmail address (e.g., `your-email@gmail.com`)
- Click **"Save Changes"**

### Variable 5: GMAIL_APP_PASSWORD
- **Key**: `GMAIL_APP_PASSWORD`
- **Value**: Your Gmail App Password (16 characters, no spaces)
  - **Don't have one?** See instructions below ⬇️
- Click **"Save Changes"**

### Variable 6: ALLOWED_ORIGINS
- **Key**: `ALLOWED_ORIGINS`
- **Value**: `*` (asterisk)
- Click **"Save Changes"**

### Optional Variables (if you have them):
- **EXERCISEDB_API_KEY**: Your ExerciseDB API key
- **GROQ_API_KEY**: Your Groq AI API key (for AI Coach features)

---

## 📧 How to Get Gmail App Password

If you don't have a Gmail App Password yet:

1. Go to: https://myaccount.google.com/security
2. Make sure **2-Step Verification** is enabled (if not, enable it first)
3. Go to: https://myaccount.google.com/apppasswords
4. You might need to sign in again
5. Under "Select app", choose **"Mail"**
6. Under "Select device", choose **"Other (Custom name)"**
7. Type: `Render Deployment`
8. Click **"Generate"**
9. **Copy the 16-character password** (it will look like: `abcd efgh ijkl mnop`)
10. **Remove the spaces** when pasting into Render (should be: `abcdefghijklmnop`)

---

## 🚀 Step 6: Watch the Deployment

After adding all environment variables:

1. **Go to the "Logs" tab** (left sidebar)
2. You'll see the deployment starting automatically
3. **Watch the logs** - you should see:
   ```
   Cloning repository...
   Installing dependencies...
   Building...
   Starting service...
   ```
4. **Wait 2-5 minutes** for the build to complete
5. Look for a message like:
   ```
   Your service is live at https://nutrition-app.onrender.com
   ```

**⚠️ If you see errors:**
- Check that all environment variables are set correctly
- Make sure SECRET_KEY and NEON_DATABASE_URL are valid
- Check the logs for specific error messages

---

## ✅ Step 7: Test Your Deployment

1. **Copy your app URL** from the Render dashboard (top of the page)
   - It will be: `https://nutrition-app.onrender.com` (or your chosen name)

2. **Test the health endpoint:**
   - Open a new browser tab
   - Go to: `https://your-app-name.onrender.com/api/health`
   - You should see: `{"status": "healthy"}` or similar

3. **Check the logs** for any errors:
   - Go back to Render dashboard
   - Click "Logs" tab
   - Look for `[INFO] Using config: production (Platform=Render)`
   - No red error messages should appear

---

## 📱 Step 8: Update Your Flutter App

Once your backend is live, update your Flutter app to use the new URL:

1. **Open**: `nutrition_flutter/lib/config.dart`
2. **Find the line**:
   ```dart
   static const String baseUrl = 'https://your-old-url.com';
   ```
3. **Replace with**:
   ```dart
   static const String baseUrl = 'https://your-app-name.onrender.com';
   ```
   (Use your actual Render URL)

4. **Save the file**

5. **Rebuild your app** (if needed):
   ```powershell
   cd nutrition_flutter
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

---

## 🎉 You're Done!

Your app is now deployed on Render! 

**Your Render URL**: `https://your-app-name.onrender.com`

---

## 🆘 Troubleshooting

### Service Won't Start
- **Check logs** in Render dashboard
- **Verify all environment variables** are set correctly
- **Make sure SECRET_KEY** is a valid hex string (64 characters)
- **Verify NEON_DATABASE_URL** is correct

### Database Connection Failed
- **Test your Neon database URL** locally first
- **Make sure** the URL includes `?sslmode=require`
- **Check** that your Neon database is active

### Build Fails
- **Check** that `requirements.txt` is in your repository
- **Verify** Python version in `runtime.txt` is `python-3.11`
- **Look at logs** for specific package installation errors

### Service Spins Down (Free Tier)
- This is normal - free tier spins down after 15 minutes of inactivity
- **First request** after spin-down may take 30-60 seconds
- **Upgrade to paid** ($7/month) for always-on service

---

## 📚 Need More Help?

- **Full Guide**: See `DEPLOY_TO_RENDER.md`
- **Quick Reference**: See `RENDER_QUICK_START.md`
- **Render Docs**: https://render.com/docs

---

## ✅ Checklist

Before considering deployment complete:

- [ ] SECRET_KEY generated and added
- [ ] All environment variables added to Render
- [ ] Service deployed successfully
- [ ] Health endpoint responds correctly
- [ ] Logs show no errors
- [ ] Flutter app updated with new backend URL
- [ ] Tested API endpoints

---

**Good luck with your deployment! 🚀**






