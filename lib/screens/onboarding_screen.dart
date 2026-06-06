import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_screen.dart';
import '../services/mode_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  bool _isNextPressed = false;
  bool _isGetStartedPressed = false;
  UserMode? _selectedMode;

  bool get onLastPage => _currentIndex == 3;

  Future<void> _completeOnboarding() async {
    if (onLastPage && _selectedMode == null) return; // Prevent completion without selection

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    
    if (_selectedMode != null) {
      await prefs.setString('pending_mode', ModeService.getStringFromMode(_selectedMode!));
    } else {
      await prefs.setString('pending_mode', 'personal'); // Default fallback
    }
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              _buildPage(
                index: 0,
                title: "Create productive work",
                subtitle: "Stay focused and start managing your tasks easily",
                imagePath: "assets/images/onboarding1.png",
              ),
              _buildPage(
                index: 1,
                title: "Manage tasks easily",
                subtitle: "Organize, track and complete your daily tasks efficiently",
                imagePath: "assets/images/onboarding2.png",
              ),
              _buildPage(
                index: 2,
                title: "Achieve your goals",
                subtitle: "Stay consistent and accomplish more every day",
                imagePath: "assets/images/onboarding3.png",
              ),
              _buildModeSelectionPage(),
            ],
          ),
          
          // Skip button
          if (!onLastPage)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    _controller.animateToPage(3, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                  },
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          
          // Bottom controls
          Container(
            alignment: const Alignment(0, 0.85),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 4,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Theme.of(context).primaryColor,
                      dotColor: Colors.black12,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                  onLastPage
                      ? Listener(
                          onPointerDown: (_) => setState(() => _isGetStartedPressed = true),
                          onPointerUp: (_) => setState(() => _isGetStartedPressed = false),
                          onPointerCancel: (_) => setState(() => _isGetStartedPressed = false),
                          child: AnimatedScale(
                            scale: _isGetStartedPressed ? 0.95 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              onPressed: _selectedMode == null ? null : _completeOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                disabledBackgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                "Continue",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      : Listener(
                          onPointerDown: (_) => setState(() => _isNextPressed = true),
                          onPointerUp: (_) => setState(() => _isNextPressed = false),
                          onPointerCancel: (_) => setState(() => _isNextPressed = false),
                          child: AnimatedScale(
                            scale: _isNextPressed ? 0.95 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              onPressed: () {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeIn,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                "Next",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
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

  Widget _buildPage({
    required int index,
    required String title,
    required String subtitle,
    required String imagePath,
  }) {
    bool isVisible = (index == _currentIndex);

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: AnimatedScale(
              scale: isVisible ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: Image.asset(
                imagePath,
                height: 550,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 1),
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 0.5),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 0.5),
              duration: const Duration(milliseconds: 500),
              curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionPage() {
    bool isVisible = (_currentIndex == 3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: const Text(
              "How do you plan to use Tasker?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: const Text(
              "Tasker adapts to the way you work.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 48),
          
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: _buildModeCard(
              mode: UserMode.personal,
              title: "Personal Productivity",
              description: "Daily tasks • Goals • Focus sessions • Habit tracking",
              icon: Icons.person_outline,
              color: const Color(0xFF6A1B9A),
              lightColor: const Color(0xFFF3E5F5),
            ),
          ),
          
          const SizedBox(height: 20),
          
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 700),
            child: _buildModeCard(
              mode: UserMode.developer,
              title: "Team & Development",
              description: "Projects • Team collaboration • Activity feed • Sprint workflow",
              icon: Icons.code,
              color: Theme.of(context).primaryColor,
              lightColor: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 60), // Space for bottom controls
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required UserMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color lightColor,
  }) {
    final bool isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? lightColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.black87,
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
}
