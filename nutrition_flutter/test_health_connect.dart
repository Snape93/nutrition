import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lib/services/health_service.dart';

void main() {
  runApp(HealthConnectTestApp());
}

class HealthConnectTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Connect Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HealthConnectTestScreen(),
    );
  }
}

class HealthConnectTestScreen extends StatefulWidget {
  @override
  _HealthConnectTestScreenState createState() =>
      _HealthConnectTestScreenState();
}

class _HealthConnectTestScreenState extends State<HealthConnectTestScreen> {
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health Connect Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Connect Integration Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This test will help diagnose why your app is not appearing in Health Connect.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testHealthConnectAvailability,
              child: Text('1. Test Health Connect Availability'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testHealthConnectPermissions,
              child: Text('2. Test Permission Request'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testHealthConnectDiagnostics,
              child: Text('3. Run Diagnostics'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testNativeChannel,
              child: Text('4. Test Native Channel'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(_status, style: TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testHealthConnectAvailability() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Health Connect availability...';
    });

    try {
      bool isAvailable = await HealthService.isHealthConnectAvailable();
      setState(() {
        _status =
            'Health Connect Available: $isAvailable\n\n'
            'If this returns false, Health Connect may not be installed or accessible.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error testing availability: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testHealthConnectPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting Health Connect permissions...';
    });

    try {
      Map<String, dynamic> result =
          await HealthService.requestHealthConnectPermissions();
      setState(() {
        _status =
            'Permission Request Result:\n'
            'Success: ${result['success']}\n'
            'Message: ${result['message'] ?? result['error']}\n'
            'Action: ${result['action']}\n\n'
            'If success is false, check the action field for next steps.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error requesting permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testHealthConnectDiagnostics() async {
    setState(() {
      _isLoading = true;
      _status = 'Running diagnostics...';
    });

    try {
      Map<String, dynamic> diagnostics =
          await HealthService.diagnoseHealthConnectVisibility();
      setState(() {
        _status =
            'Diagnostics Results:\n'
            'Installed: ${diagnostics['isInstalled']}\n'
            'Has Permissions Probe: ${diagnostics['hasPermissionsProbe']}\n'
            'Data Probe Count: ${diagnostics['dataProbeCount']}\n'
            'Core Types: ${diagnostics['coreTypes']}\n'
            'Permissions: ${diagnostics['permissions']}\n\n'
            'If installed is false, Health Connect is not installed.\n'
            'If hasPermissionsProbe is null, the app is not registered with Health Connect.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error running diagnostics: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testNativeChannel() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing native channel...';
    });

    try {
      const channel = MethodChannel(
        'com.example.nutrition_flutter/healthconnect',
      );

      // Test if Health Connect is installed
      bool isInstalled =
          await channel.invokeMethod<bool>('isInstalled') ?? false;

      setState(() {
        _status =
            'Native Channel Test Results:\n'
            'Health Connect Installed: $isInstalled\n\n'
            'If installed is false, you need to install Health Connect from Play Store.\n'
            'If installed is true but app still not showing, there may be a configuration issue.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error testing native channel: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
