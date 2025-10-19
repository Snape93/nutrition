import csv

with open('data/exercises.csv', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

print(f"Total exercises in new file: {len(rows)}")
print(f"\nFirst exercise:")
print(f"  ID: {rows[0]['id']}")
print(f"  Name: {rows[0]['name']}")
print(f"  Category: {rows[0]['category']}")
print(f"  Difficulty: {rows[0]['difficulty']}")
print(f"  Instructions (first 100 chars): {rows[0]['instructions'][:100]}...")
print(f"\nInstruction separator check:")
if ';' in rows[0]['instructions']:
    print("  [OK] Instructions use semicolon separator (compatible with app)")
else:
    print("  [WARNING] Instructions may not be properly formatted")

print(f"\nCategories available:")
categories = {}
for r in rows:
    cat = r['category']
    categories[cat] = categories.get(cat, 0) + 1
for cat, count in sorted(categories.items()):
    print(f"  - {cat}: {count} exercises")

