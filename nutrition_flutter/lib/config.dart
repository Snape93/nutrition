// Centralized API base URL for the Flutter app
// Uses --dart-define=API_BASE_URL to override per environment
// Defaults to production Railway URL
const String apiBase = String.fromEnvironment(
  'API_BASE_URL',
  // Production: Railway deployment
  // For local development, override via: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
  // For Android emulator, use 10.0.2.2 (maps to host localhost)
  // For physical device, use your computer's LAN IP (e.g., 192.168.1.5)
  defaultValue: 'https://web-production-e167.up.railway.app', // Production Railway URL
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
