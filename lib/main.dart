import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/projects_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/focus_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_init;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz_init.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  await FCMService.init();
  
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermission();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  await FocusService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(seenOnboarding: seenOnboarding),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primaryColor: const Color(0xFF0D47A1),
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D47A1),
              primary: const Color(0xFF0D47A1),
              brightness: Brightness.light,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF0D47A1),
            ),
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2.0),
              ),
              floatingLabelStyle: const TextStyle(color: Color(0xFF0D47A1)),
            ),
            datePickerTheme: const DatePickerThemeData(
              headerBackgroundColor: Color(0xFF0D47A1),
              headerForegroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            primaryColor: const Color(0xFF0D47A1),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D47A1),
              primary: const Color(0xFF0D47A1),
              brightness: Brightness.dark,
            ),
            textTheme: Typography.material2021().white,
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF0D47A1),
            ),
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2.0),
              ),
              floatingLabelStyle: const TextStyle(color: Color(0xFF0D47A1)),
            ),
            datePickerTheme: const DatePickerThemeData(
              headerBackgroundColor: Color(0xFF0D47A1),
              headerForegroundColor: Colors.white,
            ),
          ),
          home: const AuthGateScreen(),
        );
      },
    );
  }
}

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    _checkRouting();
  }

  Future<void> _checkRouting() async {
    // Smooth splash delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              seenOnboarding ? const LoginScreen() : const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return;
    }

    // User is logged in, check Firestore for mode
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('mode') && data['mode'] != null) {
          // Mode is selected
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          return;
        }
      }
      // Mode not selected or doc doesn't exist yet (Legacy user)
      // Default them to personal mode silently
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'mode': 'personal',
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      // Fallback on error
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // Brand primary color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo or Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.task_alt,
                size: 80,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 40),
            // App Name
            const Text(
              "Tasker",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Manage your tasks intelligently",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // Loading Indicator
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize presence service to start tracking lifecycle immediately
    PresenceService();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isDeveloper = data?['mode'] == 'developer';

        final screens = [
          const HomeScreen(),
          if (isDeveloper) const ProjectsScreen(),
          const CalendarScreen(),
          const ProfileScreen(),
        ];

        final items = [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          if (isDeveloper) const BottomNavigationBarItem(icon: Icon(Icons.business_center), label: 'Projects'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];

        // Guard index out of bounds if switching mode down
        if (_currentIndex >= screens.length) {
          _currentIndex = screens.length - 1;
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            items: items,
          ),
        );
      },
    );
  }
}
