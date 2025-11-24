// Centralized API base URL for the Flutter app.
// Uses --dart-define=API_BASE_URL to override per environment.
// Default behavior:
//   • Release/profile builds  → Production Railway URL
//   • Debug builds            → Local dev server (Android emulator 10.0.2.2)
const bool _isReleaseMode = bool.fromEnvironment('dart.vm.product');
const String _prodApiBase = 'https://web-production-e167.up.railway.app';
const String _devApiBase = 'http://10.0.2.2:5000';

const String apiBase = String.fromEnvironment(
  'API_BASE_URL',
  // For physical device testing, override with LAN IP:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
  defaultValue: _isReleaseMode ? _prodApiBase : _devApiBase,
);

// ExerciseDB (RapidAPI) configuration
// Provide your key at build time:
// flutter run --dart-define=RAPIDAPI_KEY=YOUR_API_KEY
const String exerciseDbBaseUrl = 'https://exercisedb.p.rapidapi.com';
const String exerciseDbHost = 'exercisedb.p.rapidapi.com';
const String rapidApiKey = String.fromEnvironment(
  'RAPIDAPI_KEY',
  defaultValue: '',
);
