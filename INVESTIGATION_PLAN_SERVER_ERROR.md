# 🔍 Investigation Plan: Server Connection Error

## Problem Statement
User reports "Server is not responding" error when:
- Trying to register (waiting for email verification)
- Trying to change password
- Error shows: "Server is not responding. Please check if Flask server is running on https://web-production-e167.up.railway.app"

## Current Status
✅ Server is running (tested - Status 200)
✅ Config has correct Railway URL
✅ Timeout increased from 10s to 30s
❌ Error still occurs

---

## 🔎 Root Cause Analysis Plan

### Phase 1: Verify Server Status
**Goal:** Confirm server is actually accessible

**Tests:**
1. ✅ Test `/health` endpoint - **PASSED** (Status 200)
2. ⏳ Test `/register` endpoint directly - **NEEDS TEST**
3. ⏳ Test from device browser (not app) - **NEEDS TEST**
4. ⏳ Check Railway logs for incoming requests - **NEEDS CHECK**
5. ⏳ Verify Railway deployment is "Active" - **NEEDS CHECK**

**Expected Results:**
- Server should respond to all endpoints
- Railway logs should show requests (if app is connecting)

---

### Phase 2: Analyze Error Flow
**Goal:** Understand exactly when/why TimeoutException occurs

**Current Error Flow:**
```
1. User clicks Register
2. Connectivity check runs (checkAndNotifyIfDisconnected)
3. If connected → HTTP POST to $apiBase/register
4. Timeout after 30 seconds
5. TimeoutException caught
6. Error dialog shown: "Server is not responding..."
```

**Key Questions:**
1. ⏳ Is connectivity check passing? (Device has internet)
2. ⏳ Is the request actually being sent? (Check debug logs)
3. ⏳ Is Railway receiving the request? (Check Railway logs)
4. ⏳ Is Railway taking >30 seconds to respond? (Check response times)
5. ⏳ Is it a network issue on device? (Firewall, proxy, DNS)

---

### Phase 3: Connectivity Check Analysis
**Goal:** Verify connectivity check is accurate

**Current Implementation:**
- Uses `InternetConnectionChecker` with default settings
- Checks general internet connectivity (not specific server)
- Timeout: 3 seconds for connectivity check
- May pass even if Railway is unreachable

**Potential Issues:**
1. ⚠️ **Connectivity check passes but Railway is unreachable**
   - Device has internet ✓
   - But Railway URL might be blocked/filtered
   - Or DNS resolution fails for Railway domain

2. ⚠️ **Connectivity check uses cached status**
   - Might show "connected" from previous check
   - But actual connection to Railway fails

3. ⚠️ **Connectivity check timeout too short**
   - 3 seconds might not be enough
   - Fails before Railway can respond

**Tests Needed:**
- ⏳ Test connectivity check with Railway URL specifically
- ⏳ Test DNS resolution for Railway domain
- ⏳ Test SSL certificate validation
- ⏳ Check if device can reach Railway from browser

---

### Phase 4: Railway-Specific Issues
**Goal:** Check Railway free tier limitations

**Known Railway Free Tier Behavior:**
- Apps sleep after ~30 minutes inactivity
- First request after sleep takes 10-30 seconds to wake up
- Timeout increased to 30s should handle this

**Potential Issues:**
1. ⚠️ **Railway app is sleeping and taking >30s to wake**
   - First request times out
   - Subsequent requests work

2. ⚠️ **Railway rate limiting**
   - Too many requests from same IP
   - Temporary blocking

3. ⚠️ **Railway deployment issues**
   - App crashed but shows as "running"
   - Health check works but other endpoints fail

**Tests Needed:**
- ⏳ Check Railway deployment status
- ⏳ Check Railway logs for errors
- ⏳ Test multiple requests in sequence
- ⏳ Check Railway metrics (CPU, memory, response times)

---

### Phase 5: Network/Device Issues
**Goal:** Rule out device/network problems

**Potential Issues:**
1. ⚠️ **Device firewall/proxy blocking Railway**
   - Corporate/school network
   - VPN interference
   - Firewall rules

2. ⚠️ **DNS resolution issues**
   - Device can't resolve Railway domain
   - Wrong DNS server

3. ⚠️ **SSL certificate issues**
   - Certificate validation fails
   - Self-signed certificate rejection

4. ⚠️ **Mobile data vs WiFi**
   - One works, other doesn't
   - Carrier blocking

**Tests Needed:**
- ⏳ Test on different network (WiFi vs Mobile)
- ⏳ Test from device browser (not app)
- ⏳ Check device network settings
- ⏳ Test DNS resolution: `nslookup web-production-e167.up.railway.app`

---

### Phase 6: App-Specific Issues
**Goal:** Check if issue is in app code

**Potential Issues:**
1. ⚠️ **Old APK still installed**
   - User hasn't installed new APK
   - Old APK has wrong URL or timeout

2. ⚠️ **App cache issues**
   - Cached old API URL
   - Need to clear app data

3. ⏳ **Error handling too generic**
   - TimeoutException caught but doesn't distinguish between:
     - Server actually down
     - Server slow to respond
     - Network issue
     - DNS issue

4. ⚠️ **HTTP client configuration**
   - Missing headers
   - SSL verification issues
   - Proxy settings

**Tests Needed:**
- ⏳ Verify user installed NEW APK (check build date)
- ⏳ Clear app data and retry
- ⏳ Add more detailed error logging
- ⏳ Check HTTP client configuration

---

## 🎯 Most Likely Root Causes (Priority Order)

### 1. **Railway Server Sleep/Wake Time** (HIGH PROBABILITY)
- **Symptom:** First request times out, subsequent work
- **Fix:** Already increased timeout to 30s, but might need more
- **Test:** Make request, wait, make another request immediately

### 2. **Connectivity Check False Positive** (MEDIUM PROBABILITY)
- **Symptom:** Connectivity check passes but Railway unreachable
- **Fix:** Test connectivity to Railway URL specifically, not just general internet
- **Test:** Add Railway-specific connectivity check

### 3. **Old APK Still Installed** (MEDIUM PROBABILITY)
- **Symptom:** User hasn't installed new APK with fixes
- **Fix:** Verify new APK is installed
- **Test:** Check APK build date, verify config.dart changes are in APK

### 4. **Network/DNS Issues** (LOW-MEDIUM PROBABILITY)
- **Symptom:** Device can't reach Railway domain
- **Fix:** Test from device browser, check DNS
- **Test:** Try Railway URL in device browser

### 5. **Railway Deployment Issue** (LOW PROBABILITY)
- **Symptom:** Health works but register endpoint fails
- **Fix:** Check Railway logs, redeploy
- **Test:** Test register endpoint directly

---

## 📋 Action Items (In Order)

### Immediate (Do First)
1. ✅ **Verify server is running** - DONE (Status 200)
2. ⏳ **Check Railway logs** - See if requests are arriving
3. ⏳ **Test register endpoint directly** - From browser/Postman
4. ⏳ **Verify new APK is installed** - Check build date

### Short Term
5. ⏳ **Add Railway-specific connectivity check** - Test Railway URL, not just general internet
6. ⏳ **Improve error messages** - Distinguish between timeout types
7. ⏳ **Add retry logic** - Retry once if timeout (Railway wake-up)
8. ⏳ **Test on different networks** - WiFi vs Mobile data

### Long Term
9. ⏳ **Add request logging** - Log full request/response details
10. ⏳ **Monitor Railway metrics** - Response times, errors
11. ⏳ **Add health check before requests** - Wake Railway before main request

---

## 🔧 Recommended Fixes (Based on Investigation)

### Fix 1: Add Railway-Specific Connectivity Check
**Problem:** General internet check passes but Railway unreachable
**Solution:** Test connectivity to Railway URL specifically before requests

### Fix 2: Add Retry Logic for Timeouts
**Problem:** Railway sleep takes time, first request times out
**Solution:** Auto-retry once after timeout (gives Railway time to wake)

### Fix 3: Improve Error Messages
**Problem:** Generic "Server not responding" doesn't help debug
**Solution:** Distinguish between:
- Network connectivity issue
- Server timeout (Railway sleeping)
- Server error
- DNS resolution failure

### Fix 4: Add Health Check Before Critical Requests
**Problem:** First request wakes Railway, times out
**Solution:** Make a quick health check first to wake Railway, then make main request

---

## 📊 Success Criteria

**Investigation Complete When:**
- ✅ Root cause identified
- ✅ Reproducible test case created
- ✅ Fix implemented and tested
- ✅ Error no longer occurs

**Fix Successful When:**
- ✅ Registration works on first try
- ✅ Password change works
- ✅ No timeout errors
- ✅ Works on both WiFi and Mobile data

---

## 🚨 Critical Next Steps

1. **Check Railway Logs** - See if requests are arriving
2. **Test from Device Browser** - Verify Railway is reachable from device
3. **Verify New APK Installed** - User must install APK with 30s timeout
4. **Add Detailed Logging** - Log exact error type and timing

---

**Created:** 2025-11-18
**Status:** Investigation in progress
**Priority:** HIGH











