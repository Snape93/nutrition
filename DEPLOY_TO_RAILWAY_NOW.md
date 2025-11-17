# 🚀 Deploy to Railway - Step-by-Step Guide

## ✅ Prerequisites (You Have These!)

- ✅ Gmail credentials configured
- ✅ Neon database URL ready
- ✅ SECRET_KEY generated
- ✅ .env file updated

---

## 📋 Step-by-Step Deployment

### Step 1: Go to Railway (2 minutes)

1. **Open your browser** and go to: **https://railway.app**

2. **Sign up / Log in**
   - Click "Start a New Project" or "Login"
   - **Recommended**: Sign up with GitHub (easiest)
   - Authorize Railway to access your GitHub account

---

### Step 2: Create New Project (1 minute)

1. **Click "New Project"** (big button on dashboard)

2. **Select "Deploy from GitHub repo"**
   - You'll see a list of your GitHub repositories

3. **Select your repository**: `Snape93/nutrition`
   - Railway will automatically detect it's a Python app
   - It will start deploying automatically (but we need to configure it first)

---

### Step 3: Configure Environment Variables (5 minutes) ⭐ MOST IMPORTANT

1. **Go to your project** in Railway dashboard

2. **Click on "Variables" tab** (in the left sidebar or top menu)

3. **Add each environment variable** by clicking "New Variable" or "+":

   **Variable 1: SECRET_KEY**
   ```
   Name: SECRET_KEY
   Value: bbc58109f8c55315934146dcc0a83751f97050889f03d907cf3012133136eceb
   ```

   **Variable 2: NEON_DATABASE_URL**
   ```
   Name: NEON_DATABASE_URL
   Value: postgresql://neondb_owner:npg_9OjQXmcEB3Vn@ep-curly-tooth-a17bgdzr-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
   ```

   **Variable 3: GMAIL_USERNAME**
   ```
   Name: GMAIL_USERNAME
   Value: team.nutritionapp@gmail.com
   ```

   **Variable 4: GMAIL_APP_PASSWORD**
   ```
   Name: GMAIL_APP_PASSWORD
   Value: dbapoawpycutkiln
   ```

   **Variable 5: FLASK_ENV**
   ```
   Name: FLASK_ENV
   Value: production
   ```

   **Variable 6: ALLOWED_ORIGINS**
   ```
   Name: ALLOWED_ORIGINS
   Value: *
   ```

   **Variable 7: EXERCISEDB_API_KEY** (if you have it)
   ```
   Name: EXERCISEDB_API_KEY
   Value: <your-rapidapi-key-if-you-have-it>
   ```

   **Variable 8: GROQ_API_KEY** (optional, if you have it)
   ```
   Name: GROQ_API_KEY
   Value: <your-groq-key-if-you-have-it>
   ```

4. **Save all variables** - Railway will automatically redeploy when you add variables

---

### Step 4: Set Start Command (2 minutes)

1. **Go to "Settings"** tab (in your project)

2. **Scroll down to "Deploy" section**

3. **Find "Start Command"** field

4. **Enter this command:**
   ```
   gunicorn app:app --bind 0.0.0.0:$PORT
   ```

5. **Save** - Railway will redeploy automatically

---

### Step 5: Wait for Deployment (3-5 minutes)

1. **Go to "Deployments" tab** to see deployment progress

2. **Watch the logs** - You should see:
   - Building Python environment
   - Installing dependencies
   - Starting gunicorn
   - "Deployment successful" ✅

3. **If there are errors**, check the logs:
   - Missing environment variables?
   - Import errors?
   - Database connection issues?

---

### Step 6: Get Your Backend URL (1 minute)

1. **Go to "Settings" tab**

2. **Click on "Domains" section**

3. **You'll see your Railway URL** like:
   ```
   https://your-app-name.railway.app
   ```

4. **Copy this URL** - You'll need it for:
   - Testing your backend
   - Building your Flutter app
   - Deploying your web app

---

### Step 7: Test Your Backend (2 minutes)

1. **Open your Railway URL** in browser:
   ```
   https://your-app-name.railway.app/api/health
   ```

2. **You should see a response** (JSON or text)

3. **If it works**, your backend is live! 🎉

4. **If it doesn't work**:
   - Check Railway logs for errors
   - Verify all environment variables are set
   - Make sure deployment completed successfully

---

## 🎯 Quick Copy-Paste Checklist

Use this to make sure you add all variables:

```
✅ SECRET_KEY=bbc58109f8c55315934146dcc0a83751f97050889f03d907cf3012133136eceb
✅ NEON_DATABASE_URL=postgresql://neondb_owner:npg_9OjQXmcEB3Vn@ep-curly-tooth-a17bgdzr-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
✅ GMAIL_USERNAME=team.nutritionapp@gmail.com
✅ GMAIL_APP_PASSWORD=dbapoawpycutkiln
✅ FLASK_ENV=production
✅ ALLOWED_ORIGINS=*
```

---

## 🆘 Troubleshooting

### Deployment fails

**Check:**
- All environment variables are added correctly
- No typos in variable names or values
- Start command is set correctly

### Backend URL doesn't work

**Check:**
- Deployment completed successfully
- Check Railway logs for errors
- Verify database connection (check NEON_DATABASE_URL)

### Database connection errors

**Check:**
- NEON_DATABASE_URL is correct
- Database is accessible from Railway
- SSL mode is set correctly

### Email not sending

**Check:**
- GMAIL_USERNAME is correct
- GMAIL_APP_PASSWORD has no spaces
- 2-Step Verification is enabled on Gmail

---

## ✅ Success Checklist

- [ ] Railway account created
- [ ] Project created from GitHub
- [ ] All environment variables added
- [ ] Start command set
- [ ] Deployment successful
- [ ] Backend URL obtained
- [ ] Backend tested and working

---

## 🎉 What's Next?

Once your backend is live:

1. **Test it**: Visit `https://your-app-name.railway.app/api/health`
2. **Build Flutter app**: Use `build_android.ps1` with your Railway URL
3. **Deploy web app**: Use `deploy_web.ps1` with your Railway URL
4. **Keep it awake**: Set up UptimeRobot (optional but recommended)

---

## 📝 Notes

- **Free tier**: Railway gives you $5 credit/month (about 500 hours)
- **Sleep mode**: App may sleep after 30 min inactivity (wakes on request)
- **Logs**: Check Railway logs if something doesn't work
- **Updates**: Railway auto-deploys when you push to GitHub

---

**🚀 Ready? Go to https://railway.app and start deploying!**

**Need help? Check the logs in Railway dashboard or refer to `railway_deploy.md`**

