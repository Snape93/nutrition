import 'package:flutter/material.dart';
import 'my_app.dart';
import 'services/connectivity_service.dart';

void main() {
  // Initialize connectivity service
  ConnectivityService.instance.initialize();
  
  runApp(MyApp());
}
