// Centralized API base URL for the Flutter app
// Uses --dart-define=API_BASE_URL to override per environment
// Defaults to localhost for development
const String apiBase = String.fromEnvironment(
  'API_BASE_URL',
  // Set your LAN IP as default for physical devices; override via --dart-define
  defaultValue: 'http://192.168.1.8:5000',
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
