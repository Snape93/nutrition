# Railway Deployment Guide

Quick guide to deploy your Flask backend to Railway for free.

## Prerequisites

1. GitHub account (recommended) or Railway account
2. Your code pushed to GitHub (or ready to deploy)

## Step-by-Step Deployment

### Option 1: Deploy from GitHub (Recommended)

1. **Sign up for Railway**
   - Go to https://railway.app
   - Sign up with GitHub (easiest)

2. **Create New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - Railway will auto-detect it's a Python app

3. **Configure Environment Variables**
   - Go to your project → Variables tab
   - Add all variables from your `.env` file:
     ```
     SECRET_KEY=your-secret-key-here
     NEON_DATABASE_URL=postgresql://...
     GMAIL_USERNAME=your-email@gmail.com
     GMAIL_APP_PASSWORD=your-app-password
     EXERCISEDB_API_KEY=your-key
     GROQ_API_KEY=your-key (optional)
     FLASK_ENV=production
     ```

4. **Configure Start Command**
   - Go to Settings → Deploy
   - Set Start Command: `gunicorn app:app --bind 0.0.0.0:$PORT`
   - Railway automatically sets `$PORT` environment variable

5. **Deploy**
   - Railway will automatically deploy
   - Wait for deployment to complete
   - Get your app URL from the Settings → Domains tab

### Option 2: Deploy with Railway CLI

1. **Install Railway CLI**
   ```powershell
   # Windows (PowerShell)
   iwr https://railway.app/install.sh | iex
   ```

2. **Login**
   ```powershell
   railway login
   ```

3. **Initialize Project**
   ```powershell
   railway init
   ```

4. **Set Environment Variables**
   ```powershell
   railway variables set SECRET_KEY=your-secret-key
   railway variables set NEON_DATABASE_URL=postgresql://...
   # ... add all other variables
   ```

5. **Deploy**
   ```powershell
   railway up
   ```

## Important Files for Railway

### Create `Procfile` (optional, Railway auto-detects)
```
web: gunicorn app:app --bind 0.0.0.0:$PORT
```

### Create `runtime.txt` (optional, Railway auto-detects)
```
python-3.11.0
```

### Update `requirements.txt` (ensure gunicorn is included)
```
gunicorn==21.2.0
# ... your other dependencies
```

## Post-Deployment

1. **Get Your App URL**
   - Railway provides: `https://your-app-name.railway.app`
   - You can also add custom domain in Settings → Domains

2. **Test Your API**
   ```powershell
   curl https://your-app-name.railway.app/api/health
   # or test in browser
   ```

3. **Update Flutter App**
   - Update `lib/config.dart` or use build flags:
   ```powershell
   flutter build web --dart-define=API_BASE_URL=https://your-app-name.railway.app
   ```

## Troubleshooting

### App sleeps after inactivity
- **Solution**: Use UptimeRobot (free) to ping your app every 5 minutes
- **URL**: https://uptimerobot.com
- **Monitor URL**: `https://your-app-name.railway.app/api/health`

### Database connection errors
- Check `NEON_DATABASE_URL` is correct
- Ensure SSL mode is enabled: `?sslmode=require`
- Check Railway logs: `railway logs`

### Build fails
- Check Railway logs for errors
- Ensure all dependencies are in `requirements.txt`
- Verify Python version compatibility

### CORS errors
- Update CORS in `app.py` to allow your Flutter app domains:
  ```python
  CORS(app, resources={
      r"/*": {
          "origins": [
              "https://your-flutter-app.web.app",
              "https://your-flutter-app.vercel.app",
          ]
      }
  })
  ```

## Free Tier Limits

- **$5 credit/month** (about 500 hours of runtime)
- **Sleeps after 30 min** of inactivity
- **Wakes automatically** on next request (may take 10-30 seconds)

## Upgrade Options

If you need:
- **No sleep**: Upgrade to Hobby plan ($5/month)
- **More resources**: Upgrade to Pro plan ($20/month)

## Monitoring

- View logs: Railway dashboard → Deployments → View logs
- Monitor usage: Railway dashboard → Usage tab
- Set up alerts: Railway dashboard → Settings → Notifications

