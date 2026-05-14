import 'package:flutter/material.dart';
import 'dart:async';
import '../services/focus_service.dart';

class FocusModeScreen extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;
  final String? projectName;

  const FocusModeScreen({
    super.key,
    this.taskId,
    this.taskTitle,
    this.projectName,
  });

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with SingleTickerProviderStateMixin {
  static const int defaultFocusSeconds = 25 * 60;
  
  int _secondsRemaining = defaultFocusSeconds;
  Timer? _timer;
  bool _isRunning = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final FocusService _focusService = FocusService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
        });
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _secondsRemaining = defaultFocusSeconds;
    });
  }

  void _onSessionComplete() async {
    // Save session
    await _focusService.saveFocusSession(
      taskId: widget.taskId,
      taskTitle: widget.taskTitle ?? 'Deep Focus',
      durationInSeconds: defaultFocusSeconds,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
              const SizedBox(height: 24),
              const Text(
                "Great work.",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "You completed a 25 minute focus session.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _resetTimer();
                    _startTimer(); // Focus Again
                  },
                  child: const Text("Focus Again", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Exit Focus Space
                  },
                  child: const Text("Exit Focus Space"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _timerString {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Determine progress for circular indicator
    double progress = _secondsRemaining / defaultFocusSeconds;

    return Scaffold(
      // Completely immersive, no app bar, no bottom nav
      backgroundColor: const Color(0xFF0F0F13), // Deep elegant dark
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFF1C1C24), // Center slightly lighter
              Color(0xFF0F0F13), // Edge deep dark
            ],
            radius: 1.2,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Top Action: Exit
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Exit Focus Space",
                    ),
                  ),
                ),
                
                const Spacer(),

                // Task Info
                if (widget.projectName != null)
                  Text(
                    widget.projectName!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    widget.taskTitle ?? "Deep Focus",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Timer Circular Display
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      _timerString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_secondsRemaining < defaultFocusSeconds)
                      IconButton(
                        icon: const Icon(Icons.replay),
                        color: Colors.white54,
                        iconSize: 32,
                        onPressed: _resetTimer,
                      )
                    else
                      const SizedBox(width: 48), // Placeholder for balance

                    const SizedBox(width: 24),
                    
                    GestureDetector(
                      onTap: _isRunning ? _pauseTimer : _startTimer,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _isRunning ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: _isRunning ? [] : [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          color: _isRunning ? Colors.white : Colors.black,
                          size: 36,
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),
                    
                    // Invisible placeholder to keep the play button perfectly centered
                    const SizedBox(width: 48),
                  ],
                ),

                const Spacer(),

                // Bottom Motivation
                const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Text(
                    "Stay focused on one thing at a time.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
