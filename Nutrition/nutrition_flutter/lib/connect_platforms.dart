import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/health_service.dart';

const Color kGreen = Color(0xFF43A047);
const Color kLightGreen = Color(0xFFF8FBF8);

class ConnectPlatformsScreen extends StatefulWidget {
  const ConnectPlatformsScreen({super.key});
  @override
  ConnectPlatformsScreenState createState() => ConnectPlatformsScreenState();
}

class ConnectPlatformsScreenState extends State<ConnectPlatformsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Show both Health Connect and Google Fit for Android 13 compatibility
  List<PlatformData> platforms = [
    PlatformData(
      name: 'Health Connect',
      subtitle: 'Android\'s unified health platform (Android 14+)',
      icon: Icons.health_and_safety,
      color: Color(0xFF4285F4),
      connected: false,
      recommended: false,
      description:
          'Seamlessly sync your health data from compatible devices and apps',
      features: ['Heart Rate', 'Steps', 'Workouts', 'Sleep', 'Water Intake'],
    ),
    PlatformData(
      name: 'Google Fit',
      subtitle: 'Works on Android 13+ (Recommended for your device)',
      icon: Icons.fitness_center,
      color: Color(0xFF0F9D58),
      connected: false,
      recommended: true,
      description:
          'Connect your Redmi Watch via Mi Fitness → Google Fit → Your App',
      features: ['Steps', 'Calories', 'Workouts', 'Heart Rate', 'Distance'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _loadConnectionStatuses();
    _animationController.forward();
  }

  Future<void> _loadConnectionStatuses() async {
    final statuses = await HealthService.getAllConnectionStatuses();
    setState(() {
      for (int i = 0; i < platforms.length; i++) {
        final platformName = platforms[i].name;
        if (statuses.containsKey(platformName)) {
          platforms[i].connected = statuses[platformName]!;
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection(String platformName) async {
    HapticFeedback.lightImpact();

    final platform = platforms.firstWhere((p) => p.name == platformName);
    final wasConnected = platform.connected;

    // Optimistic toggle UI while processing
    setState(() {
      platform.connected = !platform.connected;
    });

    try {
      if (wasConnected) {
        // Disconnect
        bool success;
        if (platformName == 'Health Connect') {
          success = await HealthService.disconnectHealthConnect();
        } else {
          success = await HealthService.disconnectPlatform(platformName);
        }

        if (success) {
          _showSuccessSnackBar('$platformName disconnected');
          await _loadConnectionStatuses();
        } else {
          _showErrorSnackBar(
            'Failed to disconnect from $platformName',
            wasConnected,
            platformName: platformName,
          );
        }
      } else {
        // Connect - Use MyFitnessPal-style method for Health Connect
        if (platformName == 'Health Connect') {
          Map<String, dynamic> result =
              await HealthService.requestHealthConnectPermissions();

          if (result['success']) {
            _showSuccessSnackBar(result['message']);
            await _loadConnectionStatuses();
          } else {
            _showMyFitnessPalStyleErrorSnackBar(
              result,
              wasConnected,
              platformName,
            );
          }
        } else if (platformName == 'Google Fit') {
          // Special handling for Google Fit
          try {
            Map<String, dynamic> result = await HealthService.connectPlatform(
              platformName,
            );
            if (result['success']) {
              _showSuccessSnackBar(
                result['message'] ?? 'Google Fit connected successfully!',
              );
              // Force update the UI state
              setState(() {
                final platform = platforms.firstWhere(
                  (p) => p.name == platformName,
                );
                platform.connected = true;
              });
              await _loadConnectionStatuses();
            } else {
              _showErrorSnackBar(
                result['error'] ?? 'Failed to connect to Google Fit',
                wasConnected,
                platformName: platformName,
              );
            }
          } catch (e) {
            _showErrorSnackBar(
              'Google Fit connection error: ${e.toString()}',
              wasConnected,
              platformName: platformName,
            );
          }
        } else {
          // For other platforms, use the connectPlatform method
          bool success = await HealthService.connectPlatform(platformName);
          if (success) {
            _showSuccessSnackBar('$platformName connected successfully!');
            await _loadConnectionStatuses();
          } else {
            _showErrorSnackBar(
              'Failed to connect to $platformName',
              wasConnected,
              platformName: platformName,
            );
          }
        }
      }
    } catch (e) {
      // Error occurred, revert state
      setState(() {
        platform.connected = wasConnected;
      });
      await _loadConnectionStatuses();

      _showErrorSnackBar('Unexpected error: ${e.toString()}', wasConnected);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(
    String message,
    bool revertTo, {
    String? platformName,
  }) {
    setState(() {
      final platform = platforms.firstWhere(
        (p) => p.name == (platformName ?? 'Health Connect'),
      );
      platform.connected = revertTo;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showMyFitnessPalStyleErrorSnackBar(
    Map<String, dynamic> result,
    bool revertTo,
    String platformName,
  ) {
    setState(() {
      final platform = platforms.firstWhere((p) => p.name == platformName);
      platform.connected = revertTo;
    });

    String errorMessage = result['error'] ?? 'Unknown error occurred';
    String? errorCode = result['errorCode'];
    String? instruction = result['instruction'];

    // Show MyFitnessPal-style message with action buttons
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            if (instruction != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  instruction,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            if (errorCode == 'PERMISSION_PENDING' ||
                errorCode == 'SETTINGS_OPENED' ||
                errorCode == 'CANNOT_OPEN')
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          await _checkHealthConnectPermissions();
                        },
                        icon: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          'Check Permissions',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.3),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          bool opened =
                              await HealthService.openHealthConnectSettings();
                          if (!opened) {
                            _showErrorSnackBar(
                              'Could not open Health Connect',
                              revertTo,
                            );
                          }
                        },
                        icon: Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          'Open Health Connect',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.3),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 8),
      ),
    );
  }

  Future<void> _checkHealthConnectPermissions() async {
    try {
      Map<String, dynamic> result =
          await HealthService.checkHealthConnectPermissionsAfterGrant();

      if (result['success']) {
        _showSuccessSnackBar(result['message']);
        await _loadConnectionStatuses();
      } else {
        _showErrorSnackBar(
          result['error'] ?? 'Permissions not granted yet',
          false,
          platformName: 'Health Connect',
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        'Error checking permissions: ${e.toString()}',
        false,
        platformName: 'Health Connect',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedCount = platforms.where((p) => p.connected).length;

    return Scaffold(
      backgroundColor: kLightGreen,
      appBar: AppBar(
        title: Text(
          'Connect Platforms',
          style: TextStyle(
            color: kGreen,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: kGreen),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(connectedCount),
                      SizedBox(height: 24),
                      _buildStatsSection(connectedCount),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final platform = platforms[index];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.only(bottom: 16),
                      child: _buildModernPlatformCard(platform, index),
                    );
                  }, childCount: platforms.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildManageConnectionsButton(),
                ),
              ),
              // Diagnostics button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final diag =
                            await HealthService.diagnoseHealthConnectVisibility();
                        // Simple presentation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Diagnostics captured. Check logs for details.',
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );
                        debugPrint(
                          '🧭 Diagnostics summary: isInstalled=${diag['isInstalled']}, hasPermissionsProbe=${diag['hasPermissionsProbe']}, dataProbeCount=${diag['dataProbeCount']}',
                        );
                      },
                      icon: Icon(Icons.analytics, size: 18, color: kGreen),
                      label: Text(
                        'Run Health Connect Diagnostics',
                        style: TextStyle(color: kGreen),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kGreen.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/test/health');
                      },
                      icon: Icon(Icons.bug_report, size: 18, color: kGreen),
                      label: Text(
                        'Run Health Connect Test',
                        style: TextStyle(color: kGreen),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kGreen.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(int connectedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4285F4).withValues(alpha: 0.1),
                    Color(0xFF0F9D58).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.health_and_safety,
                color: Color(0xFF4285F4),
                size: 32,
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Platform Integration',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Connect your preferred health platform',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            'Seamlessly sync your health data from Google Fit or Health Connect to automatically track your fitness progress and maintain accurate calorie calculations.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(int connectedCount) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4285F4).withValues(alpha: 0.1),
            Color(0xFF0F9D58).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF4285F4).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Connected',
              connectedCount.toString(),
              Icons.check_circle,
              Color(0xFF4285F4),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              'Available',
              platforms.length.toString(),
              Icons.health_and_safety,
              Color(0xFF0F9D58),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              'Recommended',
              platforms.where((p) => p.recommended).length.toString(),
              Icons.star,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildModernPlatformCard(PlatformData platform, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
          border:
              platform.connected
                  ? Border.all(color: kGreen.withValues(alpha: 0.3), width: 2)
                  : null,
        ),
        child: InkWell(
          onTap: () => _toggleConnection(platform.name),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: platform.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        platform.icon,
                        color: platform.color,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  platform.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (platform.recommended) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'RECOMMENDED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            platform.subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    _buildConnectionToggle(platform),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  platform.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      platform.features.map((feature) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: platform.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 12,
                              color: platform.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionToggle(PlatformData platform) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: 60,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: platform.connected ? kGreen : Colors.grey[300],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: platform.connected ? 28 : 4,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                platform.connected ? Icons.check : Icons.close,
                size: 16,
                color: platform.connected ? kGreen : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageConnectionsButton() {
    return Column(
      children: [
        // Reset Health Connect Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _showResetHealthConnectDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 20),
                SizedBox(width: 8),
                Text(
                  'Reset All Health Connect',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        // Manage Connections Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              // Add manage connections functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Manage connections feature coming soon!'),
                  backgroundColor: kGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings, size: 20),
                SizedBox(width: 8),
                Text(
                  'Manage Connections',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showResetHealthConnectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600], size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reset Health Connect',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will completely reset all Health Connect connections and data. You will need to reconnect and grant permissions again.',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What will be reset:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• All saved connection statuses\n• Permission states\n• Sync settings\n• Health data access',
                      style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performFullHealthConnectReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Reset All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performFullHealthConnectReset() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.red[600]),
              SizedBox(height: 16),
              Text(
                'Resetting Health Connect...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Step 1: Reset local Health Connect status
      await HealthService.resetHealthConnect();

      // Step 2: Try to open Health Connect settings for manual cleanup
      bool opened = await HealthService.openHealthConnectSettings();

      // Step 3: Reload connection statuses
      await _loadConnectionStatuses();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success dialog with next steps
      if (mounted) _showResetSuccessDialog(opened);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) _showErrorSnackBar('Reset failed: ${e.toString()}', false);
    }
  }

  void _showResetSuccessDialog(bool settingsOpened) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reset Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Connect has been reset locally. To complete the full reset:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Steps:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. In Health Connect: Revoke all permissions for this app\n2. Remove this app from Health Connect\n3. Clear Health Connect data (optional)\n4. Return here and reconnect',
                      style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              if (settingsOpened) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green[600], size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Health Connect settings opened',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!settingsOpened)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  bool opened = await HealthService.openHealthConnectSettings();
                  if (!opened) {
                    _showErrorSnackBar(
                      'Could not open Health Connect settings',
                      false,
                    );
                  }
                },
                child: Text('Open Health Connect'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

class PlatformData {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  bool connected;
  final bool recommended;
  final String description;
  final List<String> features;

  PlatformData({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.connected,
    required this.recommended,
    required this.description,
    required this.features,
  });
}
