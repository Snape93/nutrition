# pyright: reportCallIssue=false
from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np
import pandas as pd
from nutrition_model import NutritionModel
import os
import json
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date, timedelta
from dotenv import load_dotenv
import requests
import re
from config import config
from werkzeug.security import generate_password_hash, check_password_hash
import csv

# Load environment variables
load_dotenv()

"""
Deprecated: External ExerciseDB seeding has been removed in favor of a curated local dataset.
"""

def local_seed_exercises():
    """Return a small, offline seed list of exercises for each category."""
    return [
        # Cardio
        {"id": "loc_cardio_1", "name": "Jumping Jacks", "bodyPart": "cardio", "equipment": "body weight", "target": "cardiovascular", "gifUrl": "", "instructions": ["Stand tall","Jump legs apart and raise arms","Return and repeat"]},
        {"id": "loc_cardio_2", "name": "High Knees", "bodyPart": "cardio", "equipment": "body weight", "target": "cardiovascular", "gifUrl": "", "instructions": ["Run in place","Drive knees high"]},
        {"id": "loc_cardio_3", "name": "Mountain Climbers", "bodyPart": "cardio", "equipment": "body weight", "target": "core", "gifUrl": "", "instructions": ["Plank position","Alternate knee drives"]},
        {"id": "loc_cardio_4", "name": "Burpees", "bodyPart": "cardio", "equipment": "body weight", "target": "full body", "gifUrl": "", "instructions": ["Squat","Kick back","Push-up (optional)","Jump up"]},
        # Strength
        {"id": "loc_strength_1", "name": "Push-up", "bodyPart": "chest", "equipment": "body weight", "target": "pectorals", "gifUrl": "", "instructions": ["Plank","Lower chest","Press up"]},
        {"id": "loc_strength_2", "name": "Bodyweight Squat", "bodyPart": "upper legs", "equipment": "body weight", "target": "glutes", "gifUrl": "", "instructions": ["Feet shoulder-width","Sit back","Stand"]},
        {"id": "loc_strength_3", "name": "Lunge", "bodyPart": "upper legs", "equipment": "body weight", "target": "quads", "gifUrl": "", "instructions": ["Step forward","Lower knee","Return"]},
        {"id": "loc_strength_4", "name": "Plank", "bodyPart": "waist", "equipment": "body weight", "target": "abs", "gifUrl": "", "instructions": ["Elbows under shoulders","Hold neutral line"]},
        # Flexibility/Mobility
        {"id": "loc_flex_1", "name": "Hamstring Stretch", "bodyPart": "leg", "equipment": "body weight", "target": "flexibility", "gifUrl": "", "instructions": ["Hinge at hips","Hold stretch"]},
        {"id": "loc_flex_2", "name": "Cat-Cow", "bodyPart": "back", "equipment": "body weight", "target": "mobility", "gifUrl": "", "instructions": ["Arch and round spine","Breathe"]},
        {"id": "loc_flex_3", "name": "Child's Pose", "bodyPart": "back", "equipment": "body weight", "target": "yoga", "gifUrl": "", "instructions": ["Hips to heels","Arms forward","Relax"]},
        {"id": "loc_flex_4", "name": "Hip Flexor Stretch", "bodyPart": "hip", "equipment": "body weight", "target": "flexibility", "gifUrl": "", "instructions": ["Half-kneel","Shift forward","Hold"]},
    ]

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

def categorize_exercise(exercise_data):
    """Categorize exercise based on name, body part, and target into 3 buckets."""
    name_lower = exercise_data.get('name', '').lower()
    body_part = exercise_data.get('bodyPart', '').lower()
    target = exercise_data.get('target', '').lower()

    # Cardio: explicit cardio or common cardio verbs/contexts, sports, dance
    if (
        body_part == 'cardio'
        or 'run' in name_lower
        or 'jump' in name_lower
        or 'bike' in name_lower
        or 'cycle' in name_lower
        or 'cardio' in name_lower
        or 'zumba' in name_lower
        or 'dance' in name_lower
        or 'salsa' in name_lower
        or 'basketball' in name_lower
        or 'soccer' in name_lower
        or 'tennis' in name_lower
        or 'volleyball' in name_lower
        or 'sport' in name_lower
    ):
        return 'Cardio'

    # Flexibility/Mobility: yoga, stretch, mobility, flexibility
    if (
        'yoga' in name_lower
        or 'pose' in name_lower
        or 'meditation' in name_lower
        or 'stretch' in name_lower
        or 'mobility' in name_lower
        or 'flexibility' in name_lower
        or 'yoga' in target
        or 'flexibility' in target
    ):
        return 'Flexibility/Mobility'

    # Default bucket: Strength
    return 'Strength'

def get_difficulty_level(equipment):
    """Determine difficulty level based on equipment"""
    equipment_lower = equipment.lower()
    if equipment_lower == 'body weight':
        return 'Beginner'
    elif equipment_lower in ['barbell', 'dumbbell', 'kettlebell']:
        return 'Intermediate'
    else:
        return 'Advanced'

def get_calories_per_minute(category):
    """Get estimated calories burned per minute by 3-category model."""
    calories_map = {
        'Cardio': 8,
        'Strength': 5,
        'Flexibility/Mobility': 3,
    }
    return calories_map.get(category, 5)  # Default to Strength if unknown

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
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

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
    # Auto-seed exercises on first run if database is empty
    try:
        if Exercise.query.count() == 0:
            print("[INFO] No exercises found. Importing from local CSV dataset...")
            csv_path = os.path.join(os.path.dirname(__file__), 'data', 'exercises.csv')
            added, updated = _import_exercises_from_csv_path(csv_path)
            if added == 0 and updated == 0:
                print("[WARNING] CSV not found or invalid; seeding minimal offline set.")
                exercises_data = local_seed_exercises()
                for exercise_data in exercises_data:
                    try:
                        ex = Exercise(
                            exercise_id=exercise_data.get('id'),
                            name=exercise_data.get('name', ''),
                            body_part=exercise_data.get('bodyPart', ''),
                            equipment=exercise_data.get('equipment', ''),
                            target=exercise_data.get('target', ''),
                            gif_url=exercise_data.get('gifUrl', ''),
                            instructions=json.dumps(exercise_data.get('instructions', [])),
                            category=categorize_exercise(exercise_data),
                            difficulty=get_difficulty_level(exercise_data.get('equipment', '')),
                            estimated_calories_per_minute=get_calories_per_minute(categorize_exercise(exercise_data))
                        )
                        db.session.add(ex)
                    except Exception:
                        continue
                db.session.commit()
                print("[SUCCESS] Seeded minimal offline set.")
            else:
                print(f"[SUCCESS] Imported exercises from CSV (added={added}, updated={updated}).")
    except Exception as e:
        print(f"[WARNING] Exercise seeding skipped: {e}")

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
        'body recomposition': 'body recomposition',
        'athletic performance': 'athletic performance',
    }
    return mapping.get(g, 'maintain')

ALLOWED_ACTIVITY_LEVELS = {'sedentary', 'lightly active', 'active', 'very active'}
ALLOWED_GOALS = {
    'maintain', 'lose weight', 'gain muscle', 'gain weight', 'body recomposition', 'athletic performance'
}

def validate_metrics(age: int, weight_kg: float, height_cm: float) -> tuple[bool, str]:
    if age is None:
        return False, 'Age is required'
    if not (13 <= int(age) <= 120):
        return False, 'Age must be between 13 and 120 years'
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

@app.route('/exercises/sync', methods=['POST'])
def sync_exercises():
    """Deprecated passthrough: populate from local CSV instead of external API."""
    try:
        csv_path = os.path.join(os.path.dirname(__file__), 'data', 'exercises.csv')
        added, updated = _import_exercises_from_csv_path(csv_path)
        return jsonify({
            'success': True,
            'message': f'Imported from CSV (added={added}, updated={updated})',
            'total_exercises': Exercise.query.count()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

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

        # If this category is underpopulated, opportunistically seed locally and retry once
        if category and len(exercises) < 10:
            try:
                seeds = local_seed_exercises()
                wanted = normalize_category(category)
                added = 0
                for exd in seeds:
                    cat = categorize_exercise(exd)
                    if cat != wanted:
                        continue
                    exists = Exercise.query.filter_by(exercise_id=exd.get('id')).first()
                    if exists:
                        continue
                    ex = Exercise(
                        exercise_id=exd.get('id'),
                        name=exd.get('name', ''),
                        body_part=exd.get('bodyPart', ''),
                        equipment=exd.get('equipment', ''),
                        target=exd.get('target', ''),
                        gif_url=exd.get('gifUrl', ''),
                        instructions=json.dumps(exd.get('instructions', [])),
                        category=cat,
                        difficulty=get_difficulty_level(exd.get('equipment', '')),
                        estimated_calories_per_minute=get_calories_per_minute(cat)
                    )
                    db.session.add(ex)
                    added += 1
                if added > 0:
                    db.session.commit()
                    query = Exercise.query
                    if category:
                        aliases = category_aliases(category)
                        query = query.filter(Exercise.category.in_(aliases))
                    exercises = query.order_by(Exercise.name.asc()).limit(limit).all()
            except Exception:
                pass
        
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

@app.route('/exercises/import', methods=['POST'])
def import_exercises_from_csv():
    """Import exercises from a local CSV file path or default data/exercises.csv.

    Accepts optional JSON body: { "path": "absolute/or/relative/path.csv" }
    Columns required: id,name,category,body_part,target,equipment,difficulty,calories_per_minute,instructions,tags
    """
    try:
        body = request.get_json(silent=True) or {}
        csv_path = body.get('path') or os.path.join(os.path.dirname(__file__), 'data', 'exercises.csv')
        if not os.path.isabs(csv_path):
            csv_path = os.path.join(os.path.dirname(__file__), csv_path)
        if not os.path.exists(csv_path):
            return jsonify({ 'success': False, 'error': f'CSV not found: {csv_path}' }), 400

        added = 0
        updated = 0
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            required = {
                'id','name','category','body_part','target','equipment','difficulty','calories_per_minute','instructions','tags'
            }
            if not required.issubset(set([c.strip() for c in reader.fieldnames or []])):
                return jsonify({ 'success': False, 'error': 'CSV missing required headers' }), 400
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
        return jsonify({ 'success': True, 'added': added, 'updated': updated, 'total_exercises': Exercise.query.count() })
    except Exception as e:
        db.session.rollback()
        return jsonify({ 'success': False, 'error': str(e) }), 500

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
            nut = lookup_nutrition(food_name, grams, quantity)
            log = FoodLog(
                user=data.get('user', 'default'),
                food_name=food_name,
                meal_type=food.get('meal_type', 'unspecified'),
                serving_size=serving_size_str,
                quantity=quantity,
                calories=nut['calories'] if nut else food.get('calories', 0),
                protein=nut['protein'] if nut else food.get('protein', 0),
                carbs=nut['carbs'] if nut else food.get('carbs', 0),
                fat=nut['fat'] if nut else food.get('fat', 0),
                fiber=nut['fiber'] if nut else food.get('fiber', 0),
                sodium=nut['sodium'] if nut else food.get('sodium', 0),
                date=datetime.fromisoformat(food.get('timestamp', datetime.utcnow().isoformat()))
            )
            db.session.add(log)
            db.session.flush()  # Get log.id before commit
            log_ids.append(log.id)
        db.session.commit()
        return jsonify({'success': True, 'ids': log_ids})
    # Fallback: single food log (legacy)
    food_name = data.get('food_name')
    serving_size_str = data.get('serving_size', '100g')
    quantity = float(data.get('quantity', 1))
    grams = parse_grams(serving_size_str)
    nut = lookup_nutrition(food_name, grams, quantity)
    log = FoodLog(
        user=data.get('user', 'default'),
        food_name=food_name,
        meal_type=data.get('meal_type', 'unspecified'),
        serving_size=serving_size_str,
        quantity=quantity,
        calories=nut['calories'] if nut else data.get('calories', 0),
        protein=nut['protein'] if nut else data.get('protein', 0),
        carbs=nut['carbs'] if nut else data.get('carbs', 0),
        fat=nut['fat'] if nut else data.get('fat', 0),
        fiber=nut['fiber'] if nut else data.get('fiber', 0),
        sodium=nut['sodium'] if nut else data.get('sodium', 0),
        date=datetime.strptime(data.get('date', datetime.utcnow().strftime('%Y-%m-%d')), '%Y-%m-%d')
    )
    db.session.add(log)
    db.session.commit()
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
    return jsonify({
        'logs': [
            {
                'id': log.id,
                'food_name': log.food_name,
                'meal_type': log.meal_type,
                'serving_size': log.serving_size,
                'quantity': log.quantity,
                'calories': log.calories,
                'protein': log.protein,
                'carbs': log.carbs,
                'fat': log.fat,
                'fiber': log.fiber,
                'sodium': log.sodium
            } for log in logs
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
    age = data.get('age', 25)
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
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Extract required fields
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        full_name = data.get('full_name')
        
        # For simplified registration, use defaults for missing fields
        age = data.get('age', 25)
        sex = data.get('sex', 'male')
        weight_kg = data.get('weight_kg', 70)
        height_cm = data.get('height_cm', 170)
        activity_level = data.get('activity_level', 'active')
        goal = data.get('goal', 'maintain')
        
        # Validate required fields
        if not username:
            return jsonify({'error': 'Username is required'}), 400
        
        # Check if user already exists
        existing_user = User.query.filter_by(username=username).first()
        if existing_user:
            return jsonify({'success': False, 'message': 'Username already exists'}), 409
        
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
        
        # Create new user (hash password for security)
        hashed_password = generate_password_hash(password) if password else None
        new_user = User(
            username=username,
            email=data.get('email'),
            password=hashed_password,
            age=age,
            sex=sex,
            weight_kg=weight_kg,
            height_cm=height_cm,
            activity_level=activity_level,
            goal=goal,
            target_weight=data.get('target_weight'),
            timeline=data.get('timeline'),
            motivation=data.get('motivation'),
            experience=data.get('experience'),
            current_state=data.get('current_state'),
            schedule=data.get('schedule'),
            exercise_types=str(data.get('exercise_types', [])) if data.get('exercise_types') else None,
            exercise_equipment=str(data.get('exercise_equipment', [])) if data.get('exercise_equipment') else None,
            exercise_experience=data.get('exercise_experience'),
            exercise_limitations=data.get('exercise_limitations'),
            workout_duration=data.get('workout_duration'),
            workout_frequency=data.get('workout_frequency'),
            diet_type=data.get('diet_type'),
            restrictions=str(data.get('restrictions', [])) if data.get('restrictions') else None,
            allergies=str(data.get('allergies', [])) if data.get('allergies') else None,
            cooking_frequency=data.get('cooking_frequency'),
            cooking_skill=data.get('cooking_skill'),
            meal_prep_habit=data.get('meal_prep_habit'),
            tracking_experience=data.get('tracking_experience'),
            used_apps=str(data.get('used_apps', [])) if data.get('used_apps') else None,
            data_importance=data.get('data_importance'),
            is_metric=data.get('is_metric', True),
            daily_calorie_goal=daily_calorie_goal
        )
        
        # Save to database
        db.session.add(new_user)
        db.session.commit()
        
        print(f"[SUCCESS] User registered successfully: {username}, Daily calories: {daily_calorie_goal}")
        
        return jsonify({
            'success': True,
            'message': 'User registered successfully',
            'user_id': new_user.id,
            'username': username,
            'daily_calorie_goal': daily_calorie_goal
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Registration failed: {e}")
        return jsonify({'error': f'Registration failed: {str(e)}'}), 500

@app.route('/login', methods=['POST'])
def login_user():
    """Login user with username/email and password"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        username_or_email = data.get('username_or_email')
        password = data.get('password')
        
        if not username_or_email or not password:
            return jsonify({'error': 'Username/email and password are required'}), 400
        
        # Find user by username or email
        user = User.query.filter(
            (User.username == username_or_email) | (User.email == username_or_email)
        ).first()
        
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
                'has_seen_tutorial': True  # Default to True for now
            }
        }), 200
        
    except Exception as e:
        print(f"[ERROR] Login failed: {e}")
        return jsonify({'error': f'Login failed: {str(e)}'}), 500

@app.route('/user/<username>', methods=['GET'])
def get_user(username):
    """Get user profile data by username"""
    try:
        user = User.query.filter_by(username=username).first()
        
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
        user = User.query.filter_by(username=username).first()
        
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

@app.route('/foods/recommend', methods=['GET'])
def recommend_foods():
    user = request.args.get('user', 'default')
    meal_type = request.args.get('meal_type', '').lower()  # e.g., 'breakfast', 'lunch', etc.
    user_obj = User.query.filter_by(username=user).first()
    if user_obj:
        age = user_obj.age
        sex = user_obj.sex
        weight_kg = user_obj.weight_kg
        height_cm = user_obj.height_cm
        activity_level = user_obj.activity_level
        goal = user_obj.goal
        def parse_list(val):
            if not val or val == '[]':
                return []
            try:
                return eval(val) if val.startswith('[') else val.split(',')
            except:
                return []
        dietary_preferences = parse_list(getattr(user_obj, 'dietary_preferences', None))
        allergies = parse_list(getattr(user_obj, 'allergies', None))
        dislikes = parse_list(getattr(user_obj, 'dislikes', None))
        restrictions = parse_list(getattr(user_obj, 'restrictions', None))
        medical_history = parse_list(getattr(user_obj, 'medical_history', None))
        all_preferences = list(set(dietary_preferences + restrictions + dislikes))
        rec = nutrition_model.recommend_meals(
            user_gender=sex,
            user_age=age,
            user_weight=weight_kg,
            user_height=height_cm,
            user_activity_level=activity_level,
            user_goal=goal,
            dietary_preferences=all_preferences,
            medical_history=medical_history + allergies
        )
        meal_plan = rec.get('meal_plan', {})
        foods = []
        if meal_type and meal_type in meal_plan:
            foods = meal_plan[meal_type].get('foods', [])
        else:
            for meal in ['breakfast', 'lunch', 'dinner', 'snacks']:
                foods.extend(meal_plan.get(meal, {}).get('foods', []))
        # Remove duplicates, keep order
        seen = set()
        unique_foods = []
        for food in foods:
            if food not in seen:
                seen.add(food)
                unique_foods.append(food)
        recs = []
        for food_name in unique_foods:
            match = food_df[food_df['Food Name'].str.lower() == food_name.lower()]
            if not match.empty:
                recs.append(match.iloc[0].to_dict())
            if len(recs) >= 8:
                break
        # Fallback: most popular foods for that meal type if available
        if len(recs) < 8:
            if meal_type:
                # Try to get popular foods for this meal type
                meal_col = 'Meal Type' if 'Meal Type' in food_df.columns else None
                if meal_col:
                    popular = food_df[food_df[meal_col].str.lower() == meal_type].head(8 - len(recs)).to_dict(orient='records')
                    recs.extend(popular)
            # If still not enough, fallback to any popular foods
            if len(recs) < 8:
                popular = food_df.head(8 - len(recs)).to_dict(orient='records')
                recs.extend(popular)
        # Final deduplication
        final_seen = set()
        final_recs = []
        for food in recs:
            food_name = food.get('Food Name', '').lower()
            if food_name and food_name not in final_seen:
                final_seen.add(food_name)
                final_recs.append(food)
        return jsonify({'recommended': final_recs})
    # If no user profile, fallback to old logic
    logs = (
        FoodLog.query.filter_by(user=user)
        .order_by(FoodLog.date.desc())
        .all()
    )
    seen = set()
    recs = []
    for log in logs:
        if log.food_name not in seen:
            match = food_df[food_df['Food Name'].str.lower() == log.food_name.lower()]
            if not match.empty:
                recs.append(match.iloc[0].to_dict())
                seen.add(log.food_name)
        if len(recs) >= 8:
            break
    if len(recs) < 8:
        popular = food_df.head(8 - len(recs)).to_dict(orient='records')
        recs.extend(popular)
    # Final deduplication for fallback
    final_seen = set()
    final_recs = []
    for food in recs:
        food_name = food.get('Food Name', '').lower()
        if food_name and food_name not in final_seen:
            final_seen.add(food_name)
            final_recs.append(food)
    return jsonify({'recommended': final_recs})

# --- Progress Endpoints ---
@app.route('/progress/weight')
def progress_weight():
    user = request.args.get('user')
    logs = WeightLog.query.filter_by(user=user).order_by(WeightLog.date).all()
    return jsonify([
        {'date': log.date.isoformat(), 'weight': log.weight}
        for log in logs
    ])

@app.route('/progress/calories')
def progress_calories():
    user = request.args.get('user')
    logs = FoodLog.query.filter_by(user=user).order_by(FoodLog.date).all()
    return jsonify([
        {'date': log.date.isoformat(), 'calories': log.calories}
        for log in logs
    ])

@app.route('/progress/workouts')
def progress_workouts():
    user = request.args.get('user')
    logs = WorkoutLog.query.filter_by(user=user).order_by(WorkoutLog.date).all()
    return jsonify([
        {'date': log.date.isoformat(), 'type': log.type, 'duration': log.duration, 'calories_burned': log.calories_burned}
        for log in logs
    ])

@app.route('/progress/summary')
def progress_summary():
    user = request.args.get('user')
    latest_weight = WeightLog.query.filter_by(user=user).order_by(WeightLog.date.desc()).first()
    total_calories = db.session.query(db.func.sum(FoodLog.calories)).filter_by(user=user).scalar() or 0
    total_workouts = WorkoutLog.query.filter_by(user=user).count()
    return jsonify({
        'calories': total_calories,
        'weight': latest_weight.weight if latest_weight else None,
        'workouts': total_workouts,
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

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True) 