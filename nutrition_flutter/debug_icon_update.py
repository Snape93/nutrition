#!/usr/bin/env python3
"""
Debug script to verify launcher icon updates.
Checks icon file timestamps and sizes before/after generation.
"""

import os
import sys
import hashlib
import subprocess
from pathlib import Path
from datetime import datetime

def get_file_hash(filepath):
    """Calculate MD5 hash of a file."""
    hash_md5 = hashlib.md5()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception:
        return None

def get_file_info(filepath):
    """Get file information."""
    try:
        path = Path(filepath)
        if path.exists():
            stat = path.stat()
            return {
                'exists': True,
                'size': stat.st_size,
                'last_write': datetime.fromtimestamp(stat.st_mtime),
                'hash': get_file_hash(filepath)
            }
    except Exception:
        pass
    return {
        'exists': False,
        'size': 0,
        'last_write': None,
        'hash': None
    }

def format_size(size_bytes):
    """Format file size in KB."""
    return f"{size_bytes / 1024:.2f} KB"

def main():
    print("\n🔍 Launcher Icon Debug Tool")
    print("=" * 50)
    
    # Get script directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    # Read pubspec.yaml to get source icon
    source_icon = "design/logo.png"
    adaptive_foreground = "design/logo.png"
    
    pubspec_path = Path("pubspec.yaml")
    if pubspec_path.exists():
        content = pubspec_path.read_text()
        import re
        match = re.search(r"image_path:\s*['\"]([^'\"]+)['\"]", content)
        if match:
            source_icon = match.group(1)
        match = re.search(r"adaptive_icon_foreground:\s*['\"]([^'\"]+)['\"]", content)
        if match:
            adaptive_foreground = match.group(1)
    
    print(f"\n📋 Configuration Check:")
    print(f"  Source icon: {source_icon}")
    print(f"  Adaptive foreground: {adaptive_foreground}")
    
    # Check source file
    print(f"\n📁 Source Icon File:")
    source_path = Path(source_icon)
    if source_path.exists():
        source_info = get_file_info(source_icon)
        print(f"  ✅ File exists: {source_icon}")
        print(f"  📏 Size: {format_size(source_info['size'])}")
        print(f"  🕐 Last Modified: {source_info['last_write']}")
        print(f"  🔑 MD5: {source_info['hash']}")
    else:
        print(f"  ❌ Source file not found: {source_icon}")
        sys.exit(1)
    
    # Icon file locations to check
    icon_locations = [
        {"path": "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", "name": "Android MDPI"},
        {"path": "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", "name": "Android HDPI"},
        {"path": "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", "name": "Android XHDPI"},
        {"path": "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", "name": "Android XXHDPI"},
        {"path": "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", "name": "Android XXXHDPI"},
        {"path": "android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png", "name": "Adaptive MDPI"},
        {"path": "android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png", "name": "Adaptive HDPI"},
        {"path": "android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png", "name": "Adaptive XHDPI"},
        {"path": "android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png", "name": "Adaptive XXHDPI"},
        {"path": "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png", "name": "Adaptive XXXHDPI"},
    ]
    
    # Store before state
    print(f"\n📊 Current Icon Files Status:")
    before_state = {}
    for icon in icon_locations:
        info = get_file_info(icon["path"])
        before_state[icon["path"]] = info
        if info['exists']:
            print(f"  ✅ {icon['name']}: {format_size(info['size'])} - {info['last_write']}")
        else:
            print(f"  ❌ {icon['name']}: NOT FOUND")
    
    # Check if we should generate icons
    generate = "--generate" in sys.argv or "-g" in sys.argv
    
    if generate:
        print(f"\n🔄 Generating Icons...")
        print(f"  Running: flutter pub run flutter_launcher_icons")
        
        start_time = datetime.now()
        try:
            result = subprocess.run(
                ["flutter", "pub", "run", "flutter_launcher_icons"],
                capture_output=True,
                text=True,
                check=True
            )
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            print(f"  ✅ Icon generation completed in {duration:.2f} seconds")
            if result.stdout:
                print(f"  Output: {result.stdout[:200]}...")
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Icon generation failed!")
            print(f"  Error: {e.stderr}")
            sys.exit(1)
        except FileNotFoundError:
            print(f"  ❌ Flutter not found! Make sure Flutter is in your PATH")
            sys.exit(1)
        
        # Wait a moment for file system to sync
        import time
        time.sleep(1)
        
        # Check after state
        print(f"\n📊 Icon Files Status After Generation:")
        after_state = {}
        changes_detected = False
        
        for icon in icon_locations:
            after_info = get_file_info(icon["path"])
            after_state[icon["path"]] = after_info
            before_info = before_state[icon["path"]]
            
            if after_info['exists']:
                if before_info['exists']:
                    if before_info['hash'] != after_info['hash']:
                        print(f"  🔄 {icon['name']}: CHANGED")
                        print(f"     Size: {format_size(before_info['size'])} → {format_size(after_info['size'])}")
                        print(f"     Time: {before_info['last_write']} → {after_info['last_write']}")
                        changes_detected = True
                    else:
                        print(f"  ⏸️  {icon['name']}: UNCHANGED")
                else:
                    print(f"  ✨ {icon['name']}: CREATED ({format_size(after_info['size'])})")
                    changes_detected = True
            else:
                print(f"  ❌ {icon['name']}: STILL MISSING")
        
        print(f"\n📈 Summary:")
        if changes_detected:
            print(f"  ✅ Icons were updated successfully!")
            print(f"  💡 Next steps:")
            print(f"     1. Rebuild the app: flutter build apk")
            print(f"     2. Uninstall old app from device")
            print(f"     3. Install new build to see updated icon")
        else:
            print(f"  ⚠️  No changes detected - icons may already be up to date")
            print(f"  💡 Try modifying the source icon file and run again")
    else:
        print(f"\n💡 To generate/update icons, run:")
        print(f"   python debug_icon_update.py --generate")
        print(f"   or")
        print(f"   python debug_icon_update.py -g")
    
    print()

if __name__ == "__main__":
    main()






