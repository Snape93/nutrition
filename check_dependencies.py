"""Check if all required dependencies are installed"""
import sys

packages = {
    'xgboost': 'xgboost',
    'matplotlib': 'matplotlib',
    'seaborn': 'seaborn',
    'sklearn': 'sklearn',
    'pandas': 'pandas',
    'numpy': 'numpy',
    'joblib': 'joblib'
}

missing = []
installed = []

print("=" * 70)
print("CHECKING DEPENDENCIES")
print("=" * 70)

for display_name, import_name in packages.items():
    try:
        if import_name == 'sklearn':
            __import__('sklearn')
        else:
            __import__(import_name)
        print(f"[OK] {display_name}")
        installed.append(display_name)
    except ImportError:
        print(f"[MISSING] {display_name}")
        missing.append(display_name)

print("\n" + "=" * 70)
if missing:
    print(f"Missing packages: {', '.join(missing)}")
    print(f"\nInstall with: pip install {' '.join(missing)}")
    print("\n[WARNING] Training will work but some features may be unavailable")
else:
    print("All required packages are installed!")
    print("\n[SUCCESS] Ready to train!")

print("=" * 70)
















