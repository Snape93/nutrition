# ✅ Ready to Deploy Checklist

## What You Have ✅

- ✅ **Gmail Username**: `team.nutritionapp@gmail.com`
- ✅ **Gmail App Password**: `dbapoawpycutkiln` (remember: no spaces!)
- ✅ **NEON_DATABASE_URL**: Already in your .env file

## What You Still Need

### 1. SECRET_KEY (Required)

Generate a secret key for Flask. Run this command:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

Or if that doesn't work, try:
```powershell
.\python.bat -c "import secrets; print(secrets.token_hex(32))"
```

**Add the output to your `.env` file:**
```env
SECRET_KEY=<paste-the-generated-key-here>
```

### 2. EXERCISEDB_API_KEY (Optional - if you have it)

If you already have a RapidAPI key, add it:
```env
EXERCISEDB_API_KEY=your-key-here
```

### 3. GROQ_API_KEY (Optional - for AI Coach features)

If you want AI Coach features:
```env
GROQ_API_KEY=your-key-here
```

---

## Your Complete .env File Should Look Like:

```env
# Flask Configuration
FLASK_ENV=production
SECRET_KEY=<generate-this>

# Database
NEON_DATABASE_URL=<you-already-have-this>

# Gmail
GMAIL_USERNAME=team.nutritionapp@gmail.com
GMAIL_APP_PASSWORD=dbapoawpycutkiln

# Optional
EXERCISEDB_API_KEY=<if-you-have-it>
GROQ_API_KEY=<if-you-have-it>
ALLOWED_ORIGINS=*
```

---

## 🚀 Next Step: Deploy to Railway!

Once you have the SECRET_KEY, you're ready to deploy!

### Quick Deploy Steps:

1. **Go to Railway**: https://railway.app
2. **Sign up** with GitHub
3. **Create New Project** → Deploy from GitHub repo
4. **Select**: `Snape93/nutrition`
5. **Add Environment Variables** (copy from your .env):
   - SECRET_KEY
   - NEON_DATABASE_URL
   - GMAIL_USERNAME
   - GMAIL_APP_PASSWORD
   - EXERCISEDB_API_KEY (if you have it)
   - FLASK_ENV=production
   - ALLOWED_ORIGINS=*
6. **Set Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT`
7. **Deploy!** 🎉

---

## Status

- ✅ Gmail credentials
- ✅ Neon database URL
- ⬜ SECRET_KEY (generate now)
- ⬜ Deploy to Railway (next step)

**You're almost ready! Just need the SECRET_KEY!**

