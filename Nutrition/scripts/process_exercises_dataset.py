#!/usr/bin/env python3
"""
Process the exercises.csv dataset to filter and sort cardio and strength exercises.
This script will:
1. Read the exercises.csv file
2. Filter exercises by category (Cardio and Strength)
3. Sort them alphabetically by name
4. Generate the processed data for the Flutter app
"""

import csv
import json
import os
from typing import List, Dict, Any

def read_exercises_csv(file_path: str) -> List[Dict[str, Any]]:
    """Read exercises from CSV file."""
    exercises = []
    
    with open(file_path, 'r', encoding='utf-8') as file:
        # Skip empty lines and read the CSV
        lines = [line for line in file if line.strip()]
        reader = csv.DictReader(lines)
        
        for row in reader:
            # Skip rows with empty id
            if not row.get('id', '').strip():
                continue
                
            # Clean up the data
            exercise = {
                'id': row['id'].strip(),
                'name': row['name'].strip(),
                'category': row['category'].strip(),
                'body_part': row['body_part'].strip(),
                'target': row['target'].strip(),
                'equipment': row['equipment'].strip(),
                'difficulty': row['difficulty'].strip(),
                'calories_per_minute': float(row['calories_per_minute']) if row['calories_per_minute'] else 0.0,
                'instructions': row['instructions'].strip(),
                'tags': row['tags'].strip()
            }
            exercises.append(exercise)
    
    return exercises

def filter_and_sort_exercises(exercises: List[Dict[str, Any]], category: str) -> List[Dict[str, Any]]:
    """Filter exercises by category and sort alphabetically."""
    filtered = [ex for ex in exercises if ex['category'].lower() == category.lower()]
    return sorted(filtered, key=lambda x: x['name'].lower())

def process_instructions(instructions_str: str) -> List[str]:
    """Process instructions string into a list of steps."""
    if not instructions_str:
        return []
    
    # Split by numbered steps (1., 2., etc.)
    steps = []
    current_step = ""
    
    for char in instructions_str:
        if char.isdigit() and (not current_step or current_step.endswith('.')):
            if current_step.strip():
                steps.append(current_step.strip())
            current_step = char
        else:
            current_step += char
    
    if current_step.strip():
        steps.append(current_step.strip())
    
    # Clean up steps
    cleaned_steps = []
    for step in steps:
        # Remove leading numbers and periods
        cleaned = step.strip()
        if cleaned and cleaned[0].isdigit():
            # Find the first non-digit, non-period character
            for i, char in enumerate(cleaned):
                if not char.isdigit() and char != '.':
                    cleaned = cleaned[i:].strip()
                    break
        
        if cleaned:
            cleaned_steps.append(cleaned)
    
    return cleaned_steps if cleaned_steps else [instructions_str]

def convert_to_flutter_format(exercises: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Convert exercises to Flutter app format."""
    flutter_exercises = []
    
    for exercise in exercises:
        flutter_exercise = {
            'id': exercise['id'],
            'name': exercise['name'],
            'category': exercise['category'],
            'bodyPart': exercise['body_part'],
            'target': exercise['target'],
            'equipment': exercise['equipment'],
            'difficulty': exercise['difficulty'],
            'estimatedCaloriesPerMinute': exercise['calories_per_minute'],
            'instructions': process_instructions(exercise['instructions']),
            'tags': exercise['tags'].split(',') if exercise['tags'] else [],
            'gifUrl': '',  # Will be populated later if needed
        }
        flutter_exercises.append(flutter_exercise)
    
    return flutter_exercises

def main():
    """Main function to process the exercises dataset."""
    # Get the current directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Path to the exercises CSV file
    csv_file_path = os.path.join(current_dir, '..', 'data', 'exercises.csv')
    
    if not os.path.exists(csv_file_path):
        print(f"Error: CSV file not found at {csv_file_path}")
        return
    
    print("Reading exercises from CSV...")
    exercises = read_exercises_csv(csv_file_path)
    print(f"Total exercises loaded: {len(exercises)}")
    
    # Filter and sort cardio exercises
    print("\nProcessing Cardio exercises...")
    cardio_exercises = filter_and_sort_exercises(exercises, 'Cardio')
    cardio_flutter = convert_to_flutter_format(cardio_exercises)
    print(f"Cardio exercises found: {len(cardio_exercises)}")
    
    # Filter and sort strength exercises
    print("\nProcessing Strength exercises...")
    strength_exercises = filter_and_sort_exercises(exercises, 'Strength')
    strength_flutter = convert_to_flutter_format(strength_exercises)
    print(f"Strength exercises found: {len(strength_exercises)}")
    
    # Create output directory
    output_dir = os.path.join(current_dir, '..', 'nutrition_flutter', 'lib', 'data')
    os.makedirs(output_dir, exist_ok=True)
    
    # Save cardio exercises
    cardio_output_path = os.path.join(output_dir, 'cardio_exercises.json')
    with open(cardio_output_path, 'w', encoding='utf-8') as f:
        json.dump(cardio_flutter, f, indent=2, ensure_ascii=False)
    print(f"Cardio exercises saved to: {cardio_output_path}")
    
    # Save strength exercises
    strength_output_path = os.path.join(output_dir, 'strength_exercises.json')
    with open(strength_output_path, 'w', encoding='utf-8') as f:
        json.dump(strength_flutter, f, indent=2, ensure_ascii=False)
    print(f"Strength exercises saved to: {strength_output_path}")
    
    # Save combined data
    combined_data = {
        'cardio': cardio_flutter,
        'strength': strength_flutter,
        'metadata': {
            'total_cardio': len(cardio_flutter),
            'total_strength': len(strength_flutter),
            'total_exercises': len(cardio_flutter) + len(strength_flutter),
            'processed_at': str(pd.Timestamp.now()) if 'pd' in globals() else 'unknown'
        }
    }
    
    combined_output_path = os.path.join(output_dir, 'exercises_dataset.json')
    with open(combined_output_path, 'w', encoding='utf-8') as f:
        json.dump(combined_data, f, indent=2, ensure_ascii=False)
    print(f"Combined dataset saved to: {combined_output_path}")
    
    # Print summary
    print("\n" + "="*50)
    print("PROCESSING SUMMARY")
    print("="*50)
    print(f"Total exercises processed: {len(exercises)}")
    print(f"Cardio exercises: {len(cardio_exercises)}")
    print(f"Strength exercises: {len(strength_exercises)}")
    print(f"Other categories: {len(exercises) - len(cardio_exercises) - len(strength_exercises)}")
    
    # Show first few exercises from each category
    print("\nFirst 5 Cardio exercises:")
    for i, exercise in enumerate(cardio_exercises[:5]):
        print(f"  {i+1}. {exercise['name']}")
    
    print("\nFirst 5 Strength exercises:")
    for i, exercise in enumerate(strength_exercises[:5]):
        print(f"  {i+1}. {exercise['name']}")
    
    print("\nProcessing complete!")

if __name__ == "__main__":
    main()
