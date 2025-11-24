# How to Run the Flutter App

## Prerequisites

1. **Flutter SDK** installed (check with `flutter doctor`)
2. **Android Studio** or **VS Code** with Flutter extensions
3. **Backend Flask server** running on `http://localhost:5000`

## Quick Start

### 1. Navigate to Flutter project directory
```powershell
cd nutrition_flutter
```

### 2. Get dependencies
```powershell
flutter pub get
```

### 3. Run the app

#### Option A: Android Emulator (Recommended for testing)
```powershell
# Make sure Android emulator is running first
flutter run
```

#### Option B: Physical Android Device
```powershell
# Connect your phone via USB with USB debugging enabled
# Use your computer's LAN IP address (e.g., 192.168.1.7)
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
```

#### Option C: iOS Simulator (Mac only)
```powershell
# Make sure iOS simulator is running first
flutter run
```

#### Option D: Chrome (Web)
```powershell
flutter run -d chrome
```

## Important Notes

### API Configuration

The app automatically uses:
- **Debug mode**: `http://10.0.2.2:5000` (Android emulator)
- **Release mode**: Production Railway URL

### For Physical Device Testing

If testing on a physical device, you need to:
1. Find your computer's local IP address:
   ```powershell
   ipconfig
   # Look for IPv4 Address (e.g., 192.168.1.7)
   ```

2. Make sure Flask server is accessible from your network:
   ```python
   # In app.py, Flask should run on:
   app.run(host='0.0.0.0', port=5000)
   ```

3. Run Flutter with your IP:
   ```powershell
   flutter run --dart-define=API_BASE_URL=http://YOUR_IP:5000
   ```

### Common Issues

1. **"No devices found"**
   - Start an emulator: `flutter emulators --launch <emulator_id>`
   - Or connect a physical device with USB debugging enabled

2. **"Connection refused"**
   - Make sure Flask server is running on port 5000
   - Check firewall settings
   - For physical device, use LAN IP instead of localhost

3. **"Package not found"**
   - Run `flutter pub get` again
   - Run `flutter clean` then `flutter pub get`

## Development Commands

```powershell
# Check Flutter setup
flutter doctor

# List available devices
flutter devices

# Run in debug mode (hot reload enabled)
flutter run

# Run in release mode
flutter run --release

# Build APK for Android
flutter build apk

# Build app bundle for Play Store
flutter build appbundle
```

## Hot Reload

While the app is running:
- Press `r` in terminal to hot reload
- Press `R` to hot restart
- Press `q` to quit










