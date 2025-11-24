#!/usr/bin/env python3
"""
Migration script to add status, verified_at, and cancelled_at columns
to pending_password_changes table
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from sqlalchemy import text

def run_migration():
    """Run the migration to add status columns"""
    print("🔧 Starting Migration: Add status columns to pending_password_changes")
    print("=" * 60)
    
    with app.app_context():
        try:
            # Check if status column already exists
            inspector = db.inspect(db.engine)
            columns = [col['name'] for col in inspector.get_columns('pending_password_changes')]
            
            if 'status' in columns:
                print("✅ status column already exists")
            else:
                print("Adding status column...")
                db.session.execute(text("""
                    ALTER TABLE pending_password_changes 
                    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending' NOT NULL
                """))
                print("✅ Added status column")
            
            if 'verified_at' in columns:
                print("✅ verified_at column already exists")
            else:
                print("Adding verified_at column...")
                db.session.execute(text("""
                    ALTER TABLE pending_password_changes 
                    ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP NULL
                """))
                print("✅ Added verified_at column")
            
            if 'cancelled_at' in columns:
                print("✅ cancelled_at column already exists")
            else:
                print("Adding cancelled_at column...")
                db.session.execute(text("""
                    ALTER TABLE pending_password_changes 
                    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP NULL
                """))
                print("✅ Added cancelled_at column")
            
            # Create index if it doesn't exist
            print("Creating index on status column...")
            db.session.execute(text("""
                CREATE INDEX IF NOT EXISTS ix_pending_password_status 
                ON pending_password_changes(status)
            """))
            print("✅ Created index")
            
            # Update existing records to have 'pending' status
            print("Updating existing records...")
            db.session.execute(text("""
                UPDATE pending_password_changes 
                SET status = 'pending' 
                WHERE status IS NULL OR status = ''
            """))
            
            db.session.commit()
            print("\n🎉 Migration completed successfully!")
            print("The pending_password_changes table now has status tracking.")
            return True
            
        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Migration failed: {e}")
            import traceback
            traceback.print_exc()
            return False

if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)















