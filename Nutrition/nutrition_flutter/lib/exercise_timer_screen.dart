import 'package:flutter/material.dart';
import 'dart:async';
import 'models/exercise.dart';
import 'theme_service.dart';
import 'services/exercise_service.dart';

class ExerciseTimerScreen extends StatefulWidget {
  final Exercise exercise;
  final String usernameOrEmail;

  const ExerciseTimerScreen({
    super.key,
    required this.exercise,
    required this.usernameOrEmail,
  });

  @override
  State<ExerciseTimerScreen> createState() => _ExerciseTimerScreenState();
}

class _ExerciseTimerScreenState extends State<ExerciseTimerScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _timeLeft = 60; // Default 60 seconds
  int _totalTime = 60; // Track total time for progress calculation
  bool _isRunning = false;
  bool _isPaused = false;
  String? userSex;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserSex();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadUserSex() async {
    // Load user sex for theming
    setState(() {
      userSex = 'female'; // Default for now
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          _animationController.forward().then((_) {
            _animationController.reverse();
          });
        } else {
          _stopTimer();
          _showCompletionDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
  }

  void _resumeTimer() {
    if (!_isPaused) return;

    setState(() {
      _isPaused = false;
    });
    _startTimer();
  }

  void _stopTimer() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
    _timer?.cancel();
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _timeLeft = _totalTime; // Reset to the selected total time
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Great job!'),
            content: Text('You completed ${widget.exercise.name}!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Finish'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetTimer();
                  _startTimer();
                },
                child: Text('Do Another Set'),
              ),
            ],
          ),
    );

    // Log the exercise session to the backend
    _logExerciseSession();
  }

  Future<void> _logExerciseSession() async {
    try {
      final success = await ExerciseService.logExerciseSession(
        user: widget.usernameOrEmail,
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        durationSeconds: _totalTime - _timeLeft, // Actual time spent
        caloriesBurned:
            widget.exercise.exerciseCaloriesPerMinute *
            ((_totalTime - _timeLeft) / 60),
        setsCompleted: 1,
        notes: 'Completed via timer',
      );

      if (success) {
        debugPrint('Exercise session logged successfully');
      } else {
        debugPrint('Failed to log exercise session');
      }
    } catch (e) {
      debugPrint('Error logging exercise session: $e');
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color get primaryColor => ThemeService.getPrimaryColor(userSex);
  Color get backgroundColor => ThemeService.getBackgroundColor(userSex);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Exercise Timer',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
          child: Column(
            children: [
              // Exercise info card - make it more compact
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                  child: Column(
                    children: [
                      // Exercise icon - smaller for small screens
                      Container(
                        width: isVerySmallScreen ? 60 : 80,
                        height: isVerySmallScreen ? 60 : 80,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getExerciseIcon(widget.exercise.exerciseCategory),
                          color: primaryColor,
                          size: isVerySmallScreen ? 30 : 40,
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),

                      // Exercise name
                      Text(
                        widget.exercise.name,
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),

                      // Target muscle
                      Text(
                        'Target: ${widget.exercise.target}',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isVerySmallScreen ? 16 : 24),

              // Timer display - use Expanded to prevent overflow
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Timer circle - responsive size
                    Container(
                      width: isVerySmallScreen ? 160 : 200,
                      height: isVerySmallScreen ? 160 : 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.1),
                        border: Border.all(color: primaryColor, width: 3),
                      ),
                      child: Center(
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Text(
                            _formatTime(_timeLeft),
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 36 : 48,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isVerySmallScreen ? 16 : 24),

                    // Progress indicator - use _totalTime instead of hardcoded 60
                    LinearProgressIndicator(
                      value: (_totalTime - _timeLeft) / _totalTime,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 6,
                    ),

                    SizedBox(height: isVerySmallScreen ? 12 : 16),

                    // Status text
                    Text(
                      _isRunning
                          ? 'Keep going!'
                          : _isPaused
                          ? 'Paused'
                          : 'Ready to start',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 14 : 16,
                        color: _isRunning ? Colors.green : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Control buttons - more compact
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 8 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reset button
                    IconButton(
                      onPressed: _resetTimer,
                      icon: Icon(Icons.refresh, color: primaryColor, size: 24),
                      tooltip: 'Reset',
                    ),

                    // Play/Pause button - smaller for small screens
                    Container(
                      width: isVerySmallScreen ? 60 : 80,
                      height: isVerySmallScreen ? 60 : 80,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed:
                            _isRunning
                                ? _pauseTimer
                                : _isPaused
                                ? _resumeTimer
                                : _startTimer,
                        icon: Icon(
                          _isRunning
                              ? Icons.pause
                              : _isPaused
                              ? Icons.play_arrow
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: isVerySmallScreen ? 24 : 32,
                        ),
                      ),
                    ),

                    // Stop button
                    IconButton(
                      onPressed: _stopTimer,
                      icon: Icon(Icons.stop, color: primaryColor, size: 24),
                      tooltip: 'Stop',
                    ),
                  ],
                ),
              ),

              // Quick time presets - more compact
              Padding(
                padding: EdgeInsets.only(bottom: isVerySmallScreen ? 8 : 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimePreset(30),
                    _buildTimePreset(60),
                    _buildTimePreset(90),
                    _buildTimePreset(120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePreset(int seconds) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeLeft = seconds;
          _totalTime = seconds; // Update total time when preset is selected
        });
        _resetTimer();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _timeLeft == seconds ? primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${seconds}s',
          style: TextStyle(
            color: _timeLeft == seconds ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  IconData _getExerciseIcon(String category) {
    switch (category) {
      case 'Cardio':
        return Icons.directions_run;
      case 'Strength':
        return Icons.fitness_center;
      case 'Flexibility':
        return Icons.accessibility_new;
      case 'Sports':
        return Icons.sports_soccer;
      case 'Dance':
        return Icons.music_note;
      case 'Yoga':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }
}
