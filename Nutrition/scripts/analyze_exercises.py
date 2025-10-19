import csv

with open('data/exercisedb_exercises.csv', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

print(f"Total exercises: {len(rows)}")
print(f"\nCategories: {sorted(set(r['category'] for r in rows if r['category']))}")
print(f"\nDifficulty levels: {sorted(set(r['difficulty'] for r in rows if r['difficulty']))}")
print(f"\nEquipment types ({len(set(r['equipment'] for r in rows if r['equipment']))} unique):")
equipment_types = sorted(set(r['equipment'] for r in rows if r['equipment']))
for eq in equipment_types:
    count = sum(1 for r in rows if r['equipment'] == eq)
    print(f"  - {eq}: {count}")

print(f"\nBody parts covered:")
body_parts = {}
for r in rows:
    if r['body_part']:
        for bp in r['body_part'].split('|'):
            body_parts[bp] = body_parts.get(bp, 0) + 1
for bp, count in sorted(body_parts.items(), key=lambda x: x[1], reverse=True)[:15]:
    print(f"  - {bp}: {count}")

