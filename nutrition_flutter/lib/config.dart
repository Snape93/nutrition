// Centralized API base URL for the Flutter app.
// Uses --dart-define=API_BASE_URL to override per environment.
// Default behavior:
//   • All builds (debug/release) → Azure App Service (production)
//   • To use local dev server: override with --dart-define=API_BASE_URL=http://10.0.2.2:5000
const bool _isReleaseMode = bool.fromEnvironment('dart.vm.product');
// Primary backend URL (Azure App Service)
const String _prodApiBase = 'https://nutritionist-app-backend-dnbgf8bzf4h3hhhn.southeastasia-01.azurewebsites.net';
// For local testing on emulator: override with --dart-define=API_BASE_URL=http://10.0.2.2:5000
const String _devApiBase = 'http://10.0.2.2:5000';

const String apiBase = String.fromEnvironment(
  'API_BASE_URL',
  // Default to Azure for both debug and release builds
  // For local dev server testing, override with:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
  // For physical device with local server, use your PC's LAN IP:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
  defaultValue: _prodApiBase, // Always use Azure by default
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
