import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/focus_service.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _bgController;

  final FocusService _focusService = FocusService();
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();

    // Entry transition
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    // Breathing background animation
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final state = _focusService.currentState;
    if (state.status == FocusSessionStatus.running || state.status == FocusSessionStatus.paused) {
      if (state.status == FocusSessionStatus.running) {
        _focusService.pauseSession();
      }
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
                        _focusService.resumeSession();
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
        await _focusService.endSessionEarly();
        return true;
      }
      return false;
    }
    return true;
  }

  void _showCompletionDialog(FocusSessionState state) {
    if (_dialogShowing) return;
    _dialogShowing = true;
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
                "You completed a ${state.targetDurationInSeconds ~/ 60} minute focus session.",
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
                    _focusService.resetSession();
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Exit Focus Space
                    // Can open setup sheet from home screen instead
                  },
                  child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _dialogShowing = false;
    });
  }

  String _formatTimer(int remainingSeconds) {
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
              child: StreamBuilder<FocusSessionState>(
                stream: _focusService.activeSessionStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final state = snapshot.data!;
                  
                  // Auto-show completion dialog
                  if (state.status == FocusSessionStatus.completed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showCompletionDialog(state);
                    });
                  }

                  double progress = 0.0;
                  if (state.targetDurationInSeconds > 0) {
                    progress = state.elapsedSeconds / state.targetDurationInSeconds;
                  }
                  
                  final isRunning = state.status == FocusSessionStatus.running;

                  return Column(
                    children: [
                      // Top Action: Exit
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 36),
                              onPressed: () {
                                // Minimize without ending
                                Navigator.pop(context);
                              },
                              tooltip: "Minimize Focus Space",
                            ),
                            if (state.ambientSound != null && state.ambientSound != 'None')
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
                                    Text(state.ambientSound!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              )
                            else
                              const SizedBox(width: 48), // Balance spacing
                              
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                              onPressed: () async {
                                if (await _onWillPop()) {
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                              tooltip: "End Session",
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),

                      // Task Info
                      if (state.projectName != null && state.projectName!.isNotEmpty)
                        Text(
                          state.projectName!.toUpperCase(),
                          style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          state.taskTitle.isNotEmpty ? state.taskTitle : "Deep Focus",
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
                                _formatTimer(state.remainingSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 72,
                                  fontWeight: FontWeight.w200,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (state.remainingSeconds > 0)
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
                          if (state.elapsedSeconds > 0 && state.status != FocusSessionStatus.completed)
                            IconButton(
                              icon: const Icon(Icons.stop),
                              color: Colors.white54,
                              iconSize: 32,
                              onPressed: () async {
                                if (await _onWillPop()) {
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                            )
                          else
                            const SizedBox(width: 48),

                          const SizedBox(width: 24),
                          
                          GestureDetector(
                            onTap: () {
                              if (isRunning) {
                                _focusService.pauseSession();
                              } else {
                                _focusService.resumeSession();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isRunning ? Colors.white10 : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: isRunning ? [] : [
                                  BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                                ],
                              ),
                              child: Icon(
                                isRunning ? Icons.pause : Icons.play_arrow,
                                color: isRunning ? Colors.white : Colors.black,
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
                  );
                }
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
