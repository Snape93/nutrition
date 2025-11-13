import csv

# Read the exercisedb CSV and convert instruction separators
input_file = 'data/exercisedb_exercises.csv'
output_file = 'data/exercises.csv'
backup_file = 'data/exercises_backup.csv'

# First, backup the current exercises.csv
import shutil
import os

if os.path.exists(output_file):
    print(f"Backing up current {output_file} to {backup_file}...")
    shutil.copy2(output_file, backup_file)
    print(f"[OK] Backup created")

# Now convert the new file
print(f"Converting {input_file} to replace {output_file}...")

with open(input_file, 'r', encoding='utf-8') as infile:
    reader = csv.DictReader(infile)
    rows = []
    
    for row in reader:
        # Convert instructions separator from " | " to ";"
        if row.get('instructions'):
            row['instructions'] = row['instructions'].replace(' | ', ';')
        rows.append(row)

# Write the converted data
fieldnames = ['id', 'name', 'category', 'body_part', 'target', 'equipment', 
              'difficulty', 'calories_per_minute', 'instructions', 'tags']

with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"[OK] Successfully replaced {output_file} with {len(rows)} exercises from ExerciseDB")
print(f"   Old file backed up to: {backup_file}")
print(f"\nSummary:")
print(f"  - Total exercises: {len(rows)}")
print(f"  - Categories: {len(set(r['category'] for r in rows if r['category']))}")
print(f"  - Difficulty levels: {sorted(set(r['difficulty'] for r in rows if r['difficulty']))}")

