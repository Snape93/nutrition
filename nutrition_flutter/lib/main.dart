import 'package:flutter/material.dart';
import 'my_app.dart';
import 'services/connectivity_service.dart';

void main() {
  // Ensure Flutter bindings are initialized before using any services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize connectivity service after bindings are ready
  ConnectivityService.instance.initialize();
  
  runApp(MyApp());
}
