# Email Verification Implementation - Updated Flow ✅

## Summary of Changes

The email verification system has been **completely redesigned** to meet your requirements:

### ✅ Key Changes

1. **No unverified accounts in database** - Users are only created AFTER email verification
2. **Pending registrations table** - Temporary storage for unverified registrations (15 minutes)
3. **Email change allowed** - Users can change email on verification screen
4. **Rate limiting** - Max 5 resend requests per email
5. **Countdown timer** - Shows code expiration time (15 minutes)
6. **Automatic cleanup** - Expired pending registrations are deleted automatically

---

## New Flow

### Registration Flow:
1. User fills registration form → clicks "Register"
2. **Backend saves to `pending_registrations` table** (NOT users table)
3. Verification code generated and sent via email
4. User navigates to verification screen
5. User enters code → **Backend creates user in `users` table**
6. User can now log in

### If Code Expires:
- Pending registration is automatically deleted
- User must register again
- No data saved in database

---

## Database Changes Required

**Run this SQL migration:**

```sql
-- Create pending_registrations table
CREATE TABLE IF NOT EXISTS pending_registrations (
    id SERIAL PRIMARY KEY,
    email VARCHAR(120) NOT NULL,
    username VARCHAR(80) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200),
    verification_code VARCHAR(10) NOT NULL,
    verification_expires_at TIMESTAMP NOT NULL,
    registration_data TEXT,
    resend_count INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS ix_pending_reg_email ON pending_registrations(email);
CREATE INDEX IF NOT EXISTS ix_pending_reg_expires ON pending_registrations(verification_expires_at);

-- Grandfather existing users
UPDATE users SET email_verified = TRUE WHERE email IS NOT NULL AND email_verified = FALSE;
```

**Or use the migration file:** `migration_pending_registrations.sql`

---

## New Backend Endpoints

### `POST /auth/change-email`
- Changes email for pending registration
- Generates new verification code
- Sends code to new email
- Resets resend count

**Request:**
```json
{
  "old_email": "old@example.com",
  "new_email": "new@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Email changed successfully. Verification code sent to new email.",
  "new_email": "new@example.com",
  "expires_at": "2025-01-15T10:30:00Z"
}
```

---

## Updated Endpoints

### `POST /register`
- **Now saves to `pending_registrations`** (not `users`)
- Returns `expires_at` timestamp
- No user account created until verification

### `POST /auth/verify-code`
- **Now creates user in `users` table** after verification
- Deletes from `pending_registrations`
- Returns user_id and username

### `POST /auth/resend-code`
- **Rate limiting:** Max 5 resends per email
- Returns `resend_count` and `max_resends`
- Returns `expires_at` for countdown timer

### `POST /login`
- **Removed email verification check** (users are only created after verification)
- All users in database are already verified

---

## Frontend Features

### Verification Screen (`verify_code_screen.dart`)

**New Features:**
1. **Email Change Button** - Edit icon next to email
   - Click to edit email
   - Update button to change email
   - New code sent to new email

2. **Expiration Countdown Timer**
   - Shows: "Code expires in: 14:32"
   - Changes color to orange when < 5 minutes
   - Updates every second

3. **Resend Rate Limiting Display**
   - Shows: "Resend attempts: 2/5"
   - Disables resend button when limit reached
   - Shows "Max resends reached" message

4. **Better Error Handling**
   - Shows expiration errors
   - Shows rate limit errors
   - Clear messages for all scenarios

---

## Automatic Cleanup

**Backend automatically deletes expired pending registrations:**
- Runs on every request (via `@app.before_request`)
- Deletes registrations older than 15 minutes
- Keeps database clean
- No manual cleanup needed

---

## Testing Checklist

- [ ] Run database migration
- [ ] Register new user → check `pending_registrations` table (should have entry)
- [ ] Check `users` table (should NOT have entry yet)
- [ ] Enter verification code → check `users` table (should have entry now)
- [ ] Check `pending_registrations` table (entry should be deleted)
- [ ] Test email change on verification screen
- [ ] Test resend code (5 times max)
- [ ] Test code expiration (wait 15 minutes)
- [ ] Test expired code cleanup

---

## Files Modified

**Backend:**
- `app.py` - Added PendingRegistration model, updated endpoints
- `email_service.py` - Email sending (unchanged)

**Frontend:**
- `nutrition_flutter/lib/verify_code_screen.dart` - Added email change, countdown timer
- `nutrition_flutter/lib/register.dart` - Updated to pass expires_at
- `nutrition_flutter/lib/login.dart` - Removed email verification check

**Database:**
- `migration_pending_registrations.sql` - Migration script

---

## Next Steps

1. **Run the database migration** (SQL above or use migration file)
2. **Restart Flask server** to load new code
3. **Test the complete flow:**
   - Register → verify → login
   - Test email change
   - Test rate limiting
   - Test expiration

---

**Implementation Complete!** 🎉

The system now ensures:
- ✅ No unverified accounts in database
- ✅ Email change allowed
- ✅ Rate limiting (5 max)
- ✅ Countdown timer
- ✅ Automatic cleanup

