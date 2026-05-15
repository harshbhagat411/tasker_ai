import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import '../services/focus_service.dart';

class FocusModeScreen extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;
  final String? projectName;
  final int durationInSeconds;
  final String? ambientSound;

  const FocusModeScreen({
    super.key,
    this.taskId,
    this.taskTitle,
    this.projectName,
    this.durationInSeconds = 25 * 60,
    this.ambientSound,
  });

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with TickerProviderStateMixin {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isRunning = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _bgController;

  final FocusService _focusService = FocusService();
  AudioPlayer? _audioPlayer;

  // Sound URLs mapped from selection
  final Map<String, String> _soundUrls = {
    'Rain': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/weather/rain_heavy_loud.ogg',
    'Cafe': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
    'White Noise': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg',
    'Lofi': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Placeholder instrumental
  };

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationInSeconds;

    // Entry transition
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    // Breathing background animation
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

    _initAudio();
  }

  Future<void> _initAudio() async {
    if (widget.ambientSound != null && widget.ambientSound != 'None') {
      _audioPlayer = AudioPlayer();
      final url = _soundUrls[widget.ambientSound!];
      if (url != null) {
        try {
          // Attempt to load the audio source.
          await _audioPlayer?.setAudioSource(AudioSource.uri(Uri.parse(url)));
          await _audioPlayer?.setLoopMode(LoopMode.one);
        } catch (e) {
          print("Error loading audio: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Could not load ambient sound. It may be unavailable."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _bgController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _audioPlayer?.play();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _audioPlayer?.pause();
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _audioPlayer?.pause();
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() => _secondsRemaining = widget.durationInSeconds);
    _audioPlayer?.seek(Duration.zero);
  }

  Future<bool> _onWillPop() async {
    if (_secondsRemaining > 0 && _secondsRemaining < widget.durationInSeconds) {
      _pauseTimer();
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                const Text("End focus session early?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("This will be recorded as an interrupted session.", style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                        _startTimer(); // Resume
                      },
                      child: const Text("Keep Focusing", style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text("End Session"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (shouldExit == true) {
        // Save as interrupted
        await _focusService.saveFocusSession(
          taskId: widget.taskId,
          taskTitle: widget.taskTitle ?? 'Deep Focus',
          durationInSeconds: widget.durationInSeconds,
          actualDurationInSeconds: widget.durationInSeconds - _secondsRemaining,
          status: 'interrupted',
        );
        return true;
      }
      return false;
    }
    return true;
  }

  void _onSessionComplete() async {
    // Save as completed
    await _focusService.saveFocusSession(
      taskId: widget.taskId,
      taskTitle: widget.taskTitle ?? 'Deep Focus',
      durationInSeconds: widget.durationInSeconds,
      actualDurationInSeconds: widget.durationInSeconds,
      status: 'completed',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.star_rounded, color: Colors.greenAccent, size: 64),
              ),
              const SizedBox(height: 24),
              const Text("Great work.", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "You completed a ${widget.durationInSeconds ~/ 60} minute focus session.",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
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
    double progress = 1.0 - (_secondsRemaining / widget.durationInSeconds);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F13), // Deep elegant dark
        body: AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            // Breathing background effect
            final double glowOpacity = 0.3 + (_bgController.value * 0.2); // 0.3 to 0.5
            
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(30, 40, 80, glowOpacity), // Subtle blue breathing glow
                    const Color(0xFF0F0F13),
                  ],
                  radius: 1.5,
                  center: Alignment.center,
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Top Action: Exit
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                          onPressed: () async {
                            if (await _onWillPop()) {
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          tooltip: "Exit Focus Space",
                        ),
                        if (widget.ambientSound != null && widget.ambientSound != 'None')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text(widget.ambientSound!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          const SizedBox(width: 48), // Balance spacing
                      ],
                    ),
                  ),
                  
                  const Spacer(),

                  // Task Info
                  if (widget.projectName != null)
                    Text(
                      widget.projectName!.toUpperCase(),
                      style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      widget.taskTitle ?? "Deep Focus",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 0.5),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Timer Circular Display
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CustomPaint(
                          painter: TimerPainter(
                            progress: progress,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            progressColor: Colors.white,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timerString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w200,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (widget.durationInSeconds - _secondsRemaining > 0)
                            Text(
                              "${(progress * 100).toInt()}% completed",
                              style: const TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_secondsRemaining < widget.durationInSeconds)
                        IconButton(
                          icon: const Icon(Icons.replay),
                          color: Colors.white54,
                          iconSize: 32,
                          onPressed: _resetTimer,
                        )
                      else
                        const SizedBox(width: 48),

                      const SizedBox(width: 24),
                      
                      GestureDetector(
                        onTap: _isRunning ? _pauseTimer : _startTimer,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _isRunning ? Colors.white10 : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: _isRunning ? [] : [
                              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
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
                      const SizedBox(width: 48), // Invisible placeholder
                    ],
                  ),

                  const Spacer(),

                  // Bottom Motivation
                  const Padding(
                    padding: EdgeInsets.only(bottom: 40.0),
                    child: Text(
                      "Stay focused on one thing at a time.",
                      style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter for a premium smooth ring
class TimerPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  TimerPainter({required this.progress, required this.backgroundColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
