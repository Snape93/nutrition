import 'package:flutter/material.dart';
import 'services/health_service.dart';

/// Test widget to verify Health Connect integration
/// Add this to your app to test the connection
class HealthConnectTestWidget extends StatefulWidget {
  const HealthConnectTestWidget({super.key});

  @override
  State<HealthConnectTestWidget> createState() =>
      _HealthConnectTestWidgetState();
}

class _HealthConnectTestWidgetState extends State<HealthConnectTestWidget> {
  String _status = 'Ready to test...';
  bool _isLoading = false;
  int _steps = 0;
  int? _heartRate;
  double _calories = 0.0;

  Future<void> _runTest() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _status = 'Running Health Connect test...';
    });

    try {
      // Test 1: Check availability
      _updateStatus('1. Checking Health Connect availability...');
      bool isAvailable = await HealthService.isHealthConnectAvailable();
      _updateStatus('Health Connect available: $isAvailable');

      // Test 2: Check current connection status
      _updateStatus('2. Checking current connection status...');
      bool isConnected = await HealthService.isHealthConnectConnected();
      _updateStatus('Health Connect connected: $isConnected');

      // Test 3: Try to connect (if not already connected)
      if (!isConnected) {
        _updateStatus('3. Requesting permissions...');
        Map<String, dynamic> result =
            await HealthService.requestHealthConnectPermissions();
        _updateStatus(
          'Connection result: ${result['success'] ? 'SUCCESS' : 'FAILED'}',
        );

        if (result['success']) {
          _updateStatus('✅ Health Connect connected successfully!');
          await _testDataRetrieval();
        } else {
          _updateStatus('❌ Connection failed: ${result['error']}');
          if (result['action'] != null) {
            _updateStatus('Suggested action: ${result['action']}');
          }
        }
      } else {
        _updateStatus('✅ Health Connect already connected!');
        await _testDataRetrieval();
      }
    } catch (e) {
      _updateStatus('❌ Test failed with error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testDataRetrieval() async {
    _updateStatus('4. Testing data retrieval...');

    // Get steps
    int steps = await HealthService.getTodaySteps();
    if (!mounted) return;
    setState(() {
      _steps = steps;
    });
    _updateStatus('Today\'s steps: $steps');

    // Get heart rate
    int? heartRate = await HealthService.getLatestHeartRate();
    if (!mounted) return;
    setState(() {
      _heartRate = heartRate;
    });
    _updateStatus('Latest heart rate: ${heartRate ?? 'No data'}');

    // Get calories
    double calories = await HealthService.getTodayCaloriesBurned();
    if (!mounted) return;
    setState(() {
      _calories = calories;
    });
    _updateStatus('Today\'s calories: $calories');

    _updateStatus('🏁 Test completed successfully!');
  }

  void _updateStatus(String message) {
    if (!mounted) return;
    setState(() {
      _status = message;
    });
    debugPrint('🧪 $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Connect Integration Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This test will verify your Health Connect integration and try to retrieve health data.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _runTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            _isLoading
                                ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Testing...'),
                                  ],
                                )
                                : const Text('Run Health Connect Test'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Retrieved Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDataRow('Steps Today', '$_steps'),
                    _buildDataRow(
                      'Heart Rate',
                      _heartRate?.toString() ?? 'No data',
                    ),
                    _buildDataRow(
                      'Calories Burned',
                      _calories.toStringAsFixed(1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
