-- Migration: Add pending_registrations table for email verification
-- This table stores unverified registrations temporarily (15 minutes)
-- Users are only created in the users table after email verification

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

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS ix_pending_reg_email ON pending_registrations(email);
CREATE INDEX IF NOT EXISTS ix_pending_reg_expires ON pending_registrations(verification_expires_at);

-- Clean up any existing unverified users (optional - only if you want to clean up old data)
-- This sets email_verified = TRUE for existing users (grandfather them in)
UPDATE users SET email_verified = TRUE WHERE email IS NOT NULL AND email_verified = FALSE;

-- Note: The email_verified, verification_code, and verification_expires_at columns
-- in the users table are kept for backward compatibility but are no longer used
-- for new registrations (new users are only created after verification)

