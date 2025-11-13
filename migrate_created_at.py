#!/usr/bin/env python3
"""
Database migration script to add created_at field to existing food_logs
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db, FoodLog
from datetime import datetime

def migrate_created_at():
    """Add created_at field to existing food_logs records"""
    with app.app_context():
        try:
            # Get all food logs without created_at
            logs_without_created_at = FoodLog.query.filter(FoodLog.created_at.is_(None)).all()
            
            print(f"Found {len(logs_without_created_at)} records without created_at")
            
            if logs_without_created_at:
                # Set created_at to current time for existing records
                current_time = datetime.utcnow()
                for log in logs_without_created_at:
                    log.created_at = current_time
                
                # Commit the changes
                db.session.commit()
                print(f"✅ Updated {len(logs_without_created_at)} records with created_at")
            else:
                print("✅ No records need updating")
                
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            db.session.rollback()

if __name__ == "__main__":
    migrate_created_at()














