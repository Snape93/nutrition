# 🔐 Resend Domain Verification Guide

## Goal
Verify your domain in Resend so you can send emails from `team.nutritionapp@gmail.com` instead of `onboarding@resend.dev`.

---

## Step 1: Access Resend Domains

1. **Go to Resend Dashboard:**
   - Visit: https://resend.com
   - Log in to your account

2. **Navigate to Domains:**
   - Click on **"Domains"** in the left sidebar
   - Or go directly to: https://resend.com/domains

---

## Step 2: Add Your Domain

1. **Click "Add Domain"** button (usually top right)

2. **Enter your domain:**
   - For Gmail: You need to verify the domain `gmail.com`
   - **BUT WAIT** - You can't verify `gmail.com` because you don't own it!
   - **Solution:** You need to use your own domain (like `nutritionapp.com` or similar)

3. **Alternative Options:**
   - **Option A:** Use a custom domain you own (e.g., `nutritionapp.com`)
   - **Option B:** Keep using `onboarding@resend.dev` (works fine for testing)
   - **Option C:** Use a subdomain (e.g., `mail.nutritionapp.com`)

---

## Step 3: Domain Verification Process

### If you have your own domain (e.g., `nutritionapp.com`):

1. **Add Domain:**
   - Enter: `nutritionapp.com`
   - Click "Add Domain"

2. **Resend will show DNS records to add:**
   - You'll see records like:
     ```
     Type: TXT
     Name: @
     Value: resend-verification=abc123...
     ```
   - And SPF/DKIM records

3. **Add DNS Records:**
   - Go to your domain registrar (GoDaddy, Namecheap, etc.)
   - Go to DNS Management
   - Add the TXT records Resend provides
   - Wait for DNS propagation (5-60 minutes)

4. **Verify in Resend:**
   - Click "Verify" in Resend dashboard
   - Resend will check DNS records
   - Status will change to "Verified" ✅

---

## Step 4: Use Your Verified Domain

### After domain is verified:

1. **Add to Railway Variables:**
   - Go to Railway Dashboard → Your Service → Variables
   - Add new variable:
     - **Name:** `RESEND_FROM_EMAIL`
     - **Value:** `team@nutritionapp.com` (or your verified domain email)
   - Save

2. **Update Code (Already Done!):**
   - The code already checks for `RESEND_FROM_EMAIL` environment variable
   - If set, it uses that; otherwise defaults to `onboarding@resend.dev`

---

## Important Notes

### ⚠️ Gmail Domain Limitation:
- **You CANNOT verify `gmail.com`** - Google owns it
- You can only verify domains you own
- `team.nutritionapp@gmail.com` uses Google's domain, not yours

### ✅ Solutions:

#### Option 1: Use Your Own Domain (Best for Production)
- Buy a domain (e.g., `nutritionapp.com` - ~$10-15/year)
- Verify it in Resend
- Use `team@nutritionapp.com` as sender
- Most professional option

#### Option 2: Keep Using Test Domain (Fine for Testing)
- Use `onboarding@resend.dev` (no verification needed)
- Works perfectly for testing
- Free and easy
- Users still see "Nutrition App" as sender name

#### Option 3: Use Resend's Verified Domain
- Resend may provide a verified domain option
- Check Resend dashboard for available options

---

## Quick Setup (If You Have a Domain)

### Step-by-Step:

1. **Buy a domain** (if you don't have one):
   - GoDaddy, Namecheap, Google Domains, etc.
   - Cost: ~$10-15/year

2. **Add domain to Resend:**
   - Resend Dashboard → Domains → Add Domain
   - Enter your domain (e.g., `nutritionapp.com`)

3. **Get DNS records from Resend:**
   - Resend will show TXT, SPF, DKIM records
   - Copy each record

4. **Add DNS records to your domain:**
   - Go to your domain registrar's DNS settings
   - Add each record Resend provided
   - Save changes

5. **Wait for DNS propagation:**
   - Usually 5-60 minutes
   - Can check with: https://dnschecker.org

6. **Verify in Resend:**
   - Click "Verify" button
   - Status should change to "Verified" ✅

7. **Add to Railway:**
   - Variable: `RESEND_FROM_EMAIL`
   - Value: `team@yourdomain.com`

8. **Test:**
   - Register a new user
   - Check email - should come from your domain

---

## Current Status (No Domain Needed)

**Right now, you can:**
- ✅ Use `onboarding@resend.dev` (no verification needed)
- ✅ Send emails successfully
- ✅ Test all features
- ✅ Users see "Nutrition App" as sender name

**The only difference:**
- "From" address shows `onboarding@resend.dev`
- But email design and functionality are identical

---

## Recommendation

### For Now (Testing):
- ✅ **Keep using `onboarding@resend.dev`**
- ✅ No domain verification needed
- ✅ Works perfectly
- ✅ Free

### For Production (Later):
- Consider buying a domain ($10-15/year)
- Verify it in Resend
- Use professional email address
- More trustworthy for users

---

## Summary

**Current Setup:**
- Using `onboarding@resend.dev` ✅
- No verification needed ✅
- Works perfectly ✅

**To Use Your Own Domain:**
1. Buy a domain (if needed)
2. Add to Resend
3. Add DNS records
4. Verify domain
5. Add `RESEND_FROM_EMAIL` to Railway
6. Done!

**For now, `onboarding@resend.dev` is perfectly fine for testing!** 🎉











