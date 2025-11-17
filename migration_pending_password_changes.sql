-- Migration: Add pending_password_changes table
-- This table stores pending password change and reset requests until verified

-- Create pending_password_changes table
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

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS ix_pending_password_user ON pending_password_changes(user_id);
CREATE INDEX IF NOT EXISTS ix_pending_password_expires ON pending_password_changes(verification_expires_at);
CREATE INDEX IF NOT EXISTS ix_pending_password_email ON pending_password_changes(email);
CREATE INDEX IF NOT EXISTS ix_pending_password_ip ON pending_password_changes(ip_address);

-- Note: Expired records will be automatically cleaned up by the backend cleanup job
-- that runs on each request (see _cleanup_expired_pending_operations in app.py)






