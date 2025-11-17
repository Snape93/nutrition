# ✅ Environment Variables Checklist

## Your Gmail Credentials (✅ You Have These!)

```
GMAIL_USERNAME=team.nutritionapp@gmail.com
GMAIL_APP_PASSWORD=dbapoawpycutkiln  ← Remove spaces!
```

## Complete .env File Checklist

Make sure your `.env` file has all these:

### ✅ Gmail (You Have This!)
```env
GMAIL_USERNAME=team.nutritionapp@gmail.com
GMAIL_APP_PASSWORD=dbapoawpycutkiln
```

### ⬜ Flask Secret Key (Generate This)
```env
SECRET_KEY=<generate-with-command-below>
```

**Generate it:**
```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

### ⬜ Neon Database URL (Get From Neon)
```env
NEON_DATABASE_URL=postgresql://user:password@host/database?sslmode=require
```

**Get it from:** https://neon.tech → Your Project → Connection String

### ⬜ RapidAPI Key (If You Have It)
```env
EXERCISEDB_API_KEY=your-rapidapi-key
```

### ⬜ Groq API Key (Optional)
```env
GROQ_API_KEY=your-groq-key
```

### ⬜ Flask Environment
```env
FLASK_ENV=production
```

---

## Next Steps

1. ✅ Gmail credentials - **DONE!**
2. ⬜ Generate SECRET_KEY
3. ⬜ Get NEON_DATABASE_URL
4. ⬜ Add to Railway when deploying

---

## For Railway Deployment

When you deploy to Railway, add ALL these to Railway → Variables:

```
GMAIL_USERNAME=team.nutritionapp@gmail.com
GMAIL_APP_PASSWORD=dbapoawpycutkiln
SECRET_KEY=<your-generated-secret-key>
NEON_DATABASE_URL=<your-neon-url>
EXERCISEDB_API_KEY=<your-key>
FLASK_ENV=production
ALLOWED_ORIGINS=*
```

