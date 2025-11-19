# Nutritionist App

A comprehensive nutrition and fitness tracking application with Flutter mobile app and Flask backend API.

## 🚀 Deployment Status

**Backend:** Deployed on Railway / Render (configurable)  
**Database:** Neon PostgreSQL  
**Mobile App:** Android APK/AAB available

## 📋 Quick Links

- **Backend API:** Check your deployment platform dashboard for your deployed URL
- **Documentation:** See deployment guides in the repository
- **GitHub Repository:** https://github.com/Snape93/nutrition

## 🛠️ Tech Stack

### Backend
- Flask (Python)
- PostgreSQL (Neon)
- SQLAlchemy
- Gunicorn

### Mobile App
- Flutter/Dart
- Android & iOS support

## 📚 Deployment Documentation

### Railway Deployment
- `DEPLOY_TO_RAILWAY_NOW.md` - Step-by-step Railway deployment guide
- `RAILWAY_CRASH_FIX.md` - Troubleshooting deployment issues
- `railway_deploy.md` - General Railway deployment guide
- `RAILWAY_ENV_VARIABLES.txt` - Required environment variables

### Render Deployment
- `DEPLOY_TO_RENDER.md` - Complete Render deployment guide
- `RENDER_QUICK_START.md` - Quick 5-minute Render deployment guide

## ✅ Post-Deployment Checklist

After deploying, verify:

- [ ] Backend is accessible at your deployment URL (Railway/Render)
- [ ] Health endpoint works: `https://your-app.railway.app/api/health` or `https://your-app.onrender.com/api/health`
- [ ] Database connection is working
- [ ] Email service is configured (Gmail)
- [ ] All environment variables are set in your deployment platform
- [ ] Mobile app is configured with correct API URL

## 🔧 Environment Variables

Required for production deployment:

- `SECRET_KEY` - Flask secret key
- `NEON_DATABASE_URL` - PostgreSQL connection string
- `GMAIL_USERNAME` - Email service username
- `GMAIL_APP_PASSWORD` - Gmail app password
- `FLASK_ENV` - Set to `production`
- `ALLOWED_ORIGINS` - CORS allowed origins (use `*` for development)

Optional:
- `GROQ_API_KEY` - For AI Coach features
- `EXERCISEDB_API_KEY` - For exercise database API

## 📱 Mobile App

Build scripts available:
- `build_android.ps1` - Build Android APK/AAB
- `build_all.ps1` - Build all platforms

## 🐛 Troubleshooting

- **Railway:** See `RAILWAY_CRASH_FIX.md` for common deployment issues and solutions
- **Render:** See `DEPLOY_TO_RENDER.md` troubleshooting section for Render-specific issues

## 📝 License

[Add your license here]

---

**Status:** ✅ Deployed and operational
