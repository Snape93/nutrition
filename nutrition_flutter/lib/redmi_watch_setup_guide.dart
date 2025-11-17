import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'connect_platforms.dart';

class RedmiWatchSetupGuide extends StatelessWidget {
  const RedmiWatchSetupGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Setup Your Redmi Watch 5 Active',
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.green[800]),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withValues(alpha: 0.1),
                    Colors.blue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.watch, size: 64, color: Colors.green[600]),
                  SizedBox(height: 16),
                  Text(
                    'Connect Your Redmi Watch 5 Active',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Get real-time fitness data including steps, heart rate, and workout tracking for better nutrition insights.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            Text(
              'Setup Steps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),

            SizedBox(height: 16),

            // Step 1
            _buildSetupStep(
              stepNumber: 1,
              title: 'Install Mi Fitness App',
              description:
                  'Download and install the Mi Fitness app (Xiaomi Wear Lite) from Google Play Store or App Store.',
              icon: Icons.download,
              color: Colors.blue,
            ),

            // Step 2
            _buildSetupStep(
              stepNumber: 2,
              title: 'Pair Your Redmi Watch',
              description:
                  'Open Mi Fitness app, create/login to Xiaomi account, and pair your Redmi Watch 5 Active via Bluetooth.',
              icon: Icons.bluetooth,
              color: Colors.indigo,
            ),

            // Step 3
            _buildSetupStep(
              stepNumber: 3,
              title: 'Enable Health Connect',
              description:
                  'In Mi Fitness app settings, enable "Health Connect" data sharing to allow access to your health data.',
              icon: Icons.health_and_safety,
              color: Colors.green,
            ),

            // Step 4
            _buildSetupStep(
              stepNumber: 4,
              title: 'Connect in Nutritionist App',
              description:
                  'Return to this app and connect to Health Connect to start syncing your fitness data.',
              icon: Icons.link,
              color: Colors.orange,
              isLast: true,
            ),

            SizedBox(height: 24),

            // Features section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What You\'ll Get',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildFeatureItem(
                    'Real-time heart rate monitoring',
                    Icons.favorite,
                    Colors.red,
                  ),
                  _buildFeatureItem(
                    'Daily step counting and distance tracking',
                    Icons.directions_walk,
                    Colors.blue,
                  ),
                  _buildFeatureItem(
                    'Automatic workout detection and logging',
                    Icons.fitness_center,
                    Colors.green,
                  ),
                  _buildFeatureItem(
                    'Accurate calorie burn calculations',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildFeatureItem(
                    'Sleep quality and duration tracking',
                    Icons.bedtime,
                    Colors.purple,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[700],
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConnectPlatformsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Connect Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Troubleshooting
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber[700], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Troubleshooting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Make sure your Redmi Watch is charged and nearby\n'
                    '• Enable Bluetooth on your phone\n'
                    '• Restart Mi Fitness app if connection fails\n'
                    '• Check that Health Connect is available on your device (Android 14+)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number and line
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 40, color: Colors.grey[300]),
            ],
          ),
          SizedBox(width: 16),
          // Content
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
