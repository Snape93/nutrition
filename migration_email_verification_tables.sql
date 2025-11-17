-- Migration: Add pending_email_changes and pending_account_deletions tables
-- These tables store pending email change and account deletion requests until verified

-- Create pending_email_changes table
CREATE TABLE IF NOT EXISTS pending_email_changes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(80) NOT NULL,
    old_email VARCHAR(120) NOT NULL,
    new_email VARCHAR(120) NOT NULL,
    verification_code VARCHAR(10) NOT NULL,
    verification_expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resend_count INTEGER DEFAULT 0 NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS ix_pending_email_user ON pending_email_changes(user_id);
CREATE INDEX IF NOT EXISTS ix_pending_email_expires ON pending_email_changes(verification_expires_at);
CREATE INDEX IF NOT EXISTS ix_pending_email_new_email ON pending_email_changes(new_email);

-- Create pending_account_deletions table
CREATE TABLE IF NOT EXISTS pending_account_deletions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(80) NOT NULL,
    email VARCHAR(120) NOT NULL,
    verification_code VARCHAR(10) NOT NULL,
    verification_expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resend_count INTEGER DEFAULT 0 NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS ix_pending_deletion_user ON pending_account_deletions(user_id);
CREATE INDEX IF NOT EXISTS ix_pending_deletion_expires ON pending_account_deletions(verification_expires_at);

-- Note: Expired records will be automatically cleaned up by the backend cleanup job
-- that runs on each request (see _cleanup_expired_pending_operations in app.py)






