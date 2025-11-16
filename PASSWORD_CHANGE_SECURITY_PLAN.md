# Password Change Security Enhancement Plan
## Aligning Change Password with Forgot Password Security

---

## 📋 Current State Analysis

### Current Change Password (`PUT /user/<username>/password`)
**Security Level: MEDIUM**
- ✅ Requires current password verification
- ✅ Validates new password (min 6 characters)
- ❌ No email verification
- ❌ No rate limiting
- ❌ No verification code
- ❌ Direct password change (single-step)

### Current Reset Password (`POST /auth/reset-password`)
**Security Level: LOW**
- ❌ No email verification
- ❌ No verification code
- ❌ No rate limiting
- ❌ Direct password reset (single-step)
- ⚠️ **CRITICAL SECURITY ISSUE**: Anyone with email/username can reset password

### Reference: Email Change & Account Deletion
**Security Level: HIGH**
- ✅ Email verification required
- ✅ 6-digit verification code
- ✅ 15-minute code expiration
- ✅ Rate limiting (3 requests/hour for email change, 1/hour for deletion)
- ✅ Resend code functionality (60-second cooldown)
- ✅ Pending operations table
- ✅ Single-use codes
- ✅ Automatic cleanup of expired records

---

## 🎯 Goal

Enhance **Change Password** to match the security level of **Email Change** and **Account Deletion** operations, ensuring:
1. Email verification before password change
2. Verification code sent to user's registered email
3. Rate limiting to prevent abuse
4. Proper expiration and cleanup
5. Consistent user experience with other secure operations

---

## 🗄️ Database Changes

### New Table: `pending_password_changes`

```sql
CREATE TABLE IF NOT EXISTS pending_password_changes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(80) NOT NULL,
    email VARCHAR(120) NOT NULL,
    verification_code VARCHAR(10) NOT NULL,
    verification_expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resend_count INTEGER DEFAULT 0 NOT NULL,
    request_count INTEGER DEFAULT 1 NOT NULL,
    failed_attempts INTEGER DEFAULT 0 NOT NULL,
    ip_address VARCHAR(45),
    new_password_hash VARCHAR(255) NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS ix_pending_password_user ON pending_password_changes(user_id);
CREATE INDEX IF NOT EXISTS ix_pending_password_expires ON pending_password_changes(verification_expires_at);
CREATE INDEX IF NOT EXISTS ix_pending_password_email ON pending_password_changes(email);
CREATE INDEX IF NOT EXISTS ix_pending_password_ip ON pending_password_changes(ip_address);
```

**Fields:**
- `user_id`: Foreign key to users table
- `username`: For quick lookup without joins
- `email`: User's registered email (where code is sent)
- `verification_code`: 6-digit code sent to email
- `verification_expires_at`: Expiration timestamp (15 minutes)
- `resend_count`: Track resend attempts for rate limiting
- `request_count`: Track total requests for rate limiting
- `failed_attempts`: Track failed verification attempts (max 5 before invalidation)
- `ip_address`: IP address for rate limiting (IPv6 compatible)
- `new_password_hash`: Hashed new password (stored temporarily until verification)

---

## 🔄 New Flow Design

### Flow 1: Change Password (Authenticated User)

```
1. User opens Account Settings → Password Settings
2. User enters current password (for initial verification)
3. User enters new password
4. User clicks "Change Password"
   ↓
5. Frontend: Call POST /user/<username>/password/request-change
6. Backend: Verify current password
7. Backend: Validate new password (min 6 chars, different from current)
8. Backend: Check rate limiting (max 3 requests/hour)
9. Backend: Generate 6-digit verification code
10. Backend: Send code to user's registered email
11. Backend: Create pending_password_changes record
    ↓
12. Frontend: Navigate to Password Change Verification Screen
13. User checks email inbox
14. User enters 6-digit code
    ↓
15. Frontend: Call POST /user/<username>/password/verify-change
16. Backend: Verify code (check expiration, match)
17. Backend: Update user password
18. Backend: Delete pending record
19. Backend: Optionally invalidate all sessions (force re-login)
    ↓
20. Frontend: Show success message
21. Frontend: Optionally redirect to login (if sessions invalidated)
```

**Alternative Paths:**
- Current password incorrect → Show error, allow retry
- Code expired → Show error, offer resend (resend restarts 15-minute timer)
- Invalid code → Show error, allow retry
- Rate limit exceeded → Show error, inform user to wait
- User cancels → Delete pending record, return to settings

### Flow 2: Reset Password (Forgot Password - Unauthenticated)

```
1. User clicks "Forgot Password" on login screen
2. User enters email or username
3. User clicks "Send Reset Code"
   ↓
4. Frontend: Call POST /auth/password-reset/request
5. Backend: Find user by email/username (don't reveal if exists)
6. Backend: Check rate limiting (max 3 requests/hour per email + IP)
7. Backend: Generate 6-digit verification code
8. Backend: Send code to user's registered email (only if user exists)
9. Backend: Create pending_password_changes record (only if email sent successfully)
    ↓
10. Frontend: Navigate to Password Reset Verification Screen
11. User checks email inbox
12. User enters 6-digit code
13. User enters new password (with real-time strength validation)
14. User confirms new password
    ↓
15. Frontend: Call POST /auth/password-reset/verify-and-complete
16. Backend: Verify code (check expiration, match, failed attempts)
17. Backend: Validate password strength (Medium or Strong only)
18. Backend: Check against common passwords
19. Backend: Update user password in database (visible in Neon console)
20. Backend: Delete pending record
21. Backend: Frontend clears local storage (force re-login)
    ↓
22. Frontend: Show success message
23. Frontend: Redirect to login screen
```

**Note**: Simplified flow - no temporary token needed. Code verification happens once with password submission.

**Alternative Paths:**
- User not found → Show generic message (don't reveal if email exists)
- Code expired → Show error, offer resend
- Invalid code → Show error, allow retry
- Rate limit exceeded → Show error, inform user to wait

---

## 🔒 Security Considerations

### 1. Rate Limiting

**Implementation Decision: Database-Based with IP Tracking**

- **Change Password**: Max 3 requests per hour per user (database-based)
- **Reset Password**: Max 3 requests per hour per email + IP address (prevent enumeration)
- **Resend Codes**: Max 3 per hour, minimum 60 seconds between resends
- **Failed Verification Attempts**: Max 5 attempts per code before code invalidation

**Rate Limiting Algorithm:**
- Use `request_count` and `resend_count` fields in pending table
- Check against `created_at` timestamp (fixed 1-hour window)
- Track IP address for reset password requests
- Reset count after window expires

### 2. Code Security
- 6-digit codes (1,000,000 possible combinations)
- 15-minute expiration (timer restarts on each resend)
- Single-use codes (delete after successful verification)
- Codes stored as plain text (acceptable for 6-digit codes with expiration)

### 3. Email Verification
- **Change Password**: Verify ownership of CURRENT email (user is authenticated)
- **Reset Password**: Verify ownership of CURRENT email (user is not authenticated)
- Email must match user's registered email exactly (case-insensitive)

### 4. Password Validation & Strength Requirements

**Minimum Requirements (Must Have):**
- ✅ **Minimum 8 characters** (increased from 6)
- ✅ **At least 1 uppercase letter** (A-Z)
- ✅ **At least 1 number** (0-9)
- ✅ **At least 1 special character** (!@#$%^&*()_+-=[]{}|;:,.<>?)
- ✅ **Must be different from current password**

**Strength Levels:**
- **WEAK** (Rejected): Less than 8 characters OR missing 2+ required character types
- **MEDIUM** (Accepted): 8+ characters with 3-4 requirement types met
- **STRONG** (Accepted): 8+ characters with all 4 requirement types met

**Additional Validation:**
- ✅ Check against common passwords list (reject top 10,000 common passwords)
- ✅ Check similarity to username/email (reject if contains username or email)
- ✅ Maximum 128 characters (prevent DoS attacks)
- ✅ Real-time frontend validation with strength meter
- ✅ Server-side validation (security requirement)

**Special Characters Allowed:**
```
! @ # $ % ^ & * ( ) _ + - = [ ] { } | ; : , . < > ? ~
```

**User Guidance:**
- Real-time password strength meter (Weak/Medium/Strong)
- Live checklist showing requirements met
- Good password examples
- Clear error messages for missing requirements

### 5. Session Management

**Implementation Decision: Frontend Local Storage Clear**

Since the app uses stateless authentication (no JWT tokens or server sessions):
- **Change Password**: Frontend clears local storage, redirects to login
- **Reset Password**: Frontend clears local storage, redirects to login
- **No backend changes needed** - password update in database (Neon console) happens automatically
- User must re-login with new password after change/reset

**Database Update:**
- Password changes update `users.password` column in database immediately
- Changes are committed and visible in Neon console as hash string
- Format: `pbkdf2:sha256:600000$...`

### 6. Prevention of Abuse

**Implementation Decisions:**
- ✅ **Cancel old pending operations** when new ones are created
- ✅ **Block conflicting operations** (e.g., can't change password while email change is pending)
- ✅ **Clean up expired pending records** automatically (via cleanup job)
- ✅ **Track failed attempts** in database, invalidate code after 5 failures
- ✅ **Email service failures**: Don't create pending record if email fails, return 503 error
- ✅ Log security events (password changes, reset attempts)

**Failed Attempt Handling:**
- Track `failed_attempts` in `pending_password_changes` table
- Increment on each failed verification
- Invalidate code (delete pending record) after 5 failures
- Require new password change/reset request

### 7. User Privacy
- **Reset Password**: Don't reveal if email/username exists (generic error message)
- **Change Password**: User is authenticated, so can show specific errors

---

## 📧 Email Templates

### Password Change Verification Email

**To**: User's registered email address  
**Subject**: "Nutrition App - Verify Your Password Change"

**Content:**
- Greeting with username
- Confirmation that password change was requested
- Current email address (for context)
- 6-digit verification code (prominently displayed)
- Expiration time (15 minutes)
- Security warning if user didn't request this
- Instructions to contact support if suspicious
- Link to cancel the request (optional)

### Password Reset Verification Email

**To**: User's registered email address  
**Subject**: "Nutrition App - Reset Your Password"

**Content:**
- Greeting with username
- Confirmation that password reset was requested
- 6-digit verification code (prominently displayed)
- Expiration time (15 minutes)
- Security warning if user didn't request this
- Instructions to contact support if suspicious
- Note that all sessions will be invalidated after reset

---

## 🔌 API Endpoints

### Change Password (Authenticated)

#### 1. Request Password Change
```
POST /user/<username>/password/request-change
Headers: Authorization: Bearer <token>
Body: {
    "current_password": "currentpass123",
    "new_password": "newpass456"
}
Response: {
    "success": true,
    "message": "Verification code sent to your email",
    "email": "user@example.com",
    "expires_at": "2024-01-01T12:15:00Z"
}
```

#### 2. Verify Password Change
```
POST /user/<username>/password/verify-change
Headers: Authorization: Bearer <token>
Body: {
    "code": "123456"
}
Response: {
    "success": true,
    "message": "Password changed successfully"
}
```

#### 3. Resend Verification Code
```
POST /user/<username>/password/resend-code
Headers: Authorization: Bearer <token>
Response: {
    "success": true,
    "message": "Verification code resent",
    "expires_at": "2024-01-01T12:15:00Z"
}
```

#### 4. Cancel Password Change
```
POST /user/<username>/password/cancel-change
Headers: Authorization: Bearer <token>
Response: {
    "success": true,
    "message": "Password change cancelled"
}
```

### Reset Password (Unauthenticated)

#### 1. Request Password Reset
```
POST /auth/password-reset/request
Body: {
    "email": "user@example.com"
    // OR
    "username": "username"
    // OR
    "username_or_email": "user@example.com"
}
Response: {
    "success": true,
    "message": "If an account exists, a verification code has been sent",
    "email": "u***@example.com"  // Partially masked for privacy
}
```

#### 2. Verify and Complete Password Reset (Combined)
```
POST /auth/password-reset/verify-and-complete
Body: {
    "email": "user@example.com",
    "code": "123456",
    "new_password": "newpass456"
}
Response: {
    "success": true,
    "message": "Password reset successfully. Please log in with your new password"
}
```

**Note**: Simplified flow - no temporary token needed. Code verification and password update happen in single request.

#### 4. Resend Reset Code
```
POST /auth/password-reset/resend-code
Body: {
    "email": "user@example.com"
}
Response: {
    "success": true,
    "message": "If an account exists, a verification code has been resent",
    "expires_at": "2024-01-01T12:15:00Z"
}
```

---

## 🗂️ Backend Implementation Plan

### 1. Database Model
- Create `PendingPasswordChange` model (similar to `PendingEmailChange`)
- Add indexes for performance
- Add cleanup job for expired records

### 2. Helper Functions
- `generate_verification_code()` - Already exists, reuse
- `send_password_change_email()` - New function
- `send_password_reset_email()` - New function
- `_cleanup_expired_password_changes()` - New cleanup function
- `_check_password_change_rate_limit()` - Rate limiting check (database-based)
- `validate_password_strength()` - New function (returns weak/medium/strong)
- `check_common_passwords()` - New function (check against common passwords list)
- `check_password_similarity()` - New function (check against username/email)
- `get_client_ip()` - New function (extract IP address from request)

### 3. Endpoint Implementation

#### Change Password Endpoints
1. `POST /user/<username>/password/request-change`
   - Verify user authentication
   - Verify current password
   - Validate new password strength (Medium/Strong only)
   - Check against common passwords
   - Check similarity to username/email
   - Check rate limiting (database-based)
   - Generate code
   - Send email (don't create pending if email fails)
   - Create pending record with hashed password
   - Track IP address

2. `POST /user/<username>/password/verify-change`
   - Verify user authentication
   - Verify code (check expiration, failed attempts)
   - Update password in database (visible in Neon console)
   - Delete pending record
   - Frontend clears local storage (force re-login)

3. `POST /user/<username>/password/resend-code`
   - Verify user authentication
   - Check rate limiting (60-second cooldown, max 3/hour)
   - Generate new code
   - Send email
   - Update pending record (reset expiration timer)

4. `POST /user/<username>/password/cancel-change`
   - Verify user authentication
   - Delete pending record

#### Reset Password Endpoints
1. `POST /auth/password-reset/request`
   - Find user (don't reveal if exists - generic response)
   - Check rate limiting (per email + IP address)
   - Generate code
   - Send email (only if user exists)
   - Create pending record (only if email sent successfully)
   - Track IP address
   - Return generic success message (don't reveal if user exists)

2. `POST /auth/password-reset/verify-and-complete`
   - Verify code (check expiration, failed attempts)
   - Validate password strength (Medium/Strong only)
   - Check against common passwords
   - Check similarity to username/email
   - Update password in database (visible in Neon console)
   - Delete pending record
   - Frontend clears local storage (force re-login)

3. `POST /auth/password-reset/resend-code`
   - Find user (don't reveal if exists)
   - Check rate limiting (60-second cooldown, max 3/hour, IP-based)
   - Generate new code
   - Send email (only if user exists)
   - Update pending record (reset expiration timer)
   - Return generic success message

### 4. Deprecation
- Mark old `PUT /user/<username>/password` as deprecated (return 410 Gone)
- Mark old `POST /auth/reset-password` as deprecated (return 410 Gone)
- Add deprecation notice in response

---

## 🎨 Frontend Implementation Plan

### 1. New Screens

#### Password Change Verification Screen
- Similar to `verify_code_screen.dart`
- 6-digit code input
- Resend code button (60-second cooldown)
- Expiration countdown
- Cancel button
- Error handling

#### Password Reset Verification Screen
- Similar to password change verification
- Two-step process:
  1. Enter code
  2. Enter new password
- Or combine into single screen with conditional rendering

### 2. Updated Screens

#### Account Settings (Password Section)
- Update to use new flow:
  1. Enter current password
  2. Enter new password
  3. Click "Change Password"
  4. Navigate to verification screen
  5. Enter code
  6. Success → return to settings

#### Login Screen
- Update "Forgot Password" flow:
  1. Enter email/username
  2. Click "Send Reset Code"
  3. Navigate to reset verification screen
  4. Enter code
  5. Enter new password
  6. Success → redirect to login

### 3. Reusable Components
- Code input component (6 digits)
- Resend code button with countdown
- Expiration countdown display
- Error message display
- **Password strength meter widget** (Weak/Medium/Strong indicator)
- **Password requirements checklist widget** (real-time validation)
- **Password strength calculator** (reuse from register screen)

### 4. Password Strength Validation (Frontend)

**Real-time Validation:**
- Show password strength meter as user types
- Display requirements checklist with checkmarks
- Show which requirements are met/missing
- Disable submit button if password is Weak
- Show helpful examples of good passwords

**Visual Indicators:**
- 🔴 **Weak**: Red indicator, "Password is too weak"
- 🟠 **Medium**: Orange indicator, "Password strength: Medium"
- 🟢 **Strong**: Green indicator, "Password strength: Strong"

**Requirements Display:**
```
Password Requirements:
✓ At least 8 characters
✓ 1 uppercase letter (A-Z)
✓ 1 number (0-9)
✓ 1 special character (!@#$%^&*...)
```

---

## 📋 Migration Plan

### Phase 1: Database Setup
1. Create `pending_password_changes` table
2. Add indexes
3. Test table creation

### Phase 2: Backend Implementation
1. Create `PendingPasswordChange` model
2. Implement helper functions
3. Implement change password endpoints
4. Implement reset password endpoints
5. Add cleanup job
6. Add rate limiting
7. Test all endpoints

### Phase 3: Email Templates
1. Create password change email template
2. Create password reset email template
3. Test email sending

### Phase 4: Frontend Implementation
1. Create password change verification screen
2. Create password reset verification screen
3. Update account settings screen
4. Update login screen
5. Test all flows

### Phase 5: Testing
1. Unit tests for backend
2. Integration tests for flows
3. Security testing (rate limiting, expiration, etc.)
4. User acceptance testing

### Phase 6: Deployment
1. Deploy backend changes
2. Deploy frontend changes
3. Monitor for issues
4. Gather user feedback

### Phase 7: Deprecation
1. Mark old endpoints as deprecated
2. Monitor usage
3. Remove old endpoints after grace period

---

## ✅ Success Criteria

1. ✅ Users cannot change password without email verification
2. ✅ Users cannot reset password without email verification
3. ✅ Verification codes expire after 15 minutes
4. ✅ Rate limiting prevents abuse (database-based with IP tracking)
5. ✅ Password strength validation enforced (Medium/Strong only)
6. ✅ Weak passwords are rejected with clear error messages
7. ✅ Real-time password strength feedback provided to users
8. ✅ Common passwords are rejected
9. ✅ Passwords similar to username/email are rejected
10. ✅ Failed verification attempts tracked and limited (max 5)
11. ✅ All edge cases are handled gracefully
12. ✅ User experience is smooth and intuitive
13. ✅ Security is maintained throughout the process
14. ✅ Old endpoints are properly deprecated
15. ✅ System is resilient to failures
16. ✅ Email delivery is reliable
17. ✅ Password changes update database (Neon console) immediately
18. ✅ Frontend clears local storage after password change/reset

---

## 🔍 Edge Cases to Handle

1. User changes password while verification is pending
2. User resets password while change is pending (or vice versa)
3. Email service is down (graceful error handling)
4. User enters wrong code multiple times
5. User closes app during verification
6. Network errors during verification
7. User's email is changed while password change is pending
8. User account is deleted while password change is pending
9. Multiple devices trying to change password simultaneously
10. Code expires while user is entering it

---

## 📝 Notes & Considerations

### Security Enhancements
- Consider requiring 2FA for password changes (future enhancement)
- Consider password strength requirements (future enhancement)
- Consider checking against breached passwords (future enhancement)

### User Experience
- Provide clear instructions at each step
- Show expiration countdown
- Allow cancellation at any point
- Provide helpful error messages
- Support resend functionality

### Backward Compatibility
- Old endpoints should return 410 Gone with helpful message
- Consider redirecting to new endpoints (optional)
- Provide migration guide for API consumers

---

## 📚 References

- Email Change Implementation (`EMAIL_VERIFICATION_PLAN.md`)
- Account Deletion Implementation (`EMAIL_VERIFICATION_PLAN.md`)
- Email Service (`email_service.py`)
- Verification Code Generation (existing implementation)

---

---

## 📌 **Implementation Decisions Summary**

Based on codebase analysis and security best practices, the following decisions have been made:

### **1. Session Invalidation**
✅ **Decision**: Frontend clears local storage (no backend changes needed)
- App uses stateless authentication (no JWT tokens or server sessions)
- Frontend clears local storage after password change/reset
- User redirected to login screen
- Password update in database (Neon console) happens automatically

### **2. Reset Password Token**
✅ **Decision**: Remove temporary token; verify code twice instead
- Simplified flow: Single endpoint `/auth/password-reset/verify-and-complete`
- Code verification and password update in one request
- No token storage needed
- More secure and simpler implementation

### **3. Rate Limiting**
✅ **Decision**: Database-based with IP tracking
- Use `request_count` and `resend_count` fields in pending table
- Check against `created_at` timestamp (fixed 1-hour window)
- Track IP address for reset password (prevent email enumeration)
- Reset count after window expires

### **4. Failed Attempts**
✅ **Decision**: Track in database, invalidate after 5 failures
- Add `failed_attempts` column to `pending_password_changes` table
- Increment on each failed verification
- Invalidate code (delete pending record) after 5 failures
- Require new password change/reset request

### **5. Email Service Failures**
✅ **Decision**: Don't create pending record, return 503 error
- Only create pending record if email sent successfully
- Return 503 Service Unavailable if email fails
- Log error for monitoring
- User can retry request

### **6. Concurrent Operations**
✅ **Decision**: Cancel old pending, block conflicts
- Cancel old pending password changes when new ones are created
- Block password change if email change is pending (and vice versa)
- Prevent multiple pending operations for same user

### **7. Password Strength Validation**
✅ **Decision**: Require Medium or Strong passwords only
- Minimum 8 characters (increased from 6)
- Must include: uppercase, number, special character
- Reject Weak passwords
- Real-time frontend validation + server-side validation
- Check against common passwords list
- Check similarity to username/email

### **8. Database Updates**
✅ **Decision**: Password changes update Neon console immediately
- Password hashed and stored in `users.password` column
- Changes committed to database immediately
- Visible in Neon console as hash string
- Format: `pbkdf2:sha256:600000$...`

---

**Plan Status**: Ready for Implementation  
**Priority**: High (Security Critical)  
**Estimated Effort**: 3-4 days (including password strength validation)

