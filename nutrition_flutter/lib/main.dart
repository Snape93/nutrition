import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'my_app.dart';
import 'services/connectivity_service.dart';

void main() {
  // Ensure Flutter bindings are initialized before using any services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add error handling to catch widget errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }
  };
  
  // Initialize connectivity service after bindings are ready
  ConnectivityService.instance.initialize();
  
  runApp(MyApp());
}
