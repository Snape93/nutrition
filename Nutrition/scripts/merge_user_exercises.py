import os
import csv
from datetime import datetime
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

# This script is intended to be run with the project root as CWD

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///instance/nutrition.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


class UserExerciseSubmission(db.Model):
  __tablename__ = 'user_exercise_submissions'
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
  status = db.Column(db.String(20), default='pending')
  created_at = db.Column(db.DateTime, default=datetime.utcnow)


CSV_PATH = os.path.join('Nutrition', 'data', 'exercises.csv')


def main():
  with app.app_context():
    # Fetch approved submissions
    subs = UserExerciseSubmission.query.filter_by(status='approved').all()
    if not subs:
      print('No approved submissions found.')
      return

    # Ensure CSV exists and read header
    exists = os.path.exists(CSV_PATH)
    if not exists:
      raise SystemExit(f'CSV not found at {CSV_PATH}.')

    # Append normalized rows
    appended = 0
    with open(CSV_PATH, 'a', newline='', encoding='utf-8') as f:
      writer = csv.writer(f)
      for s in subs:
        row = [
          f'user_{s.id}',
          s.name,
          (s.category or 'Strength'),
          '',  # body_part unknown
          '',  # target unknown
          'body weight',
          'Beginner',
          s.est_calories or 5,
          'User submitted',
          'source:user',
        ]
        writer.writerow(row)
        appended += 1
    print(f'Appended {appended} exercises. Remember to mark them as merged or change status to archived.')


if __name__ == '__main__':
  main()









