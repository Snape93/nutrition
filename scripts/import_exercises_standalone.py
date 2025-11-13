"""
Standalone script to import exercises directly into the database
"""
import sqlite3
import csv
import json
import os
from datetime import datetime

db_path = 'instance/nutrition.db'
csv_path = 'data/exercises.csv'

if not os.path.exists(csv_path):
    print(f"CSV file not found: {csv_path}")
    exit(1)

print(f"Importing exercises from {csv_path}...")
print(f"Target database: {db_path}")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

added = 0
updated = 0
errors = 0

with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for row in reader:
        try:
            exercise_id = row.get('id')
            name = row.get('name', '')
            body_part = row.get('body_part', '')
            equipment = row.get('equipment', '')
            target = row.get('target', '')
            category = row.get('category', '')
            difficulty = row.get('difficulty', '')
            
            # Parse instructions into JSON array
            instructions_text = row.get('instructions', '')
            instructions = [s.strip() for s in instructions_text.split(';') if s.strip()]
            instructions_json = json.dumps(instructions)
            
            # Parse calories
            try:
                calories = int(float(row.get('calories_per_minute', '5')))
            except:
                calories = 5
            
            # Check if exercise already exists
            cursor.execute('SELECT id FROM exercises WHERE exercise_id = ?', (exercise_id,))
            existing = cursor.fetchone()
            
            if existing:
                # Update existing
                cursor.execute('''
                    UPDATE exercises 
                    SET name=?, body_part=?, equipment=?, target=?, instructions=?, 
                        category=?, difficulty=?, estimated_calories_per_minute=?
                    WHERE exercise_id=?
                ''', (name, body_part, equipment, target, instructions_json, 
                      category, difficulty, calories, exercise_id))
                updated += 1
            else:
                # Insert new
                cursor.execute('''
                    INSERT INTO exercises 
                    (exercise_id, name, body_part, equipment, target, gif_url, 
                     instructions, category, difficulty, estimated_calories_per_minute, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (exercise_id, name, body_part, equipment, target, '',
                      instructions_json, category, difficulty, calories, datetime.utcnow()))
                added += 1
                
            if (added + updated) % 100 == 0:
                print(f"  Processed: {added + updated} exercises...")
                
        except Exception as e:
            errors += 1
            if errors <= 5:  # Only show first 5 errors
                print(f"  Error with {row.get('id', 'unknown')}: {e}")

conn.commit()
conn.close()

print("\n" + "="*60)
print("[OK] Import completed!")
print("="*60)
print(f"  Added: {added} exercises")
print(f"  Updated: {updated} exercises")
print(f"  Errors: {errors} exercises")
print(f"  Total: {added + updated} exercises in database")

