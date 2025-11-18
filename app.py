# pyright: reportCallIssue=false
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
from nutrition_model import NutritionModel
import os
import json
import sys
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text, func
from datetime import datetime, date, timedelta
from dotenv import load_dotenv
import requests
import re
import time
import threading
from config import config
from werkzeug.security import generate_password_hash, check_password_hash
import csv
import random
from email_service import (
    send_verification_email, 
    generate_verification_code,
    send_email_change_verification,
    send_account_deletion_verification,
    send_email_change_notification,
    send_password_change_verification,
    send_password_reset_verification
)
try:
    from zoneinfo import ZoneInfo
except ImportError:
    # Fallback for Python < 3.9
    try:
        from backports.zoneinfo import ZoneInfo
    except ImportError:
        ZoneInfo = None
        import pytz

# Load environment variables
load_dotenv()

# Optional Groq AI configuration (for AI Coach features)
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
GROQ_API_URL = os.environ.get(
    "GROQ_API_URL",
    "https://api.groq.com/openai/v1/chat/completions",
)
GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")

# Ensure instance directory exists for SQLite databases
try:
    base_dir = os.path.dirname(__file__)
    os.makedirs(os.path.join(base_dir, 'instance'), exist_ok=True)
except Exception:
    pass

def normalize_category(category: str) -> str:
    """Map any legacy or granular category to one of three standard buckets."""
    c = (category or '').strip().lower()
    if c in ['cardio', 'dance', 'sports']:
        return 'Cardio'
    if c in ['flexibility', 'mobility', 'yoga']:
        return 'Flexibility/Mobility'
    return 'Strength'

def category_aliases(requested: str):
    """Return a list of category labels that should be treated as the same bucket for filtering."""
    bucket = normalize_category(requested)
    if bucket == 'Cardio':
        return ['Cardio', 'cardio', 'Dance', 'dance', 'Sports', 'sports']
    if bucket == 'Flexibility/Mobility':
        return ['Flexibility/Mobility', 'Flexibility', 'flexibility', 'Mobility', 'mobility', 'Yoga', 'yoga']
    # Strength fallback
    return ['Strength', 'strength']

 

app = Flask(__name__)

# CORS configuration - allow all origins for development, restrict for production
# Mobile apps (Android/iOS) don't need CORS - only web browsers do
allowed_origins = os.environ.get('ALLOWED_ORIGINS', '*').split(',')
if allowed_origins == ['*']:
    # Development: allow all origins
    CORS(app)
else:
    # Production: allow specific origins only
    CORS(app, resources={
        r"/*": {
            "origins": allowed_origins,
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

# Configure app based on environment
# Auto-detect Railway environment (Railway sets PORT environment variable)
is_railway = os.environ.get('PORT') is not None or os.environ.get('RAILWAY_ENVIRONMENT') is not None
default_env = 'production' if is_railway else 'development'

config_name = (os.environ.get('FLASK_ENV') or default_env).strip().lower()
if config_name not in config:
    print(f"[WARN] Unknown FLASK_ENV '{config_name}', falling back to 'default'")
    config_name = 'default'
    
print(f"[INFO] Using config: {config_name} (FLASK_ENV={os.environ.get('FLASK_ENV', 'not set')}, Railway={is_railway})")
app.config.from_object(config[config_name])

# Validate required environment variables for production
if config_name == 'production' or is_railway:
    required_vars = {
        'NEON_DATABASE_URL': 'Database connection string (get from https://neon.tech)',
        'SECRET_KEY': 'Flask secret key for session security (generate with: python -c "import secrets; print(secrets.token_hex(32))")',
        'GMAIL_USERNAME': 'Gmail address for sending emails',
        'GMAIL_APP_PASSWORD': 'Gmail App Password (enable 2FA and generate at https://myaccount.google.com/apppasswords)'
    }
    
    missing_vars = []
    for var_name, description in required_vars.items():
        value = os.environ.get(var_name)
        if not value or value.strip() == '':
            missing_vars.append(f"  - {var_name}: {description}")
    
    if missing_vars:
        error_msg = "\n" + "="*80 + "\n"
        error_msg += "ERROR: Missing required environment variables for production!\n"
        error_msg += "="*80 + "\n"
        error_msg += "The following environment variables must be set in Railway:\n\n"
        error_msg += "\n".join(missing_vars)
        error_msg += "\n\n"
        error_msg += "To fix this:\n"
        error_msg += "1. Go to Railway Dashboard → Your Project → Variables tab\n"
        error_msg += "2. Add each missing variable with its value\n"
        error_msg += "3. Redeploy the service\n"
        error_msg += "="*80 + "\n"
        print(error_msg, file=sys.stderr)
        # Don't crash - let Railway show the error in logs
        # But make it very clear what's wrong

# Log which database URI is being used (without credentials)
try:
    active_uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
    if active_uri:
        redacted = active_uri
        # Basic redaction of credentials in URI for console log
        if '://' in active_uri and '@' in active_uri:
            scheme, rest = active_uri.split('://', 1)
            creds_host = rest.split('@', 1)
            if len(creds_host) == 2:
                redacted = f"{scheme}://***:***@{creds_host[1]}"
        print(f"[INFO] Using database: {redacted}")
except Exception:
    pass

# Log Groq AI configuration status
if GROQ_API_KEY:
    print(f"[INFO] Groq AI configured: Model={GROQ_MODEL}, URL={GROQ_API_URL}")
    print(f"[INFO] AI Coach features enabled (daily summary, meal suggestions, chat)")
else:
    print(f"[WARN] Groq API key not configured. AI Coach features will be unavailable.")
    print(f"[WARN] Set GROQ_API_KEY environment variable to enable AI features.")

db = SQLAlchemy(app)

# Flask 3 removed before_first_request; guard warm-up with a flag in before_request
_did_db_warm_up = False

@app.before_request
def _warm_up_db_connection_once():
    global _did_db_warm_up
    if _did_db_warm_up:
        return
    try:
        db.session.execute(text('SELECT 1'))
        db.session.commit()
        _did_db_warm_up = True
        print('[INFO] Database connection warm-up successful')
    except Exception as e:
        # Rollback any failed warm-up attempt but keep app running; try again next request
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f'[WARN] Database warm-up failed (will retry on next request): {e}')

@app.before_request
def _cleanup_expired_pending_registrations():
    """Clean up expired pending registrations (older than 15 minutes)"""
    try:
        expired_count = PendingRegistration.query.filter(
            PendingRegistration.verification_expires_at < datetime.utcnow()
        ).delete()
        if expired_count > 0:
            db.session.commit()
            print(f'[CLEANUP] Deleted {expired_count} expired pending registration(s)')
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        # Don't log cleanup errors as they're not critical

@app.before_request
def _cleanup_expired_pending_operations():
    """Clean up expired pending email changes, account deletions, and password changes"""
    try:
        # Clean up expired email changes
        expired_email_changes = PendingEmailChange.query.filter(
            PendingEmailChange.verification_expires_at < datetime.utcnow()
        ).delete()
        
        # Clean up expired account deletions
        expired_deletions = PendingAccountDeletion.query.filter(
            PendingAccountDeletion.verification_expires_at < datetime.utcnow()
        ).delete()
        
        # Clean up expired password changes (mark as expired first, then delete)
        expired_pending = PendingPasswordChange.query.filter(
            PendingPasswordChange.verification_expires_at < datetime.utcnow(),
            PendingPasswordChange.status == 'pending'
        ).all()
        
        expired_password_changes = len(expired_pending)
        
        # Mark as expired and delete
        if expired_password_changes > 0:
            for pending in expired_pending:
                pending.status = 'expired'
            db.session.commit()
            # Delete expired records
            PendingPasswordChange.query.filter(
                PendingPasswordChange.status == 'expired'
            ).delete()
        
        if expired_email_changes > 0 or expired_deletions > 0 or expired_password_changes > 0:
            db.session.commit()
            if expired_email_changes > 0:
                print(f'[CLEANUP] Deleted {expired_email_changes} expired pending email change(s)')
            if expired_deletions > 0:
                print(f'[CLEANUP] Deleted {expired_deletions} expired pending account deletion(s)')
            if expired_password_changes > 0:
                print(f'[CLEANUP] Deleted {expired_password_changes} expired pending password change(s)')
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        # Don't log cleanup errors as they're not critical

# --- Progress Tracking Models ---
class WeightLog(db.Model):
    __tablename__ = 'weight_logs'
    __table_args__ = (
        db.Index('ix_weight_logs_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    weight = db.Column(db.Float, nullable=False)
    date = db.Column(db.Date, nullable=False, default=date.today)

class FoodLog(db.Model):
    __tablename__ = 'food_logs'
    __table_args__ = (
        db.Index('ix_food_logs_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    food_name = db.Column(db.String(200), nullable=False)
    calories = db.Column(db.Float, nullable=False)
    meal_type = db.Column(db.String(50), nullable=True)
    serving_size = db.Column(db.String(100), nullable=True)
    quantity = db.Column(db.Float, default=1.0)
    protein = db.Column(db.Float, default=0.0)
    carbs = db.Column(db.Float, default=0.0)
    fat = db.Column(db.Float, default=0.0)
    fiber = db.Column(db.Float, default=0.0)
    sodium = db.Column(db.Float, default=0.0)
    date = db.Column(db.Date, nullable=False, default=date.today)
    # created_at = db.Column(db.DateTime, nullable=True, default=datetime.utcnow)  # Temporarily disabled

class WorkoutLog(db.Model):
    __tablename__ = 'workout_logs'
    __table_args__ = (
        db.Index('ix_workout_logs_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    type = db.Column(db.String(80))
    duration = db.Column(db.Float)
    calories_burned = db.Column(db.Float)
    date = db.Column(db.Date, nullable=False, default=date.today)

class ExerciseLog(db.Model):
    __tablename__ = 'exercise_logs'
    __table_args__ = (
        db.Index('ix_exercise_logs_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80))
    exercise = db.Column(db.String(120))
    calories = db.Column(db.Float)
    date = db.Column(db.Date, default=datetime.utcnow)

@app.route('/health')
def health():
    """Lightweight health check for DB and model readiness."""
    try:
        db_ok = bool(db.session.execute(db.text('SELECT 1')).scalar())
    except Exception as e:
        return jsonify({'ok': False, 'db': False, 'model': False, 'error': str(e)}), 500
    try:
        model_ok = bool(nutrition_model and nutrition_model.is_model_loaded())
    except Exception:
        model_ok = False
    return jsonify({'ok': db_ok and model_ok, 'db': db_ok, 'model': model_ok}), 200

@app.route('/debug/console')
def debug_console():
    """Diagnostic console for quick operational checks.

    Optional query params:
      - user: username to validate onboarding completeness
      - query: food query to probe search-style prediction
    """
    resp = {
        'ok': False,
        'db': False,
        'model': False,
        'tables': {},
        'user': {},
        'predictions': {}
    }
    # DB health and lightweight counts
    try:
        resp['db'] = bool(db.session.execute(db.text('SELECT 1')).scalar())
        # Count a few key tables (catch errors individually)
        for name, model in [('users', User), ('food_logs', FoodLog), ('exercises', Exercise)]:
            try:
                resp['tables'][name] = model.query.limit(1).count()
            except Exception as e:
                resp['tables'][name] = f'error: {e}'
    except Exception as e:
        resp['db_error'] = str(e)

    # Model health + sample predictions
    try:
        resp['model'] = bool(nutrition_model and nutrition_model.is_model_loaded())
        # Known food via DB lookup
        try:
            known = nutrition_model.predict_calories('adobo', serving_size=100)
            resp['predictions']['known'] = {'method': known.get('method'), 'calories': known.get('calories')}
        except Exception as e:
            resp['predictions']['known'] = {'error': str(e)}
        # Unknown food via ML path
        try:
            unknown = nutrition_model.predict_calories('debug custom item', food_category='meats', serving_size=100, preparation_method='fried', ingredients=['pork'])
            resp['predictions']['unknown'] = {'method': unknown.get('method'), 'calories': unknown.get('calories')}
        except Exception as e:
            resp['predictions']['unknown'] = {'error': str(e)}
    except Exception as e:
        resp['model_error'] = str(e)

    # Optional user completeness check
    try:
        username = request.args.get('user')
        if username:
            user_obj = User.query.filter_by(username=username).first()
            if not user_obj:
                resp['user'] = {'username': username, 'exists': False}
            else:
                required = ['sex','age','height_cm','weight_kg','activity_level','goal']
                missing = []
                for f in required:
                    if getattr(user_obj, f, None) in (None, ''):
                        missing.append(f)
                resp['user'] = {
                    'username': username,
                    'exists': True,
                    'missing': missing,
                }
    except Exception as e:
        resp['user_error'] = str(e)

    # Optional ad-hoc query probe
    q = (request.args.get('query') or '').strip()
    if q:
        try:
            pn = nutrition_model.predict_nutrition(
                food_name=q,
                serving_size=100,
                user_gender='male',
                user_age=25,
                user_weight=70,
                user_height=175,
                user_activity_level='active',
                user_goal='maintain'
            )
            resp['predictions']['probe'] = {
                'name': q,
                'calories_100g': pn.get('nutrition_info', {}).get('calories'),
                'method': pn.get('method', 'mixed')
            }
        except Exception as e:
            resp['predictions']['probe'] = {'error': str(e)}

    resp['ok'] = bool(resp.get('db')) and bool(resp.get('model'))
    return jsonify(resp), (200 if resp['ok'] else 500)

# New enhanced exercise models
class Exercise(db.Model):
    """Exercise database model for storing ExerciseDB data locally"""
    __tablename__ = 'exercises'
    __table_args__ = (
        db.Index('ix_exercises_name', 'name'),
        db.Index('ix_exercises_category', 'category'),
    )
    id = db.Column(db.Integer, primary_key=True)
    exercise_id = db.Column(db.String(50), unique=True)  # ExerciseDB ID
    name = db.Column(db.String(200), nullable=False)
    body_part = db.Column(db.String(100))
    equipment = db.Column(db.String(100))
    target = db.Column(db.String(100))
    gif_url = db.Column(db.String(500))
    instructions = db.Column(db.Text)  # JSON string of instructions
    category = db.Column(db.String(50))  # Cardio, Strength, etc.
    difficulty = db.Column(db.String(20))  # Beginner, Intermediate, Advanced
    estimated_calories_per_minute = db.Column(db.Integer, default=5)  # Deprecated: kept for backward compatibility
    met_value = db.Column(db.Float, default=None)  # MET (Metabolic Equivalent of Task) value for personalized calorie calculation
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class ExerciseSession(db.Model):
    """Model for tracking exercise sessions with timer data"""
    __tablename__ = 'exercise_sessions'
    __table_args__ = (
        db.Index('ix_exercise_sessions_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    exercise_id = db.Column(db.String(50), nullable=False)
    exercise_name = db.Column(db.String(200), nullable=False)
    duration_seconds = db.Column(db.Integer, default=0)
    calories_burned = db.Column(db.Float, default=0.0)
    sets_completed = db.Column(db.Integer, default=1)
    notes = db.Column(db.Text)
    date = db.Column(db.Date, nullable=False, default=date.today)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Streak(db.Model):
    """Model for tracking user streaks (calories or exercise)"""
    __tablename__ = 'streaks'
    __table_args__ = (
        db.Index('ix_streaks_user_type', 'user', 'streak_type'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(88), nullable=False)
    current_streak = db.Column(db.Integer, default=0)
    longest_streak = db.Column(db.Integer, default=0)
    last_activity_date = db.Column(db.Date, nullable=True)
    streak_start_date = db.Column(db.Date, nullable=True)
    streak_type = db.Column(db.String(58), nullable=False)  # 'calories' or 'exercise'
    minimum_exercise_minutes = db.Column(db.Integer, default=15)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# --- Goal History Tracking ---
class GoalHistory(db.Model):
    """Model for tracking historical daily calorie goals"""
    __tablename__ = 'goal_history'
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column('user', db.String(80), nullable=False, index=True)  # 'user' is reserved in PostgreSQL
    date = db.Column(db.Date, nullable=False, index=True)  # The date this goal was active
    daily_calorie_goal = db.Column(db.Integer, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Note: Composite index is created in database migration
    # SQLAlchemy will handle quoting automatically when using column names
    # The index 'ix_goal_history_user_date' already exists from migration
    
    def to_dict(self):
        return {
            'id': self.id,
            'user': self.user,
            'date': self.date.isoformat() if self.date else None,
            'daily_calorie_goal': self.daily_calorie_goal,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

# --- User-submitted custom exercises ---
class UserExerciseSubmission(db.Model):
    __tablename__ = 'user_exercise_submissions'
    __table_args__ = (
        db.Index('ix_user_ex_submissions_status', 'status'),
        db.Index('ix_user_ex_submissions_user', 'user'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    name = db.Column(db.String(200), nullable=False)
    category = db.Column(db.String(80))
    intensity = db.Column(db.String(20))
    duration_min = db.Column(db.Integer)
    reps = db.Column(db.Integer)
    sets = db.Column(db.Integer)
    notes = db.Column(db.Text)
    est_calories = db.Column(db.Integer)
    status = db.Column(db.String(20), default='pending')  # pending|approved|rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class PendingRegistration(db.Model):
    """Temporary storage for unverified registrations"""
    __tablename__ = 'pending_registrations'
    __table_args__ = (
        db.Index('ix_pending_reg_email', 'email'),
    )
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), nullable=False, index=True)
    username = db.Column(db.String(80), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(200), nullable=True)
    verification_code = db.Column(db.String(10), nullable=False)
    verification_expires_at = db.Column(db.DateTime, nullable=False, index=True)
    registration_data = db.Column(db.Text, nullable=True)  # JSON string for all user data
    resend_count = db.Column(db.Integer, default=0, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

class PendingEmailChange(db.Model):
    """Temporary storage for pending email change requests"""
    __tablename__ = 'pending_email_changes'
    __table_args__ = (
        db.Index('ix_pending_email_user', 'user_id'),
        db.Index('ix_pending_email_expires', 'verification_expires_at'),
        db.Index('ix_pending_email_new_email', 'new_email'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    username = db.Column(db.String(80), nullable=False)
    old_email = db.Column(db.String(120), nullable=False)
    new_email = db.Column(db.String(120), nullable=False)
    verification_code = db.Column(db.String(10), nullable=False)
    verification_expires_at = db.Column(db.DateTime, nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    resend_count = db.Column(db.Integer, default=0, nullable=False)

class PendingAccountDeletion(db.Model):
    """Temporary storage for pending account deletion requests"""
    __tablename__ = 'pending_account_deletions'
    __table_args__ = (
        db.Index('ix_pending_deletion_user', 'user_id'),
        db.Index('ix_pending_deletion_expires', 'verification_expires_at'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    username = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    verification_code = db.Column(db.String(10), nullable=False)
    verification_expires_at = db.Column(db.DateTime, nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    resend_count = db.Column(db.Integer, default=0, nullable=False)

class PendingPasswordChange(db.Model):
    """Temporary storage for pending password change/reset requests"""
    __tablename__ = 'pending_password_changes'
    __table_args__ = (
        db.Index('ix_pending_password_user', 'user_id'),
        db.Index('ix_pending_password_expires', 'verification_expires_at'),
        db.Index('ix_pending_password_email', 'email'),
        db.Index('ix_pending_password_ip', 'ip_address'),
        db.Index('ix_pending_password_status', 'status'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    username = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    verification_code = db.Column(db.String(10), nullable=False)
    verification_expires_at = db.Column(db.DateTime, nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    resend_count = db.Column(db.Integer, default=0, nullable=False)
    request_count = db.Column(db.Integer, default=1, nullable=False)
    failed_attempts = db.Column(db.Integer, default=0, nullable=False)
    ip_address = db.Column(db.String(45), nullable=True, index=True)
    new_password_hash = db.Column(db.String(255), nullable=False)
    # Status tracking for security
    status = db.Column(db.String(20), default='pending', nullable=False, index=True)  # pending, verified, cancelled, expired
    verified_at = db.Column(db.DateTime, nullable=True)
    cancelled_at = db.Column(db.DateTime, nullable=True)

class User(db.Model):
    __tablename__ = 'users'
    __table_args__ = (
        db.Index('ix_users_username', 'username'),
    )
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password = db.Column(db.String(255), nullable=True)  # Add password field
    age = db.Column(db.Integer, nullable=False)
    sex = db.Column(db.String(10), nullable=False)
    weight_kg = db.Column(db.Float, nullable=False)
    height_cm = db.Column(db.Float, nullable=False)
    activity_level = db.Column(db.String(50), nullable=False)
    goal = db.Column(db.String(50), nullable=False)
    target_weight = db.Column(db.Float, nullable=True)
    timeline = db.Column(db.String(50), nullable=True)
    motivation = db.Column(db.Text, nullable=True)
    experience = db.Column(db.String(50), nullable=True)
    current_state = db.Column(db.String(50), nullable=True)
    schedule = db.Column(db.String(50), nullable=True)
    exercise_types = db.Column(db.Text, nullable=True)  # JSON string
    exercise_equipment = db.Column(db.Text, nullable=True)  # JSON string
    exercise_experience = db.Column(db.String(50), nullable=True)
    exercise_limitations = db.Column(db.Text, nullable=True)
    workout_duration = db.Column(db.String(50), nullable=True)
    workout_frequency = db.Column(db.String(50), nullable=True)
    diet_type = db.Column(db.String(50), nullable=True)
    restrictions = db.Column(db.Text, nullable=True)  # JSON string
    allergies = db.Column(db.Text, nullable=True)  # JSON string
    cooking_frequency = db.Column(db.String(50), nullable=True)
    cooking_skill = db.Column(db.String(50), nullable=True)
    meal_prep_habit = db.Column(db.Text, nullable=True)  # JSON string
    tracking_experience = db.Column(db.String(50), nullable=True)
    used_apps = db.Column(db.Text, nullable=True)  # JSON string
    data_importance = db.Column(db.String(50), nullable=True)
    is_metric = db.Column(db.Boolean, default=True)
    daily_calorie_goal = db.Column(db.Integer, nullable=True)
    has_seen_tutorial = db.Column(db.Boolean, default=False)
    email_verified = db.Column(db.Boolean, default=False, nullable=False)
    verification_code = db.Column(db.String(10), nullable=True)
    verification_expires_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ===== Password Strength Validation Functions =====

def validate_password_strength(password: str) -> dict:
    """
    Validate password strength and return result.
    
    Returns:
        {
            'strength': 'weak' | 'medium' | 'strong',
            'score': int (0-5),
            'requirements_met': list of strings,
            'requirements_missing': list of strings,
            'is_valid': bool (True if medium or strong)
        }
    """
    if not password:
        return {
            'strength': 'weak',
            'score': 0,
            'requirements_met': [],
            'requirements_missing': ['length', 'uppercase', 'number', 'special'],
            'is_valid': False
        }
    
    requirements_met = []
    requirements_missing = []
    score = 0
    
    # Check length (minimum 8 characters)
    has_length = len(password) >= 8
    if has_length:
        requirements_met.append('length')
        score += 1
    else:
        requirements_missing.append('length')
    
    # Check uppercase letter
    has_upper = bool(re.search(r'[A-Z]', password))
    if has_upper:
        requirements_met.append('uppercase')
        score += 1
    else:
        requirements_missing.append('uppercase')
    
    # Check lowercase letter
    has_lower = bool(re.search(r'[a-z]', password))
    if has_lower:
        requirements_met.append('lowercase')
        score += 1
    else:
        requirements_missing.append('lowercase')
    
    # Check number
    has_digit = bool(re.search(r'[0-9]', password))
    if has_digit:
        requirements_met.append('number')
        score += 1
    else:
        requirements_missing.append('number')
    
    # Check special character
    has_special = bool(re.search(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?~]', password))
    if has_special:
        requirements_met.append('special')
        score += 1
    else:
        requirements_missing.append('special')
    
    # Determine strength
    # Core requirements: length >= 8, uppercase, number
    # Special character is optional - passwords without it can still be medium
    core_requirements_met = sum([has_length, has_upper, has_digit])
    
    # Weak: less than 3 core requirements (length, uppercase, number) OR score <= 2
    # Note: Special character is not required for medium strength
    if core_requirements_met < 3 or score <= 2:
        strength = 'weak'
        is_valid = False
    # Medium: has length, uppercase, and number (3 core requirements) AND score >= 3
    # Can be medium even without special character
    elif core_requirements_met >= 3 and score >= 3:
        strength = 'medium'
        is_valid = True
    # Strong: all 5 requirements met (length, uppercase, lowercase, number, special) AND score == 5
    else:  # score == 5
        strength = 'strong'
        is_valid = True
    
    return {
        'strength': strength,
        'score': score,
        'requirements_met': requirements_met,
        'requirements_missing': requirements_missing,
        'is_valid': is_valid
    }

def check_common_passwords(password: str) -> bool:
    """
    Check if password is in common passwords list.
    
    Returns:
        True if password is common (should be rejected), False otherwise
    """
    # Top 20 most common passwords (expandable)
    common_passwords = [
        'password', 'password123', 'Password123', 'PASSWORD123',
        '12345678', '123456789', '1234567890',
        'qwerty', 'qwerty123', 'Qwerty123',
        'admin', 'admin123', 'Admin123',
        'welcome', 'welcome123', 'Welcome123',
        'letmein', 'monkey', 'dragon',
        'sunshine', 'master', 'football'
    ]
    
    password_lower = password.lower()
    return password_lower in [p.lower() for p in common_passwords]

def check_password_similarity(password: str, username: str = None, email: str = None) -> dict:
    """
    Check if password is too similar to username or email.
    
    Returns:
        {
            'is_similar': bool,
            'reason': str (if similar)
        }
    """
    password_lower = password.lower()
    
    if username:
        username_lower = username.lower()
        if username_lower in password_lower or password_lower in username_lower:
            return {
                'is_similar': True,
                'reason': 'Password cannot contain your username'
            }
    
    if email:
        email_lower = email.lower()
        # Extract email username (before @)
        email_username = email_lower.split('@')[0] if '@' in email_lower else email_lower
        if email_username and (email_username in password_lower or password_lower in email_username):
            return {
                'is_similar': True,
                'reason': 'Password cannot contain your email address'
            }
    
    return {
        'is_similar': False,
        'reason': None
    }

def get_client_ip() -> str:
    """Get client IP address from request"""
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    elif request.headers.get('X-Real-IP'):
        return request.headers.get('X-Real-IP')
    else:
        return request.remote_addr or 'unknown'

def get_user_by_identifier(identifier: str):
    """Return a User matched by username or email (case-insensitive)."""
    if not identifier:
        return None
    ident = identifier.strip()
    if not ident:
        return None
    ident_lower = ident.lower()
    query = None
    try:
        if '@' in ident_lower:
            query = User.query.filter(func.lower(User.email) == ident_lower)
        else:
            query = User.query.filter(func.lower(User.username) == ident_lower)
        return query.first()
    except Exception:
        return None

# --- Custom Recipes Models ---
class CustomRecipe(db.Model):
    """Model for storing custom recipes created by users"""
    __tablename__ = 'custom_recipes'
    __table_args__ = (
        db.Index('ix_custom_recipes_user', 'user'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    recipe_name = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    servings = db.Column(db.Integer, default=1)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class RecipeIngredient(db.Model):
    """Model for storing ingredients in custom recipes"""
    __tablename__ = 'recipe_ingredients'
    __table_args__ = (
        db.Index('ix_recipe_ingredients_recipe', 'recipe_id'),
    )
    id = db.Column(db.Integer, primary_key=True)
    recipe_id = db.Column(db.Integer, db.ForeignKey('custom_recipes.id'), nullable=False)
    ingredient_name = db.Column(db.String(200), nullable=False)
    quantity = db.Column(db.Float, nullable=False)
    unit = db.Column(db.String(50), nullable=False)
    calories = db.Column(db.Float, default=0.0)
    protein = db.Column(db.Float, default=0.0)
    carbs = db.Column(db.Float, default=0.0)
    fat = db.Column(db.Float, default=0.0)
    fiber = db.Column(db.Float, default=0.0)
    sodium = db.Column(db.Float, default=0.0)

class RecipeLog(db.Model):
    """Model for logging when users consume custom recipes"""
    __tablename__ = 'recipe_logs'
    __table_args__ = (
        db.Index('ix_recipe_logs_user_date', 'user', 'date'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(80), nullable=False)
    recipe_id = db.Column(db.Integer, db.ForeignKey('custom_recipes.id'), nullable=False)
    servings_consumed = db.Column(db.Float, default=1.0)
    meal_type = db.Column(db.String(50), default='Other')
    date = db.Column(db.Date, nullable=False, default=date.today)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# --- Import helper for local CSV (shared by startup and endpoint) ---
def _import_exercises_from_csv_path(csv_path: str) -> tuple[int, int]:
    added = 0
    updated = 0
    if not os.path.exists(csv_path):
        return added, updated
    with open(csv_path, 'r', encoding='utf-8') as f:
        # Read first line to check if it's blank
        first_line = f.readline()
        if not first_line.strip():
            # Skip blank first line - file pointer is already at line 2
            pass
        else:
            # Rewind to start if first line is not blank
            f.seek(0)
        reader = csv.DictReader(f)
        required = {
            'id','name','category','body_part','target','equipment','difficulty','calories_per_minute','instructions','tags'
        }
        if not required.issubset(set([c.strip() for c in (reader.fieldnames or [])])):
            print(f"[WARNING] CSV missing required fields. Found: {reader.fieldnames}")
            return added, updated
        for row in reader:
            try:
                ext_id = row.get('id')
                existing = Exercise.query.filter_by(exercise_id=ext_id).first()
                if existing:
                    existing.name = row.get('name','')
                    existing.body_part = row.get('body_part','')
                    existing.equipment = row.get('equipment','')
                    existing.target = row.get('target','')
                    existing.gif_url = existing.gif_url or ''
                    # Parse instructions - CSV has numbered list format like "1. Step one. 2. Step two."
                    instructions_text = row.get('instructions', '')
                    # Split by numbered pattern (1., 2., etc.) or semicolon
                    if instructions_text:
                        # Try splitting by numbered list first
                        import re
                        parts = re.split(r'\d+\.\s+', instructions_text)
                        parts = [p.strip() for p in parts if p.strip()]
                        if len(parts) > 1:
                            existing.instructions = json.dumps(parts)
                        else:
                            # Fallback to semicolon split
                            existing.instructions = json.dumps([s.strip() for s in instructions_text.split(';') if s.strip()])
                    else:
                        existing.instructions = json.dumps([])
                    existing.category = row.get('category','')
                    existing.difficulty = row.get('difficulty','')
                    try:
                        cpm = int(float(row.get('calories_per_minute', '5')))
                        existing.estimated_calories_per_minute = cpm
                        # Derive MET from calories_per_minute (assuming 70kg person)
                        if existing.met_value is None:
                            existing.met_value = (float(cpm) * 60) / 70.0
                    except Exception:
                        existing.estimated_calories_per_minute = 5
                        if existing.met_value is None:
                            existing.met_value = (5.0 * 60) / 70.0
                    updated += 1
                else:
                    cpm = int(float(row.get('calories_per_minute', '5')))
                    # Derive MET from calories_per_minute (assuming 70kg person)
                    met_val = (float(cpm) * 60) / 70.0
                    
                    # Parse instructions - CSV has numbered list format like "1. Step one. 2. Step two."
                    instructions_text = row.get('instructions', '')
                    if instructions_text:
                        # Try splitting by numbered list first
                        import re
                        parts = re.split(r'\d+\.\s+', instructions_text)
                        parts = [p.strip() for p in parts if p.strip()]
                        if len(parts) > 1:
                            instructions_json = json.dumps(parts)
                        else:
                            # Fallback to semicolon split
                            instructions_json = json.dumps([s.strip() for s in instructions_text.split(';') if s.strip()])
                    else:
                        instructions_json = json.dumps([])
                    
                    ex = Exercise(
                        exercise_id=ext_id,
                        name=row.get('name',''),
                        body_part=row.get('body_part',''),
                        equipment=row.get('equipment',''),
                        target=row.get('target',''),
                        gif_url='',
                        instructions=instructions_json,
                        category=row.get('category',''),
                        difficulty=row.get('difficulty',''),
                        estimated_calories_per_minute=cpm,
                        met_value=met_val
                    )
                    db.session.add(ex)
                    added += 1
            except Exception as e:
                # Log first few errors for debugging
                if added + updated < 5:
                    print(f"[WARNING] Error importing exercise {row.get('id', 'unknown')}: {e}")
                continue
    try:
        db.session.commit()
    except Exception as e:
        print(f"[ERROR] Failed to commit exercises: {e}")
        db.session.rollback()
    return added, updated

# Initialize the nutrition model (with error handling)
try:
    # Use absolute path for model file
    base_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(base_dir, 'model', 'best_regression_model.joblib')
    print(f"[DEBUG] Looking for model at: {model_path}")
    print(f"[DEBUG] Model file exists: {os.path.exists(model_path)}")
    if os.path.exists(model_path):
        file_size = os.path.getsize(model_path) / (1024 * 1024)  # Size in MB
        print(f"[DEBUG] Model file size: {file_size:.2f} MB")
    nutrition_model = NutritionModel(model_path=model_path)
    print("[SUCCESS] Nutrition model initialized")
except Exception as e:
    print(f"[WARNING] Nutrition model initialization failed: {e}")
    print("[INFO] App will continue but ML features may not work")
    nutrition_model = None

# Initialize database tables (with proper error handling)
db_initialized = False
try:
    # Check if database URL is set
    db_url = app.config.get('SQLALCHEMY_DATABASE_URI', '')
    if not db_url or db_url.strip() == '':
        raise ValueError("SQLALCHEMY_DATABASE_URI is not set. NEON_DATABASE_URL environment variable is required.")
    
    with app.app_context():
        # Test database connection
        try:
            db.session.execute(text('SELECT 1'))
            db.session.commit()
            print("[SUCCESS] Database connection verified")
        except Exception as conn_err:
            raise ConnectionError(f"Failed to connect to database: {conn_err}. Check your NEON_DATABASE_URL.")
        
        db.create_all()
        print("[SUCCESS] Database tables initialized successfully")
        db_initialized = True
        
        # Auto-import exercises from CSV if database is empty or has few exercises
        try:
            exercise_count = Exercise.query.count()
            if exercise_count < 50:  # If less than 50 exercises, import from CSV
                print(f"[INFO] Found {exercise_count} exercises in database. Importing from CSV...")
                base_dir = os.path.dirname(os.path.abspath(__file__))
                csv_paths = [
                    os.path.join(base_dir, 'data', 'exercises.csv'),
                    os.path.join(base_dir, 'exercises.csv'),
                ]
                for csv_path in csv_paths:
                    if os.path.exists(csv_path):
                        added, updated = _import_exercises_from_csv_path(csv_path)
                        print(f"[SUCCESS] Imported exercises from {csv_path}: {added} added, {updated} updated")
                        break
                else:
                    print(f"[WARNING] Exercises CSV not found. Tried paths: {csv_paths}")
            else:
                print(f"[INFO] Database already has {exercise_count} exercises. Skipping import.")
        except Exception as e:
            print(f"[WARNING] Exercise import failed: {e}")
            # Continue - exercises can be imported later
except Exception as e:
    error_msg = "\n" + "="*80 + "\n"
    error_msg += "CRITICAL ERROR: Database initialization failed!\n"
    error_msg += "="*80 + "\n"
    error_msg += f"Error: {str(e)}\n\n"
    error_msg += "The app cannot function without a working database connection.\n"
    error_msg += "Please ensure NEON_DATABASE_URL is correctly set in Railway.\n"
    error_msg += "="*80 + "\n"
    print(error_msg, file=sys.stderr)
    # In production, we should fail fast - but let Railway show the error first
    if config_name == 'production' or is_railway:
        # Don't crash immediately - let Railway logs show the error
        # But make it very clear the app won't work
        pass

# Load Filipino food dataset at startup (robust path + encoding)
try:
    # Try multiple possible locations for the CSV file
    base_dir = os.path.dirname(os.path.abspath(__file__))  # Root directory
    print(f"[DEBUG] Base directory: {base_dir}")
    possible_paths = [
        os.path.join(base_dir, 'nutrition_flutter', 'lib', 'Filipino_Food_Nutrition_Dataset.csv'),  # nutrition_flutter/lib/ folder
        os.path.join(base_dir, 'data', 'Filipino_Food_Nutrition_Dataset.csv'),  # data/ folder
        os.path.join(base_dir, 'Filipino_Food_Nutrition_Dataset.csv'),  # Root directory
        os.path.join(os.path.dirname(__file__), 'Filipino_Food_Nutrition_Dataset.csv'),  # Same dir as app.py
    ]
    
    # Debug: List files in data directory
    data_dir = os.path.join(base_dir, 'data')
    if os.path.exists(data_dir):
        print(f"[DEBUG] Contents of data/ directory:")
        try:
            for item in os.listdir(data_dir):
                item_path = os.path.join(data_dir, item)
                if os.path.isfile(item_path):
                    size = os.path.getsize(item_path) / 1024  # KB
                    print(f"  - {item} ({size:.2f} KB)")
        except Exception as e:
            print(f"  [ERROR] Could not list data directory: {e}")
    
    FOOD_CSV_PATH = None
    for path in possible_paths:
        if os.path.exists(path):
            FOOD_CSV_PATH = path
            print(f"[DEBUG] Found CSV at: {path}")
            break
    
    if FOOD_CSV_PATH and os.path.exists(FOOD_CSV_PATH):
        food_df = pd.read_csv(FOOD_CSV_PATH, encoding='utf-8')
        print(f'[SUCCESS] Loaded Filipino food dataset from {FOOD_CSV_PATH}')
        print(f'[INFO] Dataset contains {len(food_df)} foods')
    else:
        # Minimal fallback DataFrame
        print(f"[WARNING] Filipino food CSV not found. Tried paths:")
        for path in possible_paths:
            exists = os.path.exists(path)
            print(f"  - {path} (exists: {exists})")
        print(f"[WARNING] Using empty dataset - search will not work!")
        food_df = pd.DataFrame(columns=['Food Name','Calories','Protein (g)','Carbs (g)','Fat (g)','Fiber (g)','Sodium (mg)'])
except Exception as e:
    print(f"[ERROR] Failed to load Filipino food dataset: {e}")
    import traceback
    traceback.print_exc()
    food_df = pd.DataFrame(columns=['Food Name','Calories','Protein (g)','Carbs (g)','Fat (g)','Fiber (g)','Sodium (mg)'])


# --- Calorie Goal Helpers (single source of truth) ---
def normalize_activity_level(level: str) -> str:
    l = (level or '').strip().lower().replace('-', ' ')
    mapping = {
        'sedentary': 'sedentary',
        'lightly active': 'lightly active',
        'lightly_active': 'lightly active',
        'lightlyactive': 'lightly active',
        'moderate': 'active',
        'moderately active': 'active',
        'moderately_active': 'active',
        'active': 'active',
        'very active': 'very active',
        'very_active': 'very active',
        'veryactive': 'very active',
    }
    return mapping.get(l, 'active')

def normalize_goal(goal: str) -> str:
    g = (goal or '').strip().lower().replace('_', ' ')
    mapping = {
        'maintain': 'maintain',
        'lose weight': 'lose weight',
        'lose weights': 'lose weight',
        'gain muscle': 'gain muscle',
        'gain weight': 'gain weight',
        'improve health': 'improve health',
        'body recomposition': 'body recomposition',
        'athletic performance': 'athletic performance',
    }
    return mapping.get(g, 'maintain')

ALLOWED_ACTIVITY_LEVELS = {'sedentary', 'lightly active', 'active', 'very active'}
ALLOWED_GOALS = {
    'maintain', 'lose weight', 'gain muscle', 'gain weight', 'body recomposition', 'athletic performance', 'improve health'
}

def validate_metrics(age: int, weight_kg: float, height_cm: float) -> tuple[bool, str]:
    if age is None:
        return False, 'Age is required'
    if not (21 <= int(age) <= 120):
        return False, 'You must be at least 21 years old'
    if weight_kg is None:
        return False, 'Weight is required'
    if not (30 <= float(weight_kg) <= 300):
        return False, 'Weight must be between 30-300 kg'
    if height_cm is None:
        return False, 'Height is required'
    if not (100 <= float(height_cm) <= 250):
        return False, 'Height must be between 100-250 cm'
    return True, ''

def compute_daily_calorie_goal(sex: str, age: int, weight_kg: float, height_cm: float, activity_level: str, goal: str) -> int:
    s = (sex or '').lower()
    lvl = normalize_activity_level(activity_level)

    # BMR (Mifflin-St Jeor)
    if s == 'female':
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5

    multipliers = {
        'sedentary': 1.2,
        'lightly active': 1.375,
        'active': 1.55,
        'very active': 1.725,
    }
    tdee = bmr * multipliers.get(lvl, 1.55)

    g = (goal or '').lower()
    if g == 'lose weight' or g == 'lose weights':
        tdee -= 300
    elif g == 'gain muscle':
        tdee += 200
    elif g == 'gain weight':
        tdee += 300
    elif g == 'improve health':
        # Slight optimization uplift similar to frontend behavior
        tdee += 50
    elif g == 'body recomposition':
        tdee -= 100
    elif g == 'athletic performance':
        tdee += 150

    # Scientific ranges per sex/age (19-30 default buckets)
    if s == 'female':
        if 19 <= age <= 30:
            min_calories, max_calories = 1800, (2400 if lvl in ['active', 'very active'] else 2200)
        elif 31 <= age <= 50:
            min_calories, max_calories = 1800, (2200 if lvl in ['active', 'very active'] else 2000)
        else:
            min_calories, max_calories = 1600, (2000 if lvl in ['active', 'very active'] else 1800)
    else:
        if 19 <= age <= 30:
            min_calories, max_calories = 2400, (3000 if lvl in ['active', 'very active'] else 2800)
        elif 31 <= age <= 50:
            min_calories, max_calories = 2200, (2800 if lvl in ['active', 'very active'] else 2600)
        else:
            min_calories, max_calories = 2000, (2600 if lvl in ['active', 'very active'] else 2400)

    # Clamp to scientific range with minor headroom for gain goals
    allowed_excess = 100 if g in ['gain muscle', 'gain weight'] else 0
    if tdee < min_calories:
        tdee = min_calories
    if tdee > max_calories + allowed_excess:
        tdee = max_calories + allowed_excess

    # Absolute safety caps
    if s == 'female':
        tdee = max(1200, min(tdee, 2800))
    else:
        tdee = max(1500, min(tdee, 3500))

    return int(round(tdee))

def normalize_measurements(weight: float, height: float) -> tuple[float, float]:
    try:
        w = float(weight)
        h = float(height)
        if w > 250:  # likely pounds
            w = w * 0.453592
        if h > 250:  # likely inches
            h = h * 2.54
        return w, h
    except Exception:
        return float(weight), float(height)

def get_exercise_met_value(exercise: Exercise) -> float:
    """Get MET value for an exercise. If not set, derive from estimated_calories_per_minute (assuming 70kg person)."""
    if exercise.met_value is not None and exercise.met_value > 0:
        return float(exercise.met_value)
    
    # Fallback: derive MET from estimated_calories_per_minute (assuming 70kg person)
    # Formula: calories_per_minute = (MET × weight_kg) / 60
    # So: MET = (calories_per_minute × 60) / weight_kg
    # Assuming 70kg person: MET = (calories_per_minute × 60) / 70
    cpm = exercise.estimated_calories_per_minute or 5
    derived_met = (float(cpm) * 60) / 70.0
    return round(derived_met, 1)

def calculate_calories_burned(met_value: float, weight_kg: float, duration_minutes: float) -> float:
    """
    Calculate calories burned using MET formula.
    
    Formula: Calories = MET × Weight (kg) × Duration (hours)
    Or per minute: Calories per minute = (MET × Weight) / 60
    
    Args:
        met_value: MET (Metabolic Equivalent of Task) value for the exercise
        weight_kg: User's weight in kilograms
        duration_minutes: Duration of exercise in minutes
    
    Returns:
        Total calories burned
    """
    # Convert minutes to hours for the formula
    duration_hours = duration_minutes / 60.0
    calories = met_value * weight_kg * duration_hours
    return round(calories, 2)

def calculate_calories_per_minute(met_value: float, weight_kg: float) -> float:
    """
    Calculate calories burned per minute using MET formula.
    
    Formula: Calories per minute = (MET × Weight in kg) / 60
    
    Args:
        met_value: MET (Metabolic Equivalent of Task) value for the exercise
        weight_kg: User's weight in kilograms
    
    Returns:
        Calories burned per minute
    """
    calories_per_min = (met_value * weight_kg) / 60.0
    return round(calories_per_min, 2)

 

@app.route('/exercises', methods=['GET'])
def get_exercises():
    """Get exercises with optional filtering"""
    try:
        category = request.args.get('category')
        search = request.args.get('search')
        limit = request.args.get('limit', 200, type=int)
        
        query = Exercise.query
        
        if category:
            aliases = category_aliases(category)
            query = query.filter(Exercise.category.in_(aliases))
        
        if search:
            search_term = f'%{search}%'
            query = query.filter(
                db.or_(
                    Exercise.name.ilike(search_term),
                    Exercise.target.ilike(search_term),
                    Exercise.equipment.ilike(search_term)
                )
            )
        
        exercises = query.order_by(Exercise.name.asc()).limit(limit).all()

        # No automatic seeding; return what exists
        
        # Get user's weight if provided for personalized calculations
        user = request.args.get('user')
        weight_kg = request.args.get('weight_kg')
        
        if user and not weight_kg:
            user_obj = User.query.filter(
                (User.username == user) | (User.email == user)
            ).first()
            if user_obj:
                weight_kg = float(user_obj.weight_kg)
        
        exercises_list = []
        for ex in exercises:
            met_value = get_exercise_met_value(ex)
            exercise_data = {
                'id': ex.exercise_id,
                'name': ex.name,
                'body_part': ex.body_part,
                'equipment': ex.equipment,
                'target': ex.target,
                'gif_url': ex.gif_url,
                'instructions': json.loads(ex.instructions) if ex.instructions else [],
                'category': normalize_category(ex.category or ''),
                'difficulty': ex.difficulty,
                'met_value': met_value,
            }
            
            # Add personalized calories per minute if weight is provided
            if weight_kg:
                try:
                    exercise_data['calories_per_minute'] = calculate_calories_per_minute(met_value, float(weight_kg))
                except Exception:
                    pass
            
            # Include deprecated field for backward compatibility
            if ex.estimated_calories_per_minute:
                exercise_data['estimated_calories_per_minute'] = ex.estimated_calories_per_minute
            
            exercises_list.append(exercise_data)
        
        return jsonify({
            'success': True,
            'exercises': exercises_list
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/exercises/import', methods=['POST'])
def import_exercises():
    """Import exercises from CSV file"""
    try:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        csv_paths = [
            os.path.join(base_dir, 'data', 'exercises.csv'),
            os.path.join(base_dir, 'exercises.csv'),
        ]
        
        for csv_path in csv_paths:
            if os.path.exists(csv_path):
                added, updated = _import_exercises_from_csv_path(csv_path)
                return jsonify({
                    'success': True,
                    'message': f'Imported exercises from {csv_path}',
                    'added': added,
                    'updated': updated,
                    'total': added + updated
                }), 200
        
        return jsonify({
            'success': False,
            'error': 'Exercises CSV file not found',
            'tried_paths': csv_paths
        }), 404
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

 

@app.route('/exercises/categories', methods=['GET'])
def get_exercise_categories():
    """Get available exercise categories"""
    try:
        # Always return the standardized 3-category list
        return jsonify({
            'success': True,
            'categories': ['Cardio', 'Strength', 'Flexibility/Mobility']
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/exercises/calculate', methods=['POST'])
def calculate_exercise_calories():
    """Calculate calories burned for an exercise based on duration and user's weight.

    Request JSON body supports:
      - exercise_id: preferred unique id (matches exercises.exercise_id)
      - name: alternative lookup by name if id not provided
      - duration_seconds: required, total active duration in seconds
      - user: optional, username/email to get personalized weight-based calculation
      - weight_kg: optional, weight in kg for calculation (if user not provided)

    Returns: { success, exercise_id, name, minutes, calories_per_minute, calories, met_value, weight_kg }
    """
    try:
        body = request.get_json(silent=True) or {}
        exercise_id = (body.get('exercise_id') or '').strip()
        name = (body.get('name') or '').strip()
        duration_seconds = body.get('duration_seconds')
        user = body.get('user') or body.get('username') or body.get('usernameOrEmail')
        weight_kg = body.get('weight_kg')

        if duration_seconds is None:
            return jsonify({'success': False, 'error': 'duration_seconds is required'}), 400
        try:
            duration_seconds = float(duration_seconds)
        except Exception:
            return jsonify({'success': False, 'error': 'duration_seconds must be a number'}), 400
        if duration_seconds <= 0:
            return jsonify({'success': False, 'error': 'duration_seconds must be > 0'}), 400

        exercise = None
        if exercise_id:
            exercise = Exercise.query.filter_by(exercise_id=exercise_id).first()
        if exercise is None and name:
            exercise = Exercise.query.filter(Exercise.name.ilike(name)).first()
        if exercise is None:
            return jsonify({'success': False, 'error': 'Exercise not found by id or name'}), 404

        # Get user's weight if user is provided
        if user and not weight_kg:
            user_obj = User.query.filter(
                (User.username == user) | (User.email == user)
            ).first()
            if user_obj:
                weight_kg = float(user_obj.weight_kg)
        
        # Default to 70kg if no weight provided (standard reference weight)
        if not weight_kg:
            weight_kg = 70.0

        # Get MET value for the exercise
        met_value = get_exercise_met_value(exercise)
        
        # Calculate personalized calories
        minutes = duration_seconds / 60.0
        calories_per_min = calculate_calories_per_minute(met_value, float(weight_kg))
        total_calories = calculate_calories_burned(met_value, float(weight_kg), minutes)

        return jsonify({
            'success': True,
            'exercise_id': exercise.exercise_id,
            'name': exercise.name,
            'minutes': round(minutes, 3),
            'calories_per_minute': calories_per_min,
            'calories': total_calories,
            'met_value': met_value,
            'weight_kg': float(weight_kg)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/exercises/<exercise_id>', methods=['GET'])
def get_exercise_details(exercise_id):
    """Get detailed information about a specific exercise with personalized calorie estimates.
    
    Query params:
      - user: optional, username/email to get personalized weight-based calculation
      - weight_kg: optional, weight in kg for calculation (if user not provided)
    """
    try:
        exercise = Exercise.query.filter_by(exercise_id=exercise_id).first()
        
        if not exercise:
            return jsonify({'error': 'Exercise not found'}), 404
        
        # Get user's weight if provided
        user = request.args.get('user')
        weight_kg = request.args.get('weight_kg')
        
        if user and not weight_kg:
            user_obj = User.query.filter(
                (User.username == user) | (User.email == user)
            ).first()
            if user_obj:
                weight_kg = float(user_obj.weight_kg)
        
        # Get MET value
        met_value = get_exercise_met_value(exercise)
        
        # Calculate personalized calories per minute if weight is provided
        calories_per_minute = None
        if weight_kg:
            try:
                calories_per_minute = calculate_calories_per_minute(met_value, float(weight_kg))
            except Exception:
                pass
        
        exercise_data = {
            'id': exercise.exercise_id,
            'name': exercise.name,
            'body_part': exercise.body_part,
            'equipment': exercise.equipment,
            'target': exercise.target,
            'gif_url': exercise.gif_url,
            'instructions': json.loads(exercise.instructions) if exercise.instructions else [],
            'category': exercise.category,
            'difficulty': exercise.difficulty,
            'met_value': met_value,
            'calories_per_minute': calories_per_minute,  # Personalized if weight provided
        }
        
        # Include deprecated field for backward compatibility
        if exercise.estimated_calories_per_minute:
            exercise_data['estimated_calories_per_minute'] = exercise.estimated_calories_per_minute
        
        return jsonify({
            'success': True,
            'exercise': exercise_data
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/exercises/session', methods=['POST'])
def log_exercise_session():
    """Log an exercise session with timer data"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        required_fields = ['user', 'exercise_id', 'exercise_name', 'duration_seconds']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Calculate calories burned
        duration_minutes = data['duration_seconds'] / 60
        calories_burned = data.get('calories_burned', 0)
        
        if not calories_burned:
            # Estimate calories if not provided using MET formula
            exercise = Exercise.query.filter_by(exercise_id=data['exercise_id']).first()
            if exercise:
                # Get user's weight for personalized calculation
                user_obj = User.query.filter(
                    (User.username == data['user']) | (User.email == data['user'])
                ).first()
                weight_kg = float(user_obj.weight_kg) if user_obj else 70.0  # Default to 70kg
                
                # Calculate using MET formula
                met_value = get_exercise_met_value(exercise)
                calories_burned = calculate_calories_burned(met_value, weight_kg, duration_minutes)
            else:
                # Custom exercise (not in Exercise table) - derive MET from intensity if provided
                # Check if it's a custom exercise (exercise_id starts with 'custom_')
                if data.get('exercise_id', '').startswith('custom_'):
                    # Try to get intensity from notes or use default
                    # For custom exercises, we'll use the calories_burned if provided
                    # Otherwise, use a default MET calculation
                    user_obj = User.query.filter(
                        (User.username == data['user']) | (User.email == data['user'])
                    ).first()
                    weight_kg = float(user_obj.weight_kg) if user_obj else 70.0
                    
                    # Default MET for custom exercises (moderate intensity)
                    # This is a fallback - ideally frontend should calculate and send calories_burned
                    default_met = 5.0  # Moderate intensity default
                    calories_burned = calculate_calories_burned(default_met, weight_kg, duration_minutes)
        
        # Use Philippines timezone for date consistency (same as food logs)
        if 'date' in data and data['date']:
            try:
                # Parse the provided date string
                session_date = parse_date_safe(data['date'])
                if not session_date:
                    # If parsing fails, use Philippines date
                    session_date = get_philippines_date()
            except Exception:
                # If any error, use Philippines date
                session_date = get_philippines_date()
        else:
            # No date provided, use current Philippines date
            session_date = get_philippines_date()
        
        session = ExerciseSession(
            user=data['user'],
            exercise_id=data['exercise_id'],
            exercise_name=data['exercise_name'],
            duration_seconds=data['duration_seconds'],
            calories_burned=calories_burned,
            sets_completed=data.get('sets_completed', 1),
            notes=data.get('notes', ''),
            date=session_date
        )
        
        db.session.add(session)
        db.session.commit()
        
        # Update exercise streak after logging exercise session
        try:
            user = data['user']
            streak = get_or_create_streak(user, 'exercise')
            met_goal = check_exercise_goal_met(user, session_date, streak.minimum_exercise_minutes)
            update_streak(user, 'exercise', met_goal, session_date)
        except Exception as e:
            # Don't fail the request if streak update fails
            print(f'Warning: Failed to update exercise streak: {e}')
        
        return jsonify({
            'success': True,
            'message': 'Exercise session logged successfully',
            'session_id': session.id
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/exercises/sessions', methods=['GET'])
def get_exercise_sessions():
    """Get exercise sessions for a user"""
    try:
        user = request.args.get('user')
        date_str = request.args.get('date')
        
        if not user:
            return jsonify({'error': 'User parameter required'}), 400
        
        query = ExerciseSession.query.filter_by(user=user)
        
        if date_str:
            try:
                date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
                query = query.filter_by(date=date_obj)
            except ValueError:
                return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        sessions = query.order_by(ExerciseSession.created_at.desc()).all()
        
        total_calories = sum(session.calories_burned for session in sessions)
        total_duration = sum(session.duration_seconds for session in sessions)
        
        return jsonify({
            'success': True,
            'sessions': [{
                'id': session.id,
                'exercise_id': session.exercise_id,
                'exercise_name': session.exercise_name,
                'duration_seconds': session.duration_seconds,
                'duration_minutes': round(session.duration_seconds / 60, 1),
                'calories_burned': session.calories_burned,
                'sets_completed': session.sets_completed,
                'notes': session.notes,
                'date': session.date.strftime('%Y-%m-%d'),
                'created_at': session.created_at.isoformat()
            } for session in sessions],
            'summary': {
                'total_sessions': len(sessions),
                'total_calories_burned': total_calories,
                'total_duration_minutes': round(total_duration / 60, 1)
            }
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/exercises/session/<int:session_id>', methods=['DELETE'])
def delete_exercise_session(session_id):
    """Delete an exercise session"""
    try:
        session = ExerciseSession.query.get(session_id)
        
        if not session:
            return jsonify({'error': 'Exercise session not found'}), 404
        
        db.session.delete(session)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Exercise session deleted successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    model_status = nutrition_model.is_model_loaded() if nutrition_model else False
    return jsonify({
        'status': 'healthy',
        'message': 'Nutrition API is running',
        'model_loaded': model_status
    })

@app.route('/debug/db', methods=['GET'])
def debug_db_info():
    """Return minimal database info (scheme and host) for troubleshooting."""
    try:
        uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
        scheme = ''
        host = ''
        if '://' in uri:
            scheme, rest = uri.split('://', 1)
            try:
                # Remove creds portion if present
                rest_no_creds = rest.split('@', 1)[-1]
                host = rest_no_creds.split('/', 1)[0]
            except Exception:
                host = ''
        return jsonify({ 'scheme': scheme, 'host': host })
    except Exception as e:
        return jsonify({ 'error': str(e) }), 500

@app.route('/predict/calories', methods=['POST'])
def predict_calories():
    """Predict calories for a food item"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Extract food information
        food_name = data.get('food_name', '')
        food_category = data.get('food_category', '')
        serving_size = data.get('serving_size', 100)  # grams
        preparation_method = data.get('preparation_method', '')
        ingredients = data.get('ingredients', [])
        
        # Make prediction
        prediction = nutrition_model.predict_calories(
            food_name=food_name,
            food_category=food_category,
            serving_size=serving_size,
            preparation_method=preparation_method,
            ingredients=ingredients
        )
        
        return jsonify({
            'success': True,
            'prediction': prediction,
            'food_name': food_name,
            'serving_size': serving_size
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/predict/nutrition', methods=['POST'])
def predict_nutrition():
    """Predict comprehensive nutrition information"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Extract user and food information
        food_name = data.get('food_name', '')
        food_category = data.get('food_category', '')
        serving_size = data.get('serving_size', 100)
        user_gender = data.get('user_gender', '')
        user_age = data.get('user_age', 25)
        user_weight = data.get('user_weight', 60)
        user_height = data.get('user_height', 160)
        user_activity_level = data.get('user_activity_level', 'moderate')
        user_goal = data.get('user_goal', 'maintain')
        
        # Make comprehensive prediction
        nutrition_info = nutrition_model.predict_nutrition(
            food_name=food_name,
            food_category=food_category,
            serving_size=serving_size,
            user_gender=user_gender,
            user_age=user_age,
            user_weight=user_weight,
            user_height=user_height,
            user_activity_level=user_activity_level,
            user_goal=user_goal
        )
        
        return jsonify({
            'success': True,
            'nutrition_info': nutrition_info
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recommend/meals', methods=['POST'])
def recommend_meals():
    """Generate meal recommendations based on user profile"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Extract user information
        user_gender = data.get('user_gender', '')
        user_age = data.get('user_age', 25)
        user_weight = data.get('user_weight', 60)
        user_height = data.get('user_height', 160)
        user_activity_level = data.get('user_activity_level', 'moderate')
        user_goal = data.get('user_goal', 'maintain')
        dietary_preferences = data.get('dietary_preferences', [])
        medical_history = data.get('medical_history', [])
        
        # Generate recommendations
        recommendations = nutrition_model.recommend_meals(
            user_gender=user_gender,
            user_age=user_age,
            user_weight=user_weight,
            user_height=user_height,
            user_activity_level=user_activity_level,
            user_goal=user_goal,
            dietary_preferences=dietary_preferences,
            medical_history=medical_history
        )
        
        return jsonify({
            'success': True,
            'recommendations': recommendations
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/analyze/food-log', methods=['POST'])
def analyze_food_log():
    """Analyze a food log and provide insights"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        food_log = data.get('food_log', [])
        user_gender = data.get('user_gender', '')
        user_goal = data.get('user_goal', 'maintain')
        
        # Analyze food log
        analysis = nutrition_model.analyze_food_log(
            food_log=food_log,
            user_gender=user_gender,
            user_goal=user_goal
        )
        
        return jsonify({
            'success': True,
            'analysis': analysis
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/foods/filipino', methods=['GET'])
def get_filipino_foods():
    """Get list of Filipino foods in the database"""
    try:
        foods = nutrition_model.get_filipino_foods()
        return jsonify({
            'success': True,
            'foods': foods
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Helper functions for 3-phase food deletion system
def get_food_log_phase(created_at):
    """Determine the current phase of a food log entry"""
    # Temporarily return 'deletable' for all items until database migration is complete
    return 'deletable'

def can_delete_food_log(created_at):
    """Check if a food log can be deleted"""
    # Temporarily allow all deletions until database migration is complete
    return True

def get_deletion_available_time(created_at):
    """Get the time when deletion becomes available"""
    # Temporarily return current time until database migration is complete
    return datetime.utcnow().isoformat()

def get_auto_removal_time(created_at):
    """Get the time when auto-removal occurs"""
    # Temporarily return current time + 1 hour until database migration is complete
    return (datetime.utcnow() + timedelta(hours=1)).isoformat()

def get_time_remaining(created_at):
    """Get remaining time in minutes"""
    # Temporarily return 0.0 until database migration is complete
    return 0.0

def get_progress_percentage(created_at):
    """Get progress percentage for the current phase"""
    # Temporarily return 100.0 until database migration is complete
    return 100.0

@app.route('/log/food', methods=['POST'])
def log_food():
    def parse_grams(serving_size):
        match = re.search(r'(\d+(\.\d+)?)\s*g', str(serving_size).lower())
        if match:
            return float(match.group(1))
        return 100.0  # Default to 100g if not specified

    def lookup_nutrition(food_name, grams, quantity):
        match = food_df[food_df['Food Name'].str.lower() == str(food_name).lower()]
        factor = (grams / 100.0) * quantity
        if not match.empty:
            row = match.iloc[0]
            return {
                'calories': row.get('Calories', 0) * factor,
                'protein': row.get('Protein (g)', 0) * factor,
                'carbs': row.get('Carbs (g)', 0) * factor,
                'fat': row.get('Fat (g)', 0) * factor,
                'fiber': row.get('Fiber (g)', 0) * factor,
                'sodium': row.get('Sodium (mg)', 0) * factor,
            }
        return None

    data = request.get_json()
    # If 'foods' is present, log multiple foods
    if 'foods' in data:
        log_ids = []
        for food in data['foods']:
            food_name = food.get('food_name')
            serving_size_str = food.get('serving_size', '100g')
            quantity = float(food.get('quantity', 1))
            grams = parse_grams(serving_size_str)
            # Use frontend-provided calories if available (already multiplied by quantity)
            # Only use lookup_nutrition as fallback if calories not provided
            # Check if 'calories' key exists in the food dict (frontend always sends it)
            if 'calories' in food:
                # Frontend already calculated calories with quantity, use them directly
                calories = float(food.get('calories', 0))
                protein = float(food.get('protein', 0))
                carbs = float(food.get('carbs', 0))
                fat = float(food.get('fat', 0))
                fiber = float(food.get('fiber', 0))
                sodium = float(food.get('sodium', 0))
            else:
                # Fallback: lookup from database and multiply by quantity
                nut = lookup_nutrition(food_name, grams, quantity)
                calories = nut['calories'] if nut else 0
                protein = nut['protein'] if nut else 0
                carbs = nut['carbs'] if nut else 0
                fat = nut['fat'] if nut else 0
                fiber = nut['fiber'] if nut else 0
                sodium = nut['sodium'] if nut else 0
            log = FoodLog(
                user=data.get('user', 'default'),
                food_name=food_name,
                meal_type=food.get('meal_type', 'unspecified'),
                serving_size=serving_size_str,
                quantity=quantity,
                calories=calories,
                protein=protein,
                carbs=carbs,
                fat=fat,
                fiber=fiber,
                sodium=sodium,
                date=datetime.fromisoformat(food.get('timestamp', datetime.utcnow().isoformat()))
            )
            db.session.add(log)
            db.session.flush()  # Get log.id before commit
            log_ids.append(log.id)
        db.session.commit()
        
        # Update calories streak after logging food
        try:
            user = data.get('user', 'default')
            # Use the date from the first food log, or today if not specified
            # FIXED: Always use Philippines timezone for consistency
            first_food_date = None
            if data.get('foods') and len(data['foods']) > 0:
                first_food = data['foods'][0]
                if first_food.get('timestamp'):
                    # Convert timestamp to Philippines timezone date
                    try:
                        timestamp_dt = datetime.fromisoformat(first_food['timestamp'].replace('Z', '+00:00'))
                        # Convert to Philippines timezone
                        ph_tz = get_philippines_timezone()
                        if ph_tz:
                            ph_dt = timestamp_dt.astimezone(ph_tz)
                            first_food_date = ph_dt.date()
                        else:
                            first_food_date = timestamp_dt.date()
                    except (ValueError, AttributeError):
                        # Fallback to Philippines date if parsing fails
                        first_food_date = get_philippines_date()
            if not first_food_date:
                first_food_date = get_philippines_date()
            # Check if goal is met after this log
            met_goal = check_calories_goal_met(user, first_food_date)
            update_streak(user, 'calories', met_goal, first_food_date)
        except Exception as e:
            # Don't fail the request if streak update fails
            print(f'Warning: Failed to update streak: {e}')
        
        return jsonify({'success': True, 'ids': log_ids})
    # Fallback: single food log (legacy)
    food_name = data.get('food_name')
    serving_size_str = data.get('serving_size', '100g')
    quantity = float(data.get('quantity', 1))
    grams = parse_grams(serving_size_str)
    # Use frontend-provided calories if available (already multiplied by quantity)
    # Only use lookup_nutrition as fallback if calories not provided
    # Check if 'calories' key exists in the data dict (frontend always sends it)
    if 'calories' in data:
        # Frontend already calculated calories with quantity, use them directly
        calories = float(data.get('calories', 0))
        protein = float(data.get('protein', 0))
        carbs = float(data.get('carbs', 0))
        fat = float(data.get('fat', 0))
        fiber = float(data.get('fiber', 0))
        sodium = float(data.get('sodium', 0))
    else:
        # Fallback: lookup from database and multiply by quantity
        nut = lookup_nutrition(food_name, grams, quantity)
        calories = nut['calories'] if nut else 0
        protein = nut['protein'] if nut else 0
        carbs = nut['carbs'] if nut else 0
        fat = nut['fat'] if nut else 0
        fiber = nut['fiber'] if nut else 0
        sodium = nut['sodium'] if nut else 0
    log = FoodLog(
        user=data.get('user', 'default'),
        food_name=food_name,
        meal_type=data.get('meal_type', 'unspecified'),
        serving_size=serving_size_str,
        quantity=quantity,
        calories=calories,
        protein=protein,
        carbs=carbs,
        fat=fat,
        fiber=fiber,
        sodium=sodium,
        date=datetime.strptime(data.get('date', datetime.utcnow().strftime('%Y-%m-%d')), '%Y-%m-%d')
    )
    db.session.add(log)
    db.session.commit()
    
    # Update calories streak after logging food
    try:
        user = data.get('user', 'default')
        # FIXED: Always use Philippines timezone for consistency
        date_str = data.get('date', datetime.utcnow().strftime('%Y-%m-%d'))
        try:
            log_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except (ValueError, AttributeError):
            # Fallback to Philippines date if parsing fails
            log_date = get_philippines_date()
        # Check if goal is met after this log
        met_goal = check_calories_goal_met(user, log_date)
        update_streak(user, 'calories', met_goal, log_date)
    except Exception as e:
        # Don't fail the request if streak update fails
        print(f'Warning: Failed to update streak: {e}')
    
    return jsonify({'success': True, 'id': log.id})

@app.route('/log/food', methods=['GET'])
def get_food_logs():
    user = request.args.get('user', 'default')
    date_str = request.args.get('date', datetime.utcnow().strftime('%Y-%m-%d'))
    date = datetime.strptime(date_str, '%Y-%m-%d').date()
    logs = FoodLog.query.filter_by(user=user, date=date).all()
    total_calories = sum(log.calories for log in logs)
    total_protein = sum(log.protein for log in logs)
    total_carbs = sum(log.carbs for log in logs)
    total_fat = sum(log.fat for log in logs)
    total_fiber = sum(log.fiber for log in logs)
    total_sodium = sum(log.sodium for log in logs)
    
    # Temporarily show all logs until database migration is complete
    active_logs = logs
    
    return jsonify({
        'logs': [
            {
                'id': log.id,
                'food_name': log.food_name,
                'meal_type': log.meal_type,
                'serving_size': log.serving_size,
                'quantity': float(log.quantity),
                'calories': float(log.calories),
                'protein': float(log.protein),
                'carbs': float(log.carbs),
                'fat': float(log.fat),
                'fiber': float(log.fiber),
                'sodium': float(log.sodium),
                'created_at': datetime.utcnow().isoformat(),
                'timestamp': int(datetime.utcnow().timestamp() * 1000),  # Milliseconds for Flutter
                'phase': get_food_log_phase(None),
                'can_delete': can_delete_food_log(None),
                'deletion_available_at': get_deletion_available_time(None),
                'auto_removal_at': get_auto_removal_time(None),
                'time_remaining': get_time_remaining(None),
                'progress_percentage': get_progress_percentage(None)
            } for log in active_logs
        ],
        'totals': {
            'calories': total_calories,
            'protein': total_protein,
            'carbs': total_carbs,
            'fat': total_fat,
            'fiber': total_fiber,
            'sodium': total_sodium
        }
    })

@app.route('/log/food/<int:log_id>', methods=['PUT'])
def edit_food_log(log_id):
    data = request.get_json()
    log = FoodLog.query.get_or_404(log_id)
    # Store user and date before editing (needed for streak recalculation)
    user = log.user
    log_date = log.date
    
    log.food_name = data.get('food_name', log.food_name)
    log.meal_type = data.get('meal_type', log.meal_type)
    log.serving_size = data.get('serving_size', log.serving_size)
    log.quantity = data.get('quantity', log.quantity)
    log.calories = data.get('calories', log.calories)
    log.protein = data.get('protein', log.protein)
    log.carbs = data.get('carbs', log.carbs)
    log.fat = data.get('fat', log.fat)
    log.fiber = data.get('fiber', log.fiber)
    log.sodium = data.get('sodium', log.sodium)
    db.session.commit()
    
    # Recalculate streak after editing (calories may have changed)
    try:
        met_goal = check_calories_goal_met(user, log_date)
        update_streak(user, 'calories', met_goal, log_date)
    except Exception as e:
        # Don't fail the request if streak update fails
        print(f'Warning: Failed to update streak after edit: {e}')
    
    return jsonify({'success': True})

@app.route('/log/food/<int:log_id>', methods=['DELETE'])
def delete_food_log(log_id):
    log = FoodLog.query.get_or_404(log_id)
    # Store user and date before deleting (needed for streak recalculation)
    user = log.user
    log_date = log.date
    
    # Delete the log
    db.session.delete(log)
    db.session.commit()
    
    # Recalculate streak after deletion
    # Check if goal is still met after this deletion
    try:
        met_goal = check_calories_goal_met(user, log_date)
        update_streak(user, 'calories', met_goal, log_date)
    except Exception as e:
        # Don't fail the request if streak update fails
        print(f'Warning: Failed to update streak after deletion: {e}')
    
    return jsonify({'success': True})

# --- Custom Recipes Endpoints ---
@app.route('/recipes', methods=['POST'])
def create_recipe():
    """Create a new custom recipe"""
    data = request.get_json()
    user = data.get('user', 'default')
    recipe_name = data.get('recipe_name', '')
    description = data.get('description', '')
    servings = data.get('servings', 1)
    ingredients = data.get('ingredients', [])
    
    if not recipe_name:
        return jsonify({'error': 'Recipe name is required'}), 400
    
    # Create the recipe
    recipe = CustomRecipe(
        user=user,
        recipe_name=recipe_name,
        description=description,
        servings=servings
    )
    db.session.add(recipe)
    db.session.flush()  # Get the recipe ID
    
    # Add ingredients
    for ing in ingredients:
        ingredient = RecipeIngredient(
            recipe_id=recipe.id,
            ingredient_name=ing.get('ingredient_name', ''),
            quantity=ing.get('quantity', 0),
            unit=ing.get('unit', 'g'),
            calories=ing.get('calories', 0),
            protein=ing.get('protein', 0),
            carbs=ing.get('carbs', 0),
            fat=ing.get('fat', 0),
            fiber=ing.get('fiber', 0),
            sodium=ing.get('sodium', 0)
        )
        db.session.add(ingredient)
    
    db.session.commit()
    return jsonify({'success': True, 'id': recipe.id})

@app.route('/recipes', methods=['GET'])
def get_recipes():
    """Get all custom recipes for a user"""
    user = request.args.get('user', 'default')
    recipes = CustomRecipe.query.filter_by(user=user).all()
    
    result = []
    for recipe in recipes:
        # Get ingredients
        ingredients = RecipeIngredient.query.filter_by(recipe_id=recipe.id).all()
        
        # Calculate total nutrition per serving
        total_calories = sum(ing.calories for ing in ingredients)
        total_protein = sum(ing.protein for ing in ingredients)
        total_carbs = sum(ing.carbs for ing in ingredients)
        total_fat = sum(ing.fat for ing in ingredients)
        total_fiber = sum(ing.fiber for ing in ingredients)
        total_sodium = sum(ing.sodium for ing in ingredients)
        
        result.append({
            'id': recipe.id,
            'name': recipe.recipe_name,
            'description': recipe.description,
            'servings': recipe.servings,
            'calories_per_serving': total_calories / recipe.servings if recipe.servings > 0 else 0,
            'protein_per_serving': total_protein / recipe.servings if recipe.servings > 0 else 0,
            'carbs_per_serving': total_carbs / recipe.servings if recipe.servings > 0 else 0,
            'fat_per_serving': total_fat / recipe.servings if recipe.servings > 0 else 0,
            'fiber_per_serving': total_fiber / recipe.servings if recipe.servings > 0 else 0,
            'sodium_per_serving': total_sodium / recipe.servings if recipe.servings > 0 else 0,
            'created_at': recipe.created_at.isoformat() if recipe.created_at else None,
            'ingredients': [
                {
                    'name': ing.ingredient_name,
                    'quantity': ing.quantity,
                    'unit': ing.unit,
                    'calories': ing.calories,
                    'protein': ing.protein,
                    'carbs': ing.carbs,
                    'fat': ing.fat,
                    'fiber': ing.fiber,
                    'sodium': ing.sodium
                } for ing in ingredients
            ]
        })
    
    return jsonify({'recipes': result})

@app.route('/recipes/<int:recipe_id>', methods=['DELETE'])
def delete_recipe(recipe_id):
    """Delete a custom recipe"""
    recipe = CustomRecipe.query.get_or_404(recipe_id)
    
    # Delete all ingredients first
    RecipeIngredient.query.filter_by(recipe_id=recipe_id).delete()
    
    # Delete the recipe
    db.session.delete(recipe)
    db.session.commit()
    
    return jsonify({'success': True})

@app.route('/log/recipe', methods=['POST'])
def log_recipe():
    """Log a custom recipe consumption"""
    data = request.get_json()
    user = data.get('user', 'default')
    recipe_id = data.get('recipe_id')
    servings_consumed = data.get('servings_consumed', 1.0)
    meal_type = data.get('meal_type', 'Other')
    date_str = data.get('date', datetime.utcnow().strftime('%Y-%m-%d'))
    
    # Get the recipe
    recipe = CustomRecipe.query.get_or_404(recipe_id)
    
    # Get ingredients
    ingredients = RecipeIngredient.query.filter_by(recipe_id=recipe_id).all()
    
    # Calculate nutrition for the consumed servings
    total_calories = sum(ing.calories for ing in ingredients)
    total_protein = sum(ing.protein for ing in ingredients)
    total_carbs = sum(ing.carbs for ing in ingredients)
    total_fat = sum(ing.fat for ing in ingredients)
    total_fiber = sum(ing.fiber for ing in ingredients)
    total_sodium = sum(ing.sodium for ing in ingredients)
    
    calories_per_serving = total_calories / recipe.servings if recipe.servings > 0 else 0
    protein_per_serving = total_protein / recipe.servings if recipe.servings > 0 else 0
    carbs_per_serving = total_carbs / recipe.servings if recipe.servings > 0 else 0
    fat_per_serving = total_fat / recipe.servings if recipe.servings > 0 else 0
    fiber_per_serving = total_fiber / recipe.servings if recipe.servings > 0 else 0
    sodium_per_serving = total_sodium / recipe.servings if recipe.servings > 0 else 0
    
    # Log the recipe consumption
    recipe_log = RecipeLog(
        user=user,
        recipe_id=recipe_id,
        servings_consumed=servings_consumed,
        meal_type=meal_type,
        date=datetime.strptime(date_str, '%Y-%m-%d').date()
    )
    db.session.add(recipe_log)
    
    # Also add to food log for tracking
    food_log = FoodLog(
        user=user,
        food_name=f"{recipe.recipe_name} (Recipe)",
        calories=calories_per_serving * servings_consumed,
        protein=protein_per_serving * servings_consumed,
        carbs=carbs_per_serving * servings_consumed,
        fat=fat_per_serving * servings_consumed,
        fiber=fiber_per_serving * servings_consumed,
        sodium=sodium_per_serving * servings_consumed,
        meal_type=meal_type,
        serving_size=f"{servings_consumed} serving(s)",
        quantity=servings_consumed,
        date=datetime.strptime(date_str, '%Y-%m-%d').date()
    )
    db.session.add(food_log)
    
    db.session.commit()
    return jsonify({'success': True, 'id': recipe_log.id})

@app.route('/log/exercise', methods=['POST'])
def log_exercise():
    data = request.get_json()
    # Simple de-dupe: if an identical legacy log exists for the same user/date/exercise/calories, skip insert
    user_val = data.get('user', 'default')
    ex = data['exercise']
    cal = float(data['calories'])
    date_obj = datetime.strptime(data.get('date', datetime.utcnow().strftime('%Y-%m-%d')), '%Y-%m-%d')
    existing = ExerciseLog.query.filter_by(user=user_val, exercise=ex, calories=cal, date=date_obj).first()
    if existing:
        return jsonify({'success': True, 'skipped': True, 'id': existing.id})
    log = ExerciseLog(
        user=user_val,
        exercise=ex,
        calories=cal,
        date=date_obj
    )  # type: ignore
    db.session.add(log)
    db.session.commit()
    
    # Update exercise streak after logging exercise
    try:
        # Check if goal is met (minimum 15 minutes by default)
        streak = get_or_create_streak(user_val, 'exercise')
        met_goal = check_exercise_goal_met(user_val, date_obj, streak.minimum_exercise_minutes)
        update_streak(user_val, 'exercise', met_goal, date_obj)
    except Exception as e:
        # Don't fail the request if streak update fails
        print(f'Warning: Failed to update exercise streak: {e}')
    
    return jsonify({'success': True, 'id': log.id})

@app.route('/log/exercise', methods=['GET'])
def get_exercise_logs():
    user = request.args.get('user', 'default')
    date_str = request.args.get('date', datetime.utcnow().strftime('%Y-%m-%d'))
    date = datetime.strptime(date_str, '%Y-%m-%d').date()
    logs = ExerciseLog.query.filter_by(user=user, date=date).all()
    total_calories = sum(log.calories for log in logs)
    return jsonify({
        'logs': [{'exercise': log.exercise, 'calories': log.calories} for log in logs],
        'total_calories': total_calories
    })

# Custom Exercise Submission: store user-submitted exercises for later review/merge
@app.route('/api/exercises/custom', methods=['POST'])
def submit_custom_exercise():
    try:
        data = request.get_json() or {}
        user = data.get('user') or data.get('username') or 'default'
        name = (data.get('name') or '').strip()
        category = data.get('category')
        intensity = data.get('intensity')
        duration_min = data.get('duration_min')
        reps = data.get('reps')
        sets = data.get('sets')
        notes = data.get('notes')
        est_calories = data.get('est_calories')

        if not name:
            return jsonify({'error': 'name is required'}), 400
        if not (duration_min or (reps and sets)):
            return jsonify({'error': 'Provide duration or reps & sets'}), 400

        # Basic duplicate check for recent submissions by same user and name
        existing = (
            UserExerciseSubmission.query
            .filter(UserExerciseSubmission.user == user)
            .filter(UserExerciseSubmission.name.ilike(name))
            .order_by(UserExerciseSubmission.created_at.desc())
            .first()
        )
        if existing and existing.status in ('pending', 'approved'):
            return jsonify({'success': True, 'id': existing.id, 'status': existing.status, 'duplicate': True}), 200

        sub = UserExerciseSubmission(
            user=user,
            name=name,
            category=category,
            intensity=intensity,
            duration_min=duration_min,
            reps=reps,
            sets=sets,
            notes=notes,
            est_calories=est_calories,
            status='pending',
        )
        db.session.add(sub)
        db.session.commit()
        return jsonify({'success': True, 'id': sub.id, 'status': sub.status}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Admin moderation: list pending/approved submissions
@app.route('/api/exercises/custom', methods=['GET'])
def list_custom_exercises():
    status = request.args.get('status')
    q = UserExerciseSubmission.query
    if status:
        q = q.filter(UserExerciseSubmission.status == status)
    subs = q.order_by(UserExerciseSubmission.created_at.desc()).limit(200).all()
    return jsonify({
        'items': [
            {
                'id': s.id,
                'user': s.user,
                'name': s.name,
                'category': s.category,
                'intensity': s.intensity,
                'duration_min': s.duration_min,
                'reps': s.reps,
                'sets': s.sets,
                'notes': s.notes,
                'est_calories': s.est_calories,
                'status': s.status,
                'created_at': s.created_at.isoformat(),
            }
            for s in subs
        ]
    })

@app.route('/api/exercises/custom/<int:sub_id>/approve', methods=['POST'])
def approve_custom_exercise(sub_id: int):
    sub = UserExerciseSubmission.query.get_or_404(sub_id)
    sub.status = 'approved'
    db.session.commit()
    return jsonify({'success': True, 'id': sub.id, 'status': sub.status})

@app.route('/api/exercises/custom/<int:sub_id>/reject', methods=['POST'])
def reject_custom_exercise(sub_id: int):
    sub = UserExerciseSubmission.query.get_or_404(sub_id)
    sub.status = 'rejected'
    db.session.commit()
    return jsonify({'success': True, 'id': sub.id, 'status': sub.status})

@app.route('/calculate/daily_goal', methods=['POST'])
def calculate_daily_goal():
    data = request.get_json()
    age = data.get('age')
    if age is None:
        return jsonify({'error': 'Age is required'}), 400
    sex = data.get('sex', 'male')
    weight = data.get('weight', data.get('weight_kg', 60))
    height = data.get('height', data.get('height_cm', 160))
    activity_level = data.get('activity_level', 'active')
    goal = data.get('goal', 'maintain')

    # Input validation and unit correction
    try:
        weight = float(weight)
        height = float(height)
        age = int(age)
        # Unit normalization
        if weight > 250:
            weight = weight * 0.453592
        if height > 250:
            height = height * 2.54
        ok, msg = validate_metrics(age, weight, height)
        if not ok:
            return jsonify({'error': msg}), 400
    except Exception as e:
        return jsonify({'error': 'Invalid input for weight, height, or age.'}), 400

    tdee = compute_daily_calorie_goal(
        sex=sex,
        age=int(age),
        weight_kg=float(weight),
        height_cm=float(height),
        activity_level=normalize_activity_level(str(activity_level)),
        goal=normalize_goal(str(goal)),
    )

    return jsonify({
        'daily_calorie_goal': int(tdee),
        'validation_info': {
            'normalized_activity_level': normalize_activity_level(activity_level),
            'sex': sex,
            'age': int(age),
            'weight_kg': float(weight),
            'height_cm': float(height),
        }
    })

def _send_verification_email_async(email: str, code: str, username: str | None):
    """Send verification email in a background thread so HTTP response isn't blocked."""
    if not email:
        return

    def _task():
        try:
            success = send_verification_email(email, code, username)
            if success:
                print(f"[ASYNC] Verification email sent to {email}")
            else:
                print(f"[WARN] Verification email dispatch failed for {email}. User may need to request a resend.")
        except Exception as err:
            print(f"[ERROR] Async verification email failed for {email}: {err}")

    threading.Thread(target=_task, daemon=True).start()


@app.route('/register', methods=['POST'])
def register_user():
    """Register a new user with complete profile data"""
    print(f"[DEBUG] Registration request received from {request.remote_addr}")
    try:
        data = request.get_json()
        print(f"[DEBUG] Registration data: username={data.get('username')}, email={data.get('email')}")
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Extract required fields
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        full_name = data.get('full_name')
        age = data.get('age')
        
        # Validate required fields
        if not username:
            return jsonify({'error': 'Username is required'}), 400
        if age is None:
            return jsonify({'error': 'Age is required'}), 400
        
        # For simplified registration, use defaults for missing fields
        sex = data.get('sex', 'male')
        weight_kg = data.get('weight_kg', 70)
        height_cm = data.get('height_cm', 170)
        activity_level = data.get('activity_level', 'active')
        goal = data.get('goal', 'maintain')
        
        # Check if username already exists (with retry logic for connection errors)
        existing_username = None
        max_retries = 3
        for attempt in range(max_retries):
            try:
                existing_username = User.query.filter_by(username=username).first()
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error checking username (attempt {attempt + 1}/{max_retries}): {db_err}")
                    try:
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.1)
                else:
                    print(f"[ERROR] DB error checking username: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise
        
        if existing_username:
            return jsonify({'success': False, 'message': 'Username already exists'}), 409
        
        # Check if email already exists (with retry logic for connection errors)
        if email:
            existing_email = None
            for attempt in range(max_retries):
                try:
                    existing_email = User.query.filter_by(email=email).first()
                    break
                except Exception as db_err:
                    error_str = str(db_err)
                    is_connection_error = any(keyword in error_str.lower() for keyword in [
                        'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                    ])
                    
                    if attempt < max_retries - 1 and is_connection_error:
                        print(f"[WARN] DB connection error checking email (attempt {attempt + 1}/{max_retries}): {db_err}")
                        try:
                            db.session.close()
                            db.session.remove()
                        except Exception:
                            pass
                        time.sleep(0.1)
                    else:
                        print(f"[ERROR] DB error checking email: {db_err}")
                        try:
                            db.session.rollback()
                        except Exception:
                            pass
                        raise
            
            if existing_email:
                return jsonify({'success': False, 'message': 'Email already registered'}), 409
        
        # Calculate daily calorie goal (normalized + calibrated)
        try:
            weight_kg, height_cm = normalize_measurements(weight_kg, height_cm)
            age = int(age)
            ok, msg = validate_metrics(age, float(weight_kg), float(height_cm))
            if not ok:
                return jsonify({'error': msg}), 400
            normalized_level = normalize_activity_level(activity_level)
            normalized_goal = normalize_goal(goal)
            if normalized_level not in ALLOWED_ACTIVITY_LEVELS:
                return jsonify({'error': 'Invalid activity level'}), 400
            if normalized_goal not in ALLOWED_GOALS:
                return jsonify({'error': 'Invalid goal'}), 400
            daily_calorie_goal = compute_daily_calorie_goal(
                sex=sex,
                age=age,
                weight_kg=weight_kg,
                height_cm=height_cm,
                activity_level=normalized_level,
                goal=normalized_goal,
            )
            activity_level = normalized_level
            goal = normalized_goal
        except Exception as e:
            return jsonify({'error': 'Invalid inputs for calorie calculation'}), 400
        
        # Check if user already exists and is verified
        existing_user = User.query.filter_by(username=username).first()
        if existing_user:
            return jsonify({'success': False, 'message': 'Username already exists'}), 409
        
        if email:
            existing_email_user = User.query.filter_by(email=email).first()
            if existing_email_user:
                return jsonify({'success': False, 'message': 'Email already registered'}), 409
        
        # Check for existing pending registration (allow update if expired or resend)
        existing_pending = None
        if email:
            existing_pending = PendingRegistration.query.filter_by(email=email).first()
            # Delete if expired
            if existing_pending and existing_pending.verification_expires_at < datetime.utcnow():
                db.session.delete(existing_pending)
                db.session.commit()
                existing_pending = None
        
        # Generate verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Hash password
        hashed_password = generate_password_hash(password) if password else None
        
        # Store all registration data as JSON
        registration_data = {
            'username': username,
            'email': email,
            'full_name': full_name,
            'age': age,
            'sex': sex,
            'weight_kg': weight_kg,
            'height_cm': height_cm,
            'activity_level': activity_level,
            'goal': goal,
            'target_weight': data.get('target_weight'),
            'timeline': data.get('timeline'),
            'motivation': data.get('motivation'),
            'experience': data.get('experience'),
            'current_state': data.get('current_state'),
            'schedule': data.get('schedule'),
            'exercise_types': data.get('exercise_types', []),
            'exercise_equipment': data.get('exercise_equipment', []),
            'exercise_experience': data.get('exercise_experience'),
            'exercise_limitations': data.get('exercise_limitations'),
            'workout_duration': data.get('workout_duration'),
            'workout_frequency': data.get('workout_frequency'),
            'diet_type': data.get('diet_type'),
            'restrictions': data.get('restrictions', []),
            'allergies': data.get('allergies', []),
            'cooking_frequency': data.get('cooking_frequency'),
            'cooking_skill': data.get('cooking_skill'),
            'meal_prep_habit': data.get('meal_prep_habit'),
            'tracking_experience': data.get('tracking_experience'),
            'used_apps': data.get('used_apps', []),
            'data_importance': data.get('data_importance'),
            'is_metric': data.get('is_metric', True),
            'daily_calorie_goal': daily_calorie_goal
        }
        
        # Create or update pending registration
        if existing_pending:
            # Update existing pending registration
            existing_pending.username = username
            existing_pending.password_hash = hashed_password
            existing_pending.full_name = full_name
            existing_pending.verification_code = verification_code
            existing_pending.verification_expires_at = verification_expires_at
            existing_pending.registration_data = json.dumps(registration_data)
            # Don't reset resend_count - keep it for rate limiting
            pending_reg = existing_pending
        else:
            # Create new pending registration
            pending_reg = PendingRegistration(
                email=email,
                username=username,
                password_hash=hashed_password,
                full_name=full_name,
                verification_code=verification_code,
                verification_expires_at=verification_expires_at,
                registration_data=json.dumps(registration_data),
                resend_count=0
            )
            db.session.add(pending_reg)
        
        # Save to database (with retry logic for connection errors)
        max_commit_retries = 3
        for attempt in range(max_commit_retries):
            try:
                db.session.commit()
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_commit_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error on commit (attempt {attempt + 1}/{max_commit_retries}): {db_err}")
                    try:
                        db.session.rollback()
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.2)
                    if not existing_pending:
                        db.session.add(pending_reg)
                else:
                    print(f"[ERROR] DB error on commit: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise
        
        print(f"[SUCCESS] Pending registration created: {username}, Email: {email}")
        
        # Send verification email in the background so we don't block the HTTP response
        if email:
            _send_verification_email_async(email, verification_code, username)
        
        return jsonify({
            'success': True,
            'message': 'Registration pending. Please check your email for verification code.',
            'verification_required': True,
            'email': email,
            'username': username,
            'expires_at': verification_expires_at.isoformat()
        }), 201
        
    except Exception as e:
        error_str = str(e)
        is_connection_error = any(keyword in error_str.lower() for keyword in [
            'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
        ])
        
        try:
            if is_connection_error:
                db.session.close()
                db.session.remove()
            else:
                db.session.rollback()
        except Exception:
            pass
        
        print(f"[ERROR] Registration failed: {e}")
        error_message = 'Database connection error. Please try again.' if is_connection_error else f'Registration failed: {str(e)}'
        return jsonify({'error': error_message}), 500

@app.route('/auth/check-username', methods=['GET'])
def check_username_exists():
    """Check if a username already exists (case-insensitive)."""
    username = (request.args.get('username') or '').strip()
    if not username:
        return jsonify({'error': 'Username query parameter is required'}), 400

    try:
        exists = bool(
            User.query.filter(func.lower(User.username) == username.lower()).first()
        )
        return jsonify({'exists': exists}), 200
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify({'error': f'Failed to check username: {str(e)}'}), 500

@app.route('/auth/check-email', methods=['GET'])
def check_email_exists():
    """Check if an email already exists (case-insensitive)."""
    email = (request.args.get('email') or '').strip()
    if not email:
        return jsonify({'error': 'Email query parameter is required'}), 400

    try:
        # Check if email exists in users table
        user_exists = bool(
            User.query.filter(func.lower(User.email) == email.lower()).first()
        )
        
        # Also check if email is in pending registrations
        pending_exists = bool(
            PendingRegistration.query.filter(
                func.lower(PendingRegistration.email) == email.lower()
            ).first()
        )
        
        exists = user_exists or pending_exists
        return jsonify({'exists': exists}), 200
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify({'error': f'Failed to check email: {str(e)}'}), 500

@app.route('/auth/verify-code', methods=['POST'])
def verify_email_code():
    """Verify email verification code and create user account"""
    print(f"[DEBUG] Verify code request received")
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        email = (data.get('email') or '').strip()
        code = (data.get('code') or '').strip()
        
        if not email:
            return jsonify({'error': 'Email is required'}), 400
        if not code:
            return jsonify({'error': 'Verification code is required'}), 400
        
        # Find pending registration by email
        pending_reg = PendingRegistration.query.filter(
            func.lower(PendingRegistration.email) == email.lower()
        ).first()
        
        if not pending_reg:
            return jsonify({'error': 'No pending registration found. Please register again.'}), 404
        
        # Check if code expired
        if pending_reg.verification_expires_at < datetime.utcnow():
            # Delete expired pending registration
            db.session.delete(pending_reg)
            db.session.commit()
            return jsonify({'error': 'Verification code has expired. Please register again.'}), 400
        
        # Check if code matches
        if pending_reg.verification_code != code:
            return jsonify({'error': 'Invalid verification code'}), 400
        
        # Parse registration data
        try:
            reg_data = json.loads(pending_reg.registration_data)
        except Exception:
            return jsonify({'error': 'Invalid registration data'}), 500
        
        # Create user account
        new_user = User(
            username=pending_reg.username,
            email=pending_reg.email,
            password=pending_reg.password_hash,
            age=reg_data.get('age', 25),
            sex=reg_data.get('sex', 'male'),
            weight_kg=reg_data.get('weight_kg', 70),
            height_cm=reg_data.get('height_cm', 170),
            activity_level=reg_data.get('activity_level', 'active'),
            goal=reg_data.get('goal', 'maintain'),
            target_weight=reg_data.get('target_weight'),
            timeline=reg_data.get('timeline'),
            motivation=reg_data.get('motivation'),
            experience=reg_data.get('experience'),
            current_state=reg_data.get('current_state'),
            schedule=reg_data.get('schedule'),
            exercise_types=str(reg_data.get('exercise_types', [])) if reg_data.get('exercise_types') else None,
            exercise_equipment=str(reg_data.get('exercise_equipment', [])) if reg_data.get('exercise_equipment') else None,
            exercise_experience=reg_data.get('exercise_experience'),
            exercise_limitations=reg_data.get('exercise_limitations'),
            workout_duration=reg_data.get('workout_duration'),
            workout_frequency=reg_data.get('workout_frequency'),
            diet_type=reg_data.get('diet_type'),
            restrictions=str(reg_data.get('restrictions', [])) if reg_data.get('restrictions') else None,
            allergies=str(reg_data.get('allergies', [])) if reg_data.get('allergies') else None,
            cooking_frequency=reg_data.get('cooking_frequency'),
            cooking_skill=reg_data.get('cooking_skill'),
            meal_prep_habit=reg_data.get('meal_prep_habit'),
            tracking_experience=reg_data.get('tracking_experience'),
            used_apps=str(reg_data.get('used_apps', [])) if reg_data.get('used_apps') else None,
            data_importance=reg_data.get('data_importance'),
            is_metric=reg_data.get('is_metric', True),
            daily_calorie_goal=reg_data.get('daily_calorie_goal'),
            email_verified=True,
            has_seen_tutorial=False
        )
        
        # Save user and delete pending registration
        max_commit_retries = 3
        for attempt in range(max_commit_retries):
            try:
                db.session.add(new_user)
                db.session.delete(pending_reg)
                db.session.commit()
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_commit_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error on verify commit (attempt {attempt + 1}/{max_commit_retries}): {db_err}")
                    try:
                        db.session.rollback()
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.2)
                    # Re-query pending registration
                    pending_reg = PendingRegistration.query.filter(
                        func.lower(PendingRegistration.email) == email.lower()
                    ).first()
                    if pending_reg:
                        reg_data = json.loads(pending_reg.registration_data)
                        new_user = User(
                            username=pending_reg.username,
                            email=pending_reg.email,
                            password=pending_reg.password_hash,
                            age=reg_data.get('age', 25),
                            sex=reg_data.get('sex', 'male'),
                            weight_kg=reg_data.get('weight_kg', 70),
                            height_cm=reg_data.get('height_cm', 170),
                            activity_level=reg_data.get('activity_level', 'active'),
                            goal=reg_data.get('goal', 'maintain'),
                            email_verified=True
                        )
                else:
                    print(f"[ERROR] DB error on verify commit: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise
        
        print(f"[SUCCESS] User account created and verified: {new_user.username}, Email: {new_user.email}")
        
        return jsonify({
            'success': True,
            'message': 'Email verified successfully. Your account has been created.',
            'user_id': new_user.id,
            'username': new_user.username
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to verify code: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': f'Failed to verify code: {str(e)}'}), 500

@app.route('/auth/resend-code', methods=['POST'])
def resend_verification_code():
    """Resend verification code to user's email (max 5 times)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        email = (data.get('email') or '').strip()
        
        if not email:
            return jsonify({'error': 'Email is required'}), 400
        
        # Find pending registration by email
        pending_reg = PendingRegistration.query.filter(
            func.lower(PendingRegistration.email) == email.lower()
        ).first()
        
        if not pending_reg:
            return jsonify({'error': 'No pending registration found. Please register again.'}), 404
        
        # Check rate limiting (max 5 resends)
        if pending_reg.resend_count >= 5:
            return jsonify({
                'error': 'Maximum resend limit reached (5 attempts). Please register again.',
                'resend_count': pending_reg.resend_count,
                'max_resends': 5
            }), 429
        
        # Generate new verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        pending_reg.verification_code = verification_code
        pending_reg.verification_expires_at = verification_expires_at
        pending_reg.resend_count += 1
        
        # Save to database
        max_commit_retries = 3
        for attempt in range(max_commit_retries):
            try:
                db.session.commit()
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_commit_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error on resend commit (attempt {attempt + 1}/{max_commit_retries}): {db_err}")
                    try:
                        db.session.rollback()
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.2)
                    # Re-query and update
                    pending_reg = PendingRegistration.query.filter(
                        func.lower(PendingRegistration.email) == email.lower()
                    ).first()
                    if pending_reg:
                        pending_reg.verification_code = verification_code
                        pending_reg.verification_expires_at = verification_expires_at
                        pending_reg.resend_count += 1
                else:
                    print(f"[ERROR] DB error on resend commit: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise
        
        # Send verification email
        email_sent = send_verification_email(email, verification_code, pending_reg.username)
        if not email_sent:
            print(f"[WARN] Failed to send verification email to {email}")
            return jsonify({
                'success': False,
                'error': 'Failed to send verification email. Please try again later.'
            }), 500
        
        print(f"[SUCCESS] Verification code resent to {email} (attempt {pending_reg.resend_count}/5)")
        
        return jsonify({
            'success': True,
            'message': 'Verification code sent successfully',
            'resend_count': pending_reg.resend_count,
            'max_resends': 5,
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to resend code: {e}")
        return jsonify({'error': f'Failed to resend code: {str(e)}'}), 500

@app.route('/auth/change-email', methods=['POST'])
def change_pending_email():
    """Change email for pending registration"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        old_email = (data.get('old_email') or '').strip()
        new_email = (data.get('new_email') or '').strip()
        
        if not old_email or not new_email:
            return jsonify({'error': 'Both old_email and new_email are required'}), 400
        
        # Validate new email format
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, new_email):
            return jsonify({'error': 'Invalid email format'}), 400
        
        # Check if new email is already registered
        existing_user = User.query.filter(func.lower(User.email) == new_email.lower()).first()
        if existing_user:
            return jsonify({'error': 'Email already registered'}), 409
        
        # Find pending registration
        pending_reg = PendingRegistration.query.filter(
            func.lower(PendingRegistration.email) == old_email.lower()
        ).first()
        
        if not pending_reg:
            return jsonify({'error': 'No pending registration found'}), 404
        
        # Check if new email has pending registration
        existing_pending = PendingRegistration.query.filter(
            func.lower(PendingRegistration.email) == new_email.lower()
        ).first()
        if existing_pending and existing_pending.id != pending_reg.id:
            return jsonify({'error': 'Email already has a pending registration'}), 409
        
        # Generate new verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Update email and code
        pending_reg.email = new_email
        pending_reg.verification_code = verification_code
        pending_reg.verification_expires_at = verification_expires_at
        # Reset resend count when email changes
        pending_reg.resend_count = 0
        
        # Update registration_data JSON
        try:
            reg_data = json.loads(pending_reg.registration_data)
            reg_data['email'] = new_email
            pending_reg.registration_data = json.dumps(reg_data)
        except Exception:
            pass
        
        # Save to database
        max_commit_retries = 3
        for attempt in range(max_commit_retries):
            try:
                db.session.commit()
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_commit_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error on email change commit (attempt {attempt + 1}/{max_commit_retries}): {db_err}")
                    try:
                        db.session.rollback()
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.2)
                    pending_reg = PendingRegistration.query.filter(
                        func.lower(PendingRegistration.email) == old_email.lower()
                    ).first()
                    if pending_reg:
                        pending_reg.email = new_email
                        pending_reg.verification_code = verification_code
                        pending_reg.verification_expires_at = verification_expires_at
                        pending_reg.resend_count = 0
                else:
                    print(f"[ERROR] DB error on email change commit: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise
        
        # Send verification email to new address
        email_sent = send_verification_email(new_email, verification_code, pending_reg.username)
        if not email_sent:
            print(f"[WARN] Failed to send verification email to {new_email}")
            return jsonify({
                'success': False,
                'error': 'Failed to send verification email. Please try again later.'
            }), 500
        
        print(f"[SUCCESS] Email changed for pending registration: {old_email} -> {new_email}")
        
        return jsonify({
            'success': True,
            'message': 'Email changed successfully. Verification code sent to new email.',
            'new_email': new_email,
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to change email: {e}")
        return jsonify({'error': f'Failed to change email: {str(e)}'}), 500

@app.route('/auth/reset-password', methods=['POST'])
def reset_password():
    """Reset password - DEPRECATED: Use /auth/password-reset/request instead"""
    return jsonify({
        'error': 'This endpoint is deprecated. Please use POST /auth/password-reset/request to initiate password reset with email verification.',
        'new_endpoint': '/auth/password-reset/request',
        'method': 'POST'
    }), 410  # 410 Gone - indicates the resource is no longer available

# ===== Password Reset Verification Endpoints =====

@app.route('/auth/password-reset/request', methods=['POST'])
def request_password_reset():
    """Request password reset - sends verification code to user's email"""
    try:
        data = request.get_json() or {}
        
        email = (data.get('email') or '').strip()
        
        # Validate email format
        if not email:
            return jsonify({'error': 'Email address is required'}), 400
        
        email_regex = re.compile(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$')
        if not email_regex.match(email):
            return jsonify({'error': 'Invalid email format'}), 400
        
        # Rate limiting: Check IP-based rate limiting for email checks (prevent enumeration)
        try:
            client_ip = get_client_ip()
        except Exception as e:
            print(f"[ERROR] Failed to get client IP: {e}")
            client_ip = 'unknown'
        
        # Ensure we have a clean transaction state before database queries
        try:
            db.session.rollback()  # Rollback any previous failed transaction
        except Exception:
            pass
        
        # Check IP-based rate limiting for password reset requests
        recent_ip_requests = 0
        try:
            recent_ip_requests = PendingPasswordChange.query.filter(
                PendingPasswordChange.ip_address == client_ip,
                PendingPasswordChange.created_at > datetime.utcnow() - timedelta(hours=1)
            ).count()
        except Exception as e:
            print(f"[ERROR] Failed to check rate limit: {e}")
            import traceback
            traceback.print_exc()
            # Rollback transaction if rate limit check fails
            try:
                db.session.rollback()
            except Exception:
                pass
            # If rate limit check fails, allow the request but log it
            recent_ip_requests = 0
        
        # Find user - this is the critical check
        # Ensure clean transaction state before user query
        try:
            db.session.rollback()  # Rollback any previous failed transaction
        except Exception:
            pass
            
        try:
            user = User.query.filter(func.lower(User.email) == email.lower()).first()
        except Exception as e:
            print(f"[ERROR] Database query failed when checking email: {e}")
            import traceback
            traceback.print_exc()
            # Rollback transaction before returning error
            try:
                db.session.rollback()
            except Exception:
                pass
            # If database query fails, return a specific error
            return jsonify({
                'success': False,
                'error': 'Database error occurred. Please try again later.'
            }), 500
        
        # If email doesn't exist, check rate limit before revealing
        if not user:
            # If rate limit exceeded, return generic message to prevent enumeration
            # But still return success: False to prevent frontend navigation
            if recent_ip_requests >= 5:
                parts = email.split('@')
                masked_email = parts[0][:3] + '***@' + '***' if len(parts) > 1 and len(parts[0]) > 3 else '***@***'
                return jsonify({
                    'success': False,
                    'error': 'Too many requests. Please try again later.',
                    'message': 'If an account exists, a verification code has been sent'
                }), 429  # 429 Too Many Requests
            else:
                # Rate limit allows, return error that email doesn't exist
                return jsonify({
                    'success': False,
                    'error': 'No account found with this email address'
                }), 404
        
        # User exists, proceed with password reset
        if user:
            # Check for existing pending password reset
            existing_pending = PendingPasswordChange.query.filter_by(user_id=user.id).first()
            
            # Check IP-based rate limiting (reuse already calculated recent_ip_requests)
            if recent_ip_requests >= 3:
                # Return generic message even if rate limited
                return jsonify({
                    'success': True,
                    'message': 'If an account exists, a verification code has been sent',
                    'email': email[:3] + '***@***' if email and '@' in email else '***@***'
                }), 200
            
            # Check user-based rate limiting
            if existing_pending:
                time_since_creation = (datetime.utcnow() - existing_pending.created_at).total_seconds()
                if time_since_creation < 3600:  # 1 hour
                    if existing_pending.request_count >= 3:
                        # Return generic message
                        return jsonify({
                            'success': True,
                            'message': 'If an account exists, a verification code has been sent',
                            'email': email[:3] + '***@***' if email and '@' in email else '***@***'
                        }), 200
                    existing_pending.request_count += 1
                else:
                    # Old pending request, delete it
                    db.session.delete(existing_pending)
                    existing_pending = None
            
            # Generate verification code
            verification_code = generate_verification_code()
            verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
            
            # Create placeholder password hash (will be set when user provides new password)
            placeholder_hash = generate_password_hash('placeholder')
            
            # Create or update pending password reset
            if existing_pending and (datetime.utcnow() - existing_pending.created_at).total_seconds() < 3600:
                existing_pending.verification_code = verification_code
                existing_pending.verification_expires_at = verification_expires_at
                existing_pending.ip_address = client_ip
                pending_reset = existing_pending
            else:
                pending_reset = PendingPasswordChange(
                    user_id=user.id,
                    username=user.username,
                    email=user.email,
                    verification_code=verification_code,
                    verification_expires_at=verification_expires_at,
                    new_password_hash=placeholder_hash,  # Will be updated when password is provided
                    ip_address=client_ip,
                    request_count=1,
                    resend_count=0,
                    failed_attempts=0
                )
                db.session.add(pending_reset)
            
            db.session.commit()
            
            # Send verification email (only if user exists)
            email_sent = send_password_reset_verification(user.email, verification_code, user.username)
            
            if not email_sent:
                # Don't create pending record if email fails
                db.session.delete(pending_reset)
                db.session.commit()
                return jsonify({
                    'success': False,
                    'error': 'Failed to send verification email. Please try again later.'
                }), 500
            
            # Email sent successfully, return success with expires_at
            parts = email.split('@')
            masked_email = parts[0][:3] + '***@' + '***' if len(parts) > 1 and len(parts[0]) > 3 else '***@***'
            
            return jsonify({
                'success': True,
                'message': 'Verification code has been sent to your email',
                'email': masked_email,
                'expires_at': verification_expires_at.isoformat()
            }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        # Log the full exception with traceback for debugging
        import traceback
        error_traceback = traceback.format_exc()
        print(f"[ERROR] Failed to request password reset: {e}")
        print(f"[ERROR] Traceback:\n{error_traceback}")
        
        # Return error message (not success) to prevent frontend navigation
        # But provide more specific error based on exception type
        error_message = 'An error occurred while processing your request. Please try again later.'
        
        # Check if it's a database-related error
        if 'database' in str(e).lower() or 'connection' in str(e).lower() or 'sql' in str(e).lower():
            error_message = 'Database connection error. Please try again later.'
        elif 'timeout' in str(e).lower():
            error_message = 'Request timed out. Please try again.'
        
        return jsonify({
            'success': False,
            'error': error_message
        }), 500

@app.route('/auth/password-reset/verify', methods=['POST'])
def verify_password_reset_code():
    """Verify password reset code only (without resetting password)"""
    try:
        data = request.get_json() or {}
        
        email = (data.get('email') or '').strip()
        code = (data.get('code') or '').strip()
        
        if not email:
            return jsonify({'error': 'Email address is required'}), 400
        if not code:
            return jsonify({'error': 'Verification code is required'}), 400
        
        # Find user
        user = User.query.filter(func.lower(User.email) == email.lower()).first()
        
        if not user:
            return jsonify({'error': 'Invalid verification code or user not found'}), 400
        
        # Find pending password reset
        pending_reset = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        if not pending_reset:
            return jsonify({'error': 'Invalid verification code or no pending reset found'}), 400
        
        # Check if code expired
        if pending_reset.verification_expires_at < datetime.utcnow():
            db.session.delete(pending_reset)
            db.session.commit()
            return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check failed attempts
        if pending_reset.failed_attempts >= 5:
            db.session.delete(pending_reset)
            db.session.commit()
            return jsonify({'error': 'Too many failed attempts. Please request a new password reset.'}), 400
        
        # Verify code
        if pending_reset.verification_code != code:
            pending_reset.failed_attempts += 1
            db.session.commit()
            remaining = 5 - pending_reset.failed_attempts
            return jsonify({
                'error': f'Invalid verification code. {remaining} attempts remaining.',
                'remaining_attempts': remaining
            }), 400
        
        # Code is valid - return success (don't delete pending_reset yet, will be deleted when password is reset)
        print(f"[SUCCESS] Password reset code verified for user {user.username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code is valid. You can now set your new password.',
            'expires_at': pending_reset.verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to verify password reset code: {e}")
        return jsonify({'error': f'Failed to verify code: {str(e)}'}), 500

@app.route('/auth/password-reset/verify-and-complete', methods=['POST'])
def verify_and_complete_password_reset():
    """Verify reset code and complete password reset"""
    try:
        data = request.get_json() or {}
        
        email = (data.get('email') or '').strip()
        code = (data.get('code') or '').strip()
        new_password = (data.get('new_password') or '').strip()
        
        if not email:
            return jsonify({'error': 'Email address is required'}), 400
        if not code:
            return jsonify({'error': 'Verification code is required'}), 400
        if not new_password:
            return jsonify({'error': 'New password is required'}), 400
        
        # Find user
        user = User.query.filter(func.lower(User.email) == email.lower()).first()
        
        if not user:
            return jsonify({'error': 'Invalid verification code or user not found'}), 400
        
        # Find pending password reset
        pending_reset = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        if not pending_reset:
            return jsonify({'error': 'Invalid verification code or no pending reset found'}), 400
        
        # Check if code expired
        if pending_reset.verification_expires_at < datetime.utcnow():
            db.session.delete(pending_reset)
            db.session.commit()
            return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check failed attempts
        if pending_reset.failed_attempts >= 5:
            db.session.delete(pending_reset)
            db.session.commit()
            return jsonify({'error': 'Too many failed attempts. Please request a new password reset.'}), 400
        
        # Verify code
        if pending_reset.verification_code != code:
            pending_reset.failed_attempts += 1
            db.session.commit()
            remaining = 5 - pending_reset.failed_attempts
            return jsonify({
                'error': f'Invalid verification code. {remaining} attempts remaining.',
                'remaining_attempts': remaining
            }), 400
        
        # Validate new password strength
        strength_result = validate_password_strength(new_password)
        if not strength_result['is_valid']:
            missing = ', '.join(strength_result['requirements_missing'])
            return jsonify({
                'error': f'Password is too weak. Please ensure: {missing}',
                'strength': strength_result['strength'],
                'requirements_missing': strength_result['requirements_missing']
            }), 400
        
        # Check against common passwords
        if check_common_passwords(new_password):
            return jsonify({'error': 'This password is too common. Please choose a more unique password.'}), 400
        
        # Check similarity to username/email
        similarity = check_password_similarity(new_password, user.username, user.email)
        if similarity['is_similar']:
            return jsonify({'error': similarity['reason']}), 400
        
        # Check maximum length
        if len(new_password) > 128:
            return jsonify({'error': 'Password cannot exceed 128 characters'}), 400
        
        # Update password
        user.password = generate_password_hash(new_password)
        db.session.delete(pending_reset)
        db.session.commit()
        
        print(f"[SUCCESS] Password reset completed for user {user.username}")
        
        return jsonify({
            'success': True,
            'message': 'Password reset successfully. Please log in with your new password.'
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to verify and complete password reset: {e}")
        return jsonify({'error': f'Failed to reset password: {str(e)}'}), 500

@app.route('/auth/password-reset/resend-code', methods=['POST'])
def resend_password_reset_code():
    """Resend password reset verification code"""
    try:
        data = request.get_json() or {}
        
        email = (data.get('email') or '').strip()
        
        if not email:
            return jsonify({'error': 'Email address is required'}), 400
        
        # Find user (don't reveal if exists)
        user = User.query.filter(func.lower(User.email) == email.lower()).first()
        
        # Always return generic success message
        parts = email.split('@')
        masked_email = parts[0][:3] + '***@' + '***' if len(parts) > 1 and len(parts[0]) > 3 else '***@***'
        
        if user:
            # Find pending password reset
            pending_reset = PendingPasswordChange.query.filter_by(user_id=user.id).first()
            
            if pending_reset:
                # Check rate limiting
                client_ip = get_client_ip()
                time_since_creation = (datetime.utcnow() - pending_reset.created_at).total_seconds()
                
                if time_since_creation < 60:
                    return jsonify({
                        'success': True,
                        'message': 'If an account exists, a verification code has been resent',
                        'email': masked_email
                    }), 200
                
                if pending_reset.resend_count >= 3:
                    return jsonify({
                        'success': True,
                        'message': 'If an account exists, a verification code has been resent',
                        'email': masked_email
                    }), 200
                
                # Generate new verification code
                verification_code = generate_verification_code()
                verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
                
                pending_reset.verification_code = verification_code
                pending_reset.verification_expires_at = verification_expires_at
                pending_reset.resend_count += 1
                
                db.session.commit()
                
                # Send verification email
                email_sent = send_password_reset_verification(user.email, verification_code, user.username)
                
                if not email_sent:
                    return jsonify({
                        'success': True,
                        'message': 'If an account exists, a verification code has been resent',
                        'email': masked_email
                    }), 200
        
        # Always return generic success message
        return jsonify({
            'success': True,
            'message': 'If an account exists, a verification code has been resent',
            'email': masked_email,
            'expires_at': (datetime.utcnow() + timedelta(minutes=15)).isoformat()
        }), 200
        
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        print(f"[ERROR] Failed to resend password reset code: {e}")
        # Return generic message
        return jsonify({
            'success': True,
            'message': 'If an account exists, a verification code has been resent',
            'email': '***@***'
        }), 200

@app.route('/login', methods=['POST'])
def login_user():
    """Login user with username/email and password"""
    print(f"[DEBUG] Login request received from {request.remote_addr}")
    try:
        data = request.get_json()
        print(f"[DEBUG] Login attempt: username_or_email={data.get('username_or_email')}")
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        username_or_email = data.get('username_or_email')
        password = data.get('password')
        
        if not username_or_email or not password:
            return jsonify({'error': 'Username/email and password are required'}), 400
        
        # Normalize inputs to avoid leading/trailing whitespace issues
        username_or_email = username_or_email.strip()
        password = password.strip()
        
        # Find user by username first (uses index), then by email
        # Handle stale connections with proper session recovery
        user = None
        max_retries = 3
        for attempt in range(max_retries):
            try:
                user = User.query.filter_by(username=username_or_email).first()
                if not user and '@' in username_or_email:
                    user = User.query.filter_by(email=username_or_email).first()
                # If we got here without exception, query succeeded
                break
            except Exception as db_err:
                error_str = str(db_err)
                is_connection_error = any(keyword in error_str.lower() for keyword in [
                    'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
                ])
                
                if attempt < max_retries - 1 and is_connection_error:
                    print(f"[WARN] DB connection error on login (attempt {attempt + 1}/{max_retries}): {db_err}")
                    try:
                        # Close the session to force a new connection on next query
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    # Small delay before retry
                    time.sleep(0.1)
                else:
                    # Last attempt failed or non-connection error
                    print(f"[ERROR] DB error on login lookup: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    user = None
                    break
        
        if not user:
            return jsonify({'success': False, 'message': 'Invalid username/email or password'}), 401
        
        # Verify password (prefer secure hash, fallback to plaintext for legacy)
        stored_password = user.password or ''
        is_valid = False
        try:
            # Attempt hashed verification first
            if stored_password:
                is_valid = check_password_hash(stored_password, password)
        except Exception:
            is_valid = False
        # Fallback to plaintext match if hashed check failed (legacy support)
        if not is_valid:
            is_valid = stored_password == password

        if not is_valid:
            return jsonify({'success': False, 'message': 'Invalid username/email or password'}), 401
        
        # Note: Users are only created after email verification, so no need to check email_verified
        # All users in the database are already verified
        
        print(f"[SUCCESS] User logged in successfully: {user.username}")
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'user_id': user.id,
            'username': user.username,
            'email': user.email,
            'daily_calorie_goal': user.daily_calorie_goal,
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'has_seen_tutorial': getattr(user, 'has_seen_tutorial', False)
            }
        }), 200
        
    except Exception as e:
        error_str = str(e)
        is_connection_error = any(keyword in error_str.lower() for keyword in [
            'connection', 'closed', 'lost', 'timeout', 'e3q8', 'parameter', 'bind', 'ssl'
        ])
        
        try:
            if is_connection_error:
                db.session.close()
                db.session.remove()
            else:
                db.session.rollback()
        except Exception:
            pass
        
        print(f"[ERROR] Login failed: {e}")
        error_message = 'Database connection error. Please try again.' if is_connection_error else f'Login failed: {str(e)}'
        return jsonify({'error': error_message}), 500

@app.route('/auth/ping', methods=['GET'])
def auth_ping():
    """Ultra-light health/warmup endpoint used by the app before login.

    Ensures DB session is responsive and returns minimal payload quickly.
    """
    try:
        db_ok = bool(db.session.execute(db.text('SELECT 1')).scalar())
        return jsonify({'ok': True, 'db': db_ok}), 200
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify({'ok': False, 'error': str(e)}), 500

@app.route('/user/<username>/complete-tutorial', methods=['POST'])
def complete_tutorial(username):
    """Mark tutorial as completed for a user"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        user.has_seen_tutorial = True
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Tutorial marked as completed'
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to update tutorial status: {str(e)}'}), 500

@app.route('/user/<username>', methods=['GET'])
def get_user(username):
    """Get user profile data by username"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Convert list strings back to arrays
        def parse_list_string(value):
            if not value or value == '[]':
                return []
            try:
                return eval(value) if value.startswith('[') else value.split(', ')
            except:
                return []
        
        user_data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'age': user.age,
            'sex': user.sex,
            'weight_kg': user.weight_kg,
            'height_cm': user.height_cm,
            'activity_level': user.activity_level,
            'goal': user.goal,
            'target_weight': user.target_weight,
            'timeline': user.timeline,
            'motivation': user.motivation,
            'experience': user.experience,
            'current_state': user.current_state,
            'schedule': user.schedule,
            'exercise_types': parse_list_string(user.exercise_types),
            'exercise_equipment': parse_list_string(user.exercise_equipment),
            'exercise_experience': user.exercise_experience,
            'exercise_limitations': user.exercise_limitations,
            'workout_duration': user.workout_duration,
            'workout_frequency': user.workout_frequency,
            'diet_type': user.diet_type,
            'restrictions': parse_list_string(user.restrictions),
            'allergies': parse_list_string(user.allergies),
            'cooking_frequency': user.cooking_frequency,
            'cooking_skill': user.cooking_skill,
            'meal_prep_habit': user.meal_prep_habit,
            'tracking_experience': user.tracking_experience,
            'used_apps': parse_list_string(user.used_apps),
            'data_importance': user.data_importance,
            'is_metric': user.is_metric,
            'daily_calorie_goal': user.daily_calorie_goal,
            'created_at': user.created_at.isoformat() if user.created_at else None
        }
        
        return jsonify({
            'success': True,
            'user': user_data
        }), 200
        
    except Exception as e:
        print(f"[ERROR] Failed to get user {username}: {e}")
        return jsonify({'error': f'Failed to get user: {str(e)}'}), 500

@app.route('/user/<username>', methods=['PUT'])
def update_user(username):
    """Update user profile data"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Update user fields if provided
        if 'email' in data:
            user.email = data['email']
        if 'age' in data:
            user.age = data['age']
        if 'sex' in data:
            user.sex = data['sex']
        if 'weight_kg' in data:
            user.weight_kg = data['weight_kg']
        if 'height_cm' in data:
            user.height_cm = data['height_cm']
        if 'activity_level' in data:
            user.activity_level = data['activity_level']
        if 'goal' in data:
            user.goal = data['goal']
        if 'target_weight' in data:
            user.target_weight = data['target_weight']
        if 'timeline' in data:
            user.timeline = data['timeline']
        if 'motivation' in data:
            user.motivation = data['motivation']
        if 'experience' in data:
            user.experience = data['experience']
        if 'current_state' in data:
            user.current_state = data['current_state']
        if 'schedule' in data:
            user.schedule = data['schedule']
        if 'exercise_types' in data:
            user.exercise_types = str(data['exercise_types']) if data['exercise_types'] else None
        if 'exercise_equipment' in data:
            user.exercise_equipment = str(data['exercise_equipment']) if data['exercise_equipment'] else None
        if 'exercise_experience' in data:
            user.exercise_experience = data['exercise_experience']
        if 'exercise_limitations' in data:
            user.exercise_limitations = data['exercise_limitations']
        if 'workout_duration' in data:
            user.workout_duration = data['workout_duration']
        if 'workout_frequency' in data:
            user.workout_frequency = data['workout_frequency']
        if 'diet_type' in data:
            user.diet_type = data['diet_type']
        if 'restrictions' in data:
            user.restrictions = str(data['restrictions']) if data['restrictions'] else None
        if 'allergies' in data:
            user.allergies = str(data['allergies']) if data['allergies'] else None
        if 'foodPreferences' in data or 'food_preferences' in data or 'dietary_preferences' in data:
            # Store food preferences from grid selections
            prefs_val = data.get('foodPreferences') or data.get('food_preferences') or data.get('dietary_preferences')
            if prefs_val:
                if hasattr(user, 'dietary_preferences'):
                    user.dietary_preferences = str(prefs_val)
                else:
                    # Fallback to diet_type if dietary_preferences column doesn't exist
                    user.diet_type = str(prefs_val) if isinstance(prefs_val, str) else str(prefs_val)
        if 'cooking_frequency' in data:
            user.cooking_frequency = data['cooking_frequency']
        if 'cooking_skill' in data:
            user.cooking_skill = data['cooking_skill']
        if 'meal_prep_habit' in data:
            user.meal_prep_habit = data['meal_prep_habit']
        if 'tracking_experience' in data:
            user.tracking_experience = data['tracking_experience']
        if 'used_apps' in data:
            user.used_apps = str(data['used_apps']) if data['used_apps'] else None
        if 'data_importance' in data:
            user.data_importance = data['data_importance']
        if 'is_metric' in data:
            user.is_metric = data['is_metric']
        
        # Recalculate daily calorie goal if relevant fields changed
        recalculate_calories = any(field in data for field in ['age', 'sex', 'weight_kg', 'height_cm', 'activity_level', 'goal'])
        
        if recalculate_calories:
            # Validate metrics and enums before recompute
            try:
                age_val = int(user.age)
                weight_val = float(user.weight_kg)
                height_val = float(user.height_cm)
                ok, msg = validate_metrics(age_val, weight_val, height_val)
                if not ok:
                    return jsonify({'error': msg}), 400
                lvl = normalize_activity_level(user.activity_level or '')
                gl = normalize_goal(user.goal or 'maintain')
                if lvl not in ALLOWED_ACTIVITY_LEVELS:
                    return jsonify({'error': 'Invalid activity level'}), 400
                if gl not in ALLOWED_GOALS:
                    return jsonify({'error': 'Invalid goal'}), 400
                user.activity_level = lvl
                user.goal = gl
                old_goal = user.daily_calorie_goal
                new_goal = compute_daily_calorie_goal(
                    sex=user.sex,
                    age=age_val,
                    weight_kg=weight_val,
                    height_cm=height_val,
                    activity_level=lvl,
                    goal=gl,
                )
                user.daily_calorie_goal = new_goal
                
                # Log goal change if it actually changed
                if old_goal != new_goal:
                    _log_goal_change(user.username, new_goal, date.today())
            except Exception as e:
                return jsonify({'error': 'Invalid inputs for calorie calculation'}), 400
        
        # Save changes
        db.session.commit()
        
        print(f"[SUCCESS] User {username} updated successfully")
        
        return jsonify({
            'success': True,
            'message': 'User updated successfully',
            'daily_calorie_goal': user.daily_calorie_goal
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to update user {username}: {e}")
        return jsonify({'error': f'Failed to update user: {str(e)}'}), 500

# ===== Email Change Verification Endpoints =====

@app.route('/user/<username>/email/request-change', methods=['POST'])
def request_email_change(username):
    """Initiate email change process - sends verification code to new email"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data or 'new_email' not in data:
            return jsonify({'error': 'New email is required'}), 400
        
        new_email = data['new_email'].strip().lower()
        old_email = user.email or ''
        
        # Validate email format
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, new_email):
            return jsonify({'error': 'Invalid email format'}), 400
        
        # Check if new email is same as current
        if old_email and old_email.lower() == new_email:
            return jsonify({'error': 'New email must be different from current email'}), 400
        
        # Check if email is already in use by another user
        existing_user = User.query.filter(func.lower(User.email) == new_email).first()
        if existing_user and existing_user.id != user.id:
            return jsonify({
                'error': 'Email already registered',
                'message': 'This email address is already registered to another account'
            }), 409
        
        # Also check if email is in pending registrations
        pending_reg = PendingRegistration.query.filter(
            func.lower(PendingRegistration.email) == new_email
        ).first()
        if pending_reg:
            return jsonify({
                'error': 'Email already registered',
                'message': 'This email address is already registered to another account'
            }), 409
        
        # Check for existing pending email change
        existing_pending = PendingEmailChange.query.filter_by(user_id=user.id).first()
        
        # Rate limiting: Check if user has made too many requests (max 3 per hour)
        if existing_pending:
            time_since_creation = (datetime.utcnow() - existing_pending.created_at).total_seconds()
            if time_since_creation < 3600:  # 1 hour
                # Check resend count
                if existing_pending.resend_count >= 3:
                    return jsonify({'error': 'Too many requests. Please wait before requesting again.'}), 429
            else:
                # Old pending request, delete it
                db.session.delete(existing_pending)
        
        # Generate verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Create or update pending email change
        if existing_pending and (datetime.utcnow() - existing_pending.created_at).total_seconds() < 3600:
            existing_pending.new_email = new_email
            existing_pending.old_email = old_email
            existing_pending.verification_code = verification_code
            existing_pending.verification_expires_at = verification_expires_at
            # Don't reset resend_count - keep it for rate limiting
            pending_change = existing_pending
        else:
            pending_change = PendingEmailChange(
                user_id=user.id,
                username=user.username,
                old_email=old_email,
                new_email=new_email,
                verification_code=verification_code,
                verification_expires_at=verification_expires_at,
                resend_count=0
            )
            db.session.add(pending_change)
        
        db.session.commit()
        
        # Send verification email to NEW email address
        # Note: Code is sent to NEW email to verify ownership of the new email address
        email_sent = send_email_change_verification(
            new_email=new_email,
            code=verification_code,
            old_email=old_email,
            username=user.username
        )
        
        if not email_sent:
            # Check if email service is configured
            import os
            if not os.environ.get('GMAIL_USERNAME') or not os.environ.get('GMAIL_APP_PASSWORD'):
                return jsonify({
                    'error': 'Email service not configured. Please contact support.',
                    'details': 'Gmail SMTP credentials are missing'
                }), 500
            return jsonify({
                'error': 'Failed to send verification email. Please check the new email address and try again.',
                'details': f'Code was generated but email could not be sent to {new_email}'
            }), 500
        
        # Send security notification to OLD email address (non-blocking)
        # This is informational only - failure should not block email change
        if old_email:
            try:
                notification_sent = send_email_change_notification(
                    old_email=old_email,
                    new_email=new_email,
                    username=user.username,
                    timestamp=datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
                )
                if notification_sent:
                    print(f"[SUCCESS] Email change notification sent to {old_email} for user {username}")
                else:
                    print(f"[WARN] Failed to send email change notification to {old_email} (non-blocking)")
            except Exception as e:
                # Log but don't fail - notification is non-critical
                print(f"[WARN] Error sending email change notification to {old_email}: {e}")
        
        print(f"[SUCCESS] Email change verification code sent to {new_email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code sent to new email address',
            'new_email': new_email,
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to request email change for user {username}: {e}")
        return jsonify({'error': f'Failed to request email change: {str(e)}'}), 500

@app.route('/user/<username>/email/verify-change', methods=['POST'])
def verify_email_change(username):
    """Verify email change code and update email"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data or 'verification_code' not in data:
            return jsonify({'error': 'Verification code is required'}), 400
        
        code = data['verification_code'].strip()
        
        # Find pending email change
        pending_change = PendingEmailChange.query.filter_by(user_id=user.id).first()
        
        if not pending_change:
            return jsonify({'error': 'No pending email change found'}), 404
        
        # Check if code expired
        if pending_change.verification_expires_at < datetime.utcnow():
            db.session.delete(pending_change)
            db.session.commit()
            return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check if code matches
        if pending_change.verification_code != code:
            return jsonify({'error': 'Invalid verification code'}), 400
        
        # Verify new email is still available
        existing_user = User.query.filter(func.lower(User.email) == pending_change.new_email.lower()).first()
        if existing_user and existing_user.id != user.id:
            db.session.delete(pending_change)
            db.session.commit()
            return jsonify({'error': 'Email is now in use by another account'}), 409
        
        # Update user email
        old_email = user.email
        user.email = pending_change.new_email
        
        # Delete pending change
        db.session.delete(pending_change)
        db.session.commit()
        
        print(f"[SUCCESS] Email changed for user {username}: {old_email} -> {user.email}")
        
        return jsonify({
            'success': True,
            'message': 'Email changed successfully',
            'new_email': user.email
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to verify email change for user {username}: {e}")
        return jsonify({'error': f'Failed to verify email change: {str(e)}'}), 500

@app.route('/user/<username>/email/resend-code', methods=['POST'])
def resend_email_change_code(username):
    """Resend email change verification code"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Find pending email change
        pending_change = PendingEmailChange.query.filter_by(user_id=user.id).first()
        
        if not pending_change:
            return jsonify({'error': 'No pending email change found'}), 404
        
        # Rate limiting: Check resend count and time since last resend
        if pending_change.resend_count >= 3:
            time_since_creation = (datetime.utcnow() - pending_change.created_at).total_seconds()
            if time_since_creation < 3600:  # 1 hour
                return jsonify({'error': 'Maximum resend attempts reached. Please wait before trying again.'}), 429
        
        # Check minimum 60 seconds between resends (check last resend time)
        # For simplicity, we'll allow resend if code is not expired
        if pending_change.verification_expires_at < datetime.utcnow():
            return jsonify({'error': 'Verification code has expired. Please request a new email change.'}), 400
        
        # Generate new code and reset expiration (restart timer)
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        pending_change.verification_code = verification_code
        pending_change.verification_expires_at = verification_expires_at
        pending_change.resend_count += 1
        
        db.session.commit()
        
        # Send verification email to NEW email address
        # Note: Code is sent to NEW email to verify ownership of the new email address
        email_sent = send_email_change_verification(
            new_email=pending_change.new_email,
            code=verification_code,
            old_email=pending_change.old_email,
            username=user.username
        )
        
        if not email_sent:
            # Check if email service is configured
            import os
            if not os.environ.get('GMAIL_USERNAME') or not os.environ.get('GMAIL_APP_PASSWORD'):
                return jsonify({
                    'error': 'Email service not configured. Please contact support.',
                    'details': 'Gmail SMTP credentials are missing'
                }), 500
            return jsonify({
                'error': 'Failed to send verification email. Please check the new email address and try again.',
                'details': f'Code was generated but email could not be sent to {pending_change.new_email}'
            }), 500
        
        print(f"[SUCCESS] Email change verification code resent to {pending_change.new_email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code resent',
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to resend email change code for user {username}: {e}")
        return jsonify({'error': f'Failed to resend code: {str(e)}'}), 500

@app.route('/user/<username>/email/pending-status', methods=['GET'])
def get_email_change_status(username):
    """Get pending email change status"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        pending_change = PendingEmailChange.query.filter_by(user_id=user.id).first()
        
        if not pending_change:
            return jsonify({
                'has_pending': False
            }), 200
        
        # Check if expired
        if pending_change.verification_expires_at < datetime.utcnow():
            db.session.delete(pending_change)
            db.session.commit()
            return jsonify({
                'has_pending': False
            }), 200
        
        return jsonify({
            'has_pending': True,
            'new_email': pending_change.new_email,
            'expires_at': pending_change.verification_expires_at.isoformat(),
            'can_resend': pending_change.resend_count < 3
        }), 200
        
    except Exception as e:
        print(f"[ERROR] Failed to get email change status for user {username}: {e}")
        return jsonify({'error': f'Failed to get status: {str(e)}'}), 500

@app.route('/user/<username>/email/cancel-change', methods=['DELETE'])
def cancel_email_change(username):
    """Cancel pending email change"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        pending_change = PendingEmailChange.query.filter_by(user_id=user.id).first()
        
        if pending_change:
            db.session.delete(pending_change)
            db.session.commit()
            print(f"[SUCCESS] Email change cancelled for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Email change cancelled'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to cancel email change for user {username}: {e}")
        return jsonify({'error': f'Failed to cancel email change: {str(e)}'}), 500

@app.route('/user/<username>/email/check-config', methods=['GET'])
def check_email_config():
    """Check if email service is configured (for debugging)"""
    try:
        import os
        gmail_username = os.environ.get('GMAIL_USERNAME')
        gmail_password = os.environ.get('GMAIL_APP_PASSWORD')
        
        is_configured = bool(gmail_username and gmail_password)
        
        return jsonify({
            'email_service_configured': is_configured,
            'gmail_username_set': bool(gmail_username),
            'gmail_password_set': bool(gmail_password),
            'message': 'Email service is configured' if is_configured else 'Email service is NOT configured. Set GMAIL_USERNAME and GMAIL_APP_PASSWORD in .env'
        }), 200
    except Exception as e:
        print(f"[ERROR] Email config check failed: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'error': str(e),
            'email_service_configured': False,
            'gmail_username_set': False,
            'gmail_password_set': False
        }), 500

@app.route('/api/email/check-config', methods=['GET'])
def check_email_config_simple():
    """Simple email config check endpoint (no username required)"""
    try:
        import os
        gmail_username = os.environ.get('GMAIL_USERNAME')
        gmail_password = os.environ.get('GMAIL_APP_PASSWORD')
        
        is_configured = bool(gmail_username and gmail_password)
        
        return jsonify({
            'email_service_configured': is_configured,
            'gmail_username_set': bool(gmail_username),
            'gmail_password_set': bool(gmail_password),
            'message': 'Email service is configured' if is_configured else 'Email service is NOT configured. Set GMAIL_USERNAME and GMAIL_APP_PASSWORD in Railway Variables'
        }), 200
    except Exception as e:
        print(f"[ERROR] Email config check failed: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'error': str(e),
            'email_service_configured': False,
            'gmail_username_set': False,
            'gmail_password_set': False
        }), 500

@app.route('/user/<username>/email', methods=['PUT'])
def change_user_email(username):
    """Change user email address - DEPRECATED: Use /email/request-change instead"""
    return jsonify({
        'error': 'This endpoint is deprecated. Please use POST /user/<username>/email/request-change to initiate email change with verification.',
        'new_endpoint': f'/user/{username}/email/request-change',
        'method': 'POST'
    }), 410  # 410 Gone - indicates the resource is no longer available

@app.route('/user/<username>/password', methods=['PUT'])
def change_user_password(username):
    """Change user password - DEPRECATED: Use /password/request-change instead"""
    return jsonify({
        'error': 'This endpoint is deprecated. Please use POST /user/<username>/password/request-change to initiate password change with email verification.',
        'new_endpoint': f'/user/{username}/password/request-change',
        'method': 'POST'
    }), 410  # 410 Gone - indicates the resource is no longer available

# ===== Password Change Verification Endpoints =====

@app.route('/user/<username>/password/request-change', methods=['POST'])
def request_password_change(username):
    """Initiate password change process - sends verification code to user's email"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        current_password = data.get('current_password')
        new_password = data.get('new_password')
        
        if not current_password or not new_password:
            return jsonify({'error': 'Current password and new password are required'}), 400
        
        # Verify current password FIRST
        current_password_correct = check_password_hash(user.password, current_password)
        if not current_password_correct:
            return jsonify({'error': 'Current password is incorrect'}), 401
        
        # Check if new password is the same as current password (do this early for better UX)
        if check_password_hash(user.password, new_password):
            return jsonify({'error': 'New password must be different from your current password'}), 400
        
        # Validate new password strength
        strength_result = validate_password_strength(new_password)
        if not strength_result['is_valid']:
            missing = ', '.join(strength_result['requirements_missing'])
            return jsonify({
                'error': f'Password is too weak. Please ensure: {missing}',
                'strength': strength_result['strength'],
                'requirements_missing': strength_result['requirements_missing']
            }), 400
        
        # Check against common passwords
        if check_common_passwords(new_password):
            return jsonify({'error': 'This password is too common. Please choose a more unique password.'}), 400
        
        # Check similarity to username/email
        similarity = check_password_similarity(new_password, user.username, user.email)
        if similarity['is_similar']:
            return jsonify({'error': similarity['reason']}), 400
        
        # Check maximum length
        if len(new_password) > 128:
            return jsonify({'error': 'Password cannot exceed 128 characters'}), 400
        
        # Check for existing pending password change
        existing_pending = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        # Rate limiting: Check if user has made too many requests (max 3 per hour)
        if existing_pending:
            time_since_creation = (datetime.utcnow() - existing_pending.created_at).total_seconds()
            if time_since_creation < 3600:  # 1 hour
                if existing_pending.request_count >= 3:
                    return jsonify({'error': 'Too many requests. Please wait before requesting again.'}), 429
                existing_pending.request_count += 1
            else:
                # Old pending request, delete it
                db.session.delete(existing_pending)
                existing_pending = None
        
        # Check for conflicting operations
        pending_email = PendingEmailChange.query.filter_by(user_id=user.id).first()
        if pending_email:
            return jsonify({'error': 'Cannot change password while email change is pending'}), 409
        
        # Check if user has an email address set
        if not user.email or not user.email.strip():
            return jsonify({
                'error': 'No email set',
                'message': 'You must have an email address set on your account to change your password. Please use the "Change Email" feature to set your email address first.'
            }), 400
        
        # Generate verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Hash new password for temporary storage
        new_password_hash = generate_password_hash(new_password)
        
        # Get client IP
        client_ip = get_client_ip()
        
        # Create or update pending password change
        if existing_pending and (datetime.utcnow() - existing_pending.created_at).total_seconds() < 3600:
            # Reset status to pending if it was cancelled or expired
            existing_pending.verification_code = verification_code
            existing_pending.verification_expires_at = verification_expires_at
            existing_pending.new_password_hash = new_password_hash
            existing_pending.ip_address = client_ip
            existing_pending.status = 'pending'
            existing_pending.verified_at = None
            existing_pending.cancelled_at = None
            pending_change = existing_pending
        else:
            pending_change = PendingPasswordChange(
                user_id=user.id,
                username=user.username,
                email=user.email,
                verification_code=verification_code,
                verification_expires_at=verification_expires_at,
                new_password_hash=new_password_hash,
                ip_address=client_ip,
                request_count=1,
                resend_count=0,
                failed_attempts=0,
                status='pending',
                verified_at=None,
                cancelled_at=None
            )
            db.session.add(pending_change)
        
        db.session.commit()
        
        # Send verification email
        email_sent = send_password_change_verification(user.email, verification_code, user.username)
        
        if not email_sent:
            # Don't create pending record if email fails
            db.session.delete(pending_change)
            db.session.commit()
            return jsonify({'error': 'Email service temporarily unavailable. Please try again later.'}), 503
        
        print(f"[SUCCESS] Password change verification code sent to {user.email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code sent to your email',
            'email': user.email,
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to request password change for user {username}: {e}")
        return jsonify({'error': f'Failed to request password change: {str(e)}'}), 500

@app.route('/user/<username>/password/verify-change', methods=['POST'])
def verify_password_change(username):
    """Verify password change code and update password"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data or 'code' not in data:
            return jsonify({'error': 'Verification code is required'}), 400
        
        code = data['code'].strip()
        
        # Find pending password change
        pending_change = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        if not pending_change:
            print(f"[SECURITY] Verify attempt for user {username}: No pending password change found")
            return jsonify({'error': 'No pending password change found'}), 404
        
        # SECURITY: Check status - must be 'pending' to verify
        if pending_change.status != 'pending':
            if pending_change.status == 'cancelled':
                print(f"[SECURITY] Verify attempt for user {username}: Attempted to verify cancelled request")
                db.session.delete(pending_change)
                db.session.commit()
                return jsonify({'error': 'This password change request was cancelled. Please request a new one.'}), 400
            elif pending_change.status == 'verified':
                print(f"[SECURITY] Verify attempt for user {username}: Attempted to re-verify already verified request")
                db.session.delete(pending_change)
                db.session.commit()
                return jsonify({'error': 'This password change has already been completed. Please request a new one if needed.'}), 400
            elif pending_change.status == 'expired':
                print(f"[SECURITY] Verify attempt for user {username}: Attempted to verify expired request")
                db.session.delete(pending_change)
                db.session.commit()
                return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check if code expired
        if pending_change.verification_expires_at < datetime.utcnow():
            pending_change.status = 'expired'
            db.session.delete(pending_change)
            db.session.commit()
            print(f"[SECURITY] Verify attempt for user {username}: Code expired")
            return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check failed attempts
        if pending_change.failed_attempts >= 5:
            pending_change.status = 'expired'
            db.session.delete(pending_change)
            db.session.commit()
            print(f"[SECURITY] Verify attempt for user {username}: Too many failed attempts")
            return jsonify({'error': 'Too many failed attempts. Please request a new password change.'}), 400
        
        # Check if code matches
        if pending_change.verification_code != code:
            pending_change.failed_attempts += 1
            db.session.commit()
            remaining = 5 - pending_change.failed_attempts
            print(f"[SECURITY] Verify attempt for user {username}: Invalid code, {remaining} attempts remaining")
            return jsonify({
                'error': f'Invalid verification code. {remaining} attempts remaining.',
                'remaining_attempts': remaining
            }), 400
        
        # SECURITY: Code is correct - use atomic transaction to update password
        # Mark as verified BEFORE updating password to prevent race conditions
        try:
            pending_change.status = 'verified'
            pending_change.verified_at = datetime.utcnow()
            user.password = pending_change.new_password_hash
            db.session.delete(pending_change)
            db.session.commit()
            print(f"[SUCCESS] Password changed for user {username} - verified at {datetime.utcnow()}")
        except Exception as e:
            db.session.rollback()
            print(f"[ERROR] Failed to update password for user {username}: {e}")
            raise
        
        return jsonify({
            'success': True,
            'message': 'Password changed successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to verify password change for user {username}: {e}")
        return jsonify({'error': f'Failed to verify password change: {str(e)}'}), 500

@app.route('/user/<username>/password/resend-code', methods=['POST'])
def resend_password_change_code(username):
    """Resend password change verification code"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check if user has an email address set
        if not user.email or not user.email.strip():
            return jsonify({
                'error': 'No email set',
                'message': 'You must have an email address set on your account to change your password. Please use the "Change Email" feature to set your email address first.'
            }), 400
        
        # Find pending password change
        pending_change = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        if not pending_change:
            return jsonify({'error': 'No pending password change found'}), 404
        
        # SECURITY: Check status - can only resend for pending requests
        if pending_change.status != 'pending':
            if pending_change.status == 'cancelled':
                return jsonify({'error': 'This password change request was cancelled. Please request a new one.'}), 400
            elif pending_change.status == 'verified':
                return jsonify({'error': 'This password change has already been completed.'}), 400
            elif pending_change.status == 'expired':
                return jsonify({'error': 'This password change request has expired. Please request a new one.'}), 400
        
        # Check rate limiting (max 3 resends per hour, 60 seconds between resends)
        time_since_creation = (datetime.utcnow() - pending_change.created_at).total_seconds()
        if time_since_creation < 60:
            return jsonify({'error': 'Please wait before requesting a new code'}), 429
        
        if pending_change.resend_count >= 3:
            return jsonify({'error': 'Maximum resend limit reached. Please request a new password change.'}), 429
        
        # Generate new verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        pending_change.verification_code = verification_code
        pending_change.verification_expires_at = verification_expires_at
        pending_change.resend_count += 1
        
        db.session.commit()
        
        # Send verification email
        email_sent = send_password_change_verification(user.email, verification_code, user.username)
        
        if not email_sent:
            return jsonify({'error': 'Email service temporarily unavailable. Please try again later.'}), 503
        
        print(f"[SUCCESS] Password change verification code resent to {user.email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code resent',
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to resend password change code for user {username}: {e}")
        return jsonify({'error': f'Failed to resend code: {str(e)}'}), 500

@app.route('/user/<username>/password/cancel-change', methods=['POST'])
def cancel_password_change(username):
    """Cancel pending password change"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Find pending password change
        pending_change = PendingPasswordChange.query.filter_by(user_id=user.id).first()
        
        if pending_change:
            # SECURITY: Mark as cancelled and set timestamp before deletion
            if pending_change.status == 'pending':
                pending_change.status = 'cancelled'
                pending_change.cancelled_at = datetime.utcnow()
                db.session.delete(pending_change)
                db.session.commit()
                print(f"[SUCCESS] Password change cancelled for user {username} at {datetime.utcnow()}")
            else:
                # Already cancelled, verified, or expired - just delete
                print(f"[INFO] Deleting non-pending password change for user {username} (status: {pending_change.status})")
                db.session.delete(pending_change)
                db.session.commit()
        else:
            print(f"[INFO] Cancel request for user {username}: No pending password change found")
        
        return jsonify({
            'success': True,
            'message': 'Password change cancelled'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to cancel password change for user {username}: {e}")
        return jsonify({'error': f'Failed to cancel password change: {str(e)}'}), 500

# ===== Account Deletion Verification Endpoints =====

@app.route('/user/<username>/delete/request', methods=['POST'])
def request_account_deletion(username):
    """Initiate account deletion process - sends verification code to current email"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check for existing pending deletion
        existing_pending = PendingAccountDeletion.query.filter_by(user_id=user.id).first()
        
        # Rate limiting: Max 1 request per hour
        if existing_pending:
            time_since_creation = (datetime.utcnow() - existing_pending.created_at).total_seconds()
            if time_since_creation < 3600:  # 1 hour
                return jsonify({'error': 'Account deletion request already pending. Please wait before requesting again.'}), 429
            else:
                # Old pending request, delete it
                db.session.delete(existing_pending)
        
        # Generate verification code
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Create pending account deletion
        pending_deletion = PendingAccountDeletion(
            user_id=user.id,
            username=user.username,
            email=user.email or user.username,  # Use email or username as fallback
            verification_code=verification_code,
            verification_expires_at=verification_expires_at,
            resend_count=0
        )
        db.session.add(pending_deletion)
        db.session.commit()
        
        # Send verification email to CURRENT email address
        email_sent = send_account_deletion_verification(
            email=user.email or user.username,
            code=verification_code,
            username=user.username
        )
        
        if not email_sent:
            return jsonify({'error': 'Failed to send verification email. Please try again.'}), 500
        
        print(f"[SUCCESS] Account deletion verification code sent to {user.email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code sent to your email',
            'expires_at': verification_expires_at.isoformat(),
            'warning': 'This action cannot be undone'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to request account deletion for user {username}: {e}")
        return jsonify({'error': f'Failed to request account deletion: {str(e)}'}), 500

@app.route('/user/<username>/delete/verify', methods=['POST'])
def verify_account_deletion(username):
    """Verify account deletion code and delete account"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data or 'verification_code' not in data:
            return jsonify({'error': 'Verification code is required'}), 400
        
        code = data['verification_code'].strip()
        
        # Find pending deletion
        pending_deletion = PendingAccountDeletion.query.filter_by(user_id=user.id).first()
        
        if not pending_deletion:
            return jsonify({'error': 'No pending account deletion found'}), 404
        
        # Check if code expired
        if pending_deletion.verification_expires_at < datetime.utcnow():
            db.session.delete(pending_deletion)
            db.session.commit()
            return jsonify({'error': 'Verification code has expired. Please request a new one.'}), 400
        
        # Check if code matches
        if pending_deletion.verification_code != code:
            return jsonify({'error': 'Invalid verification code'}), 400
        
        # Delete all associated data (same as existing delete endpoint)
        # Delete food logs
        FoodLog.query.filter_by(user=username).delete()
        
        # Delete exercise logs
        ExerciseLog.query.filter_by(user=username).delete()
        
        # Delete weight logs
        WeightLog.query.filter_by(user=username).delete()
        
        # Delete workout logs
        WorkoutLog.query.filter_by(user=username).delete()
        
        # Delete custom exercises
        UserExerciseSubmission.query.filter_by(user=username).delete()
        
        # Delete exercise sessions
        ExerciseSession.query.filter_by(user=username).delete()
        
        # Delete recipe logs
        RecipeLog.query.filter_by(user=username).delete()
        
        # Delete custom recipes and their ingredients
        user_recipes = CustomRecipe.query.filter_by(user=username).all()
        recipe_ids = [recipe.id for recipe in user_recipes]
        
        if recipe_ids:
            RecipeIngredient.query.filter(RecipeIngredient.recipe_id.in_(recipe_ids)).delete()
        
        CustomRecipe.query.filter_by(user=username).delete()
        
        # Delete streaks
        Streak.query.filter_by(user=username).delete()
        
        # Delete pending deletion record
        db.session.delete(pending_deletion)
        
        # Delete the user
        db.session.delete(user)
        db.session.commit()
        
        print(f"[SUCCESS] User account {username} deleted successfully")
        
        return jsonify({
            'success': True,
            'message': 'Account deleted successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to verify account deletion for user {username}: {e}")
        return jsonify({'error': f'Failed to verify account deletion: {str(e)}'}), 500

@app.route('/user/<username>/delete/resend-code', methods=['POST'])
def resend_account_deletion_code(username):
    """Resend account deletion verification code"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Find pending deletion
        pending_deletion = PendingAccountDeletion.query.filter_by(user_id=user.id).first()
        
        if not pending_deletion:
            return jsonify({'error': 'No pending account deletion found'}), 404
        
        # Rate limiting: Max 2 resends per hour
        if pending_deletion.resend_count >= 2:
            time_since_creation = (datetime.utcnow() - pending_deletion.created_at).total_seconds()
            if time_since_creation < 3600:  # 1 hour
                return jsonify({'error': 'Maximum resend attempts reached. Please wait before trying again.'}), 429
        
        # Check if code expired
        if pending_deletion.verification_expires_at < datetime.utcnow():
            return jsonify({'error': 'Verification code has expired. Please request a new account deletion.'}), 400
        
        # Generate new code and reset expiration (restart timer)
        verification_code = generate_verification_code()
        verification_expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        pending_deletion.verification_code = verification_code
        pending_deletion.verification_expires_at = verification_expires_at
        pending_deletion.resend_count += 1
        
        db.session.commit()
        
        # Send verification email
        email_sent = send_account_deletion_verification(
            email=user.email or user.username,
            code=verification_code,
            username=user.username
        )
        
        if not email_sent:
            return jsonify({'error': 'Failed to send verification email. Please try again.'}), 500
        
        print(f"[SUCCESS] Account deletion verification code resent to {user.email} for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Verification code resent',
            'expires_at': verification_expires_at.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to resend account deletion code for user {username}: {e}")
        return jsonify({'error': f'Failed to resend code: {str(e)}'}), 500

@app.route('/user/<username>/delete/cancel', methods=['DELETE'])
def cancel_account_deletion(username):
    """Cancel pending account deletion"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        pending_deletion = PendingAccountDeletion.query.filter_by(user_id=user.id).first()
        
        if pending_deletion:
            db.session.delete(pending_deletion)
            db.session.commit()
            print(f"[SUCCESS] Account deletion cancelled for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Account deletion cancelled'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to cancel account deletion for user {username}: {e}")
        return jsonify({'error': f'Failed to cancel account deletion: {str(e)}'}), 500

@app.route('/user/<username>', methods=['DELETE'])
def delete_user_account(username):
    """Delete user account - DEPRECATED: Use /delete/request instead"""
    return jsonify({
        'error': 'This endpoint is deprecated. Please use POST /user/<username>/delete/request to initiate account deletion with email verification.',
        'new_endpoint': f'/user/{username}/delete/request',
        'method': 'POST'
    }), 410  # 410 Gone - indicates the resource is no longer available

def clean_food_name(name):
    """
    Clean food name by removing:
    - "Var" followed by numbers (e.g., "Lechon Var1" -> "Lechon")
    - "#" followed by numbers (e.g., "Laing #52" -> "Laing")
    - Underscores (e.g., "tinolang_manok" -> "tinolang manok")
    - Trailing numbers and special characters
    """
    if not name or pd.isna(name):
        return name
    
    import re
    name_str = str(name).strip()
    
    # Remove "Var" followed by numbers (case-insensitive)
    name_str = re.sub(r'\s+var\s*\d+', '', name_str, flags=re.IGNORECASE)
    
    # Remove "#" followed by numbers
    name_str = re.sub(r'\s*#\s*\d+', '', name_str)
    
    # Replace underscores with spaces
    name_str = name_str.replace('_', ' ')
    
    # Remove trailing numbers, spaces, and special characters
    name_str = re.sub(r'\s+\d+$', '', name_str)  # Remove trailing numbers
    name_str = re.sub(r'\s+$', '', name_str)  # Remove trailing spaces
    
    return name_str.strip()

def _parse_user_preferences(user_obj):
    """Parse user's food preferences from User object."""
    preferences = []
    try:
        # Try to get dietary_preferences first
        if hasattr(user_obj, 'dietary_preferences') and user_obj.dietary_preferences:
            prefs_str = str(user_obj.dietary_preferences).strip()
            if prefs_str and prefs_str != 'None' and prefs_str != '[]':
                try:
                    if prefs_str.startswith('['):
                        preferences = eval(prefs_str) if prefs_str else []
                    else:
                        preferences = [p.strip() for p in prefs_str.split(',') if p.strip()]
                except:
                    preferences = [prefs_str]
        # Fallback to diet_type if dietary_preferences is not available
        if not preferences and hasattr(user_obj, 'diet_type') and user_obj.diet_type:
            diet_type_str = str(user_obj.diet_type).strip()
            if diet_type_str and diet_type_str != 'None':
                preferences = [diet_type_str]
    except:
        pass
    return [p.lower() for p in preferences if p]

def _filter_foods_by_preferences(foods_df, preferences):
    """Filter foods based on user preferences."""
    if not preferences or foods_df.empty:
        return foods_df
    
    filtered_df = foods_df.copy()
    prefs_lower = [p.lower() for p in preferences]
    
    # Vegetarian/Plant-based: filter out meats and fish (but keep vegetable dishes)
    if 'vegetarian' in prefs_lower or 'plant-based' in prefs_lower or 'plant_based' in prefs_lower:
        # Filter out foods with meat/fish keywords, but keep vegetable dishes
        meat_keywords = ['pork', 'chicken', 'beef', 'lechon', 'sisig', 'tocino', 'longganisa', 'bangus', 'tilapia', 'galunggong', 'tuyo', 'tinapa', 'shrimp', 'crab', 'squid']
        # Don't filter if it's a vegetable dish (contains vegetable keywords)
        vegetable_keywords = ['sitaw', 'monggo', 'ampalaya', 'kangkong', 'pinakbet', 'laing', 'ginisang', 'vegetable']
        filtered_df = filtered_df[
            ~(
                filtered_df['Food Name'].astype(str).str.lower().str.contains('|'.join(meat_keywords), na=False) &
                ~filtered_df['Food Name'].astype(str).str.lower().str.contains('|'.join(vegetable_keywords), na=False)
            )
        ]
    
    # Protein lover: prioritize high protein foods
    if 'protein' in prefs_lower:
        # Keep all foods but we'll sort by protein later
        pass
    
    # Healthy: prioritize foods with good nutritional density
    if 'healthy' in prefs_lower:
        # Keep all foods but we'll prioritize later
        pass
    
    # Spicy: prioritize spicy foods
    if 'spicy' in prefs_lower:
        spicy_keywords = ['adobo', 'sinigang', 'bicol', 'spicy', 'hot', 'chili']
        # We'll boost these in scoring, not filter
        pass
    
    return filtered_df

def _filter_foods_by_goal(foods_df, goal):
    """Filter/prioritize foods based on user goal."""
    if not goal or foods_df.empty:
        return foods_df
    
    goal_lower = str(goal).lower()
    
    # For lose weight: prioritize lower calorie, high fiber foods
    if 'lose' in goal_lower or 'weight loss' in goal_lower:
        # Keep all but we'll sort by calories (lower first) and fiber (higher first)
        pass
    
    # For gain muscle: prioritize high protein foods
    if 'muscle' in goal_lower or 'gain' in goal_lower:
        # Keep all but we'll sort by protein (higher first)
        pass
    
    return foods_df

def _get_foods_from_csv(meal_type=None, user_preferences=None, user_goal=None, activity_level=None, limit=30):
    """
    Get foods from CSV (food_df) filtered by meal type, preferences, goal, and activity level.
    Returns a list of formatted strings for AI prompts.
    """
    try:
        global_food_df = globals().get('food_df', None)
        if global_food_df is None or not isinstance(global_food_df, pd.DataFrame) or global_food_df.empty:
            return []
        
        foods_df = global_food_df.copy()
        
        # Filter by meal type if provided (using Category column)
        if meal_type:
            meal_type_lower = str(meal_type).lower()
            # Map meal types to category keywords (enhanced with more Filipino food keywords)
            meal_keywords = {
                'breakfast': ['breakfast', 'cereal', 'bread', 'porridge', 'champorado', 'arroz caldo', 'goto', 'pandesal', 'tapsilog', 'tocino', 'longganisa'],
                'lunch': ['main dish', 'stew', 'soup', 'noodle', 'adobo', 'sinigang', 'kare-kare', 'caldereta', 'afritada'],
                'dinner': ['main dish', 'stew', 'soup', 'noodle', 'adobo', 'sinigang', 'kare-kare', 'caldereta', 'afritada'],
                'snack': ['snack', 'dessert', 'appetizer', 'street food', 'beverage', 'condiment', 'spread', 'sandwich', 
                         'puto', 'bibingka', 'halo-halo', 'leche flan', 'turon', 'kakanin', 'suman', 'biko', 'sapin-sapin', 
                         'maja blanca', 'buko pandan', 'cassava cake', 'ube halaya', 'polvoron', 'pastillas', 'yema', 
                         'chicharon', 'kropek', 'banana cue', 'camote cue', 'fishball', 'kikiam', 'squidball', 'tempura',
                         'lumpia', 'siomai', 'empanada', 'ensaymada', 'pan de sal', 'pandesal', 'hopia', 'monay'],
                'snacks': ['snack', 'dessert', 'appetizer', 'street food', 'beverage', 'condiment', 'spread', 'sandwich',
                         'puto', 'bibingka', 'halo-halo', 'leche flan', 'turon', 'kakanin', 'suman', 'biko', 'sapin-sapin',
                         'maja blanca', 'buko pandan', 'cassava cake', 'ube halaya', 'polvoron', 'pastillas', 'yema',
                         'chicharon', 'kropek', 'banana cue', 'camote cue', 'fishball', 'kikiam', 'squidball', 'tempura',
                         'lumpia', 'siomai', 'empanada', 'ensaymada', 'pan de sal', 'pandesal', 'hopia', 'monay'],  # Handle plural
            }
            keywords = meal_keywords.get(meal_type_lower, [])
            if keywords:
                # Filter by category containing any of the keywords
                category_filter = foods_df['Category'].astype(str).str.lower().str.contains('|'.join(keywords), na=False)
                # Also check food name for common meal type indicators
                name_filter = foods_df['Food Name'].astype(str).str.lower().str.contains('|'.join(keywords), na=False)
                foods_df = foods_df[category_filter | name_filter]
                # If no matches, don't filter (return all)
                if foods_df.empty:
                    foods_df = global_food_df.copy()
        
        # Filter by preferences
        if user_preferences:
            foods_df = _filter_foods_by_preferences(foods_df, user_preferences)
        
        # Filter by goal (affects sorting, not filtering)
        if user_goal:
            foods_df = _filter_foods_by_goal(foods_df, user_goal)
        
        # Clean food names and deduplicate
        foods_df['Cleaned Name'] = foods_df['Food Name'].apply(clean_food_name)
        foods_df = foods_df.drop_duplicates(subset=['Cleaned Name'], keep='first')
        
        # Sort based on goal and preferences
        if user_goal:
            goal_lower = str(user_goal).lower()
            if 'lose' in goal_lower or 'weight loss' in goal_lower:
                # Sort by calories (ascending) and fiber (descending)
                foods_df = foods_df.sort_values(
                    by=['Calories', 'Fiber (g)'],
                    ascending=[True, False],
                    na_position='last'
                )
            elif 'muscle' in goal_lower or 'gain' in goal_lower:
                # Sort by protein (descending)
                foods_df = foods_df.sort_values(
                    by='Protein (g)',
                    ascending=False,
                    na_position='last'
                )
        
        # Apply activity level adjustments (affects calorie range)
        if activity_level:
            activity_lower = str(activity_level).lower()
            if 'very active' in activity_lower:
                # Include higher calorie options
                pass  # No filtering, just include all
            elif 'sedentary' in activity_lower:
                # Prefer lower calorie options
                foods_df = foods_df[foods_df['Calories'] <= 300]
        
        # Limit results
        foods_df = foods_df.head(limit)
        
        # Format for AI prompt
        food_list = []
        for _, row in foods_df.iterrows():
            food_name = row['Cleaned Name']
            calories = float(row.get('Calories', 0) or 0)
            category = str(row.get('Category', '') or '')
            protein = float(row.get('Protein (g)', 0) or 0)
            
            food_list.append(
                f"{food_name} (~{calories:.0f} kcal per serving, category: {category}, protein: {protein:.1f}g)"
            )
        
        return food_list
    except Exception as e:
        print(f"[ERROR] _get_foods_from_csv failed: {e}")
        import traceback
        traceback.print_exc()
        return []

@app.route('/foods/search', methods=['GET'])
def search_foods():
    """
    Search foods using ONLY the local Filipino_Food_Nutrition_Dataset.csv (food_df).

    This endpoint intentionally does NOT call any external APIs. It returns
    foods whose 'Food Name' contains the query substring (case-insensitive),
    limited to the first 15 matches for performance and UX.
    
    Filters out "Var" variants, numbers, and special characters from food names.
    """
    query = request.args.get('query', '').strip().lower()
    print(f"[DEBUG] /foods/search called with query: '{query}'")
    if not query:
        return jsonify({'foods': []})

    try:
        matches = food_df[
            food_df['Food Name'].astype(str).str.lower().str.contains(query)
        ]
        print(f"[DEBUG] Found {len(matches)} matches for query '{query}'")
        foods_raw = matches.head(50).to_dict(orient='records')  # Get more to filter
        
        # Clean the data: replace NaN/None with 0 for numeric fields, empty string for text
        import math
        foods_temp = []
        seen_cleaned_names = set()
        
        for food in foods_raw:
            # First, check if this food name (after cleaning) is a duplicate
            original_name = food.get('Food Name', '')
            cleaned_name = clean_food_name(original_name)
            cleaned_name_lower = cleaned_name.lower().strip()
            
            # Skip if we've already seen this cleaned name
            if cleaned_name_lower in seen_cleaned_names:
                continue  # Skip this duplicate
            
            seen_cleaned_names.add(cleaned_name_lower)
            
            # Process the food item
            cleaned_food = {}
            for key, value in food.items():
                if key == 'Food Name':
                    cleaned_food[key] = cleaned_name
                elif pd.isna(value) or value is None:
                    # Use 0 for numeric columns, empty string for text
                    if any(num_col in key for num_col in ['Calories', 'Protein', 'Carbs', 'Fat', 'Fiber', 'Sodium', 'Calcium', 'Iron']):
                        cleaned_food[key] = 0.0
                    else:
                        cleaned_food[key] = ''
                elif isinstance(value, (int, float)) and (math.isnan(value) or math.isinf(value)):
                    cleaned_food[key] = 0.0
                else:
                    cleaned_food[key] = value
            
            foods_temp.append(cleaned_food)
            if len(foods_temp) >= 15:  # Limit to 15 unique results
                break
        
        foods = foods_temp
        print(f"[DEBUG] Returning {len(foods)} cleaned and deduplicated food items")
            
    except Exception as e:
        # Fail safely: if anything goes wrong with the DataFrame, return empty list
        print(f"[ERROR] /foods/search failed using local dataset: {e}")
        import traceback
        traceback.print_exc()
        foods = []

    return jsonify({'foods': foods})

@app.route('/foods/info', methods=['GET'])
def food_info():
    name = request.args.get('name', '').strip().lower()
    if not name:
        return jsonify({'error': 'No food name provided'}), 400
    match = food_df[food_df['Food Name'].str.lower() == name]
    if match.empty:
        return jsonify({'error': 'Food not found'}), 404
    return jsonify({'food': match.iloc[0].to_dict()})

# Removed duplicate /foods/recommend route - using the enhanced version at line 3015

# --- Enhanced Progress Endpoints ---
@app.route('/progress/weight')
def progress_weight():
    user = request.args.get('user')
    start_date = request.args.get('start')
    end_date = request.args.get('end')
    
    query = WeightLog.query.filter_by(user=user)
    
    if start_date:
        query = query.filter(WeightLog.date >= datetime.fromisoformat(start_date).date())
    if end_date:
        query = query.filter(WeightLog.date <= datetime.fromisoformat(end_date).date())
    
    # Select only needed columns to reduce overhead
    rows = (
        query.with_entities(WeightLog.date, WeightLog.weight)
        .order_by(WeightLog.date)
        .all()
    )
    return jsonify([
        {'date': d.isoformat(), 'weight': w}
        for d, w in rows
    ])

@app.route('/progress/calories')
def progress_calories():
    user = request.args.get('user')
    start_date = request.args.get('start')
    end_date = request.args.get('end')
    
    query = FoodLog.query.filter_by(user=user)
    
    if start_date:
        query = query.filter(FoodLog.date >= datetime.fromisoformat(start_date).date())
    if end_date:
        query = query.filter(FoodLog.date <= datetime.fromisoformat(end_date).date())
    
    rows = (
        query.with_entities(FoodLog.date, FoodLog.calories)
        .order_by(FoodLog.date)
        .all()
    )
    return jsonify([
        {'date': d.isoformat(), 'calories': c}
        for d, c in rows
    ])

@app.route('/progress/workouts')
def progress_workouts():
    try:
        user = request.args.get('user')
        start_date = request.args.get('start')
        end_date = request.args.get('end')
        
        print(f"[DEBUG] /progress/workouts called: user={user}, start={start_date}, end={end_date}")
        
        # Parse date filters using safe date parser (no timezone conversion)
        sd = parse_date_safe(start_date) if start_date else None
        ed = parse_date_safe(end_date) if end_date else None
        
        print(f"[DEBUG] Parsed dates: start={sd}, end={ed}")
        
        # Query WorkoutLog table
        workout_query = WorkoutLog.query.filter_by(user=user)
        
        if sd:
            workout_query = workout_query.filter(WorkoutLog.date >= sd)
        if ed:
            workout_query = workout_query.filter(WorkoutLog.date <= ed)
        
        workout_rows = (
            workout_query.with_entities(WorkoutLog.date, WorkoutLog.type, WorkoutLog.duration, WorkoutLog.calories_burned)
            .order_by(WorkoutLog.date)
            .all()
        )
        
        print(f"[DEBUG] WorkoutLog query: Found {len(workout_rows)} entries")
        
        # Also query ExerciseSession table - FIRST check without date filter
        all_exercise_sessions = ExerciseSession.query.filter_by(user=user).all()
        print(f"[DEBUG] ExerciseSession total for user '{user}': {len(all_exercise_sessions)} entries")
        
        if all_exercise_sessions:
            print(f"[DEBUG] Sample ExerciseSession dates: {[s.date for s in all_exercise_sessions[:3]]}")
        
        exercise_session_query = ExerciseSession.query.filter_by(user=user)
        
        if sd:
            # ExerciseSession.date is a Date column, so compare with date directly
            exercise_session_query = exercise_session_query.filter(ExerciseSession.date >= sd)
            print(f"[DEBUG] Applied start date filter: >= {sd}")
        if ed:
            # ExerciseSession.date is a Date column, so compare with date directly
            exercise_session_query = exercise_session_query.filter(ExerciseSession.date <= ed)
            print(f"[DEBUG] Applied end date filter: <= {ed}")
        
        exercise_session_rows = (
            exercise_session_query.with_entities(ExerciseSession.date, ExerciseSession.exercise_name, ExerciseSession.duration_seconds, ExerciseSession.calories_burned)
            .order_by(ExerciseSession.date)
            .all()
        )
        
        print(f"[DEBUG] ExerciseSession query after filters: Found {len(exercise_session_rows)} entries")
        
        if exercise_session_rows:
            print(f"[DEBUG] Sample filtered dates: {[r[0] for r in exercise_session_rows[:3]]}")
        
        # Combine results from both tables
        workouts = [
            {
                'date': d.isoformat(),
                'type': t,
                'duration': int(dur) if dur else 0,  # Ensure duration is an integer
                'calories_burned': float(cb) if cb else 0.0,
            }
            for d, t, dur, cb in workout_rows
        ] + [
            {
                'date': d.isoformat(),
                'type': name,  # exercise_name maps to type
                'duration': int(dur_sec / 60) if dur_sec else 0,  # Convert seconds to minutes
                'calories_burned': float(cb) if cb else 0.0,
            }
            for d, name, dur_sec, cb in exercise_session_rows
        ]
        
        print(f"[DEBUG] Returning {len(workouts)} total workouts")
        return jsonify(workouts)
        
    except Exception as e:
        print(f"[ERROR] Exception in /progress/workouts: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/progress/summary')
def progress_summary():
    user = request.args.get('user')
    start_date = request.args.get('start')
    end_date = request.args.get('end')
    
    # Build date filter
    date_filter = {}
    if start_date:
        date_filter['start'] = datetime.fromisoformat(start_date).date()
    if end_date:
        date_filter['end'] = datetime.fromisoformat(end_date).date()
    
    # Get latest weight
    weight_query = WeightLog.query.filter_by(user=user)
    if 'start' in date_filter:
        weight_query = weight_query.filter(WeightLog.date >= date_filter['start'])
    if 'end' in date_filter:
        weight_query = weight_query.filter(WeightLog.date <= date_filter['end'])
    
    latest_weight = weight_query.order_by(WeightLog.date.desc()).first()
    
    # Get total calories
    calories_query = db.session.query(db.func.sum(FoodLog.calories)).filter_by(user=user)
    if 'start' in date_filter:
        calories_query = calories_query.filter(FoodLog.date >= date_filter['start'])
    if 'end' in date_filter:
        calories_query = calories_query.filter(FoodLog.date <= date_filter['end'])
    
    total_calories = calories_query.scalar() or 0
    
    # Get WorkoutLog totals
    workout_query = WorkoutLog.query.filter_by(user=user)
    if 'start' in date_filter:
        workout_query = workout_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        workout_query = workout_query.filter(WorkoutLog.date <= date_filter['end'])
    
    workout_count = workout_query.count()
    
    workout_duration_query = db.session.query(db.func.sum(WorkoutLog.duration)).filter_by(user=user)
    if 'start' in date_filter:
        workout_duration_query = workout_duration_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        workout_duration_query = workout_duration_query.filter(WorkoutLog.date <= date_filter['end'])
    
    workout_duration = workout_duration_query.scalar() or 0
    
    workout_calories_query = db.session.query(db.func.sum(WorkoutLog.calories_burned)).filter_by(user=user)
    if 'start' in date_filter:
        workout_calories_query = workout_calories_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        workout_calories_query = workout_calories_query.filter(WorkoutLog.date <= date_filter['end'])
    
    workout_calories = workout_calories_query.scalar() or 0.0
    
    # Also get ExerciseSession totals
    exercise_session_query = ExerciseSession.query.filter_by(user=user)
    if 'start' in date_filter:
        exercise_session_query = exercise_session_query.filter(ExerciseSession.date >= date_filter['start'])
    if 'end' in date_filter:
        exercise_session_query = exercise_session_query.filter(ExerciseSession.date <= date_filter['end'])
    
    exercise_session_count = exercise_session_query.count()
    
    # Get ExerciseSession duration (in seconds, convert to minutes)
    exercise_duration_seconds_query = db.session.query(db.func.sum(ExerciseSession.duration_seconds)).filter_by(user=user)
    if 'start' in date_filter:
        exercise_duration_seconds_query = exercise_duration_seconds_query.filter(ExerciseSession.date >= date_filter['start'])
    if 'end' in date_filter:
        exercise_duration_seconds_query = exercise_duration_seconds_query.filter(ExerciseSession.date <= date_filter['end'])
    
    exercise_duration_seconds = exercise_duration_seconds_query.scalar() or 0
    exercise_duration_minutes = int(exercise_duration_seconds / 60)  # Convert to minutes
    
    # Get ExerciseSession calories
    exercise_calories_query = db.session.query(db.func.sum(ExerciseSession.calories_burned)).filter_by(user=user)
    if 'start' in date_filter:
        exercise_calories_query = exercise_calories_query.filter(ExerciseSession.date >= date_filter['start'])
    if 'end' in date_filter:
        exercise_calories_query = exercise_calories_query.filter(ExerciseSession.date <= date_filter['end'])
    
    exercise_calories = exercise_calories_query.scalar() or 0.0
    
    # Combine totals from both tables
    total_workouts = workout_count + exercise_session_count
    total_duration = workout_duration + exercise_duration_minutes
    total_calories_burned = workout_calories + exercise_calories
    
    return jsonify({
        'calories': total_calories,
        'weight': latest_weight.weight if latest_weight else None,
        'workouts': total_workouts,
        'total_duration': total_duration,
        'total_calories_burned': total_calories_burned,
    })

# New comprehensive progress endpoints
@app.route('/progress/daily-summary')
def progress_daily_summary():
    user = request.args.get('user')
    target_date = request.args.get('date')
    
    if target_date:
        date_obj = datetime.fromisoformat(target_date).date()
    else:
        date_obj = date.today()
    
    # Get daily data
    daily_calories = db.session.query(db.func.sum(FoodLog.calories)).filter_by(user=user, date=date_obj).scalar() or 0
    daily_workouts = WorkoutLog.query.filter_by(user=user, date=date_obj).all()
    daily_weight = WeightLog.query.filter_by(user=user, date=date_obj).first()
    
    # Get WorkoutLog totals
    workout_duration = sum(workout.duration for workout in daily_workouts) or 0
    workout_calories = sum(workout.calories_burned for workout in daily_workouts) or 0.0
    workout_sessions = len(daily_workouts)
    
    # Also get ExerciseSession data for the same date
    daily_exercise_sessions = ExerciseSession.query.filter_by(user=user, date=date_obj).all()
    
    # Calculate ExerciseSession totals
    exercise_duration_seconds = sum(session.duration_seconds for session in daily_exercise_sessions) or 0
    exercise_duration_minutes = int(exercise_duration_seconds / 60)  # Convert to minutes
    exercise_calories = sum(float(session.calories_burned or 0.0) for session in daily_exercise_sessions) or 0.0
    exercise_sessions = len(daily_exercise_sessions)
    
    # Combine totals from both tables
    total_duration = workout_duration + exercise_duration_minutes
    total_calories_burned = workout_calories + exercise_calories
    total_sessions = workout_sessions + exercise_sessions
    
    # Get user goals
    user_obj = User.query.filter_by(username=user).first()
    calorie_goal = _compute_daily_goal_for_user(user_obj) if user_obj else 2000
    
    return jsonify({
        'date': date_obj.isoformat(),
        'calories': {
            'current': daily_calories,
            'goal': calorie_goal,
            'remaining': max(0, calorie_goal - daily_calories + total_calories_burned),  # Include exercise in remaining
            'percentage': min(1.0, daily_calories / calorie_goal) if calorie_goal > 0 else 0
        },
        'weight': {
            'current': daily_weight.weight if daily_weight else None,
            'previous': None  # Would need to get previous day's weight
        },
        'exercise': {
            'duration': total_duration,
            'calories_burned': total_calories_burned,
            'sessions': total_sessions,
            'average_intensity': total_calories_burned / total_duration if total_duration > 0 else 0
        },
        'achievements': _get_daily_achievements(daily_calories, calorie_goal, total_duration, total_sessions),
        'recommendations': _get_daily_recommendations(daily_calories, calorie_goal, total_duration)
    })

@app.route('/progress/weekly-summary')
def progress_weekly_summary():
    user = request.args.get('user')
    week_start = request.args.get('week_start')
    
    if week_start:
        start_date = datetime.fromisoformat(week_start).date()
    else:
        # Get start of current week (Monday)
        today = date.today()
        start_date = today - timedelta(days=today.weekday())
    
    end_date = start_date + timedelta(days=6)
    
    # Get weekly aggregated data
    weekly_calories = db.session.query(db.func.sum(FoodLog.calories)).filter(
        FoodLog.user == user,
        FoodLog.date >= start_date,
        FoodLog.date <= end_date
    ).scalar() or 0
    
    # Get WorkoutLog data
    weekly_workouts = WorkoutLog.query.filter(
        WorkoutLog.user == user,
        WorkoutLog.date >= start_date,
        WorkoutLog.date <= end_date
    ).all()
    
    workout_duration = sum(workout.duration for workout in weekly_workouts) or 0
    workout_calories = sum(workout.calories_burned for workout in weekly_workouts) or 0.0
    workout_sessions = len(weekly_workouts)
    workout_dates = set(workout.date for workout in weekly_workouts)
    
    # Also get ExerciseSession data for the week
    weekly_exercise_sessions = ExerciseSession.query.filter(
        ExerciseSession.user == user,
        ExerciseSession.date >= start_date,
        ExerciseSession.date <= end_date
    ).all()
    
    # Calculate ExerciseSession totals
    exercise_duration_seconds = sum(session.duration_seconds for session in weekly_exercise_sessions) or 0
    exercise_duration_minutes = int(exercise_duration_seconds / 60)  # Convert to minutes
    exercise_calories = sum(float(session.calories_burned or 0.0) for session in weekly_exercise_sessions) or 0.0
    exercise_sessions = len(weekly_exercise_sessions)
    exercise_dates = set(session.date for session in weekly_exercise_sessions)
    
    # Combine totals from both tables
    total_duration = workout_duration + exercise_duration_minutes
    total_calories_burned = workout_calories + exercise_calories
    total_sessions = workout_sessions + exercise_sessions
    all_dates = workout_dates.union(exercise_dates)  # Combine date sets for consistency calculation
    
    # Get user goals
    user_obj = User.query.filter_by(username=user).first()
    daily_calorie_goal = _compute_daily_goal_for_user(user_obj) if user_obj else 2000
    weekly_calorie_goal = daily_calorie_goal * 7
    
    return jsonify({
        'week_start': start_date.isoformat(),
        'week_end': end_date.isoformat(),
        'calories': {
            'current': weekly_calories,
            'goal': weekly_calorie_goal,
            'remaining': max(0, weekly_calorie_goal - weekly_calories + total_calories_burned),  # Include exercise
            'percentage': min(1.0, weekly_calories / weekly_calorie_goal) if weekly_calorie_goal > 0 else 0,
            'daily_average': weekly_calories / 7
        },
        'exercise': {
            'total_duration': total_duration,
            'total_calories_burned': total_calories_burned,
            'sessions': total_sessions,
            'daily_average_duration': total_duration / 7,
            'consistency': len(all_dates) / 7
        },
        'achievements': _get_weekly_achievements(weekly_calories, weekly_calorie_goal, total_duration, total_sessions),
        'trends': _get_weekly_trends(user, start_date, end_date)
    })

@app.route('/progress/monthly-summary')
def progress_monthly_summary():
    user = request.args.get('user')
    month_start = request.args.get('month_start')
    
    if month_start:
        start_date = datetime.fromisoformat(month_start).date()
    else:
        # Get start of current month
        today = date.today()
        start_date = today.replace(day=1)
    
    # Get end of month
    if start_date.month == 12:
        end_date = start_date.replace(year=start_date.year + 1, month=1, day=1) - timedelta(days=1)
    else:
        end_date = start_date.replace(month=start_date.month + 1, day=1) - timedelta(days=1)
    
    # Get monthly aggregated data
    monthly_calories = db.session.query(db.func.sum(FoodLog.calories)).filter(
        FoodLog.user == user,
        FoodLog.date >= start_date,
        FoodLog.date <= end_date
    ).scalar() or 0
    
    # Get WorkoutLog data
    monthly_workouts = WorkoutLog.query.filter(
        WorkoutLog.user == user,
        WorkoutLog.date >= start_date,
        WorkoutLog.date <= end_date
    ).all()
    
    workout_duration = sum(workout.duration for workout in monthly_workouts) or 0
    workout_calories = sum(workout.calories_burned for workout in monthly_workouts) or 0.0
    workout_sessions = len(monthly_workouts)
    workout_dates = set(workout.date for workout in monthly_workouts)
    
    # Also get ExerciseSession data for the month
    monthly_exercise_sessions = ExerciseSession.query.filter(
        ExerciseSession.user == user,
        ExerciseSession.date >= start_date,
        ExerciseSession.date <= end_date
    ).all()
    
    # Calculate ExerciseSession totals
    exercise_duration_seconds = sum(session.duration_seconds for session in monthly_exercise_sessions) or 0
    exercise_duration_minutes = int(exercise_duration_seconds / 60)  # Convert to minutes
    exercise_calories = sum(float(session.calories_burned or 0.0) for session in monthly_exercise_sessions) or 0.0
    exercise_sessions = len(monthly_exercise_sessions)
    exercise_dates = set(session.date for session in monthly_exercise_sessions)
    
    # Combine totals from both tables
    total_duration = workout_duration + exercise_duration_minutes
    total_calories_burned = workout_calories + exercise_calories
    total_sessions = workout_sessions + exercise_sessions
    all_dates = workout_dates.union(exercise_dates)  # Combine date sets for consistency calculation
    
    # Get user goals
    user_obj = User.query.filter_by(username=user).first()
    daily_calorie_goal = _compute_daily_goal_for_user(user_obj) if user_obj else 2000
    monthly_calorie_goal = daily_calorie_goal * end_date.day
    
    return jsonify({
        'month_start': start_date.isoformat(),
        'month_end': end_date.isoformat(),
        'calories': {
            'current': monthly_calories,
            'goal': monthly_calorie_goal,
            'remaining': max(0, monthly_calorie_goal - monthly_calories + total_calories_burned),  # Include exercise
            'percentage': min(1.0, monthly_calories / monthly_calorie_goal) if monthly_calorie_goal > 0 else 0,
            'daily_average': monthly_calories / end_date.day
        },
        'exercise': {
            'total_duration': total_duration,
            'total_calories_burned': total_calories_burned,
            'sessions': total_sessions,
            'daily_average_duration': total_duration / end_date.day,
            'consistency': len(all_dates) / end_date.day
        },
        'achievements': _get_monthly_achievements(monthly_calories, monthly_calorie_goal, total_duration, total_sessions),
        'trends': _get_monthly_trends(user, start_date, end_date)
    })

@app.route('/progress/goals', methods=['GET', 'POST'])
def progress_goals():
    user = request.args.get('user') or request.json.get('user')
    
    if request.method == 'GET':
        # Get user goals - support both username and email
        user_obj = get_user_by_identifier(user)
        if not user_obj:
            return jsonify({'error': 'User not found'}), 404
        
        # Check if a specific date is requested (for historical goals)
        date_str = request.args.get('date')
        if date_str:
            try:
                target_date = datetime.fromisoformat(date_str).date()
                # Get historical goal for that date
                historical_goal = _get_goal_for_date(user, target_date)
                return jsonify({
                    'calories': historical_goal,
                    'steps': 10000,  # Default step goal
                    'water': 2000,   # Default water goal in ml
                    'exercise': 30,   # Default exercise goal in minutes
                    'sleep': 8,       # Default sleep goal in hours
                })
            except (ValueError, TypeError) as e:
                print(f"[WARNING] Invalid date format for goal history: {date_str}, using current goal")
                # Fall through to current goal
        
        # Return current goal
        return jsonify({
            'calories': _compute_daily_goal_for_user(user_obj),
            'steps': 10000,  # Default step goal
            'water': 2000,   # Default water goal in ml
            'exercise': 30,   # Default exercise goal in minutes
            'sleep': 8,       # Default sleep goal in hours
        })
    
    elif request.method == 'POST':
        # Update user goals
        goals = request.json.get('goals', {})
        
        # Update user profile with new goals - support both username and email
        user_obj = get_user_by_identifier(user)
        if not user_obj:
            return jsonify({'error': 'User not found'}), 404
        
        # Update activity level if provided
        if 'activity_level' in goals:
            user_obj.activity_level = goals['activity_level']
        
        # Update goal if provided
        if 'goal' in goals:
            user_obj.goal = goals['goal']
        
        db.session.commit()
        
        return jsonify({'success': True, 'message': 'Goals updated successfully'})

# Helper function to log goal changes
def _log_goal_change(user: str, new_goal: int, effective_date: date = None):
    """
    Log a goal change to the goal_history table.
    
    Args:
        user: Username
        new_goal: New daily calorie goal
        effective_date: Date when this goal becomes effective (defaults to today)
    """
    try:
        if effective_date is None:
            effective_date = date.today()
        
        # Check if a goal already exists for this date
        existing = GoalHistory.query.filter_by(
            user=user,
            date=effective_date
        ).first()
        
        if existing:
            # Update existing entry
            existing.daily_calorie_goal = new_goal
        else:
            # Create new entry
            goal_entry = GoalHistory(
                user=user,
                date=effective_date,
                daily_calorie_goal=new_goal
            )
            db.session.add(goal_entry)
        
        db.session.commit()
        print(f"[GOAL_HISTORY] Logged goal change for {user}: {new_goal} cal (effective {effective_date})")
    except Exception as e:
        print(f"[ERROR] Failed to log goal change: {e}")
        db.session.rollback()

# Helper function to get goal for a specific date
def _get_goal_for_date(user: str, target_date: date) -> int:
    """
    Get the daily calorie goal that was active on a specific date.
    
    Args:
        user: Username or email
        target_date: Date to get goal for
    
    Returns:
        Daily calorie goal for that date, or None if not found
    """
    try:
        # Get user object first (supports both username and email)
        user_obj = get_user_by_identifier(user)
        if not user_obj:
            return 2000  # Default fallback
        
        username = user_obj.username  # GoalHistory stores username, not email
        
        # Find the most recent goal entry on or before the target date
        goal_entry = GoalHistory.query.filter(
            GoalHistory.user == username,
            GoalHistory.date <= target_date
        ).order_by(GoalHistory.date.desc()).first()
        
        if goal_entry:
            return goal_entry.daily_calorie_goal
        
        # If no history found, get current goal from user table
        if user_obj.daily_calorie_goal:
            return user_obj.daily_calorie_goal
        
        # Default fallback
        return 2000
    except Exception as e:
        print(f"[ERROR] Failed to get goal for date: {e}")
        # Fallback to current goal
        try:
            user_obj = get_user_by_identifier(user)
            if user_obj and user_obj.daily_calorie_goal:
                return user_obj.daily_calorie_goal
        except Exception:
            pass
        return 2000

# Helper functions for progress calculations
def _get_daily_achievements(calories, goal, duration, sessions):
    achievements = []
    
    if calories >= goal:
        achievements.append('🎯 Daily calorie goal achieved!')
    if duration >= 30:
        achievements.append('💪 30+ minutes of exercise!')
    if sessions >= 2:
        achievements.append('🏋️ Multiple workout sessions!')
    
    return achievements

def _get_daily_recommendations(calories, goal, duration):
    recommendations = []
    
    if calories < goal * 0.5:
        recommendations.append('Consider adding a healthy snack to reach your calorie goal')
    if duration < 15:
        recommendations.append('Even 15 minutes of exercise can make a difference')
    
    return recommendations

def _get_weekly_achievements(calories, goal, duration, sessions):
    achievements = []
    
    if calories >= goal:
        achievements.append('🏆 Weekly calorie goal achieved!')
    if duration >= 150:  # 30 min * 5 days
        achievements.append('💪 Consistent exercise week!')
    if sessions >= 5:
        achievements.append('🔥 5+ workout sessions this week!')
    
    return achievements

def _get_weekly_trends(user, start_date, end_date):
    # Calculate trends for the week
    trends = {
        'calories_trend': 'stable',  # Would calculate actual trend
        'exercise_trend': 'stable',
        'consistency_score': 0.8
    }
    return trends

def _get_monthly_achievements(calories, goal, duration, sessions):
    achievements = []
    
    if calories >= goal:
        achievements.append('🏆 Monthly calorie goal achieved!')
    if duration >= 600:  # 30 min * 20 days
        achievements.append('💪 Excellent exercise consistency!')
    if sessions >= 20:
        achievements.append('🔥 20+ workout sessions this month!')
    
    return achievements

def _get_monthly_trends(user, start_date, end_date):
    # Calculate trends for the month
    trends = {
        'calories_trend': 'stable',  # Would calculate actual trend
        'exercise_trend': 'stable',
        'consistency_score': 0.8,
        'improvement_areas': ['hydration', 'sleep']
    }
    return trends


def _get_next_meal_type_by_time() -> str:
    """
    Determine the next meal type based on current time (Philippines timezone).
    Returns: 'breakfast', 'lunch', 'dinner', or 'snack'
    """
    try:
        ph_tz = get_philippines_timezone()
        now = datetime.now(ph_tz)
        hour = now.hour
    except Exception:
        # Fallback to UTC if timezone fails
        hour = datetime.now().hour
    
    if 5 <= hour < 11:
        return 'breakfast'
    elif 11 <= hour < 14:
        return 'lunch'
    elif 14 <= hour < 17:
        return 'snack'  # Afternoon snack
    elif 17 <= hour < 21:
        return 'dinner'
    else:
        return 'snack'  # Late night snack or early morning


def _filter_foods_by_meal_type(foods: list[dict], meal_type: str) -> list[dict]:
    """
    Filter Filipino foods by meal_category that matches the requested meal_type.
    If no exact match, returns all foods (fallback).
    
    Args:
        foods: List of food dicts with 'meal_category' or 'category' field
        meal_type: 'breakfast', 'lunch', 'dinner', or 'snack'
    
    Returns:
        Filtered list of foods
    """
    if not foods:
        return []
    
    # Map meal_type to possible category keywords
    meal_keywords = {
        'breakfast': ['breakfast', 'morning', 'almusal'],
        'lunch': ['lunch', 'tanghalian', 'ulam'],
        'dinner': ['dinner', 'hapunan', 'supper'],
        'snack': ['snack', 'merienda', 'meryenda'],
    }
    
    keywords = meal_keywords.get(meal_type.lower(), [])
    if not keywords:
        return foods  # Return all if unknown meal type
    
    filtered = []
    for food in foods:
        category = (
            food.get("meal_category") or 
            food.get("category") or 
            ""
        ).lower()
        
        # Check if category matches any keyword
        if any(kw in category for kw in keywords):
            filtered.append(food)
    
    # If no matches found, return first 20 foods as fallback
    # (better than returning nothing)
    return filtered if filtered else foods[:20]


def _get_todays_meal_summary(food_logs: list) -> dict:
    """
    Summarize what meals the user has already eaten today.
    
    Returns:
        Dict with meal_type -> list of food names
    """
    summary = {}
    for log in food_logs:
        meal_type = (log.meal_type or 'Other').lower()
        if meal_type not in summary:
            summary[meal_type] = []
        summary[meal_type].append(log.food_name)
    return summary


def _call_groq_chat(system_prompt: str, user_prompt: str, *, max_tokens: int = 400, temperature: float = 0.4) -> tuple[bool, str]:
    """
    Helper to call Groq's chat completion API with a system + user prompt.

    Returns (ok, content). If Groq is not configured or an error occurs,
    ok will be False and content will contain a human-readable message.
    
    Rate limit information is logged to console for monitoring.
    """
    if not GROQ_API_KEY:
        return False, "Groq API key (GROQ_API_KEY) is not configured on the server."

    try:
        payload = {
            "model": GROQ_MODEL,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        headers = {
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "Content-Type": "application/json",
        }
        resp = requests.post(GROQ_API_URL, json=payload, headers=headers, timeout=15)
        
        # Log rate limit information if available
        remaining_requests = resp.headers.get('x-ratelimit-remaining-requests')
        limit_requests = resp.headers.get('x-ratelimit-limit-requests')
        if remaining_requests is not None and limit_requests is not None:
            print(f"[Groq API] Rate limit: {remaining_requests}/{limit_requests} requests remaining")
        
        if resp.status_code != 200:
            if resp.status_code == 429:
                reset_time = resp.headers.get('x-ratelimit-reset-requests', 'N/A')
                return False, f"Groq API rate limit exceeded. Reset time: {reset_time}. Response: {resp.text}"
            return False, f"Groq API error {resp.status_code}: {resp.text}"
        data = resp.json()
        choices = data.get("choices") or []
        if not choices:
            return False, "Groq API returned no choices."
        content = choices[0].get("message", {}).get("content", "")
        if not isinstance(content, str):
            return False, "Groq API returned unexpected content format."
        return True, content.strip()
    except Exception as e:
        return False, f"Groq API request failed: {e}"


@app.route('/ai/summary/daily', methods=['POST'])
def ai_summary_daily():
    """
    AI-powered daily summary for the AI Coach.

    Request JSON:
      { "user": "<username-or-email>", "date": "YYYY-MM-DD" (optional) }
    """
    data = request.get_json(silent=True) or {}
    identifier = data.get('user') or data.get('username')
    target_date_str = data.get('date')

    if not identifier:
        return jsonify({'success': False, 'error': 'user is required'}), 400

    # Resolve user by username or email
    user_obj = User.query.filter(
        (User.username == identifier) | (User.email == identifier)
    ).first()
    if not user_obj:
        return jsonify({'success': False, 'error': 'User not found'}), 404

    # Determine target date (use Philippines date for consistency with logs)
    if target_date_str:
        try:
            target_date = datetime.fromisoformat(target_date_str).date()
        except Exception:
            target_date = get_philippines_date()
    else:
        target_date = get_philippines_date()

    # Aggregate today's food logs
    food_logs = FoodLog.query.filter_by(user=user_obj.username, date=target_date).all()
    total_calories = sum(float(log.calories or 0.0) for log in food_logs)
    total_protein = sum(float(log.protein or 0.0) for log in food_logs)
    total_carbs = sum(float(log.carbs or 0.0) for log in food_logs)
    total_fat = sum(float(log.fat or 0.0) for log in food_logs)
    total_fiber = sum(float(log.fiber or 0.0) for log in food_logs)

    # Get a few key foods with meal types
    top_foods = []
    for log in food_logs[:5]:
        top_foods.append({
            'food_name': log.food_name,
            'meal_type': log.meal_type,
            'calories': float(log.calories or 0.0),
        })
    
    # Get meal summary for context
    todays_meals = _get_todays_meal_summary(food_logs)
    meal_summary_text = ""
    if todays_meals:
        meal_parts = []
        for meal_type, foods in todays_meals.items():
            if foods:
                meal_parts.append(f"{meal_type}: {len(foods)} item(s)")
        if meal_parts:
            meal_summary_text = f"Meals logged today: {', '.join(meal_parts)}."
    
    # Determine what meal might be next
    next_meal_type = _get_next_meal_type_by_time()

    # Aggregate today's exercise (WorkoutLog + ExerciseSession)
    workouts = WorkoutLog.query.filter_by(user=user_obj.username, date=target_date).all()
    workout_duration = sum(float(w.duration or 0.0) for w in workouts)
    workout_calories = sum(float(w.calories_burned or 0.0) for w in workouts)

    sessions = ExerciseSession.query.filter_by(user=user_obj.username, date=target_date).all()
    session_duration_min = sum(float(s.duration_seconds or 0) for s in sessions) / 60.0
    session_calories = sum(float(s.calories_burned or 0.0) for s in sessions)

    total_exercise_minutes = workout_duration + session_duration_min
    total_exercise_calories = workout_calories + session_calories

    # Daily calorie goal – use the same helper as the progress endpoints
    # so the value matches the dashboard target shown in the app.
    daily_goal = _compute_daily_goal_for_user(user_obj)

    remaining = daily_goal - total_calories + total_exercise_calories

    system_prompt = (
        "You are a friendly, non-judgmental nutrition and exercise coach. "
        "You DO NOT provide medical advice or diagnose conditions. "
        "You must respond with STRICTLY VALID JSON using this exact schema:\n"
        "{\n"
        '  \"summaryText\": \"short overview in 2-4 sentences\",\n'
        '  \"tips\": [\"short actionable tip 1\", \"short actionable tip 2\"]\n'
        "}\n"
        "Do not include any extra text, backticks, or explanations outside this JSON."
    )

    # Get user's food preferences and onboarding data
    user_preferences = _parse_user_preferences(user_obj)
    user_goal = user_obj.goal
    user_activity_level = user_obj.activity_level
    
    # Get a shortlist of foods from CSV for meal suggestions
    csv_foods_shortlist = _get_foods_from_csv(
        meal_type=next_meal_type,
        user_preferences=user_preferences,
        user_goal=user_goal,
        activity_level=user_activity_level,
        limit=20
    )
    
    user_prompt_parts = [
        f"User profile: sex={user_obj.sex}, age={user_obj.age}, "
        f"height_cm={user_obj.height_cm}, weight_kg={user_obj.weight_kg}, "
        f"goal={user_obj.goal}, activity_level={user_activity_level}.",
    ]
    
    # Add food preferences if available
    if user_preferences:
        user_prompt_parts.append(f"User's food preferences: {', '.join(user_preferences)}.")
    
    user_prompt_parts.extend([
        f"Daily calorie goal: {daily_goal} kcal.",
        f"Today's date: {target_date.isoformat()}.",
        f"Food today: total_calories={total_calories:.1f}, "
        f"protein={total_protein:.1f}g, carbs={total_carbs:.1f}g, "
        f"fat={total_fat:.1f}g, fiber={total_fiber:.1f}g.",
        f"Exercise today: minutes={total_exercise_minutes:.1f}, "
        f"calories_burned={total_exercise_calories:.1f}.",
        f"Remaining calories (goal - food + exercise): {remaining:.1f}.",
    ])
    
    if meal_summary_text:
        user_prompt_parts.append(meal_summary_text)
    
    user_prompt_parts.append(f"Next likely meal type (based on time): {next_meal_type}.")
    user_prompt_parts.append(f"Top foods logged today (up to 5): {top_foods}.")
    
    # Add CSV foods list for meal suggestions
    if csv_foods_shortlist:
        user_prompt_parts.append(
            "IMPORTANT: If suggesting meals, you MUST ONLY suggest foods from this list (these are the ONLY foods available in the app):\n"
            + "\n".join(f"- {item}" for item in csv_foods_shortlist)
        )
    
    user_prompt_parts.append(
        "\nSummarize how today is going relative to the goal and provide 1-2 "
        "specific, kind suggestions the user can realistically follow today or tomorrow. "
        f"If suggesting meals, you MUST ONLY suggest foods from the list above. "
        f"Consider the user's preferences ({', '.join(user_preferences) if user_preferences else 'none'}), goal ({user_goal}), and activity level ({user_activity_level}). "
        "Consider what meal type is appropriate for the current time."
    )
    
    user_prompt = "\n".join(user_prompt_parts)

    ok, content = _call_groq_chat(system_prompt, user_prompt, max_tokens=450)

    summary_text = ""
    tips: list[str] = []

    if ok:
        try:
            parsed = json.loads(content)
            summary_text = str(parsed.get("summaryText") or "").strip()
            tips_raw = parsed.get("tips") or []
            if isinstance(tips_raw, list):
                tips = [str(t).strip() for t in tips_raw if str(t).strip()]
        except Exception:
            # Fallback: treat whole content as summary
            summary_text = content
            tips = []
    else:
        summary_text = (
            "AI summary is temporarily unavailable. "
            "You are using this app's built-in calorie and progress tracking as usual."
        )
        tips = [content]

    if not summary_text:
        summary_text = (
            "I couldn't generate a detailed summary, but keep logging your meals "
            "and I'll provide more insights soon."
        )

    return jsonify({
        'success': True,
        'user': user_obj.username,
        'date': target_date.isoformat(),
        'summaryText': summary_text,
        'tips': tips,
    })


@app.route('/ai/what-to-eat-next', methods=['POST'])
def ai_what_to_eat_next():
    """
    AI-powered next-meal suggestion for the AI Coach.

    Request JSON:
      {
        \"user\": \"<username-or-email>\",
        \"next_meal_type\": \"breakfast|lunch|snack|dinner\" (optional)
      }
    """
    data = request.get_json(silent=True) or {}
    identifier = data.get('user') or data.get('username')
    next_meal_type = (data.get('next_meal_type') or '').lower().strip()

    if not identifier:
      return jsonify({'success': False, 'error': 'user is required'}), 400

    # Resolve user
    user_obj = User.query.filter(
        (User.username == identifier) | (User.email == identifier)
    ).first()
    if not user_obj:
        return jsonify({'success': False, 'error': 'User not found'}), 404

    if not next_meal_type:
        # Infer meal type from current time (Philippines timezone)
        next_meal_type = _get_next_meal_type_by_time()

    # Use same aggregates as summary to give context
    target_date = get_philippines_date()
    food_logs = FoodLog.query.filter_by(user=user_obj.username, date=target_date).all()
    total_calories = sum(float(log.calories or 0.0) for log in food_logs)
    workouts = WorkoutLog.query.filter_by(user=user_obj.username, date=target_date).all()
    workout_calories = sum(float(w.calories_burned or 0.0) for w in workouts)
    sessions = ExerciseSession.query.filter_by(user=user_obj.username, date=target_date).all()
    session_calories = sum(float(s.calories_burned or 0.0) for s in sessions)
    total_exercise_calories = workout_calories + session_calories

    # Use the same helper as the progress endpoints so AI uses
    # the exact same target calories as the dashboard.
    daily_goal = _compute_daily_goal_for_user(user_obj)
    remaining = daily_goal - total_calories + total_exercise_calories

    # Get what meals user already ate today
    todays_meals = _get_todays_meal_summary(food_logs)
    already_eaten_text = ""
    if todays_meals:
        eaten_parts = []
        for meal_type, foods in todays_meals.items():
            if foods:
                eaten_parts.append(f"{meal_type}: {', '.join(foods[:3])}")
        if eaten_parts:
            already_eaten_text = f"Meals already eaten today: {'; '.join(eaten_parts)}."

    # Get user's food preferences and onboarding data
    user_preferences = _parse_user_preferences(user_obj)
    user_goal = user_obj.goal
    user_activity_level = user_obj.activity_level
    
    # Build a shortlist of Filipino foods from CSV ONLY, filtered by meal type, preferences, goal, and activity level
    filipino_shortlist = _get_foods_from_csv(
        meal_type=next_meal_type,
        user_preferences=user_preferences,
        user_goal=user_goal,
        activity_level=user_activity_level,
        limit=30
    )

    filipino_section = ""
    if filipino_shortlist:
        filipino_section = (
            "IMPORTANT: You MUST only suggest foods from this list (these are the ONLY foods available in the app):\n"
            + "\n".join(f"- {item}" for item in filipino_shortlist)
        )

    # Build a shortlist of the user's own custom meals (if any)
    custom_meals_descriptions: list[str] = []
    try:
        custom_recipes = (
            db.session.query(CustomRecipe)
            .filter(CustomRecipe.user == user_obj.username)
            .order_by(CustomRecipe.created_at.desc())
            .limit(8)
            .all()
        )
        for recipe in custom_recipes:
            total_cals = (
                db.session.query(func.sum(RecipeIngredient.calories))
                .filter(RecipeIngredient.recipe_id == recipe.id)
                .scalar()
                or 0.0
            )
            servings = recipe.servings or 1
            per_serving = total_cals / servings if servings > 0 else total_cals
            custom_meals_descriptions.append(
                f"{recipe.recipe_name} (~{per_serving:.0f} kcal per serving)"
            )
    except Exception:
        custom_meals_descriptions = []

    custom_section = ""
    if custom_meals_descriptions:
        custom_section = (
            "The user's own saved meals (prefer these when they fit the remaining calories and goal):\n"
            + "\n".join(f"- {item}" for item in custom_meals_descriptions)
        )

    system_prompt = (
        "You are a helpful nutrition coach focused on Filipino cuisine. "
        "You DO NOT provide medical advice or strict diets; just gentle, practical ideas.\n"
        f"IMPORTANT: The user is asking for suggestions for their NEXT meal, which is: {next_meal_type}.\n"
        f"Only suggest foods that are appropriate for {next_meal_type} (e.g., don't suggest breakfast foods for dinner).\n"
        "You MUST ONLY suggest foods from the provided Filipino foods list - these are the ONLY foods available in the app.\n"
        "Always prefer Filipino dishes and ingredients and the user's own saved meals when they fit.\n"
        "Respond with STRICTLY VALID JSON using this exact schema:\n"
        "{{\n"
        '  "headline": "short 1-sentence suggestion",\n'
        '  "suggestions": ["food idea 1", "food idea 2", "optional idea 3"],\n'
        '  "explanation": "2-4 sentence explanation in simple language"\n'
        "}}\n"
        "Do not include any text outside this JSON."
    )

    # Build user prompt with onboarding data
    user_prompt_parts = [
        f"User profile: sex={user_obj.sex}, age={user_obj.age}, goal={user_obj.goal}, activity_level={user_activity_level}.",
    ]
    
    # Add food preferences if available
    if user_preferences:
        user_prompt_parts.append(f"User's food preferences: {', '.join(user_preferences)}.")
    
    user_prompt_parts.extend([
        f"Today's date: {target_date.isoformat()}.",
        f"Daily calorie goal: {daily_goal} kcal.",
        f"Calories eaten so far: {total_calories:.1f} kcal.",
        f"Exercise calories today: {total_exercise_calories:.1f} kcal.",
        f"Estimated remaining calories for the day: {remaining:.1f} kcal.",
        f"Next meal type: {next_meal_type}.",
    ])
    
    if already_eaten_text:
        user_prompt_parts.append(already_eaten_text)

    if filipino_section:
        user_prompt_parts.append(filipino_section)
    if custom_section:
        user_prompt_parts.append(custom_section)

    user_prompt_parts.append(
        "When suggesting meals or snacks, you MUST ONLY pick from the Filipino foods shortlist provided above. "
        "These are the ONLY foods available in the app. When appropriate, also consider the user's own saved meals. "
        "If you mention a saved meal, say that it is from the user's own meals. "
        f"Prioritize foods that match the user's preferences ({', '.join(user_preferences) if user_preferences else 'none'}) and goal ({user_goal}). "
        "Focus on reasonable portion sizes and a balance of protein, vegetables, and carbs. "
        "If remaining calories are very low or negative, focus on light options or planning for tomorrow rather "
        "than restriction."
    )

    user_prompt = "\n".join(user_prompt_parts)

    ok, content = _call_groq_chat(system_prompt, user_prompt, max_tokens=450)

    headline = ""
    suggestions: list[str] = []
    explanation = ""

    if ok:
        try:
            parsed = json.loads(content)
            headline = str(parsed.get("headline") or "").strip()
            raw_suggestions = parsed.get("suggestions") or []
            if isinstance(raw_suggestions, list):
                suggestions = [str(s).strip() for s in raw_suggestions if str(s).strip()]
            explanation = str(parsed.get("explanation") or "").strip()
        except Exception:
            headline = "AI meal ideas"
            explanation = content
            suggestions = []
    else:
        headline = "AI meal ideas temporarily unavailable"
        explanation = content

    if not headline:
        headline = "Here are a few ideas for your next meal."

    return jsonify({
        'success': True,
        'user': user_obj.username,
        'next_meal_type': next_meal_type,
        'headline': headline,
        'suggestions': suggestions,
        'explanation': explanation,
    })


def _call_groq_chat_messages(messages: list[dict], *, max_tokens: int = 500, temperature: float = 0.7) -> tuple[bool, str]:
    """
    Helper to call Groq's chat completion API with a full conversation history.
    
    Args:
        messages: List of dicts with 'role' ('system', 'user', 'assistant') and 'content'.
        max_tokens: Maximum tokens in response.
        temperature: Sampling temperature (0.0-2.0).
    
    Returns:
        (ok, content). If ok is False, content contains an error message.
    
    Rate limit information is logged to console for monitoring.
    """
    if not GROQ_API_KEY:
        return False, "Groq API key (GROQ_API_KEY) is not configured on the server."

    try:
        payload = {
            "model": GROQ_MODEL,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": messages,
        }
        headers = {
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "Content-Type": "application/json",
        }
        resp = requests.post(GROQ_API_URL, json=payload, headers=headers, timeout=15)
        
        # Log rate limit information if available
        remaining_requests = resp.headers.get('x-ratelimit-remaining-requests')
        limit_requests = resp.headers.get('x-ratelimit-limit-requests')
        if remaining_requests is not None and limit_requests is not None:
            print(f"[Groq API] Rate limit: {remaining_requests}/{limit_requests} requests remaining")
        
        if resp.status_code != 200:
            if resp.status_code == 429:
                reset_time = resp.headers.get('x-ratelimit-reset-requests', 'N/A')
                return False, f"Groq API rate limit exceeded. Reset time: {reset_time}. Response: {resp.text}"
            return False, f"Groq API error {resp.status_code}: {resp.text}"
        data = resp.json()
        choices = data.get("choices") or []
        if not choices:
            return False, "Groq API returned no choices."
        content = choices[0].get("message", {}).get("content", "")
        if not isinstance(content, str):
            return False, "Groq API returned unexpected content format."
        return True, content.strip()
    except Exception as e:
        return False, f"Groq API request failed: {e}"


@app.route('/ai/coach/chat', methods=['POST'])
def ai_coach_chat():
    """
    AI-powered conversational chat with the AI Coach.
    
    Request JSON:
      {
        "user": "<username-or-email>",
        "messages": [
          {"role": "user", "content": "Why am I not losing weight?"},
          {"role": "assistant", "content": "..."},
          {"role": "user", "content": "What should I change?"}
        ]
      }
    
    Response JSON:
      {
        "success": true,
        "reply": "AI coach answer...",
        "used_context": {
          "date": "2025-11-14",
          "daily_goal": 2279,
          "calories_today": 1200,
          "exercise_minutes": 30
        }
      }
    """
    data = request.get_json(silent=True) or {}
    identifier = data.get('user') or data.get('username')
    conversation_messages = data.get('messages', [])

    if not identifier:
        return jsonify({'success': False, 'error': 'user is required'}), 400

    # Resolve user
    user_obj = User.query.filter(
        (User.username == identifier) | (User.email == identifier)
    ).first()
    if not user_obj:
        return jsonify({'success': False, 'error': 'User not found'}), 404

    # Validate messages format
    if not isinstance(conversation_messages, list):
        return jsonify({'success': False, 'error': 'messages must be a list'}), 400
    
    # Limit conversation history to last 10 messages to avoid token limits
    recent_messages = conversation_messages[-10:] if len(conversation_messages) > 10 else conversation_messages

    # Gather user context (today's data)
    target_date = get_philippines_date()
    food_logs = FoodLog.query.filter_by(user=user_obj.username, date=target_date).all()
    total_calories = sum(float(log.calories or 0.0) for log in food_logs)
    total_protein = sum(float(log.protein or 0.0) for log in food_logs)
    total_carbs = sum(float(log.carbs or 0.0) for log in food_logs)
    total_fat = sum(float(log.fat or 0.0) for log in food_logs)

    workouts = WorkoutLog.query.filter_by(user=user_obj.username, date=target_date).all()
    workout_duration = sum(float(w.duration or 0.0) for w in workouts)
    workout_calories = sum(float(w.calories_burned or 0.0) for w in workouts)
    sessions = ExerciseSession.query.filter_by(user=user_obj.username, date=target_date).all()
    session_duration_min = sum(float(s.duration_seconds or 0) for s in sessions) / 60.0
    session_calories = sum(float(s.calories_burned or 0.0) for s in sessions)
    total_exercise_minutes = workout_duration + session_duration_min
    total_exercise_calories = workout_calories + session_calories

    daily_goal = _compute_daily_goal_for_user(user_obj)
    remaining = daily_goal - total_calories + total_exercise_calories

    # Get recent week's progress for context
    week_start = target_date - timedelta(days=6)
    week_food_logs = FoodLog.query.filter(
        FoodLog.user == user_obj.username,
        FoodLog.date >= week_start,
        FoodLog.date <= target_date
    ).all()
    week_calories = sum(float(log.calories or 0.0) for log in week_food_logs)
    week_avg_calories = week_calories / 7.0 if week_calories > 0 else 0.0

    # Get what meals user already ate today
    todays_meals = _get_todays_meal_summary(food_logs)
    meal_summary_text = ""
    if todays_meals:
        meal_parts = []
        for meal_type, foods in todays_meals.items():
            if foods:
                meal_parts.append(f"{meal_type}: {', '.join(foods[:2])}")
        if meal_parts:
            meal_summary_text = f"Meals already eaten today: {'; '.join(meal_parts)}."
    
    # Determine next meal type
    next_meal_type = _get_next_meal_type_by_time()
    
    # Get user's custom meals for context
    custom_recipes = CustomRecipe.query.filter_by(user=user_obj.username).limit(5).all()
    custom_meals_list = []
    for recipe in custom_recipes:
        ingredients = RecipeIngredient.query.filter_by(recipe_id=recipe.id).all()
        total_recipe_calories = sum(float(ing.calories or 0.0) for ing in ingredients)
        if total_recipe_calories > 0:
            custom_meals_list.append(f"{recipe.recipe_name} (~{int(total_recipe_calories)} kcal per serving)")

    # Build system prompt with context
    system_prompt = (
        "You are a friendly, encouraging Filipino nutrition and exercise coach for a mobile app. "
        "You help users understand their progress, make better food choices, and stay motivated.\n\n"
        "IMPORTANT RULES:\n"
        "- You DO NOT provide medical advice, diagnoses, or treatment recommendations.\n"
        "- If asked about medical conditions, weight loss medications, or serious health concerns, "
        "politely suggest consulting a doctor or registered dietitian.\n"
        "- Only answer questions about nutrition, exercise, habits, and how to use this app.\n"
        "- If asked about unrelated topics, politely redirect to nutrition/exercise questions.\n"
        "- Prefer Filipino dishes and ingredients (sinigang, tinola, monggo, saba, malunggay, pinakbet, etc.).\n"
        "- When suggesting meals, consider the appropriate meal type for the current time.\n"
        "- Keep answers concise (3-6 sentences) and encouraging.\n"
        "- Use the user's actual data (calories, goals, progress) when relevant.\n\n"
        "APP FEATURES YOU SHOULD KNOW ABOUT:\n"
        "- Progress Screen: Users can view their progress in the 'Progress' tab (bottom navigation). "
        "This screen shows Daily, Weekly, Monthly, and Custom date range views.\n"
        "- Custom Date Range: Users can select any date range in the past to view historical data. "
        "In the Progress screen, select 'Custom' and use the date picker to choose start and end dates. "
        "This allows users to track back and see their progress for any period.\n"
        "- Historical Data Viewing: Users can view past dates, trends, and historical performance. "
        "The Progress screen displays bar graphs showing calories, exercise, and other metrics over time.\n"
        "- Weight Tracking: The app tracks weight data. Users can view their weight progress in the Progress screen. "
        "The Weight metric shows current weight, average weight, and goal weight.\n"
        "- Streak Tracking: The app tracks streaks for calories and exercise. Users can see their current streaks "
        "in the Progress screen (visible in Daily view). This shows how many consecutive days they've met their goals.\n"
        "- STREAK LOGIC: A streak continues when the user meets OR exceeds their daily calorie goal. "
        "Meeting the goal (calories >= goal) counts as a successful day. Exceeding the goal (calories > goal) "
        "also counts as a successful day and does NOT break the streak. The streak only breaks if the user "
        "does NOT meet their goal (calories < goal) on a given day. Always explain this correctly to users.\n"
        "- Multiple Metrics: The Progress screen allows users to switch between different metrics: "
        "Calories (default), Exercise (minutes), and Weight (kg). Each metric shows relevant data and progress.\n"
        "- Bar Graphs: Historical data is visualized using bar graphs in the Progress screen. "
        "These graphs show trends over Daily (7 days), Weekly (4 weeks), Monthly (12 months), or Custom date ranges.\n"
        "- Historical Goals: Users' calorie goals can change over time. When viewing historical data, "
        "the app shows the goal that was active during that period, not just the current goal.\n\n"
        "FEATURE GUIDANCE:\n"
        "- If users ask about past performance, historical data, or trends, guide them to the Progress screen. "
        "Explain they can use the 'Custom' option to select any date range they want to review.\n"
        "- If users want to see how they did last week, last month, or any specific period, tell them to go to "
        "Progress > Custom > Select Date Range, then choose their desired dates.\n"
        "- If users ask about weight progress, mention the Weight metric in the Progress screen.\n"
        "- If users want motivation, reference their streaks (if available) and encourage them to maintain them.\n"
        "- If users want to see exercise trends, guide them to Progress screen and suggest switching to the Exercise metric.\n"
        "- Always be helpful in guiding users to discover and use these features to better understand their progress.\n\n"
        "CALORIE CALCULATION EXPLANATION:\n"
        "- When users ask about remaining calories or how exercise affects their calorie budget, "
        "explain the net calories concept clearly:\n"
        "- Formula: Remaining = Target - Food Consumed + Exercise Burned\n"
        "- Exercise burns calories, so it increases the remaining calories (you can eat more).\n"
        "- This is because your body needs fuel to recover from exercise.\n"
        "- Example: If target is 2277, food is 2277, and exercise is 2277, then remaining = 2277 - 2277 + 2277 = 2277 calories.\n"
        "- Always explain this in a friendly, encouraging way that helps users understand why they can eat more after exercising.\n\n"
        "User's current context:\n"
        f"- Daily calorie goal: {daily_goal} kcal\n"
        f"- Calories consumed today: {total_calories:.1f} kcal\n"
        f"- Calories burned from exercise today: {total_exercise_calories:.1f} kcal\n"
        f"- Remaining calories: {remaining:.1f} kcal\n"
        f"- Macros today: Protein {total_protein:.1f}g, Carbs {total_carbs:.1f}g, Fat {total_fat:.1f}g\n"
        f"- Exercise today: {total_exercise_minutes:.1f} minutes\n"
        f"- Weekly average calories (last 7 days): {week_avg_calories:.1f} kcal/day\n"
    )
    
    if meal_summary_text:
        system_prompt += f"- {meal_summary_text}\n"
    
    system_prompt += f"- Next likely meal type (based on current time): {next_meal_type}\n"
    
    if custom_meals_list:
        system_prompt += f"- User's saved meals: {', '.join(custom_meals_list)}\n"
    
    system_prompt += (
        "\nAnswer the user's question based on this context. Be helpful, specific, and encouraging. "
        "If mentioning foods, prefer Filipino options or the user's saved meals when appropriate."
    )

    # Build messages array: system prompt + conversation history
    groq_messages = [{"role": "system", "content": system_prompt}]
    
    # Add conversation history (validate roles)
    for msg in recent_messages:
        role = msg.get('role', '').lower()
        content = msg.get('content', '')
        if role in ['user', 'assistant'] and content:
            groq_messages.append({"role": role, "content": str(content)})

    # Call Groq
    ok, reply = _call_groq_chat_messages(groq_messages, max_tokens=500, temperature=0.7)

    if not ok:
        reply = (
            "I'm having trouble connecting to the AI Coach right now. "
            "Please check your internet connection or try again later."
        )

    return jsonify({
        'success': True,
        'reply': reply,
        'used_context': {
            'date': target_date.isoformat(),
            'daily_goal': daily_goal,
            'calories_today': round(total_calories, 1),
            'exercise_minutes': round(total_exercise_minutes, 1),
            'remaining_calories': round(remaining, 1),
        }
    })


def calculate_streak(user):
    today = date.today()
    streak = 0
    # Check if the user has any workout logs at all
    has_any_logs = WorkoutLog.query.filter_by(user=user).count() > 0
    if not has_any_logs:
        return 0
    for i in range(7):
        day = today - timedelta(days=i)
        if WorkoutLog.query.filter_by(user=user, date=day).count() > 0:
            streak += 1
        else:
            break
    return streak

@app.route('/progress/achievements')
def progress_achievements():
    user = request.args.get('user')
    streak = calculate_streak(user)
    percent = streak / 7.0 if streak > 0 else 0.0
    return jsonify([
        {'label': '7-day streak', 'percent': percent},
        # Add more achievements as needed
    ])

# --- Remaining Calories Endpoint ---
def _compute_daily_goal_for_user(user_obj: User) -> int:
    try:
        # Calculate BMR using Mifflin-St Jeor Equation
        if (user_obj.sex or '').lower() == 'female':
            bmr = 10 * user_obj.weight_kg + 6.25 * user_obj.height_cm - 5 * user_obj.age - 161
        else:
            bmr = 10 * user_obj.weight_kg + 6.25 * user_obj.height_cm - 5 * user_obj.age + 5

        activity_multipliers = {
            'sedentary': 1.2,
            'lightly active': 1.375,
            'lightly_active': 1.375,
            'active': 1.55,
            'moderately active': 1.55,
            'moderately_active': 1.55,
            'very active': 1.725,
            'very_active': 1.725
        }
        multiplier = activity_multipliers.get((user_obj.activity_level or '').lower(), 1.55)
        tdee = bmr * multiplier

        # Goal adjustments
        goal = (user_obj.goal or '').lower()
        if goal == 'lose weight':
            tdee -= 300
        elif goal == 'gain muscle':
            tdee += 200
        elif goal == 'gain weight':
            tdee += 300
        elif goal == 'body recomposition':
            tdee -= 100
        elif goal == 'athletic performance':
            tdee += 150
        return int(round(tdee))
    except Exception as e:
        # Do not fallback to arbitrary defaults; surface the error to caller
        raise e

@app.route('/remaining', methods=['GET'])
def remaining_calories():
    """Return remaining calories for a given user and date.

    Query params: user, date (YYYY-MM-DD)
    Response: { daily_calorie_goal, food_totals, exercise_totals, remaining }
    remaining = goal - food + exercise
    """
    try:
        user = request.args.get('user')
        if not user:
            return jsonify({'error': 'user is required'}), 400

        date_str = request.args.get('date', datetime.utcnow().strftime('%Y-%m-%d'))
        try:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400

        # Load user and goal
        user_obj = User.query.filter_by(username=user).first()
        if user_obj:
            # Recompute with unified helper for consistency
            daily_goal = compute_daily_calorie_goal(
                sex=user_obj.sex,
                age=int(user_obj.age),
                weight_kg=float(user_obj.weight_kg),
                height_cm=float(user_obj.height_cm),
                activity_level=str(user_obj.activity_level),
                goal=str(user_obj.goal),
            )
        else:
            return jsonify({'success': False, 'message': 'User not found'}), 200

        # Food totals for the day
        day_food_logs = FoodLog.query.filter_by(user=user, date=target_date).all()
        food_totals = {
            'calories': float(sum(l.calories for l in day_food_logs)),
            'protein': float(sum(l.protein for l in day_food_logs)),
            'carbs': float(sum(l.carbs for l in day_food_logs)),
            'fat': float(sum(l.fat for l in day_food_logs)),
            'fiber': float(sum(l.fiber for l in day_food_logs)),
            'sodium': float(sum(l.sodium for l in day_food_logs)),
        }

        # Exercise totals: merge ExerciseSession and ExerciseLog, with simple de-dup per day
        sessions = ExerciseSession.query.filter_by(user=user, date=target_date).all()
        old_logs = ExerciseLog.query.filter_by(user=user, date=target_date).all()

        seen = set()
        total_exercise_cal = 0.0

        for s in sessions:
            key = (s.exercise_id, s.exercise_name, int(s.duration_seconds or 0), round(float(s.calories_burned or 0.0), 2), target_date)
            if key in seen:
                continue
            seen.add(key)
            total_exercise_cal += float(s.calories_burned or 0.0)

        for e in old_logs:
            key = ('legacy', e.exercise, 0, round(float(e.calories or 0.0), 2), target_date)
            if key in seen:
                continue
            seen.add(key)
            total_exercise_cal += float(e.calories or 0.0)

        exercise_totals = {
            'calories': round(total_exercise_cal, 1)
        }

        remaining = round(float(daily_goal) - food_totals['calories'] + exercise_totals['calories'], 1)

        return jsonify({
            'success': True,
            'daily_calorie_goal': int(daily_goal),
            'food_totals': food_totals,
            'exercise_totals': exercise_totals,
            'remaining': remaining,
            'date': target_date.isoformat(),
            'user': user
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/log/custom-meal', methods=['POST'])
def log_custom_meal():
    """Log a custom meal (single food item) to the food log.
    
    Request body:
    {
        "user": "username",
        "meal_name": "Custom Food Name",
        "calories": 250.0,
        "carbs": 30.0,
        "fat": 15.0,
        "description": "Optional description",
        "meal_type": "Lunch",
        "date": "2024-01-15"  # Optional, defaults to today
    }
    
    Response: { "success": true, "id": 123 }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'JSON data required'}), 400
        
        # Required fields
        user = data.get('user')
        meal_name = data.get('meal_name')
        calories = data.get('calories')
        
        if not user or not meal_name or calories is None:
            return jsonify({'error': 'user, meal_name, and calories are required'}), 400
        
        # Optional fields with defaults
        carbs = data.get('carbs', 0.0)
        fat = data.get('fat', 0.0)
        description = data.get('description', '')
        meal_type = data.get('meal_type', 'Other')
        date_str = data.get('date')
        
        # Parse date
        if date_str:
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        else:
            target_date = date.today()
        
        # Validate numeric values
        try:
            calories = float(calories)
            carbs = float(carbs)
            fat = float(fat)
        except (ValueError, TypeError):
            return jsonify({'error': 'calories, carbs, and fat must be valid numbers'}), 400
        
        if calories < 0 or carbs < 0 or fat < 0:
            return jsonify({'error': 'calories, carbs, and fat must be non-negative'}), 400
        
        if calories > 2500:
            return jsonify({'error': 'calories cannot exceed 2500 per meal'}), 400
        
        # Create food log entry
        food_log = FoodLog(
            user=user,
            food_name=meal_name,
            calories=calories,
            carbs=carbs,
            fat=fat,
            protein=0.0,  # Not provided in custom meals
            fiber=0.0,    # Not provided in custom meals
            sodium=0.0,    # Not provided in custom meals
            meal_type=meal_type,
            serving_size='custom',
            quantity=1.0,
            date=target_date
        )
        
        db.session.add(food_log)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'id': food_log.id,
            'message': 'Custom meal logged successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/custom-meals', methods=['GET'])
def get_custom_meals():
    """Get recent custom meals for a user.
    
    Query params: user, limit (optional, default 20)
    Response: { "success": true, "custom_meals": [...] }
    """
    try:
        user = request.args.get('user')
        if not user:
            return jsonify({'error': 'user is required'}), 400
        
        limit = int(request.args.get('limit', 20))
        if limit > 100:
            limit = 100
        
        # Get recent custom meals (foods with serving_size='custom')
        custom_meals = db.session.query(FoodLog).filter(
            FoodLog.user == user,
            FoodLog.serving_size == 'custom'
        ).order_by(FoodLog.date.desc(), FoodLog.id.desc()).limit(limit).all()
        
        # Convert to list of dictionaries
        meals_list = []
        for meal in custom_meals:
            meals_list.append({
                'id': meal.id,
                'name': meal.food_name,
                'calories': meal.calories,
                'carbs': meal.carbs,
                'fat': meal.fat,
                'meal_type': meal.meal_type,
                'date': meal.date.isoformat(),
                'description': getattr(meal, 'description', '')  # In case we add this field later
            })
        
        return jsonify({
            'success': True,
            'custom_meals': meals_list
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recommendations/meals', methods=['POST'])
def recommendations_meals():
    """Return a gender-aware daily meal plan using onboarding + model for gaps.

    Body may contain either:
      { "user": "username" }
    or a full profile payload:
      {
        "sex": "male|female", "age": 25, "height_cm": 170, "weight_kg": 65,
        "activity_level": "active", "goal": "maintain",
        "foodPreferences": ["vegetarian"], "allergies": ["peanut"],
        "medical_history": ["hypertension"]
      }
    """
    try:
        data = request.get_json(silent=True) or {}
        username = data.get('user') or data.get('username')

        profile = {
            'sex': (data.get('sex') or '').strip(),
            'age': data.get('age'),
            'height_cm': data.get('height_cm'),
            'weight_kg': data.get('weight_kg'),
            'activity_level': data.get('activity_level'),
            'goal': data.get('goal'),
        }

        # If username provided, fetch from DB when fields are missing
        if username:
            user_obj = User.query.filter_by(username=username).first()
            if user_obj:
                profile['sex'] = profile['sex'] or (user_obj.sex or '')
                profile['age'] = profile['age'] or int(user_obj.age)
                profile['height_cm'] = profile['height_cm'] or float(user_obj.height_cm)
                profile['weight_kg'] = profile['weight_kg'] or float(user_obj.weight_kg)
                profile['activity_level'] = profile['activity_level'] or (user_obj.activity_level or '')
                profile['goal'] = profile['goal'] or (user_obj.goal or '')

        # Validate required fields
        missing = [k for k in ['sex','age','height_cm','weight_kg','activity_level','goal'] if not profile.get(k)]
        if missing:
            return jsonify({'error': f"Missing fields: {', '.join(missing)}"}), 400

        preferences = data.get('foodPreferences') or data.get('preferences') or []
        allergies = data.get('allergies') or []
        medical_history = data.get('medical_history') or []

        rec = nutrition_model.recommend_meals(
            user_gender=profile['sex'],
            user_age=int(profile['age']),
            user_weight=float(profile['weight_kg']),
            user_height=float(profile['height_cm']),
            user_activity_level=str(profile['activity_level']),
            user_goal=str(profile['goal']),
            dietary_preferences=preferences,
            medical_history=medical_history,
        )

        # Remove items that match allergies or hard dislikes
        if allergies:
            for section in ['breakfast','lunch','dinner','snacks']:
                foods = rec.get('meal_plan',{}).get(section,{}).get('foods',[])
                filtered = [f for f in foods if all(a.lower() not in f.lower() for a in allergies)]
                if 'meal_plan' in rec and section in rec['meal_plan']:
                    rec['meal_plan'][section]['foods'] = filtered

        return jsonify({'success': True, 'username': username, 'profile': profile, 'recommendations': rec}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recommendations/foods/search', methods=['POST'])
def recommendations_food_search():
    """Rank foods for a query using user onboarding and the model for missing calories.

    Body: { "query": "adobo", profile... }
    """
    try:
        data = request.get_json(silent=True) or {}
        query = (data.get('query') or '').strip()
        if not query:
            return jsonify({'error': 'query is required'}), 400

        profile = {
            'sex': (data.get('sex') or '').strip(),
            'age': data.get('age'),
            'height_cm': data.get('height_cm'),
            'weight_kg': data.get('weight_kg'),
            'activity_level': data.get('activity_level'),
            'goal': data.get('goal'),
        }
        username = data.get('user') or data.get('username')
        if username:
            user_obj = User.query.filter_by(username=username).first()
            if user_obj:
                profile['sex'] = profile['sex'] or (user_obj.sex or '')
                profile['age'] = profile['age'] or int(user_obj.age)
                profile['height_cm'] = profile['height_cm'] or float(user_obj.height_cm)
                profile['weight_kg'] = profile['weight_kg'] or float(user_obj.weight_kg)
                profile['activity_level'] = profile['activity_level'] or (user_obj.activity_level or '')
                profile['goal'] = profile['goal'] or (user_obj.goal or '')

        missing = [k for k in ['sex','age','height_cm','weight_kg','activity_level','goal'] if not profile.get(k)]
        if missing:
            return jsonify({'error': f"Missing fields: {', '.join(missing)}"}), 400

        # Search candidates
        candidates = nutrition_model.search_filipino_foods(query)
        # Fallback: if no match in expanded DB, try legacy names using simple echo
        if not candidates:
            candidates = [{ 'name_english': query, 'meal_category': '', 'calories_per_100g': None }]

        daily = nutrition_model._calculate_daily_needs(
            profile['sex'], int(profile['age']), float(profile['weight_kg']), float(profile['height_cm']), str(profile['activity_level'])
        )
        per_meal_target = {
            'breakfast': daily['calories'] * 0.25,
            'lunch': daily['calories'] * 0.35,
            'dinner': daily['calories'] * 0.30,
            'snacks': daily['calories'] * 0.10,
        }

        results = []
        for c in candidates:
            name = c.get('name_english') or c.get('name') or query
            # Predict nutrition for a default serving size of 100g (can be adjusted client-side)
            pred = nutrition_model.predict_nutrition(
                food_name=name,
                serving_size=100,
                user_gender=profile['sex'],
                user_age=int(profile['age']),
                user_weight=float(profile['weight_kg']),
                user_height=float(profile['height_cm']),
                user_activity_level=str(profile['activity_level']),
                user_goal=str(profile['goal']),
            )

            cal = float(pred.get('nutrition_info',{}).get('calories', pred.get('calories', 0)))
            # Score: closeness to any per-meal target plus gender/goal alignment signals
            target_diff = min(abs(cal - t) for t in per_meal_target.values())
            goal_score = pred.get('goal_recommendations',{}).get('goal_alignment_score', 0)
            gender_score = pred.get('gender_insights',{}).get('gender_specific_score', 0)
            score = max(0.0, 100 - (target_diff / 10)) + goal_score * 10 + gender_score * 10

            results.append({
                'name': name,
                'calories_100g': cal,
                'score': round(score, 2),
                'insights': pred.get('gender_insights',{}).get('insights', []),
                'method': pred.get('method', 'mixed')
            })

        results.sort(key=lambda x: x['score'], reverse=True)
        return jsonify({'success': True, 'results': results, 'daily_needs': daily}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def _apply_preference_filtering(foods_list, active_filters, food_df=None):
    """
    Apply intelligent filtering when multiple preferences are selected.
    
    Strategy:
    - Plant-Based: Hard exclusion (remove meats, dairy if selected)
    - Other filters: Scoring system (foods matching more filters score higher)
    - If no filters: Return all foods
    """
    if not active_filters:
        return foods_list
    
    # Normalize filters
    filters_lower = [f.lower().strip() for f in active_filters]
    
    # Hard exclusions for plant_based
    plant_based = 'plant_based' in filters_lower or 'plant-based' in filters_lower
    
    filtered = []
    
    def _infer_category_from_name(food_name):
        """Infer food category from name (fallback when not in database)"""
        name_lower = food_name.lower()
        if any(kw in name_lower for kw in ['chicken', 'pork', 'beef', 'fish', 'meat', 'egg']):
            return 'meats'
        elif any(kw in name_lower for kw in ['rice', 'noodles', 'bread']):
            return 'staple'
        elif any(kw in name_lower for kw in ['mango', 'banana', 'apple', 'papaya', 'fruit']):
            return 'fruits'
        elif any(kw in name_lower for kw in ['vegetable', 'salad', 'ampalaya', 'malunggay']):
            return 'vegetables'
        else:
            return ''
    
    for food_name in foods_list:
        if not food_name:
            continue
            
        # Normalize food name
        food_name_normalized = str(food_name).lower().replace('_', ' ').replace('-', ' ').strip()
        
        # Try to get food data from food_df if available
        food_category = ''
        if food_df is not None and hasattr(food_df, 'copy'):
            try:
                food_df_normalized = food_df.copy()
                food_df_normalized['_normalized_name'] = (
                    food_df_normalized['Food Name']
                    .astype(str)
                    .str.lower()
                    .str.replace('_', ' ', regex=False)
                    .str.replace('-', ' ', regex=False)
                    .str.strip()
                )
                food_match = food_df_normalized[
                    food_df_normalized['_normalized_name'] == food_name_normalized
                ]
                if not food_match.empty:
                    food_category = str(food_match.iloc[0].get('Category', '')).lower()
            except Exception:
                pass
        
        # Fallback: use name-based heuristics
        if not food_category:
            food_category = _infer_category_from_name(food_name_normalized)
        
        # Hard exclusion: Plant-based
        if plant_based:
            meat_keywords = ['chicken', 'pork', 'beef', 'fish', 'meat', 'egg', 'seafood', 'adobo', 'sinigang']
            if any(kw in food_name_normalized for kw in meat_keywords) or food_category == 'meats':
                continue
        
        # Calculate match score for other filters
        match_score = 0
        matched_filters = []
        
        # Healthy filter
        if 'healthy' in filters_lower:
            if food_category in ['vegetables', 'fruits', 'grains'] or \
               'salad' in food_name_normalized or 'vegetable' in food_name_normalized:
                match_score += 2
                matched_filters.append('healthy')
        
        # Comfort food filter
        if 'comfort' in filters_lower:
            comfort_keywords = ['rice', 'noodles', 'soup', 'stew', 'adobo', 'sinigang', 'tinola']
            if any(kw in food_name_normalized for kw in comfort_keywords):
                match_score += 2
                matched_filters.append('comfort')
        
        # Spicy filter
        if 'spicy' in filters_lower:
            spicy_keywords = ['spicy', 'sili', 'chili', 'curry', 'sinigang', 'ginataang', 'bicol']
            if any(kw in food_name_normalized for kw in spicy_keywords):
                match_score += 2
                matched_filters.append('spicy')
        
        # Sweet filter
        if 'sweet' in filters_lower:
            sweet_keywords = ['sweet', 'cake', 'dessert', 'mango', 'banana', 'sugar', 'papaya']
            if food_category == 'fruits' or any(kw in food_name_normalized for kw in sweet_keywords):
                match_score += 2
                matched_filters.append('sweet')
        
        # Protein filter
        if 'protein' in filters_lower:
            protein_keywords = ['chicken', 'pork', 'beef', 'egg', 'tofu', 'fish', 'meat']
            if food_category in ['meats', 'protein'] or \
               any(kw in food_name_normalized for kw in protein_keywords):
                match_score += 2
                matched_filters.append('protein')
        
        # Only include foods that match at least one filter (or all if user wants strict AND)
        # Strategy: If multiple filters selected, require at least 50% match
        non_plant_filters = [f for f in filters_lower if f not in ['plant_based', 'plant-based']]
        
        if non_plant_filters:
            min_matches_required = max(1, len(non_plant_filters) // 2)  # At least 50% match
            if match_score < min_matches_required:
                continue
        
        filtered.append(food_name)
    
    return filtered

@app.route('/foods/recommend')
def foods_recommend():
    """Endpoint for the Flutter UI to fetch recommended foods based on user profile.
    
    NO MEAL TYPE FILTERING - Recommendations are based on user profile:
    - Gender (sex-specific nutritional needs)
    - Age (age-appropriate recommendations)
    - BMI (calculated from weight/height)
    - Goal (lose weight, gain muscle, maintain, etc.)
    - Activity level (sedentary, moderate, active, very active)
    - Dietary preferences (from onboarding)
    - Medical history (allergies, conditions)

    Query params: 
        - user: username (required)
        - meal_type: (optional, ignored - kept for backward compatibility)
        - filters: comma-separated list (e.g., "healthy,spicy,protein")
    Returns: { recommended: [ { name, calories, ... } ] } - up to 25 recommendations
    """
    try:
        username = request.args.get('user')
        meal_type = (request.args.get('meal_type') or 'breakfast').lower()
        
        # Parse active filters from query params (real-time selections)
        filters_param = request.args.get('filters', '')
        active_filters = []
        if filters_param:
            active_filters = [f.strip().lower() for f in filters_param.split(',') if f.strip()]
        
        if not username:
            return jsonify({'recommended': []}), 200

        user_obj = User.query.filter_by(username=username).first()
        if not user_obj:
            return jsonify({'recommended': []}), 200

        # Parse user preferences
        def parse_list(val):
            if not val or val == '[]':
                return []
            try:
                return eval(val) if val.startswith('[') else val.split(',')
            except:
                return []
        
        # Only parse grid-based food preferences (6 options from onboarding)
        saved_preferences = parse_list(getattr(user_obj, 'dietary_preferences', None) or 
                                       getattr(user_obj, 'diet_type', None) or [])
        medical_history = parse_list(getattr(user_obj, 'medical_history', None) or [])
        
        # Always combine active_filters + saved_preferences for comprehensive scoring
        # Active filters take precedence (70% weight), but saved preferences still considered (30% weight)
        all_preferences = []
        if active_filters:
            all_preferences.extend(active_filters)
        if saved_preferences:
            # Add saved preferences that aren't already in active filters
            for pref in saved_preferences:
                if pref.lower() not in [f.lower() for f in active_filters]:
                    all_preferences.append(pref)
        
        print(f'DEBUG: [Food Recommendations] Active filters: {active_filters}')
        print(f'DEBUG: [Food Recommendations] Saved preferences: {saved_preferences}')
        print(f'DEBUG: [Food Recommendations] Combined preferences: {all_preferences}')
        print(f'DEBUG: [Food Recommendations] User goal: {user_obj.goal}')
        print(f'DEBUG: [Food Recommendations] Activity level: {user_obj.activity_level}')

        # REMOVED: Meal type filtering - now using ALL foods from database
        # Score ALL foods based on user profile (gender, age, BMI, goal, activity level, preferences)
        
        foods_to_score = []
        try:
            global_food_df = globals().get('food_df', None)
            if global_food_df is not None and isinstance(global_food_df, pd.DataFrame) and not global_food_df.empty:
                # Use ALL foods from database - no meal type filtering
                all_food_names = global_food_df['Food Name'].astype(str).dropna().unique().tolist()
                
                # Use all foods for scoring (or sample up to 100 for performance if database is huge)
                if len(all_food_names) > 100:
                    # Sample 100 foods randomly for scoring (still gives good variety)
                    foods_to_score = random.sample(all_food_names, 100)
                    print(f'DEBUG: [Food Recommendations] Using {len(foods_to_score)} randomly sampled foods from {len(all_food_names)} total foods (no meal type filtering)')
                else:
                    # Use all foods if database is smaller
                    foods_to_score = all_food_names
                    print(f'DEBUG: [Food Recommendations] Using ALL {len(foods_to_score)} foods from database (no meal type filtering)')
            else:
                # Fallback: Get recommendations from nutrition model if food_df not available
                rec = nutrition_model.recommend_meals(
                    user_gender=user_obj.sex or 'male',
                    user_age=int(user_obj.age),
                    user_weight=float(user_obj.weight_kg),
                    user_height=float(user_obj.height_cm),
                    user_activity_level=str(user_obj.activity_level),
                    user_goal=str(user_obj.goal),
                    dietary_preferences=all_preferences,
                    medical_history=medical_history
                )
                # Combine foods from all meal types
                all_meal_foods = []
                for meal in ['breakfast', 'lunch', 'dinner', 'snacks']:
                    meal_foods = rec.get('meal_plan', {}).get(meal, {}).get('foods', [])
                    all_meal_foods.extend(meal_foods)
                foods_to_score = list(set(all_meal_foods))  # Remove duplicates
                print(f'DEBUG: [Food Recommendations] Using {len(foods_to_score)} foods from nutrition model (fallback)')
        except Exception as e:
            # Final fallback: empty list
            foods_to_score = []
            print(f'DEBUG: [Food Recommendations] Error accessing database: {e}, using empty list')
        
        # Apply hard filtering for active filters (if any)
        if active_filters:
            try:
                filter_food_df = globals().get('food_df', None)
            except:
                filter_food_df = None
            foods_to_score = _apply_preference_filtering(
                foods_to_score, 
                active_filters, 
                filter_food_df
            )
        
        foods = foods_to_score

        # Derive daily calorie needs (used for scoring, not filtering)
        daily = nutrition_model._calculate_daily_needs(
            user_obj.sex or 'male', int(user_obj.age), float(user_obj.weight_kg), float(user_obj.height_cm), str(user_obj.activity_level)
        )
        
        # Use average meal target for scoring (since we're not filtering by meal type)
        # This allows foods from all categories to be scored fairly
        avg_meal_target = daily['calories'] * 0.30  # Average of breakfast/lunch/dinner (25%, 35%, 30%)
        per_meal_target = avg_meal_target

        remaining_cals = request.args.get('remaining_calories', type=float)
        if remaining_cals is not None:
            per_meal_target = min(per_meal_target, remaining_cals)

        scored = []
        seen_foods = set()  # Track foods we've already scored to prevent duplicates
        
        def normalize_food_name(food_name):
            """Normalize food name for duplicate detection: lowercase, replace underscores with spaces, strip"""
            if not food_name:
                return ''
            # Convert to lowercase, replace underscores/hyphens with spaces, strip whitespace
            normalized = str(food_name).lower().replace('_', ' ').replace('-', ' ').strip()
            # Remove extra spaces
            normalized = ' '.join(normalized.split())
            return normalized
        
        for name in foods:
            # Normalize food name for duplicate checking
            name_normalized = normalize_food_name(name)
            
            # Skip if empty or we've already processed this food
            if not name_normalized or name_normalized in seen_foods:
                continue
            
            # Mark as seen
            seen_foods.add(name_normalized)
            # Try to get nutrition from food_df first (more accurate)
            # Normalize food_df names for better matching (handle underscores, hyphens, spaces)
            food_match = pd.DataFrame()  # Initialize as empty
            try:
                # Use global food_df variable (loaded at startup from CSV)
                # Access it via globals() to avoid issues with local variable shadowing
                global_food_df = globals().get('food_df', None)
                if global_food_df is not None and isinstance(global_food_df, pd.DataFrame) and not global_food_df.empty:
                    food_df_normalized = global_food_df.copy()
                    food_df_normalized['_normalized_name'] = (
                        food_df_normalized['Food Name']
                        .astype(str)
                        .str.lower()
                        .str.replace('_', ' ', regex=False)
                        .str.replace('-', ' ', regex=False)
                        .str.strip()
                    )
                    # Replace multiple spaces with single space
                    food_df_normalized['_normalized_name'] = food_df_normalized['_normalized_name'].str.replace(r'\s+', ' ', regex=True)
                    
                    # Match using normalized names
                    food_match = food_df_normalized[food_df_normalized['_normalized_name'] == name_normalized]
            except Exception as e:
                # If food_df access fails, use empty DataFrame and fall back to prediction
                print(f'Warning: Could not access food_df: {e}')
                food_match = pd.DataFrame()
            cal = 0.0
            protein = 0.0
            carbs = 0.0
            fat = 0.0
            fiber = 0.0
            sodium = 0.0
            category = ''
            serving_size = '100g'
            
            if not food_match.empty:
                row = food_match.iloc[0]
                # Use the original Food Name from database (preserve exact formatting)
                actual_food_name = str(row.get('Food Name', name)).strip()
                # If we found a match, use the database name and update normalization
                actual_normalized = normalize_food_name(actual_food_name)
                # If the database name normalizes differently, update seen_foods
                if actual_normalized != name_normalized:
                    seen_foods.discard(name_normalized)  # Remove old normalization
                    seen_foods.add(actual_normalized)     # Add new normalization
                    name_normalized = actual_normalized
                name = actual_food_name
                cal = float(row.get('Calories', 0))
                protein = float(row.get('Protein (g)', 0))
                carbs = float(row.get('Carbs (g)', 0))
                fat = float(row.get('Fat (g)', 0))
                fiber = float(row.get('Fiber (g)', 0))
                sodium = float(row.get('Sodium (mg)', 0))
                category = str(row.get('Category', ''))
                serving_size = str(row.get('Serving Size', '100g'))
            else:
                # Fallback to prediction model
                try:
                    pn = nutrition_model.predict_nutrition(
                        food_name=name,
                        serving_size=100,
                        user_gender=user_obj.sex or 'male',
                        user_age=int(user_obj.age),
                        user_weight=float(user_obj.weight_kg),
                        user_height=float(user_obj.height_cm),
                        user_activity_level=str(user_obj.activity_level),
                        user_goal=str(user_obj.goal),
                    )
                    info = pn.get('nutrition_info', {})
                    cal = float(info.get('calories', pn.get('calories', 0)))
                    protein = float(info.get('protein', 0))
                    carbs = float(info.get('carbs', 0))
                    fat = float(info.get('fat', 0))
                    fiber = float(info.get('fiber', 0))
                    sodium = float(info.get('sodium', 0))
                except Exception:
                    pass

            # Calculate scoring
            try:
                iron = 0.0
                calcium = 0.0
                # Try to get iron and calcium for scoring (from prediction if available)
                if food_match.empty:
                    try:
                        pn = nutrition_model.predict_nutrition(
                            food_name=name,
                            serving_size=100,
                            user_gender=user_obj.sex or 'male',
                            user_age=int(user_obj.age),
                            user_weight=float(user_obj.weight_kg),
                            user_height=float(user_obj.height_cm),
                            user_activity_level=str(user_obj.activity_level),
                            user_goal=str(user_obj.goal),
                        )
                        info = pn.get('nutrition_info', {})
                        iron = float(info.get('iron', 0))
                        calcium = float(info.get('calcium', 0))
                    except:
                        pass

                # ===== ENHANCED SCORING SYSTEM =====
                # Base score: How well food fits meal calorie target (30% weight)
                target_diff = abs(cal - per_meal_target)
                base_score = max(0.0, 100 - (target_diff / 10))
                
                # Goal-based scoring (30% weight)
                goal_score = 0.0
                goal_lower = (user_obj.goal or '').lower()
                
                if 'lose' in goal_lower or 'weight loss' in goal_lower:
                    # Weight Loss: Boost low-calorie, high-fiber, high-protein foods
                    # Formula: (fiber * 2) + (protein * 1.5) - (calories / 10)
                    goal_score = (fiber * 2.0) + (protein * 1.5) - (cal / 10.0)
                    # Additional boost for low-calorie, nutrient-dense foods
                    if cal < 200 and (fiber > 3 or protein > 8):
                        goal_score += 20.0
                    # Penalize very high-calorie foods
                    if cal > 400:
                        goal_score -= 30.0
                elif 'muscle' in goal_lower or 'gain' in goal_lower:
                    # Muscle Gain: Boost high-protein, moderate-high calorie foods
                    # Formula: (protein * 3) + (calories / 5)
                    goal_score = (protein * 3.0) + (cal / 5.0)
                    # Additional boost for very high protein
                    if protein > 20:
                        goal_score += 25.0
                    # Penalize very low protein or very low calories
                    if protein < 5:
                        goal_score -= 20.0
                    if cal < 100:
                        goal_score -= 15.0
                elif 'maintain' in goal_lower:
                    # Maintain Weight: Boost balanced macros, moderate calories
                    # Calculate balanced macro score
                    macro_balance = 0.0
                    if cal > 0:
                        # Ideal ratios: 30% protein, 40% carbs, 30% fat (roughly)
                        protein_ratio = (protein * 4) / cal
                        carbs_ratio = (carbs * 4) / cal
                        fat_ratio = (fat * 9) / cal
                        # Score based on how balanced macros are
                        macro_balance = 100 - abs(protein_ratio - 0.3) * 100 - abs(carbs_ratio - 0.4) * 100 - abs(fat_ratio - 0.3) * 100
                        macro_balance = max(0.0, macro_balance)
                    
                    # Boost foods near calorie target
                    target_alignment = 1.0 - (abs(cal - per_meal_target) / per_meal_target) if per_meal_target > 0 else 0.0
                    target_alignment = max(0.0, target_alignment)
                    
                    goal_score = (macro_balance * 0.5) + (target_alignment * 50.0)
                    # Penalize extreme values
                    if cal > 500 or cal < 50:
                        goal_score -= 20.0
                else:
                    # Default/unknown goal: Balanced approach
                    goal_score = 50.0
                
                # Normalize goal_score to 0-100 range for consistent weighting
                goal_score = max(0.0, min(100.0, goal_score))
                
                # Activity level consideration (10% weight)
                activity_score = 0.0
                activity_lower = (user_obj.activity_level or '').lower()
                
                if 'very active' in activity_lower or 'very_active' in activity_lower:
                    # Very Active: Allow higher calorie foods, prioritize protein
                    if cal > 200:
                        activity_score += 15.0
                    if protein > 15:
                        activity_score += 20.0
                    activity_score += 10.0  # Base boost for active users
                elif 'active' in activity_lower:
                    # Active: Balanced approach
                    if 150 <= cal <= 350:
                        activity_score += 15.0
                    if protein > 10:
                        activity_score += 10.0
                    activity_score += 5.0  # Small base boost
                elif 'moderate' in activity_lower:
                    # Moderate: Slightly lower calories
                    if 100 <= cal <= 300:
                        activity_score += 15.0
                    if cal > 400:
                        activity_score -= 10.0
                elif 'sedentary' in activity_lower:
                    # Sedentary: Prioritize lower calorie, nutrient-dense foods
                    if cal < 250:
                        activity_score += 20.0
                    if cal > 350:
                        activity_score -= 15.0
                    if fiber > 3 or protein > 8:
                        activity_score += 15.0
                
                # Normalize activity_score to 0-100 range
                activity_score = max(0.0, min(100.0, activity_score))
                
                # Sex-based scoring (kept for compatibility, but lower weight)
                sex_score = 0.0
                if (user_obj.sex or '').lower() == 'female':
                    sex_score += iron * 0.8 + calcium * 0.2
                else:
                    sex_score += protein * 0.5
                sex_score = max(0.0, min(100.0, sex_score))

                # Preference-based scoring (20% weight)
                # Score based on how well food matches preferences
                preference_score = 0.0
                prefs_lower = [p.lower() for p in all_preferences]
                food_name_lower = name.lower()
                category_lower = category.lower() if category else ''
                
                # Separate active filters from saved preferences for weighted scoring
                active_filters_lower = [f.lower() for f in active_filters]
                saved_prefs_lower = [p.lower() for p in saved_preferences if p.lower() not in active_filters_lower]
                
                # Calculate preference match score (active filters weighted 70%, saved 30%)
                active_preference_score = 0.0
                saved_preference_score = 0.0
                
                # Plant-based preference: Boost plant foods, penalize meats
                if 'plant_based' in prefs_lower or 'plant-based' in prefs_lower:
                    if category_lower in ['vegetables', 'fruits', 'grains', 'legumes']:
                        boost = 25.0
                        if 'plant_based' in active_filters_lower or 'plant-based' in active_filters_lower:
                            active_preference_score += boost
                        else:
                            saved_preference_score += boost * 0.3  # Saved preference gets 30% weight
                    elif category_lower == 'meats':
                        penalty = -50.0
                        if 'plant_based' in active_filters_lower or 'plant-based' in active_filters_lower:
                            active_preference_score += penalty
                        else:
                            saved_preference_score += penalty * 0.3
                
                # Protein lover preference: Boost high-protein foods
                if 'protein' in prefs_lower:
                    if protein > 15:
                        boost = protein * 2.5 + 30.0
                    elif protein > 8:
                        boost = protein * 1.5 + 20.0
                    elif protein > 5:
                        boost = protein * 0.8 + 10.0
                    else:
                        boost = 0.0
                    
                    if 'protein' in active_filters_lower:
                        active_preference_score += boost
                    else:
                        saved_preference_score += boost * 0.3
                
                # Healthy preference: Boost nutritious, lower-calorie foods, penalize unhealthy options
                if 'healthy' in prefs_lower:
                    healthy_boost = 0.0
                    # Calculate nutritional density (nutrients per calorie)
                    nutrition_density = 0.0
                    if cal > 0:
                        # Weighted nutritional score per calorie
                        nutrition_density = (
                            (protein * 4) +  # Protein is important
                            (fiber * 8) +     # Fiber is very important for health
                            (iron * 0.5) +
                            (calcium * 0.1) +
                            (min(carbs * 0.5, 20))  # Some carbs are good, but not excessive
                        ) / max(cal, 1)
                    
                    # Strong boost for high nutritional density foods
                    if nutrition_density > 0.5:
                        healthy_boost += 30.0
                    elif nutrition_density > 0.3:
                        healthy_boost += 20.0
                    elif nutrition_density > 0.15:
                        healthy_boost += 10.0
                    
                    # Boost for whole grains and natural foods
                    if 'brown' in food_name_lower or 'whole grain' in food_name_lower:
                        healthy_boost += 15.0
                    
                    # Boost for fruits and vegetables
                    if category_lower in ['fruits', 'vegetables']:
                        healthy_boost += 25.0
                    elif 'fruit' in food_name_lower or 'vegetable' in food_name_lower:
                        healthy_boost += 20.0
                    
                    # Boost for lean proteins
                    if protein > 10 and fat < 10 and category_lower != 'meats':
                        healthy_boost += 15.0
                    
                    # STRONG PENALTIES for unhealthy foods
                    # Penalize fried foods heavily
                    if 'fried' in food_name_lower or 'deep fried' in food_name_lower:
                        healthy_boost -= 40.0  # Strong penalty
                    
                    # Penalize refined grains (white rice, white bread)
                    if 'white_rice' in food_name_lower or ('white rice' in food_name_lower and 'brown' not in food_name_lower):
                        healthy_boost -= 25.0  # Prefer brown rice
                    
                    if 'white bread' in food_name_lower or 'white_bread' in food_name_lower:
                        healthy_boost -= 20.0
                    
                    # Penalize high-calorie, low-nutrition foods
                    if cal > 300 and nutrition_density < 0.1:
                        healthy_boost -= 20.0
                    
                    # Penalize high-fat, high-calorie foods
                    if fat > 20 and cal > 250:
                        healthy_boost -= 15.0
                    
                    # Small boost for moderate calories with good nutrition
                    if 100 <= cal <= 200 and (fiber > 3 or protein > 8):
                        healthy_boost += 10.0
                    
                    # Apply weighted scoring
                    if 'healthy' in active_filters_lower:
                        active_preference_score += healthy_boost
                    else:
                        saved_preference_score += healthy_boost * 0.3
                
                # Comfort food preference: No specific boost (all foods considered)
                # This is more about emotional satisfaction than nutrition scoring
                
                # Spicy preference: Boost foods with spicy indicators in name
                if 'spicy' in prefs_lower:
                    spicy_keywords = ['spicy', 'hot', 'chili', 'sili', 'sili', 'adobo', 'sinigang', 'bicol']
                    if any(keyword in food_name_lower for keyword in spicy_keywords):
                        boost = 15.0
                        if 'spicy' in active_filters_lower:
                            active_preference_score += boost
                        else:
                            saved_preference_score += boost * 0.3
                
                # Sweet tooth preference: Boost sweet foods
                if 'sweet' in prefs_lower:
                    sweet_keywords = ['sweet', 'cake', 'dessert', 'candy', 'fruit', 'mango', 'banana', 'papaya']
                    if any(keyword in food_name_lower for keyword in sweet_keywords):
                        boost = 15.0
                        if 'sweet' in active_filters_lower:
                            active_preference_score += boost
                        else:
                            saved_preference_score += boost * 0.3
                
                # Comfort food preference: Boost comfort foods
                if 'comfort' in prefs_lower:
                    comfort_keywords = ['rice', 'noodles', 'soup', 'stew', 'adobo', 'sinigang', 'tinola']
                    if any(keyword in food_name_lower for keyword in comfort_keywords):
                        boost = 15.0
                        if 'comfort' in active_filters_lower:
                            active_preference_score += boost
                        else:
                            saved_preference_score += boost * 0.3
                
                # Combine active and saved preference scores (70% active, 30% saved)
                preference_score = (active_preference_score * 0.7) + (saved_preference_score * 0.3)
                
                # Normalize preference_score to 0-100 range
                preference_score = max(0.0, min(100.0, preference_score))
                
                # Meal type match score (10% weight) - boost foods that match meal type
                meal_type_score = 0.0
                meal_type_lower = meal_type.lower()
                meal_keywords = {
                    'breakfast': ['breakfast', 'cereal', 'bread', 'porridge', 'champorado', 'arroz caldo', 'goto', 'pandesal', 'tapsilog', 'tocino', 'longganisa'],
                    'lunch': ['main dish', 'stew', 'soup', 'noodle', 'adobo', 'sinigang', 'kare-kare', 'caldereta', 'afritada'],
                    'dinner': ['main dish', 'stew', 'soup', 'noodle', 'adobo', 'sinigang', 'kare-kare', 'caldereta', 'afritada'],
                    'snack': ['snack', 'dessert', 'bread', 'puto', 'bibingka', 'halo-halo', 'leche flan', 'turon'],
                    'snacks': ['snack', 'dessert', 'bread', 'puto', 'bibingka', 'halo-halo', 'leche flan', 'turon'],
                }
                keywords = meal_keywords.get(meal_type_lower, [])
                if keywords:
                    if any(kw in category_lower for kw in keywords) or any(kw in food_name_lower for kw in keywords):
                        meal_type_score = 20.0
                
                # ===== COMBINED SCORING FORMULA =====
                # final_score = (base_score * 0.3) + (goal_alignment_score * 0.3) + 
                #              (preference_match_score * 0.2) + (meal_type_match_score * 0.1) + 
                #              (activity_level_score * 0.1)
                final_score = (
                    base_score * 0.3 +
                    goal_score * 0.3 +
                    preference_score * 0.2 +
                    meal_type_score * 0.1 +
                    activity_score * 0.1
                )
                
                score = final_score
                
                # Debug logging for top foods
                if len(scored) < 5:  # Log first 5 foods for debugging
                    print(f'DEBUG: [Scoring] Food: {name[:30]}')
                    print(f'  Base: {base_score:.1f}, Goal: {goal_score:.1f}, Preference: {preference_score:.1f}, '
                          f'Meal: {meal_type_score:.1f}, Activity: {activity_score:.1f}')
                    print(f'  Final Score: {score:.1f}, Cal: {cal:.0f}, Protein: {protein:.1f}g, Fiber: {fiber:.1f}g')
            except Exception:
                score = 10.0  # Default score if calculation fails
            
            # Format to match FoodItem.fromJson() expectations
            # Clean the food name to remove Var variants, numbers, and special characters
            final_food_name = clean_food_name(name.strip())
            scored.append({
                'Food Name': final_food_name,
                'Calories': round(cal, 1),
                'Category': category,
                'Serving Size': serving_size,
                'Protein (g)': round(protein, 1),
                'Carbs (g)': round(carbs, 1),
                'Fat (g)': round(fat, 1),
                'Fiber (g)': round(fiber, 1),
                'Sodium (mg)': round(sodium, 1),
                '_score': round(score, 2)  # Internal score for sorting
            })

        # Sort by score desc
        scored.sort(key=lambda x: x.get('_score', 0), reverse=True)
        
        # Take top recommendations for variety (we'll select top 10 at the end)
        # Keep more candidates to ensure we have enough after deduplication
        top_recommendations = scored[:30]  # Get top 30 to ensure we have 10 unique after deduplication
        
        # Add some randomization: shuffle the top recommendations slightly
        # Keep top 3-5 as-is (highest scores), then slightly shuffle the rest
        if len(top_recommendations) > 5:
            top_5 = top_recommendations[:5]
            rest = top_recommendations[5:]
            random.shuffle(rest)  # Shuffle remaining to show variety
            top_recommendations = top_5 + rest
        
        scored = top_recommendations
        
        # Fallback: if we have less than 10 recommendations, add more to reach 10
        if len(scored) < 10:
            fallback_count = 10 - len(scored)
            try:
                global_food_df_fallback = globals().get('food_df', None)
                if global_food_df_fallback is not None and isinstance(global_food_df_fallback, pd.DataFrame) and not global_food_df_fallback.empty:
                    # Try to get popular foods for this meal type
                    meal_col = 'Meal Type' if 'Meal Type' in global_food_df_fallback.columns else None
                    fallback_foods = []
                    if meal_col and meal_type:
                        meal_matches = global_food_df_fallback[global_food_df_fallback[meal_col].str.lower() == meal_type]
                        if not meal_matches.empty:
                            fallback_foods = meal_matches.head(fallback_count).to_dict(orient='records')
                    
                    # If still not enough, use any popular foods from food_df
                    if len(fallback_foods) < fallback_count:
                        remaining = fallback_count - len(fallback_foods)
                        popular = global_food_df_fallback.head(remaining).to_dict(orient='records')
                        fallback_foods.extend(popular)
                else:
                    fallback_foods = []
                
                # Add fallback foods to scored list with basic scoring (check against seen_foods to avoid duplicates)
                for food in fallback_foods:
                    food_name = food.get('Food Name', '').strip()
                    if not food_name:
                        continue
                    
                    # Use same normalization function to ensure consistent duplicate detection
                    food_name_normalized = normalize_food_name(food_name)
                    
                    # Skip if already in seen_foods (from main recommendations)
                    if not food_name_normalized or food_name_normalized in seen_foods:
                        continue
                    
                    # Check against already scored items using normalized names
                    already_scored = any(
                        normalize_food_name(item.get('Food Name', '')) == food_name_normalized 
                        for item in scored
                    )
                    if already_scored:
                        continue
                    
                    # Format to match FoodItem.fromJson() expectations
                    # Clean the food name to remove Var variants, numbers, and special characters
                    cleaned_food_name = clean_food_name(food_name)
                    scored.append({
                        'Food Name': cleaned_food_name,
                        'Calories': float(food.get('Calories', 0)),
                        'Category': food.get('Category', ''),
                        'Serving Size': food.get('Serving Size', '100g'),
                        'Protein (g)': float(food.get('Protein (g)', 0)),
                        'Carbs (g)': float(food.get('Carbs (g)', 0)),
                        'Fat (g)': float(food.get('Fat (g)', 0)),
                        'Fiber (g)': float(food.get('Fiber (g)', 0)),
                        'Sodium (mg)': float(food.get('Sodium (mg)', 0)),
                        '_score': 10.0  # Lower score for fallback foods
                    })
                    seen_foods.add(food_name_normalized)  # Track in seen_foods to prevent future duplicates
                    if len(scored) >= 10:
                        break
            except Exception as e:
                # If fallback fails, at least return what we have
                pass
        
        # Final deduplication: Remove any remaining duplicates by Food Name (normalized and cleaned)
        final_seen = set()
        final_recs = []
        for item in scored:
            food_name = item.get('Food Name', '').strip()
            if not food_name:
                continue
            
            # Clean the food name first, then normalize for duplicate detection
            cleaned_food_name = clean_food_name(food_name)
            food_name_normalized = normalize_food_name(cleaned_food_name)
            # Skip if we've already added this food (normalized comparison)
            if not food_name_normalized or food_name_normalized in final_seen:
                continue
            
            final_seen.add(food_name_normalized)
            # Remove internal _score field and ensure cleaned name is used
            item_copy = {k: v for k, v in item.items() if k != '_score'}
            item_copy['Food Name'] = cleaned_food_name  # Ensure cleaned name is used
            final_recs.append(item_copy)
            
            # Limit to 25 recommendations (increased from 10 for better variety)
            if len(final_recs) >= 25:
                break
        
        # Return up to 25 recommendations (or all if we have less)
        # This gives users more variety and better discovery, aligned with their profile
        if len(final_recs) < 10:
            print(f'DEBUG: [Food Recommendations] Warning: Only {len(final_recs)} unique foods available (less than target of 10)')
        else:
            print(f'DEBUG: [Food Recommendations] Returning {len(final_recs)} recommendations (aligned with user profile: gender={user_obj.sex}, age={user_obj.age}, goal={user_obj.goal}, activity={user_obj.activity_level})')
        
        return jsonify({'recommended': final_recs[:25]}), 200
    except Exception as e:
        return jsonify({'error': str(e), 'recommended': []}), 200

@app.route('/foods/search/model')
def foods_search_model():
    """Experimental model-based food search (kept on a separate path).

    This uses the nutrition_model to score a single food candidate based on
    the raw query string and the user's profile. It is NOT used by the
    mobile Log Food search bar, which now relies purely on the local CSV.

    Query params: query, user
    Returns: { foods: [ { name, calories, score } ] }
    """
    try:
        query = (request.args.get('query') or '').strip()
        username = request.args.get('user') or ''
        if not query:
            return jsonify({'foods': []}), 200

        profile = None
        if username:
            user_obj = User.query.filter_by(username=username).first()
            if user_obj:
                profile = {
                    'sex': user_obj.sex or 'male',
                    'age': int(user_obj.age),
                    'height_cm': float(user_obj.height_cm),
                    'weight_kg': float(user_obj.weight_kg),
                    'activity_level': str(user_obj.activity_level),
                    'goal': str(user_obj.goal),
                }
        if not profile:
            # Minimal neutral defaults
            profile = {
                'sex': 'male',
                'age': 25,
                'height_cm': 175,
                'weight_kg': 70,
                'activity_level': 'active',
                'goal': 'maintain',
            }

        pn = nutrition_model.predict_nutrition(
            food_name=query,
            serving_size=100,
            user_gender=profile['sex'],
            user_age=int(profile['age']),
            user_weight=float(profile['weight_kg']),
            user_height=float(profile['height_cm']),
            user_activity_level=str(profile['activity_level']),
            user_goal=str(profile['goal']),
        )
        info = pn.get('nutrition_info', {})
        cal = float(info.get('calories', pn.get('calories', 0)))
        protein = float(info.get('protein', 0))
        iron = float(info.get('iron', 0))
        calcium = float(info.get('calcium', 0))

        score = 100.0
        if (profile['goal'] or '').lower() == 'gain muscle':
            score += protein * 1.5
        if (profile['sex'] or '').lower() == 'female':
            score += iron * 0.8 + calcium * 0.2

        return jsonify(
            {
                'foods': [
                    {
                        'name': query,
                        'calories': round(cal, 1),
                        'score': round(score, 2),
                    }
                ]
            }
        ), 200
    except Exception as e:
        return jsonify({'foods': [], 'error': str(e)}), 200

@app.route('/foods/info')
def foods_info():
    """Return nutrition info for a food name (100g baseline)."""
    try:
        name = (request.args.get('name') or '').strip()
        if not name:
            return jsonify({'error': 'name required'}), 400
        pn = nutrition_model.predict_nutrition(
            food_name=name,
            serving_size=100,
            user_gender='male',
            user_age=25,
            user_weight=70,
            user_height=175,
            user_activity_level='active',
            user_goal='maintain',
        )
        return jsonify({'food': {
            'name': name,
            'calories': pn.get('nutrition_info',{}).get('calories', pn.get('calories', 0)),
            'protein': pn.get('nutrition_info',{}).get('protein', 0),
            'carbs': pn.get('nutrition_info',{}).get('carbs', 0),
            'fat': pn.get('nutrition_info',{}).get('fat', 0),
            'fiber': pn.get('nutrition_info',{}).get('fiber', 0),
            'sodium': pn.get('nutrition_info',{}).get('sodium', 0),
        }}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/log/weight', methods=['POST', 'GET'])
def log_weight():
    """Create or read weight logs.

    POST body: { user, weight, date (YYYY-MM-DD) }
    GET params: user, limit
    """
    try:
        if request.method == 'GET':
            user = request.args.get('user')
            if not user:
                return jsonify({'error': 'user is required'}), 400
            try:
                limit = int(request.args.get('limit') or 0)
            except Exception:
                limit = 0

            q = WeightLog.query.filter_by(user=user).order_by(WeightLog.date.desc())
            if limit and limit > 0:
                q = q.limit(limit)
            rows = q.all()
            logs = [{'date': r.date.isoformat(), 'weight': r.weight} for r in rows][::-1]
            return jsonify({'logs': logs}), 200

        # POST
        data = request.get_json() or {}
        user = (data.get('user') or '').strip()
        weight = data.get('weight')
        date_str = (data.get('date') or '').strip()

        if not user:
            return jsonify({'error': 'user is required'}), 400
        try:
            weight = float(weight)
        except Exception:
            return jsonify({'error': 'valid weight is required'}), 400
        try:
            d = datetime.fromisoformat(date_str).date() if date_str else date.today()
        except Exception:
            return jsonify({'error': 'date must be ISO format YYYY-MM-DD'}), 400

        # Upsert: one entry per user/date
        existing = WeightLog.query.filter_by(user=user, date=d).first()
        if existing:
            existing.weight = weight
        else:
            db.session.add(WeightLog(user=user, weight=weight, date=d))
        db.session.commit()
        return jsonify({'ok': True}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/progress/all')
def progress_all():
    """Aggregate calories, weight, and workouts in a single response.

    Query params: user, start, end (ISO8601)
    Returns minimal fields to reduce payload size.
    """
    user = request.args.get('user')
    start_date = request.args.get('start')
    end_date = request.args.get('end')

    if not user:
        return jsonify({'error': 'user is required'}), 400

    # Build base filters
    food_q = FoodLog.query.filter_by(user=user)
    weight_q = WeightLog.query.filter_by(user=user)
    workout_q = WorkoutLog.query.filter_by(user=user)

    # Parse dates using safe date parser (no timezone conversion)
    sd = parse_date_safe(start_date) if start_date else None
    ed = parse_date_safe(end_date) if end_date else None

    if sd:
        food_q = food_q.filter(FoodLog.date >= sd)
        weight_q = weight_q.filter(WeightLog.date >= sd)
        workout_q = workout_q.filter(WorkoutLog.date >= sd)
    if ed:
        food_q = food_q.filter(FoodLog.date <= ed)
        weight_q = weight_q.filter(WeightLog.date <= ed)
        workout_q = workout_q.filter(WorkoutLog.date <= ed)

    # Select only the columns we return
    calories_rows = (
        food_q.with_entities(FoodLog.date, FoodLog.calories)
        .order_by(FoodLog.date)
        .all()
    )
    weight_rows = (
        weight_q.with_entities(WeightLog.date, WeightLog.weight)
        .order_by(WeightLog.date)
        .all()
    )
    workout_rows = (
        workout_q.with_entities(WorkoutLog.date, WorkoutLog.type, WorkoutLog.duration, WorkoutLog.calories_burned)
        .order_by(WorkoutLog.date)
        .all()
    )
    
    # Also get ExerciseSession data
    exercise_session_q = ExerciseSession.query.filter_by(user=user)
    if sd:
        # ExerciseSession.date is a Date column, so compare with date directly
        exercise_session_q = exercise_session_q.filter(ExerciseSession.date >= sd)
    if ed:
        # ExerciseSession.date is a Date column, so compare with date directly
        exercise_session_q = exercise_session_q.filter(ExerciseSession.date <= ed)
    
    exercise_session_rows = (
        exercise_session_q.with_entities(ExerciseSession.date, ExerciseSession.exercise_name, ExerciseSession.duration_seconds, ExerciseSession.calories_burned)
        .order_by(ExerciseSession.date)
        .all()
    )

    return jsonify({
        'calories': [
            {'date': d.isoformat(), 'calories': c}
            for d, c in calories_rows
        ],
        'weight': [
            {'date': d.isoformat(), 'weight': w}
            for d, w in weight_rows
        ],
        'workouts': [
            {
                'date': d.isoformat(),
                'type': t,
                'duration': dur,
                'calories_burned': cb
            }
            for d, t, dur, cb in workout_rows
        ] + [
            {
                'date': d.isoformat(),
                'type': name,
                'duration': int(dur_sec / 60),  # Convert seconds to minutes
                'calories_burned': cb
            }
            for d, name, dur_sec, cb in exercise_session_rows
        ]
    })

@app.route('/progress/start-date')
def progress_start_date():
    """Get the user's first food log date (when they started tracking).
    
    Query params: user
    Returns: {'success': true, 'start_date': 'YYYY-MM-DD', 'has_data': true}
    """
    user = request.args.get('user')
    
    if not user:
        return jsonify({'error': 'user is required'}), 400
    
    try:
        # Query the earliest date in FoodLog table for the user
        from sqlalchemy import func
        earliest_date = db.session.query(func.min(FoodLog.date)).filter_by(user=user).scalar()
        
        if earliest_date is None:
            return jsonify({
                'success': True,
                'start_date': None,
                'has_data': False
            })
        
        return jsonify({
            'success': True,
            'start_date': earliest_date.isoformat(),
            'has_data': True
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Streak Helper Functions ---
def get_philippines_timezone():
    """Get Philippines timezone object (Asia/Manila)"""
    try:
        if ZoneInfo:
            return ZoneInfo('Asia/Manila')
        else:
            return pytz.timezone('Asia/Manila')
    except Exception:
        return None

def get_philippines_date():
    """Get current date in Philippines timezone (Asia/Manila)"""
    try:
        if ZoneInfo:
            ph_tz = ZoneInfo('Asia/Manila')
        else:
            ph_tz = pytz.timezone('Asia/Manila')
        ph_now = datetime.now(ph_tz)
        return ph_now.date()
    except Exception:
        # Fallback to UTC if timezone fails
        return date.today()

def parse_date_safe(date_str):
    """Parse ISO8601 date string and extract date-only without timezone conversion.
    
    This function safely extracts the date part (YYYY-MM-DD) from ISO8601 datetime strings
    without timezone conversion, preventing date shifts when parsing dates from different timezones.
    
    Args:
        date_str: ISO8601 date string (e.g., "2025-11-13T00:00:00.000" or "2025-11-13")
    
    Returns:
        date object or None if parsing fails
    """
    if not date_str:
        return None
    try:
        # Extract date part directly (YYYY-MM-DD) without timezone conversion
        if 'T' in date_str:
            # Has time component, extract date part only
            date_part = date_str.split('T')[0]
        else:
            # Already date-only string
            date_part = date_str
        
        # Remove any timezone suffix if present (e.g., "2025-11-13+08:00" -> "2025-11-13")
        if '+' in date_part or date_part.endswith('Z'):
            date_part = date_part.split('+')[0].split('Z')[0]
        
        # Parse as date-only (no timezone conversion)
        return datetime.strptime(date_part, '%Y-%m-%d').date()
    except (ValueError, AttributeError) as e:
        print(f"[ERROR] Error parsing date: {date_str}, error: {e}")
        return None

def get_or_create_streak(user, streak_type, lock_for_update=False):
    """Get existing streak or create new one for user and type
    Args:
        user: Username
        streak_type: 'calories' or 'exercise'
        lock_for_update: If True, locks the row to prevent race conditions
    """
    query = Streak.query.filter_by(user=user, streak_type=streak_type)
    
    # Lock the row to prevent race conditions when updating streak
    if lock_for_update:
        try:
            streak = query.with_for_update().first()
        except Exception:
            # Fallback if with_for_update is not supported
            streak = query.first()
    else:
        streak = query.first()
    
    if not streak:
        streak = Streak(
            user=user,
            streak_type=streak_type,
            current_streak=0,
            longest_streak=0,
            minimum_exercise_minutes=15
        )
        db.session.add(streak)
        db.session.commit()
    return streak

def check_streak_continuity(streak, target_date=None):
    """Check if streak should continue or break based on last activity date
    Uses Philippines timezone for date calculations"""
    if target_date is None:
        target_date = get_philippines_date()
    
    if streak.last_activity_date is None:
        return False, "No previous activity"
    
    days_since_last = (target_date - streak.last_activity_date).days
    
    # Streak continues if last activity was yesterday or today (PH time)
    if days_since_last == 0:
        return True, "Activity logged today"
    elif days_since_last == 1:
        return True, "Activity logged yesterday, can continue"
    else:
        return False, f"Streak broken - {days_since_last} days since last activity"

def _normalize_to_date(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value))
    except (ValueError, TypeError, AttributeError):
        return None

def auto_reset_streak_if_inactive(streak, target_date=None):
    """
    Ensure streak is reset if user hasn't met goal for more than one full day.
    Returns True when the streak was modified.
    """
    if target_date is None:
        target_date = get_philippines_date()
    elif isinstance(target_date, datetime):
        target_date = target_date.date()

    if not isinstance(target_date, date):
        target_date = get_philippines_date()

    last_activity_date = _normalize_to_date(streak.last_activity_date)

    if last_activity_date is None:
        if streak.current_streak != 0:
            streak.current_streak = 0
            streak.streak_start_date = None
            streak.updated_at = datetime.utcnow()
            return True
        return False

    days_since_last = (target_date - last_activity_date).days

    # Break streak only when at least one full day without meeting the goal has passed
    if days_since_last > 1 and streak.current_streak != 0:
        streak.current_streak = 0
        streak.streak_start_date = None
        streak.updated_at = datetime.utcnow()
        return True

    return False

def update_streak(user, streak_type, met_goal, activity_date=None, exercise_minutes=0):
    """Update streak based on whether goal was met or exceeded
    Uses Philippines timezone for date calculations.
    Logic: Meeting OR exceeding goal = 1 streak for that day (PH time)
    Next day's streak only counts if goal is met/exceeded on that new day.
    
    FIXED: Now properly handles date comparisons and prevents double-counting
    when user exceeds goal multiple times on the same day."""
    if activity_date is None:
        activity_date = get_philippines_date()
    else:
        # Ensure we're using date object, not datetime
        if isinstance(activity_date, datetime):
            activity_date = activity_date.date()
    
    # Normalize activity_date to ensure consistent date type
    # Convert to date object if it's not already
    if not isinstance(activity_date, date):
        try:
            activity_date = activity_date.date() if hasattr(activity_date, 'date') else date.fromisoformat(str(activity_date))
        except (ValueError, AttributeError):
            activity_date = get_philippines_date()
    
    # Lock the streak row to prevent race conditions
    streak = get_or_create_streak(user, streak_type, lock_for_update=True)
    can_continue, message = check_streak_continuity(streak, activity_date)
    
    # Normalize last_activity_date for comparison
    # This fixes the bug where date types might not match exactly
    last_activity_date_normalized = None
    if streak.last_activity_date:
        last_activity_date_normalized = streak.last_activity_date
        if isinstance(last_activity_date_normalized, datetime):
            last_activity_date_normalized = last_activity_date_normalized.date()
        elif not isinstance(last_activity_date_normalized, date):
            try:
                last_activity_date_normalized = date.fromisoformat(str(last_activity_date_normalized))
            except (ValueError, AttributeError):
                last_activity_date_normalized = None
    
    # Check if we already updated the streak for today (PH time)
    # FIXED: Improved date comparison to handle type mismatches
    # This prevents multiple increments if user logs food multiple times after meeting goal
    dates_match = False
    if last_activity_date_normalized and activity_date:
        # Compare dates by converting to ISO format strings to ensure exact match
        dates_match = (last_activity_date_normalized.isoformat() == activity_date.isoformat())
    
    already_updated_today = (dates_match and streak.current_streak > 0)
    
    # Additional safety check: if dates match and goal was met, we've already counted today
    if met_goal and dates_match and streak.current_streak > 0:
        # Log warning if this happens (shouldn't with proper date normalization)
        if not already_updated_today:
            print(f"WARNING: Date match detected but already_updated_today was False! "
                  f"last_date={last_activity_date_normalized}, current_date={activity_date}, "
                  f"streak={streak.current_streak}")
        # Already counted today, don't increment again
        # This handles case where user logs food multiple times after meeting/exceeding goal
        db.session.commit()  # Commit any pending changes
        return streak
    
    if met_goal:
        # Goal met OR exceeded = 1 streak for this day (PH time)
        if can_continue:
            # Continue existing streak (last activity was yesterday or today)
            if streak.current_streak == 0:
                # Starting new streak
                streak.current_streak = 1
                streak.streak_start_date = activity_date
            else:
                # Increment existing streak (only once per day based on PH time)
                # This counts the current day as part of the streak
                streak.current_streak += 1
            streak.last_activity_date = activity_date
            
            # Update longest streak if current exceeds it
            if streak.current_streak > streak.longest_streak:
                streak.longest_streak = streak.current_streak
        else:
            # Start new streak (previous streak was broken)
            streak.current_streak = 1
            streak.streak_start_date = activity_date
            streak.last_activity_date = activity_date
    else:
        # Goal not met - need to check if we should recalculate or break streak
        # If this is the most recent day in the streak, recalculate from history
        # Otherwise, break the streak
        if dates_match and streak.current_streak > 0:
            # User deleted logs from the most recent day - recalculate streak from history
            # This prevents losing the entire streak when accidentally deleting logs
            new_streak_count, last_met_date, streak_start = recalculate_streak_from_history(
                user, streak_type, activity_date - timedelta(days=1)
            )
            
            streak.current_streak = new_streak_count
            streak.last_activity_date = last_met_date
            streak.streak_start_date = streak_start
            
            # Update longest streak if current exceeds it
            if streak.current_streak > streak.longest_streak:
                streak.longest_streak = streak.current_streak
        else:
            # Goal not met on a different day or no existing streak - break streak
            streak.current_streak = 0
            streak.streak_start_date = None
            # Keep last_activity_date for history
    
    streak.updated_at = datetime.utcnow()
    db.session.commit()
    return streak

def check_calories_goal_met(user, target_date=None):
    """Check if user met or exceeded their daily calorie goal
    Returns True if calories >= goal (meeting OR exceeding both count)"""
    if target_date is None:
        target_date = get_philippines_date()
    else:
        # Ensure we're using date object
        if isinstance(target_date, datetime):
            target_date = target_date.date()
    
    user_obj = User.query.filter_by(username=user).first()
    if not user_obj:
        return False
    
    calorie_goal = _compute_daily_goal_for_user(user_obj)
    daily_calories = db.session.query(db.func.sum(FoodLog.calories)).filter_by(
        user=user, date=target_date
    ).scalar() or 0
    
    # Meeting OR exceeding goal both count as "met"
    return daily_calories >= calorie_goal

def check_exercise_goal_met(user, target_date=None, minimum_minutes=15):
    """Check if user met their daily exercise goal (minimum minutes)
    Uses Philippines timezone for date calculations"""
    if target_date is None:
        target_date = get_philippines_date()
    else:
        # Ensure we're using date object
        if isinstance(target_date, datetime):
            target_date = target_date.date()
    
    # Check ExerciseSession data
    total_seconds = db.session.query(db.func.sum(ExerciseSession.duration_seconds)).filter_by(
        user=user, date=target_date
    ).scalar() or 0
    
    # Also check WorkoutLog data
    workout_duration = db.session.query(db.func.sum(WorkoutLog.duration)).filter_by(
        user=user, date=target_date
    ).scalar() or 0
    
    total_minutes = (total_seconds / 60) + (workout_duration or 0)
    return total_minutes >= minimum_minutes

def recalculate_streak_from_history(user, streak_type, up_to_date=None):
    """
    Recalculate streak by checking historical data day by day.
    This is used when logs are deleted to restore the correct streak count.
    
    Args:
        user: Username
        streak_type: 'calories' or 'exercise'
        up_to_date: Date to recalculate up to (defaults to yesterday if not provided)
    
    Returns:
        Tuple of (new_streak_count, last_activity_date, streak_start_date)
    """
    if up_to_date is None:
        up_to_date = get_philippines_date() - timedelta(days=1)  # Default to yesterday
    elif isinstance(up_to_date, datetime):
        up_to_date = up_to_date.date()
    
    if not isinstance(up_to_date, date):
        up_to_date = get_philippines_date() - timedelta(days=1)
    
    streak_count = 0
    last_met_date = None
    streak_start_date = None
    
    # Go backwards day by day, counting consecutive days where goal was met
    current_date = up_to_date
    max_days_to_check = 365  # Limit to prevent infinite loops
    days_checked = 0
    
    while days_checked < max_days_to_check:
        # Check if goal was met on this date
        if streak_type == 'calories':
            # Get goal for this specific date (may have changed over time)
            user_obj = User.query.filter_by(username=user).first()
            if not user_obj:
                break
            
            calorie_goal = _get_goal_for_date(user, current_date)
            daily_calories = db.session.query(db.func.sum(FoodLog.calories)).filter_by(
                user=user, date=current_date
            ).scalar() or 0
            
            met_goal = daily_calories >= calorie_goal
        else:  # exercise
            streak = get_or_create_streak(user, streak_type)
            minimum_minutes = streak.minimum_exercise_minutes if streak else 15
            met_goal = check_exercise_goal_met(user, current_date, minimum_minutes)
        
        if met_goal:
            streak_count += 1
            last_met_date = current_date if last_met_date is None else last_met_date
            streak_start_date = current_date  # This will be the oldest date as we go backwards
        else:
            # Streak broken, stop counting
            break
        
        # Move to previous day
        current_date = current_date - timedelta(days=1)
        days_checked += 1
    
    return streak_count, last_met_date, streak_start_date

# --- Streak API Endpoints ---
@app.route('/api/streaks', methods=['GET'])
def get_streaks():
    """Get user's streak data
    
    Query params:
    - user (required): Username
    - type (optional): Filter by streak type ('calories' or 'exercise')
    
    Returns:
    {
        "success": true,
        "streaks": [
            {
                "id": 1,
                "user": "markdle",
                "current_streak": 5,
                "longest_streak": 10,
                "last_activity_date": "2025-11-07",
                "streak_start_date": "2025-11-03",
                "streak_type": "calories",
                "minimum_exercise_minutes": 15,
                "days_since_start": 5,
                "is_active": true
            }
        ]
    }
    """
    try:
        user = request.args.get('user')
        streak_type = request.args.get('type')
        
        if not user:
            return jsonify({'success': False, 'error': 'user is required'}), 400
        
        query = Streak.query.filter_by(user=user)
        if streak_type:
            query = query.filter_by(streak_type=streak_type)
        
        streaks = query.all()
        
        result = []
        today_ph = get_philippines_date()  # Use PH timezone for all date calculations
        streaks_updated = False
        for streak in streaks:
            if auto_reset_streak_if_inactive(streak, today_ph):
                streaks_updated = True
            days_since_start = None
            if streak.streak_start_date:
                days_since_start = (today_ph - streak.streak_start_date).days
            
            days_since_break = None
            if streak.last_activity_date and streak.current_streak == 0:
                days_since_break = (today_ph - streak.last_activity_date).days
            
            is_active = streak.current_streak > 0 and streak.last_activity_date == today_ph
            
            result.append({
                'id': streak.id,
                'user': streak.user,
                'current_streak': streak.current_streak,
                'longest_streak': streak.longest_streak,
                'last_activity_date': streak.last_activity_date.isoformat() if streak.last_activity_date else None,
                'streak_start_date': streak.streak_start_date.isoformat() if streak.streak_start_date else None,
                'streak_type': streak.streak_type,
                'minimum_exercise_minutes': streak.minimum_exercise_minutes,
                'days_since_start': days_since_start,
                'days_since_break': days_since_break,
                'is_active': is_active,
                'created_at': streak.created_at.isoformat() if streak.created_at else None,
                'updated_at': streak.updated_at.isoformat() if streak.updated_at else None,
            })
        if streaks_updated:
            db.session.commit()
        return jsonify({'success': True, 'streaks': result}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/streaks/update', methods=['POST'])
def update_streak_endpoint():
    """Update streak when user logs activity
    
    Request body:
    {
        "user": "markdle",
        "streak_type": "calories",  // or "exercise"
        "date": "2025-11-07",  // optional, defaults to today
        "met_goal": true,  // Whether user met their goal for the day
        "exercise_minutes": 30  // Required if streak_type is "exercise"
    }
    
    Returns:
    {
        "success": true,
        "streak_updated": true,
        "current_streak": 6,
        "longest_streak": 10,
        "message": "Streak updated successfully"
    }
    """
    try:
        data = request.get_json() or {}
        user = data.get('user', '').strip()
        streak_type = data.get('streak_type', '').strip().lower()
        met_goal = data.get('met_goal', False)
        activity_date_str = data.get('date', '').strip()
        exercise_minutes = data.get('exercise_minutes', 0)
        
        if not user:
            return jsonify({'success': False, 'error': 'user is required'}), 400
        
        if streak_type not in ['calories', 'exercise']:
            return jsonify({'success': False, 'error': 'streak_type must be "calories" or "exercise"'}), 400
        
        # Parse date (defaults to PH timezone if not provided)
        if activity_date_str:
            try:
                activity_date = datetime.fromisoformat(activity_date_str).date()
            except Exception:
                return jsonify({'success': False, 'error': 'date must be ISO format YYYY-MM-DD'}), 400
        else:
            activity_date = get_philippines_date()
        
        # If met_goal is not provided, check automatically
        if 'met_goal' not in data:
            if streak_type == 'calories':
                met_goal = check_calories_goal_met(user, activity_date)
            elif streak_type == 'exercise':
                minimum_minutes = data.get('minimum_exercise_minutes', 15)
                met_goal = check_exercise_goal_met(user, activity_date, minimum_minutes)
        
        # Update streak
        streak = update_streak(user, streak_type, met_goal, activity_date, exercise_minutes)
        
        return jsonify({
            'success': True,
            'streak_updated': True,
            'current_streak': streak.current_streak,
            'longest_streak': streak.longest_streak,
            'message': 'Streak updated successfully'
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/streaks/check', methods=['GET'])
def check_streak():
    """Check if user's streak should be updated based on today's activity
    
    Query params:
    - user (required): Username
    - type (optional): Streak type to check
    
    Returns:
    {
        "success": true,
        "needs_update": true,
        "current_streak": 5,
        "will_increment": true
    }
    """
    try:
        user = request.args.get('user')
        streak_type = request.args.get('type')
        
        if not user:
            return jsonify({'success': False, 'error': 'user is required'}), 400
        
        today = get_philippines_date()
        needs_update = False
        will_increment = False
        
        # Check both streak types if not specified
        types_to_check = [streak_type] if streak_type else ['calories', 'exercise']
        
        result = {}
        streaks_updated = False
        for stype in types_to_check:
            if stype not in ['calories', 'exercise']:
                continue
            
            streak = get_or_create_streak(user, stype)
            if auto_reset_streak_if_inactive(streak, today):
                streaks_updated = True
            
            # Check if activity logged today
            if stype == 'calories':
                met_goal = check_calories_goal_met(user, today)
            else:
                met_goal = check_exercise_goal_met(user, today, streak.minimum_exercise_minutes)
            
            # Check if streak needs update
            if streak.last_activity_date != today:
                needs_update = True
                if met_goal:
                    will_increment = True
            
            result[stype] = {
                'needs_update': needs_update,
                'current_streak': streak.current_streak,
                'will_increment': will_increment,
                'met_goal': met_goal,
                'last_activity_date': streak.last_activity_date.isoformat() if streak.last_activity_date else None,
            }
        if streaks_updated:
            db.session.commit()
        return jsonify({
            'success': True,
            'results': result
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True) 