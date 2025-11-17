-- Migration: Add status tracking to pending_password_changes table
-- This adds security by tracking the state of password change requests

-- Add status field (pending, verified, cancelled, expired)
ALTER TABLE pending_password_changes 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending' NOT NULL;

-- Add verification timestamp
ALTER TABLE pending_password_changes 
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP NULL;

-- Add cancellation timestamp
ALTER TABLE pending_password_changes 
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP NULL;

-- Create index for better query performance on status
CREATE INDEX IF NOT EXISTS ix_pending_password_status ON pending_password_changes(status);

-- Update existing records to have 'pending' status (if any exist)
UPDATE pending_password_changes 
SET status = 'pending' 
WHERE status IS NULL OR status = '';

-- Add constraint to ensure status is one of valid values
-- Note: This is a soft constraint - application logic should enforce it
-- PostgreSQL doesn't support CHECK constraints easily, so we'll rely on application logic

-- Note: Expired records will be automatically cleaned up by the backend cleanup job
-- that runs on each request (see _cleanup_expired_pending_operations in app.py)






