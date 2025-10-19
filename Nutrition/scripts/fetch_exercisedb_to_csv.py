import requests
import csv
import time
import json

def fetch_exercises_from_api():
    """
    Fetch exercises from ExerciseDB API and convert to CSV format
    """
    # Try multiple API endpoints
    api_versions = [
        "https://exercisedb.p.rapidapi.com/exercises",  # RapidAPI endpoint
        "https://raw.githubusercontent.com/ExerciseDB/exercisedb-api/main/api/v1/exercises.json",  # GitHub raw data
    ]
    
    exercises = []
    
    print("Fetching exercises from ExerciseDB API...")
    
    # Try the GitHub raw data first (no rate limits, open source V1)
    # Try different possible paths for the exercise data
    github_urls = [
        "https://raw.githubusercontent.com/ExerciseDB/exercisedb-api/main/api/v1/exercises.json",
        "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json",
        "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises.json",
    ]
    
    for url in github_urls:
        try:
            print(f"Trying GitHub endpoint: {url}")
            response = requests.get(url, timeout=30)
            
            if response.status_code == 200:
                exercises = response.json()
                print(f"Successfully fetched {len(exercises)} exercises from GitHub")
                return exercises
            else:
                print(f"  Status: {response.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    
    # If GitHub fails, try pagination approach (for other APIs)
    print("Trying alternative pagination approach...")
    base_url = "https://api.exercisedb.io/api/v1/exercises"
    page = 0
    limit = 100
    
    while True:
        try:
            time.sleep(1)
            offset = page * limit
            url = f"{base_url}?offset={offset}&limit={limit}"
            print(f"Fetching offset {offset}...")
            
            response = requests.get(url, timeout=10)
            
            if response.status_code != 200:
                print(f"Error: Status code {response.status_code}")
                break
            
            data = response.json()
            
            if not data or len(data) == 0:
                break
            
            exercises.extend(data)
            print(f"Fetched {len(data)} exercises. Total: {len(exercises)}")
            
            if len(data) < limit:
                break
            
            page += 1
            
        except Exception as e:
            print(f"Error: {e}")
            break
    
    return exercises

def map_exercise_to_csv_format(exercise):
    """
    Map ExerciseDB exercise format to our CSV format
    Handles both V1 and V2 formats and free-exercise-db format
    """
    # Handle different ID fields
    exercise_id = exercise.get('exerciseId', exercise.get('id', ''))
    
    # Handle body_part - could be from different sources
    body_part = exercise.get('bodyPart', '')
    if 'bodyParts' in exercise and isinstance(exercise['bodyParts'], list):
        body_part = '|'.join(exercise['bodyParts'])
    elif not body_part:
        # Use primaryMuscles as body_part if available
        primary = exercise.get('primaryMuscles', [])
        if isinstance(primary, list) and primary:
            body_part = '|'.join(primary)
    
    # Handle target muscles
    target = exercise.get('target', '')
    if 'targetMuscles' in exercise and isinstance(exercise['targetMuscles'], list):
        target = '|'.join(exercise['targetMuscles'])
    elif 'primaryMuscles' in exercise and isinstance(exercise['primaryMuscles'], list):
        target = '|'.join(exercise['primaryMuscles'])
    
    # Handle equipment
    equipment = exercise.get('equipment', '')
    if 'equipments' in exercise and isinstance(exercise['equipments'], list):
        equipment = '|'.join(exercise['equipments'])
    
    # Handle difficulty/level
    difficulty = exercise.get('level', exercise.get('difficulty', ''))
    
    # Get instructions
    instructions = exercise.get('instructions', [])
    if isinstance(instructions, list):
        instructions = ' | '.join(instructions)
    else:
        instructions = str(instructions) if instructions else ''
    
    # Get tags/keywords - use secondaryMuscles, force, mechanic as tags
    tags = []
    if 'keywords' in exercise:
        keywords = exercise['keywords']
        if isinstance(keywords, list):
            tags.extend(keywords[:5])
    else:
        # Build tags from available metadata
        if exercise.get('force'):
            tags.append(f"force:{exercise['force']}")
        if exercise.get('mechanic'):
            tags.append(f"mechanic:{exercise['mechanic']}")
        secondary = exercise.get('secondaryMuscles', [])
        if isinstance(secondary, list):
            tags.extend(secondary[:3])
    
    tags_str = '|'.join(tags) if tags else ''
    
    # Map fields from API to our CSV structure
    csv_row = {
        'id': exercise_id,
        'name': exercise.get('name', ''),
        'category': exercise.get('category', exercise.get('exerciseType', '')),
        'body_part': body_part,
        'target': target,
        'equipment': equipment,
        'difficulty': difficulty,
        'calories_per_minute': '',  # Not provided by API - would need calculation
        'instructions': instructions,
        'tags': tags_str
    }
    
    return csv_row

def save_to_csv(exercises, output_file):
    """
    Save exercises to CSV file
    """
    if not exercises:
        print("No exercises to save.")
        return
    
    fieldnames = ['id', 'name', 'category', 'body_part', 'target', 'equipment', 
                  'difficulty', 'calories_per_minute', 'instructions', 'tags']
    
    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        for exercise in exercises:
            csv_row = map_exercise_to_csv_format(exercise)
            writer.writerow(csv_row)
    
    print(f"Saved {len(exercises)} exercises to {output_file}")

def main():
    # Fetch exercises from API
    exercises = fetch_exercises_from_api()
    
    if exercises:
        # Save to JSON for backup
        with open('data/exercisedb_raw.json', 'w', encoding='utf-8') as f:
            json.dump(exercises, f, indent=2)
        print(f"Saved raw data to data/exercisedb_raw.json")
        
        # Save to CSV
        save_to_csv(exercises, 'data/exercisedb_exercises.csv')
    else:
        print("No exercises were fetched.")

if __name__ == "__main__":
    main()

