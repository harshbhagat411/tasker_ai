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
import 'services/goal_service.dart';
import 'services/habit_service.dart';
import 'services/productivity_engine.dart';
import 'screens/habits_screen.dart';
import 'screens/goals_screen.dart';
import 'services/task_service.dart';
import 'services/workspace_service.dart';
import 'widgets/focus_setup_sheet.dart';
import 'screens/create_workspace_screen.dart';
import 'models/workspace_model.dart';
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
  bool _isMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    // Initialize presence service to start tracking lifecycle immediately
    PresenceService();
    // Run maintenance for goals and habits
    GoalService().performMaintenance();
    HabitService().performMaintenance();
    // Initialize today's productivity document on app launch
    ProductivityEngine().initializeTodayDocument();
  }

  Widget _buildFloatingNavBar(bool isDeveloper, bool isDark) {
    final List<Map<String, dynamic>> tabs = [
      {'icon': Icons.home, 'label': 'Home'},
      {'icon': Icons.repeat, 'label': 'Habits'},
      if (isDeveloper) {'icon': Icons.business_center, 'label': 'Projects'},
      {'icon': Icons.calendar_month, 'label': 'Calendar'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _currentIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = index;
                _isMenuExpanded = false; // Auto close menu when a tab is tapped!
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 20,
                    color: isSelected 
                        ? Colors.white 
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: isSelected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                tab['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCreateMenu(bool isDeveloper, bool isDark) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(
            icon: Icons.task_alt,
            label: "Add Task",
            iconColor: Colors.blueAccent,
            onTap: () {
              setState(() => _isMenuExpanded = false);
              showDialog(
                context: context,
                builder: (context) => const AddTaskDialog(),
              );
            },
            isDark: isDark,
          ),
          _buildMenuItem(
            icon: Icons.repeat,
            label: "Add Habit",
            iconColor: Colors.green,
            onTap: () {
              setState(() {
                _isMenuExpanded = false;
                _currentIndex = 1; // Switch to Habits Screen tab
              });
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddHabitSheet(),
              );
            },
            isDark: isDark,
          ),
          _buildMenuItem(
            icon: Icons.flag_rounded,
            label: "Add Goal",
            iconColor: Colors.orangeAccent,
            onTap: () {
              setState(() => _isMenuExpanded = false);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddGoalSheet(),
              );
            },
            isDark: isDark,
          ),
          _buildMenuItem(
            icon: Icons.timer_outlined,
            label: "Start Focus Session",
            iconColor: Colors.purpleAccent,
            onTap: () {
              setState(() => _isMenuExpanded = false);
              showFocusSetupSheet(context);
            },
            isDark: isDark,
          ),
          if (isDeveloper) ...[
            const Divider(height: 12, indent: 8, endIndent: 8),
            _buildMenuItem(
              icon: Icons.business_center,
              label: "Create Workspace",
              iconColor: const Color(0xFF0F766E),
              onTap: () {
                setState(() => _isMenuExpanded = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateWorkspaceScreen()),
                );
              },
              isDark: isDark,
            ),
            _buildMenuItem(
              icon: Icons.person_add,
              label: "Invite Member",
              iconColor: Colors.teal,
              onTap: () {
                setState(() => _isMenuExpanded = false);
                showDialog(
                  context: context,
                  builder: (context) => const InviteMemberDialog(),
                );
              },
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xE6FFFFFF) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftFAB(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuExpanded = !_isMenuExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedRotation(
            turns: _isMenuExpanded ? 0.125 : 0.0, // Rotates 45 degrees (+ becomes x)
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Firebase Firestore Error",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text("Sign Out & Retry"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isDeveloper = data?['mode'] == 'developer';

        final screens = [
          const HomeScreen(),
          const HabitsScreen(),
          if (isDeveloper) const ProjectsScreen(),
          const CalendarScreen(),
          const ProfileScreen(),
        ];

        // Guard index out of bounds if switching mode down
        if (_currentIndex >= screens.length) {
          _currentIndex = screens.length - 1;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: [
            Scaffold(
              extendBody: true,
              body: IndexedStack(
                index: _currentIndex,
                children: List.generate(screens.length, (index) {
                  final isCurrent = _currentIndex == index;
                  return AnimatedOpacity(
                    opacity: isCurrent ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      offset: isCurrent ? Offset.zero : const Offset(0, 0.015),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !isCurrent,
                        child: screens[index],
                      ),
                    ),
                  );
                }),
              ),
              bottomNavigationBar: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.transparent,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        // Left FAB placeholder (keeps space for the FAB)
                        const SizedBox(width: 56, height: 56),
                        const SizedBox(width: 8),
                        // Floating Pill Navigation Bar
                        Expanded(
                          child: _buildFloatingNavBar(isDeveloper, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Dimmed background barrier when menu is expanded
            if (_isMenuExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isMenuExpanded = false),
                  child: Container(
                    color: Colors.black.withOpacity(0.12),
                  ),
                ),
              ),

            // Expandable Create Menu card
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              bottom: _isMenuExpanded ? 88 + MediaQuery.of(context).padding.bottom : 40 + MediaQuery.of(context).padding.bottom,
              left: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                opacity: _isMenuExpanded ? 1.0 : 0.0,
                child: AnimatedScale(
                  scale: _isMenuExpanded ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.bottomLeft,
                  child: IgnorePointer(
                    ignoring: !_isMenuExpanded,
                    child: _buildCreateMenu(isDeveloper, isDark),
                  ),
                ),
              ),
            ),

            // Left FAB itself
            Positioned(
              left: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
              child: _buildLeftFAB(isDark),
            ),
          ],
        );
      },
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _taskController = TextEditingController();
  final TaskService _taskService = TaskService();
  String _selectedPriority = 'low';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final List<Map<String, dynamic>> _subtasks = [];

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  @override
  void dispose() {
    _taskController.dispose();
    for (var sub in _subtasks) {
      (sub['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      title: const Text("Add Task", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _taskController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Enter task details...",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A32) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Priority",
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['High', 'Medium', 'Low'].map((priority) {
                  final value = priority.toLowerCase();
                  final isSelected = _selectedPriority == value;
                  Color priorityColor;
                  if (value == 'high') {
                    priorityColor = Colors.redAccent;
                  } else if (value == 'medium') {
                    priorityColor = Colors.orangeAccent;
                  } else {
                    priorityColor = Colors.green;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(priority),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPriority = value);
                          }
                        },
                        selectedColor: priorityColor.withOpacity(0.2),
                        backgroundColor: isDark ? const Color(0xFF2A2A32) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? priorityColor : (isDark ? Colors.white12 : Colors.grey[300]!),
                            width: 1.5,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? priorityColor : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDate == null ? "No due date" : _formatDate(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null ? Colors.grey : (isDark ? const Color(0xE6FFFFFF) : Colors.black87),
                            fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                        if (_selectedTime != null)
                          Text(
                            _selectedTime!.format(context),
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() => _selectedDate = pickedDate);
                      }
                    },
                    child: const Text("Date"),
                  ),
                  if (_selectedDate != null)
                    TextButton(
                      onPressed: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() => _selectedTime = pickedTime);
                        }
                      },
                      child: const Text("Time"),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Subtasks",
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _subtasks.add({
                          'controller': TextEditingController(),
                          'isCompleted': false,
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Add", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_subtasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subtasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _subtasks[index]['controller'] as TextEditingController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: "Subtask title...",
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                (_subtasks[index]['controller'] as TextEditingController).dispose();
                                _subtasks.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () async {
            final title = _taskController.text.trim();
            if (title.isNotEmpty) {
              DateTime? finalDate = _selectedDate;
              if (finalDate != null && _selectedTime != null) {
                finalDate = DateTime(
                  finalDate.year,
                  finalDate.month,
                  finalDate.day,
                  _selectedTime!.hour,
                  _selectedTime!.minute,
                );
              }
              
              final List<Map<String, dynamic>> finalSubtasks = [];
              for (var sub in _subtasks) {
                final subTitle = (sub['controller'] as TextEditingController).text.trim();
                if (subTitle.isNotEmpty) {
                  finalSubtasks.add({
                    'title': subTitle,
                    'isCompleted': sub['isCompleted'] ?? false,
                  });
                }
              }
              
              await _taskService.addTask(
                title, 
                priority: _selectedPriority, 
                dueDate: finalDate, 
                subtasks: finalSubtasks
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Task added successfully!"),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            }
          },
          child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key});

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final TextEditingController _emailController = TextEditingController();
  final WorkspaceService _workspaceService = WorkspaceService();
  String? _selectedWorkspaceId;
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      title: const Text("Invite Member", style: TextStyle(fontWeight: FontWeight.bold)),
      content: StreamBuilder<List<Workspace>>(
        stream: _workspaceService.getUserWorkspaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final workspaces = snapshot.data ?? [];
          if (workspaces.isEmpty) {
            return const Text("You have no workspaces to invite members to. Create a workspace first.");
          }
          
          if (_selectedWorkspaceId == null && workspaces.isNotEmpty) {
            _selectedWorkspaceId = workspaces.first.id;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Workspace:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedWorkspaceId,
                  dropdownColor: isDark ? const Color(0xFF2A2A32) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: workspaces.map((ws) {
                    return DropdownMenuItem(
                      value: ws.id,
                      child: Text(ws.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedWorkspaceId = val),
                ),
                const SizedBox(height: 16),
                const Text("Invitee Email:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Enter user's email...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isInviting ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _isInviting || _selectedWorkspaceId == null
              ? null
              : () async {
                  final email = _emailController.text.trim().toLowerCase();
                  if (email.isNotEmpty) {
                    setState(() => _isInviting = true);
                    try {
                      await _workspaceService.sendProjectInvite(_selectedWorkspaceId!, email);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Project invite sent successfully!"),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => _isInviting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  }
                },
          child: _isInviting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("Invite", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
