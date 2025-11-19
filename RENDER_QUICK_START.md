# ⚡ Render Quick Start - 5 Minute Deploy

## 🚀 Fastest Path to Deploy

### 1. Push to GitHub
```powershell
git add .
git commit -m "Ready for Render"
git push origin main
```

### 2. Create Render Service
1. Go to https://render.com → Sign up
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repo
4. Configure:
   - **Name**: `nutrition-app`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT --timeout 120`
   - **Instance**: `Free`

### 3. Add Environment Variables
Go to **Environment** tab, add:

```bash
FLASK_ENV=production
SECRET_KEY=<generate-with: python -c "import secrets; print(secrets.token_hex(32))">
NEON_DATABASE_URL=<your-neon-database-url>
GMAIL_USERNAME=<your-email@gmail.com>
GMAIL_APP_PASSWORD=<your-gmail-app-password>
ALLOWED_ORIGINS=*
```

### 4. Deploy
- Render auto-deploys when you add variables
- Wait 2-5 minutes
- Check **Logs** tab for status

### 5. Test
Visit: `https://your-app-name.onrender.com/api/health`

---

## ✅ Done!

Your app is live at: `https://your-app-name.onrender.com`

**Update Flutter app**: Change `baseUrl` in `nutrition_flutter/lib/config.dart`

---

📖 **Full guide**: See `DEPLOY_TO_RENDER.md` for detailed instructions

