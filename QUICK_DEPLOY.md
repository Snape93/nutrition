# Quick Deploy Guide - Get Your App Live in 30 Minutes

## 🚀 Fastest Path to Production

### Step 1: Deploy Backend (10 minutes)

1. **Sign up for Railway** (free): https://railway.app
   - Click "Start a New Project"
   - Select "Deploy from GitHub repo"
   - Connect your repository

2. **Add Environment Variables** in Railway dashboard:
   ```
   SECRET_KEY=<generate-a-random-secret-key>
   NEON_DATABASE_URL=<your-neon-database-url>
   GMAIL_USERNAME=<your-email@gmail.com>
   GMAIL_APP_PASSWORD=<your-gmail-app-password>
   EXERCISEDB_API_KEY=<your-rapidapi-key>
   FLASK_ENV=production
   ```

3. **Set Start Command** (in Settings → Deploy):
   ```
   gunicorn app:app --bind 0.0.0.0:$PORT
   ```

4. **Deploy** - Railway will auto-deploy
5. **Copy your app URL**: `https://your-app-name.railway.app`

### Step 2: Deploy Web App (10 minutes)

**Option A: Firebase (Easiest)**

1. Install Firebase CLI:
   ```powershell
   npm install -g firebase-tools
   ```

2. Login and initialize:
   ```powershell
   firebase login
   cd nutrition_flutter
   firebase init hosting
   # Select: Use existing project or create new
   # Public directory: build/web
   # Single-page app: Yes
   ```

3. Build and deploy:
   ```powershell
   .\deploy_web.ps1 -BackendUrl "https://your-app-name.railway.app" -Platform "firebase"
   ```

**Option B: Vercel (Alternative)**

1. Install Vercel CLI:
   ```powershell
   npm install -g vercel
   ```

2. Build and deploy:
   ```powershell
   .\deploy_web.ps1 -BackendUrl "https://your-app-name.railway.app" -Platform "vercel"
   ```

### Step 3: Build Android APK (5 minutes)

```powershell
.\build_android.ps1 -BackendUrl "https://your-app-name.railway.app" -BuildType "apk"
```

The APK will be in:
- `nutrition_flutter\build\app\outputs\flutter-apk\app-release.apk`
- Also copied to root directory

### Step 4: Test Everything (5 minutes)

1. ✅ Test web app: Open your Firebase/Vercel URL
2. ✅ Test Android: Install APK on device
3. ✅ Test API: Visit `https://your-app-name.railway.app/api/health`

## 📱 Distribution Options

### Web App
- **URL**: Your Firebase/Vercel URL
- **Share**: Send link to users

### Android App
- **Option 1**: Upload APK to GitHub Releases
- **Option 2**: Host on your website
- **Option 3**: Google Play Store ($25 one-time fee)

### iOS App
- Requires Apple Developer account ($99/year)
- Use TestFlight for beta testing

## 🔧 Troubleshooting

### Backend not responding
- Check Railway logs
- Verify environment variables are set
- Test API endpoint in browser

### CORS errors
- Update CORS in `app.py` to include your web app domain
- Or use `CORS(app, resources={r"/*": {"origins": "*"}})` for testing (not recommended for production)

### Build fails
- Run `flutter clean && flutter pub get`
- Check Flutter version: `flutter --version`
- Ensure all dependencies are installed

## 📚 Next Steps

1. **Set up monitoring**: Use UptimeRobot (free) to keep backend awake
2. **Add analytics**: Firebase Analytics (free)
3. **Create privacy policy**: Required for app stores
4. **Set up error tracking**: Sentry (free tier)

## 💡 Pro Tips

- **Keep backend awake**: Use UptimeRobot to ping your app every 5 minutes
- **Monitor usage**: Check Railway dashboard for resource usage
- **Backup database**: Export Neon database regularly
- **Update regularly**: Keep dependencies updated

---

**Need help?** Check `FREE_PUBLISHING_GUIDE.md` for detailed instructions.

