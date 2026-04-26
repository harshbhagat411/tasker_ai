import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_screen.dart';

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

  bool get onLastPage => _currentIndex == 2;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    
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
            ],
          ),
          
          // Skip button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
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
                    count: 3,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: Color(0xFF0D47A1),
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
                              onPressed: _completeOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                "Get Started",
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
                                backgroundColor: const Color(0xFF0D47A1),
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
}
