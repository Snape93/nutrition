import csv
from pathlib import Path

CSV_PATH = Path('Nutrition/exercise_dataset.csv')

def main():
    rows = []
    with CSV_PATH.open('r', encoding='utf-8', newline='') as f:
        reader = csv.reader(f)
        for row in reader:
            rows.append(row)

    if not rows:
        return

    header = rows[0]
    # Ensure expected columns
    if header[:10] != [
        'id','name','category','body_part','target','equipment','difficulty','calories_per_minute','instructions','tags'
    ]:
        # if header was quoted, it will have been read correctly already; proceed anyway
        pass

    cleaned = [header]
    for row in rows[1:]:
        # Normalize row to exactly 10 columns using csv's parsing
        if len(row) < 10:
            # Skip malformed short rows
            continue
        # Copy first 8 fields as-is (without quotes when writing)
        base = row[:8]
        instructions = row[8].replace(',', ';')
        tags = row[9].replace(',', ';')
        cleaned.append(base + [instructions, tags])

    # Write out without quotes
    with CSV_PATH.open('w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, quoting=csv.QUOTE_NONE, escapechar='\\')
        writer.writerows(cleaned)

if __name__ == '__main__':
    main()



