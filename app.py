# pyright: reportCallIssue=false
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
from nutrition_model import NutritionModel
import os
import json
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text, func
from datetime import datetime, date, timedelta
from dotenv import load_dotenv
import requests
import re
import time
from config import config
from werkzeug.security import generate_password_hash, check_password_hash
import csv
import random
from email_service import send_verification_email, generate_verification_code
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
CORS(app)

# Configure app based on environment
config_name = os.environ.get('FLASK_ENV', 'development')
app.config.from_object(config[config_name])

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
    estimated_calories_per_minute = db.Column(db.Integer, default=5)
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
        reader = csv.DictReader(f)
        required = {
            'id','name','category','body_part','target','equipment','difficulty','calories_per_minute','instructions','tags'
        }
        if not required.issubset(set([c.strip() for c in (reader.fieldnames or [])])):
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
                    existing.instructions = json.dumps([s.strip() for s in row.get('instructions','').split(';') if s.strip()])
                    existing.category = row.get('category','')
                    existing.difficulty = row.get('difficulty','')
                    try:
                        existing.estimated_calories_per_minute = int(float(row.get('calories_per_minute', '5')))
                    except Exception:
                        existing.estimated_calories_per_minute = 5
                    updated += 1
                else:
                    ex = Exercise(
                        exercise_id=ext_id,
                        name=row.get('name',''),
                        body_part=row.get('body_part',''),
                        equipment=row.get('equipment',''),
                        target=row.get('target',''),
                        gif_url='',
                        instructions=json.dumps([s.strip() for s in row.get('instructions','').split(';') if s.strip()]),
                        category=row.get('category',''),
                        difficulty=row.get('difficulty',''),
                        estimated_calories_per_minute=int(float(row.get('calories_per_minute', '5')))
                    )
                    db.session.add(ex)
                    added += 1
            except Exception:
                continue
    db.session.commit()
    return added, updated

# Initialize the nutrition model
nutrition_model = NutritionModel()

# Initialize database tables
with app.app_context():
    db.create_all()
    print("[SUCCESS] Database tables initialized successfully")

# Load Filipino food dataset at startup (robust path + encoding)
try:
    FOOD_CSV_PATH = os.path.join(os.path.dirname(__file__), 'Filipino_Food_Nutrition_Dataset.csv')
    if os.path.exists(FOOD_CSV_PATH):
        food_df = pd.read_csv(FOOD_CSV_PATH, encoding='utf-8')
        print('[SUCCESS] Loaded Filipino food dataset')
    else:
        # Minimal fallback DataFrame
        print(f"[WARNING] Filipino food CSV not found at {FOOD_CSV_PATH}; using empty dataset")
        food_df = pd.DataFrame(columns=['Food Name','Calories','Protein (g)','Carbs (g)','Fat (g)','Fiber (g)','Sodium (mg)'])
except Exception as e:
    print(f"[ERROR] Failed to load Filipino food dataset: {e}")
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
        
        return jsonify({
            'success': True,
            'exercises': [{
                'id': ex.exercise_id,
                'name': ex.name,
                'body_part': ex.body_part,
                'equipment': ex.equipment,
                'target': ex.target,
                'gif_url': ex.gif_url,
                'instructions': json.loads(ex.instructions) if ex.instructions else [],
                'category': normalize_category(ex.category or ''),
                'difficulty': ex.difficulty,
                'estimated_calories_per_minute': ex.estimated_calories_per_minute
            } for ex in exercises]
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

 

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
    """Calculate calories burned for an exercise based on duration.

    Request JSON body supports:
      - exercise_id: preferred unique id (matches exercises.exercise_id)
      - name: alternative lookup by name if id not provided
      - duration_seconds: required, total active duration in seconds

    Returns: { success, exercise_id, name, minutes, calories_per_minute, calories }
    """
    try:
        body = request.get_json(silent=True) or {}
        exercise_id = (body.get('exercise_id') or '').strip()
        name = (body.get('name') or '').strip()
        duration_seconds = body.get('duration_seconds')

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

        minutes = duration_seconds / 60.0
        cpm = exercise.estimated_calories_per_minute or 5
        calories = round(float(cpm) * minutes, 2)

        return jsonify({
            'success': True,
            'exercise_id': exercise.exercise_id,
            'name': exercise.name,
            'minutes': round(minutes, 3),
            'calories_per_minute': cpm,
            'calories': calories
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/exercises/<exercise_id>', methods=['GET'])
def get_exercise_details(exercise_id):
    """Get detailed information about a specific exercise"""
    try:
        exercise = Exercise.query.filter_by(exercise_id=exercise_id).first()
        
        if not exercise:
            return jsonify({'error': 'Exercise not found'}), 404
        
        return jsonify({
            'success': True,
            'exercise': {
                'id': exercise.exercise_id,
                'name': exercise.name,
                'body_part': exercise.body_part,
                'equipment': exercise.equipment,
                'target': exercise.target,
                'gif_url': exercise.gif_url,
                'instructions': json.loads(exercise.instructions) if exercise.instructions else [],
                'category': exercise.category,
                'difficulty': exercise.difficulty,
                'estimated_calories_per_minute': exercise.estimated_calories_per_minute
            }
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
            # Estimate calories if not provided
            exercise = Exercise.query.filter_by(exercise_id=data['exercise_id']).first()
            if exercise:
                calories_burned = exercise.estimated_calories_per_minute * duration_minutes
        
        session = ExerciseSession(
            user=data['user'],
            exercise_id=data['exercise_id'],
            exercise_name=data['exercise_name'],
            duration_seconds=data['duration_seconds'],
            calories_burned=calories_burned,
            sets_completed=data.get('sets_completed', 1),
            notes=data.get('notes', ''),
            date=datetime.strptime(data.get('date', datetime.now().strftime('%Y-%m-%d')), '%Y-%m-%d').date()
        )
        
        db.session.add(session)
        db.session.commit()
        
        # Update exercise streak after logging exercise session
        try:
            user = data['user']
            session_date = datetime.strptime(data.get('date', datetime.now().strftime('%Y-%m-%d')), '%Y-%m-%d').date()
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
    return jsonify({
        'status': 'healthy',
        'message': 'Nutrition API is running',
        'model_loaded': nutrition_model.is_model_loaded()
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
    return jsonify({'success': True})

@app.route('/log/food/<int:log_id>', methods=['DELETE'])
def delete_food_log(log_id):
    log = FoodLog.query.get_or_404(log_id)
    db.session.delete(log)
    db.session.commit()
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
        
        # Send verification email
        if email:
            email_sent = send_verification_email(email, verification_code, username)
            if not email_sent:
                print(f"[WARN] Failed to send verification email to {email}")
                return jsonify({
                    'success': False,
                    'error': 'Failed to send verification email. Please try again.'
                }), 500
        
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
        exists = bool(
            User.query.filter(func.lower(User.email) == email.lower()).first()
        )
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
    """Reset a user's password using their email or username."""
    try:
        data = request.get_json() or {}

        email = (data.get('email') or '').strip()
        username = (data.get('username') or '').strip()
        identifier = (data.get('username_or_email') or '').strip()
        new_password = (data.get('new_password') or '').strip()

        if not new_password:
            return jsonify({'error': 'New password is required'}), 400
        if len(new_password) < 6:
            return jsonify(
                {'error': 'New password must be at least 6 characters long'}
            ), 400

        user = None
        lookup_error = None

        try:
            if email:
                user = User.query.filter(
                    func.lower(User.email) == email.lower()
                ).first()
            elif username:
                user = User.query.filter(
                    func.lower(User.username) == username.lower()
                ).first()
            elif identifier:
                if '@' in identifier:
                    user = User.query.filter(
                        func.lower(User.email) == identifier.lower()
                    ).first()
                else:
                    user = User.query.filter(
                        func.lower(User.username) == identifier.lower()
                    ).first()
        except Exception as lookup_ex:
            lookup_error = lookup_ex

        if lookup_error:
            raise lookup_error

        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404

        stored_password = user.password or ''
        is_same_password = False

        if stored_password:
            try:
                is_same_password = check_password_hash(stored_password, new_password)
            except Exception:
                is_same_password = stored_password == new_password
        else:
            is_same_password = False

        if not is_same_password and stored_password:
            is_same_password = stored_password == new_password

        if is_same_password:
            return jsonify({
                'success': False,
                'message': 'New password must be different from the current password'
            }), 400

        user.password = generate_password_hash(new_password)
        
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
                    print(f"[WARN] DB connection error on password reset commit (attempt {attempt + 1}/{max_commit_retries}): {db_err}")
                    try:
                        db.session.rollback()
                        db.session.close()
                        db.session.remove()
                    except Exception:
                        pass
                    time.sleep(0.2)
                    # Re-query the user and update password in the new session
                    try:
                        if email:
                            user = User.query.filter(
                                func.lower(User.email) == email.lower()
                            ).first()
                        elif username:
                            user = User.query.filter(
                                func.lower(User.username) == username.lower()
                            ).first()
                        elif identifier:
                            if '@' in identifier:
                                user = User.query.filter(
                                    func.lower(User.email) == identifier.lower()
                                ).first()
                            else:
                                user = User.query.filter(
                                    func.lower(User.username) == identifier.lower()
                                ).first()
                        if user:
                            user.password = generate_password_hash(new_password)
                    except Exception:
                        pass
                else:
                    print(f"[ERROR] DB error on password reset commit: {db_err}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise

        return jsonify({
            'success': True,
            'message': 'Password reset successfully'
        }), 200

    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify({'error': f'Failed to reset password: {str(e)}'}), 500

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
                user.daily_calorie_goal = compute_daily_calorie_goal(
                    sex=user.sex,
                    age=age_val,
                    weight_kg=weight_val,
                    height_cm=height_val,
                    activity_level=lvl,
                    goal=gl,
                )
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

@app.route('/user/<username>/email', methods=['PUT'])
def change_user_email(username):
    """Change user email address"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        if not data or 'new_email' not in data:
            return jsonify({'error': 'New email is required'}), 400
        
        new_email = data['new_email'].strip()
        
        # Validate email format
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, new_email):
            return jsonify({'error': 'Invalid email format'}), 400
        
        # Check if email is already in use by another user
        existing_user = User.query.filter_by(email=new_email).first()
        if existing_user and existing_user.username != username:
            return jsonify({'error': 'Email already in use'}), 409
        
        # Update email
        user.email = new_email
        db.session.commit()
        
        print(f"[SUCCESS] Email changed for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Email changed successfully',
            'new_email': new_email
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to change email for user {username}: {e}")
        return jsonify({'error': f'Failed to change email: {str(e)}'}), 500

@app.route('/user/<username>/password', methods=['PUT'])
def change_user_password(username):
    """Change user password"""
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
        
        # Verify current password
        if not check_password_hash(user.password, current_password):
            return jsonify({'error': 'Current password is incorrect'}), 401
        
        # Validate new password
        if len(new_password) < 6:
            return jsonify({'error': 'New password must be at least 6 characters long'}), 400
        
        # Update password
        user.password = generate_password_hash(new_password)
        db.session.commit()
        
        print(f"[SUCCESS] Password changed for user {username}")
        
        return jsonify({
            'success': True,
            'message': 'Password changed successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Failed to change password for user {username}: {e}")
        return jsonify({'error': f'Failed to change password: {str(e)}'}), 500

@app.route('/user/<username>', methods=['DELETE'])
def delete_user_account(username):
    """Delete user account and all associated data"""
    try:
        user = get_user_by_identifier(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Delete all associated data
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
        # First, get all recipe IDs for this user
        user_recipes = CustomRecipe.query.filter_by(user=username).all()
        recipe_ids = [recipe.id for recipe in user_recipes]
        
        # Delete recipe ingredients (foreign key to recipes)
        if recipe_ids:
            RecipeIngredient.query.filter(RecipeIngredient.recipe_id.in_(recipe_ids)).delete()
        
        # Delete custom recipes
        CustomRecipe.query.filter_by(user=username).delete()
        
        # Delete streaks
        Streak.query.filter_by(user=username).delete()
        
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
        print(f"[ERROR] Failed to delete user account {username}: {e}")
        return jsonify({'error': f'Failed to delete account: {str(e)}'}), 500

@app.route('/foods/search', methods=['GET'])
def search_foods():
    query = request.args.get('query', '').strip().lower()
    if not query:
        return jsonify({'foods': []})
    matches = food_df[food_df['Food Name'].str.lower().str.contains(query)]
    foods = matches.head(15).to_dict(orient='records')

    # If we have enough local results, return them
    if len(foods) >= 3:
        return jsonify({'foods': foods})

    # Otherwise, query Open Food Facts API as fallback
    try:
        off_url = f'https://world.openfoodfacts.org/cgi/search.pl?search_terms={query}&search_simple=1&action=process&json=1'
        resp = requests.get(off_url, timeout=3)
        if resp.status_code == 200:
            data = resp.json()
            for product in data.get('products', [])[:10]:
                # Map Open Food Facts fields to your frontend model
                name = product.get('product_name') or product.get('generic_name')
                if not name:
                    continue
                calories = None
                nutriments = product.get('nutriments', {})
                if 'energy-kcal_100g' in nutriments:
                    calories = nutriments['energy-kcal_100g']
                elif 'energy_100g' in nutriments:
                    # Convert kJ to kcal
                    calories = round(nutriments['energy_100g'] / 4.184, 1)
                food_item = {
                    'Food Name': name,
                    'Category': product.get('categories', ''),
                    'Serving Size': product.get('serving_size', ''),
                    'Calories': calories or 0,
                    'Protein (g)': nutriments.get('proteins_100g', 0),
                    'Carbs (g)': nutriments.get('carbohydrates_100g', 0),
                    'Fat (g)': nutriments.get('fat_100g', 0),
                    'Fiber (g)': nutriments.get('fiber_100g', 0),
                    'Sodium (mg)': nutriments.get('sodium_100g', 0),
                    'Source': 'Open Food Facts',
                }
                foods.append(food_item)
    except Exception as e:
        print(f"Open Food Facts API error: {e}")
        # Fail gracefully, just return local results

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
    user = request.args.get('user')
    start_date = request.args.get('start')
    end_date = request.args.get('end')
    
    query = WorkoutLog.query.filter_by(user=user)
    
    if start_date:
        query = query.filter(WorkoutLog.date >= datetime.fromisoformat(start_date).date())
    if end_date:
        query = query.filter(WorkoutLog.date <= datetime.fromisoformat(end_date).date())
    
    rows = (
        query.with_entities(WorkoutLog.date, WorkoutLog.type, WorkoutLog.duration, WorkoutLog.calories_burned)
        .order_by(WorkoutLog.date)
        .all()
    )
    return jsonify([
        {
            'date': d.isoformat(),
            'type': t,
            'duration': dur,
            'calories_burned': cb,
        }
        for d, t, dur, cb in rows
    ])

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
    
    # Get total workouts
    workout_query = WorkoutLog.query.filter_by(user=user)
    if 'start' in date_filter:
        workout_query = workout_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        workout_query = workout_query.filter(WorkoutLog.date <= date_filter['end'])
    
    total_workouts = workout_query.count()
    
    # Get total exercise duration
    duration_query = db.session.query(db.func.sum(WorkoutLog.duration)).filter_by(user=user)
    if 'start' in date_filter:
        duration_query = duration_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        duration_query = duration_query.filter(WorkoutLog.date <= date_filter['end'])
    
    total_duration = duration_query.scalar() or 0
    
    # Get total calories burned
    calories_burned_query = db.session.query(db.func.sum(WorkoutLog.calories_burned)).filter_by(user=user)
    if 'start' in date_filter:
        calories_burned_query = calories_burned_query.filter(WorkoutLog.date >= date_filter['start'])
    if 'end' in date_filter:
        calories_burned_query = calories_burned_query.filter(WorkoutLog.date <= date_filter['end'])
    
    total_calories_burned = calories_burned_query.scalar() or 0
    
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
    
    total_duration = sum(workout.duration for workout in daily_workouts)
    total_calories_burned = sum(workout.calories_burned for workout in daily_workouts)
    
    # Get user goals
    user_obj = User.query.filter_by(username=user).first()
    calorie_goal = _compute_daily_goal_for_user(user_obj) if user_obj else 2000
    
    return jsonify({
        'date': date_obj.isoformat(),
        'calories': {
            'current': daily_calories,
            'goal': calorie_goal,
            'remaining': max(0, calorie_goal - daily_calories),
            'percentage': min(1.0, daily_calories / calorie_goal) if calorie_goal > 0 else 0
        },
        'weight': {
            'current': daily_weight.weight if daily_weight else None,
            'previous': None  # Would need to get previous day's weight
        },
        'exercise': {
            'duration': total_duration,
            'calories_burned': total_calories_burned,
            'sessions': len(daily_workouts),
            'average_intensity': total_calories_burned / total_duration if total_duration > 0 else 0
        },
        'achievements': _get_daily_achievements(daily_calories, calorie_goal, total_duration, len(daily_workouts)),
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
    
    weekly_workouts = WorkoutLog.query.filter(
        WorkoutLog.user == user,
        WorkoutLog.date >= start_date,
        WorkoutLog.date <= end_date
    ).all()
    
    total_duration = sum(workout.duration for workout in weekly_workouts)
    total_calories_burned = sum(workout.calories_burned for workout in weekly_workouts)
    
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
            'remaining': max(0, weekly_calorie_goal - weekly_calories),
            'percentage': min(1.0, weekly_calories / weekly_calorie_goal) if weekly_calorie_goal > 0 else 0,
            'daily_average': weekly_calories / 7
        },
        'exercise': {
            'total_duration': total_duration,
            'total_calories_burned': total_calories_burned,
            'sessions': len(weekly_workouts),
            'daily_average_duration': total_duration / 7,
            'consistency': len(set(workout.date for workout in weekly_workouts)) / 7
        },
        'achievements': _get_weekly_achievements(weekly_calories, weekly_calorie_goal, total_duration, len(weekly_workouts)),
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
    
    monthly_workouts = WorkoutLog.query.filter(
        WorkoutLog.user == user,
        WorkoutLog.date >= start_date,
        WorkoutLog.date <= end_date
    ).all()
    
    total_duration = sum(workout.duration for workout in monthly_workouts)
    total_calories_burned = sum(workout.calories_burned for workout in monthly_workouts)
    
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
            'remaining': max(0, monthly_calorie_goal - monthly_calories),
            'percentage': min(1.0, monthly_calories / monthly_calorie_goal) if monthly_calorie_goal > 0 else 0,
            'daily_average': monthly_calories / end_date.day
        },
        'exercise': {
            'total_duration': total_duration,
            'total_calories_burned': total_calories_burned,
            'sessions': len(monthly_workouts),
            'daily_average_duration': total_duration / end_date.day,
            'consistency': len(set(workout.date for workout in monthly_workouts)) / end_date.day
        },
        'achievements': _get_monthly_achievements(monthly_calories, monthly_calorie_goal, total_duration, len(monthly_workouts)),
        'trends': _get_monthly_trends(user, start_date, end_date)
    })

@app.route('/progress/goals', methods=['GET', 'POST'])
def progress_goals():
    user = request.args.get('user') or request.json.get('user')
    
    if request.method == 'GET':
        # Get user goals
        user_obj = User.query.filter_by(username=user).first()
        if not user_obj:
            return jsonify({'error': 'User not found'}), 404
        
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
        
        # Update user profile with new goals
        user_obj = User.query.filter_by(username=user).first()
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
    """Compatibility endpoint for the Flutter UI to fetch recommended foods.

    Query params: 
        - user: username
        - meal_type: breakfast|lunch|dinner|snacks
        - filters: comma-separated list (e.g., "healthy,spicy,protein")
    Returns: { recommended: [ { name, calories } ] }
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
        
        # Priority: Use active_filters if provided, otherwise fall back to saved preferences
        if active_filters:
            all_preferences = active_filters
        else:
            all_preferences = saved_preferences

        # Get base recommendations from meal plan (for initial filtering)
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
        base_foods = rec.get('meal_plan', {}).get(meal_type, {}).get('foods', [])
        
        # Use FULL food_df database (900 foods) instead of just the limited meal plan
        # This gives us access to all 900 foods for recommendations
        foods_to_score = []
        try:
            global_food_df = globals().get('food_df', None)
            if global_food_df is not None and isinstance(global_food_df, pd.DataFrame) and not global_food_df.empty:
                # Get all food names from the full database
                all_food_names = global_food_df['Food Name'].astype(str).dropna().unique().tolist()
                
                # Start with base foods from meal plan (ensures some relevance)
                foods_to_score = list(base_foods)
                
                # Add additional foods from full database
                # Limit to a reasonable subset for performance (sample or take first N)
                # Add some randomization to show different foods each time
                remaining_foods = [f for f in all_food_names if f not in foods_to_score]
                
                # Sample up to 100 additional foods from the database (or all if less than 100)
                sample_size = min(100, len(remaining_foods))
                if sample_size > 0:
                    sampled = random.sample(remaining_foods, sample_size) if len(remaining_foods) > sample_size else remaining_foods
                    foods_to_score.extend(sampled)
                
                print(f'DEBUG: [Food Recommendations] Using full database: {len(foods_to_score)} foods to score (from {len(all_food_names)} total)')
            else:
                # Fallback to base foods if food_df not available
                foods_to_score = base_foods
                print(f'DEBUG: [Food Recommendations] Using limited meal plan: {len(foods_to_score)} foods')
        except Exception as e:
            # Fallback to base foods if any error
            foods_to_score = base_foods
            print(f'DEBUG: [Food Recommendations] Error accessing full database: {e}, using {len(foods_to_score)} base foods')
        
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

        # Derive daily and per-meal targets
        daily = nutrition_model._calculate_daily_needs(
            user_obj.sex or 'male', int(user_obj.age), float(user_obj.weight_kg), float(user_obj.height_cm), str(user_obj.activity_level)
        )
        per_meal_target = {
            'breakfast': daily['calories'] * 0.25,
            'lunch': daily['calories'] * 0.35,
            'dinner': daily['calories'] * 0.30,
            'snacks': daily['calories'] * 0.10,
        }.get(meal_type, daily['calories'] * 0.25)

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

                # Scoring: target fit + goal/sex weighting + preference weighting
                target_diff = abs(cal - per_meal_target)
                target_score = max(0.0, 100 - (target_diff / 10))
                
                goal_score = 0.0
                if (user_obj.goal or '').lower() == 'gain muscle':
                    goal_score += protein * 1.5
                elif (user_obj.goal or '').lower() == 'lose weight':
                    goal_score += max(0.0, 30 - cal / 10)

                sex_score = 0.0
                if (user_obj.sex or '').lower() == 'female':
                    sex_score += iron * 0.8 + calcium * 0.2
                else:
                    sex_score += protein * 0.5

                # Preference-based scoring using model predictions
                preference_score = 0.0
                prefs_lower = [p.lower() for p in all_preferences]
                food_name_lower = name.lower()
                category_lower = category.lower() if category else ''
                
                # Plant-based preference: Boost plant foods, penalize meats
                if 'plant_based' in prefs_lower or 'plant-based' in prefs_lower:
                    if category_lower in ['vegetables', 'fruits', 'grains', 'legumes']:
                        preference_score += 25.0  # Strong boost for plant foods
                    elif category_lower == 'meats':
                        preference_score -= 50.0  # Strong penalty for meats
                
                # Protein lover preference: Boost high-protein foods (stronger boost)
                if 'protein' in prefs_lower:
                    if protein > 15:  # High protein threshold
                        preference_score += protein * 2.5 + 30.0  # Strong boost: base +30 + multiplier
                    elif protein > 8:
                        preference_score += protein * 1.5 + 20.0  # Medium boost: base +20 + multiplier
                    elif protein > 5:
                        preference_score += protein * 0.8 + 10.0  # Small boost for moderate protein
                
                # Healthy preference: Boost nutritious, lower-calorie foods, penalize unhealthy options
                if 'healthy' in prefs_lower:
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
                        preference_score += 30.0
                    elif nutrition_density > 0.3:
                        preference_score += 20.0
                    elif nutrition_density > 0.15:
                        preference_score += 10.0
                    
                    # Boost for whole grains and natural foods
                    if 'brown' in food_name_lower or 'whole grain' in food_name_lower:
                        preference_score += 15.0
                    
                    # Boost for fruits and vegetables
                    if category_lower in ['fruits', 'vegetables']:
                        preference_score += 25.0
                    elif 'fruit' in food_name_lower or 'vegetable' in food_name_lower:
                        preference_score += 20.0
                    
                    # Boost for lean proteins
                    if protein > 10 and fat < 10 and category_lower != 'meats':
                        preference_score += 15.0
                    
                    # STRONG PENALTIES for unhealthy foods
                    # Penalize fried foods heavily
                    if 'fried' in food_name_lower or 'deep fried' in food_name_lower:
                        preference_score -= 40.0  # Strong penalty
                    
                    # Penalize refined grains (white rice, white bread)
                    if 'white_rice' in food_name_lower or ('white rice' in food_name_lower and 'brown' not in food_name_lower):
                        preference_score -= 25.0  # Prefer brown rice
                    
                    if 'white bread' in food_name_lower or 'white_bread' in food_name_lower:
                        preference_score -= 20.0
                    
                    # Penalize high-calorie, low-nutrition foods
                    if cal > 300 and nutrition_density < 0.1:
                        preference_score -= 20.0
                    
                    # Penalize high-fat, high-calorie foods
                    if fat > 20 and cal > 250:
                        preference_score -= 15.0
                    
                    # Small boost for moderate calories with good nutrition
                    if 100 <= cal <= 200 and (fiber > 3 or protein > 8):
                        preference_score += 10.0
                
                # Comfort food preference: No specific boost (all foods considered)
                # This is more about emotional satisfaction than nutrition scoring
                
                # Spicy preference: Boost foods with spicy indicators in name
                if 'spicy' in prefs_lower:
                    spicy_keywords = ['spicy', 'hot', 'chili', 'sili', 'sili', 'adobo', 'sinigang', 'bicol']
                    if any(keyword in food_name_lower for keyword in spicy_keywords):
                        preference_score += 15.0
                
                # Sweet tooth preference: Boost sweet foods
                if 'sweet' in prefs_lower:
                    sweet_keywords = ['sweet', 'cake', 'dessert', 'candy', 'fruit', 'mango', 'banana', 'papaya']
                    if any(keyword in food_name_lower for keyword in sweet_keywords):
                        preference_score += 15.0

                score = target_score + goal_score + sex_score + preference_score
            except Exception:
                score = 10.0  # Default score if calculation fails
            
            # Format to match FoodItem.fromJson() expectations
            # Use the original name from the database if we found a match, otherwise use the name as-is
            final_food_name = name.strip()
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
        
        # Take top 20 recommendations for variety (instead of just 8)
        top_recommendations = scored[:20]
        
        # Add some randomization: shuffle the top recommendations slightly
        # Keep top 3-5 as-is (highest scores), then slightly shuffle the rest
        if len(top_recommendations) > 5:
            top_5 = top_recommendations[:5]
            rest = top_recommendations[5:]
            random.shuffle(rest)  # Shuffle remaining to show variety
            top_recommendations = top_5 + rest
        
        scored = top_recommendations
        
        # Fallback: if we have less than 8 recommendations or empty, use default foods
        if len(scored) < 8:
            fallback_count = 8 - len(scored)
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
                    scored.append({
                        'Food Name': food_name,
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
                    if len(scored) >= 8:
                        break
            except Exception as e:
                # If fallback fails, at least return what we have
                pass
        
        # Final deduplication: Remove any remaining duplicates by Food Name (normalized)
        final_seen = set()
        final_recs = []
        for item in scored:
            food_name = item.get('Food Name', '').strip()
            if not food_name:
                continue
            
            # Use same normalization function for consistency
            food_name_normalized = normalize_food_name(food_name)
            # Skip if we've already added this food (normalized comparison)
            if not food_name_normalized or food_name_normalized in final_seen:
                continue
            
            final_seen.add(food_name_normalized)
            # Remove internal _score field
            item_copy = {k: v for k, v in item.items() if k != '_score'}
            final_recs.append(item_copy)
            
            # Limit to 15 recommendations for more variety (from full 900-food database)
            if len(final_recs) >= 15:
                break
        
        return jsonify({'recommended': final_recs}), 200
    except Exception as e:
        return jsonify({'error': str(e), 'recommended': []}), 200

@app.route('/foods/search')
def foods_search():
    """Compatibility endpoint mapping to recommendations search.

    Query params: query
    Returns: { foods: [ { name, calories } ] }
    """
    try:
        query = (request.args.get('query') or '').strip()
        username = request.args.get('user') or ''
        if not query:
            return jsonify({'foods': []}), 200

        data = {
            'query': query,
            'user': username,
        }
        # Reuse internal function by calling the model directly
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
                'sex': 'male', 'age': 25, 'height_cm': 175, 'weight_kg': 70, 'activity_level': 'active', 'goal': 'maintain'
            }

        # Simple candidate: the query itself
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
        info = pn.get('nutrition_info',{})
        cal = float(info.get('calories', pn.get('calories', 0)))
        protein = float(info.get('protein', 0))
        iron = float(info.get('iron', 0))
        calcium = float(info.get('calcium', 0))
        # Simple score for search result
        score = 100.0
        if (profile['goal'] or '').lower() == 'gain muscle':
            score += protein * 1.5
        if (profile['sex'] or '').lower() == 'female':
            score += iron * 0.8 + calcium * 0.2
        return jsonify({'foods': [{'name': query, 'calories': round(cal,1), 'score': round(score,2)}]}), 200
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

    if start_date:
        sd = datetime.fromisoformat(start_date).date()
        food_q = food_q.filter(FoodLog.date >= sd)
        weight_q = weight_q.filter(WeightLog.date >= sd)
        workout_q = workout_q.filter(WorkoutLog.date >= sd)
    if end_date:
        ed = datetime.fromisoformat(end_date).date()
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
    if start_date:
        sd = datetime.fromisoformat(start_date).date()
        exercise_session_q = exercise_session_q.filter(ExerciseSession.date >= sd)
    if end_date:
        ed = datetime.fromisoformat(end_date).date()
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
        # Goal not met AND not exceeded - break streak
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
        for streak in streaks:
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
        
        today = date.today()
        needs_update = False
        will_increment = False
        
        # Check both streak types if not specified
        types_to_check = [streak_type] if streak_type else ['calories', 'exercise']
        
        result = {}
        for stype in types_to_check:
            if stype not in ['calories', 'exercise']:
                continue
            
            streak = get_or_create_streak(user, stype)
            
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