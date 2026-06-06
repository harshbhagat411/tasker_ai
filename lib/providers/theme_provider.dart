import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/mode_service.dart';

class ThemeProvider with ChangeNotifier {
  UserMode _currentMode = UserMode.personal;
  String _personalTheme = 'classic_blue';
  bool _darkMode = false;
  bool _followSystem = false;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  UserMode get currentMode => _currentMode;
  String get personalTheme => _personalTheme;
  bool get darkMode => _darkMode;
  bool get isDarkMode => _currentMode == UserMode.developer ? true : _darkMode;
  bool get followSystem => _followSystem;

  ThemeProvider() {
    _loadFallbackPreferences().then((_) {
      _initAuthListener();
    });
  }

  ThemeData get themeData {
    if (_currentMode == UserMode.developer) {
      return ThemeService.developerTheme;
    }
    final appTheme = ThemeService.personalThemes[_personalTheme] ?? ThemeService.personalThemes['classic_blue']!;
    return appTheme.lightTheme;
  }

  ThemeData get darkThemeData {
    if (_currentMode == UserMode.developer) {
      return ThemeService.developerTheme;
    }
    final appTheme = ThemeService.personalThemes[_personalTheme] ?? ThemeService.personalThemes['classic_blue']!;
    return appTheme.darkTheme;
  }

  ThemeMode get themeMode {
    if (_currentMode == UserMode.developer) {
      return ThemeMode.dark;
    }
    if (_followSystem) {
      return ThemeMode.system;
    }
    return _darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _initAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userDocSubscription?.cancel();
      if (user != null) {
        _userDocSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
              _updateFromFirestoreSnapshot(snapshot);
            }, onError: (error) {
              debugPrint('Error listening to user theme preferences: $error');
            });
      } else {
        _resetToDefaults();
      }
    });
  }

  Future<void> _loadFallbackPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _personalTheme = prefs.getString('personalTheme') ?? 'classic_blue';
    _darkMode = prefs.getBool('isDarkMode') ?? false;
    _followSystem = prefs.getBool('followSystem') ?? false;
    notifyListeners();
  }

  Future<void> _updateFromFirestoreSnapshot(DocumentSnapshot snapshot) async {
    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>;
    
    final modeStr = data['mode'] as String?;
    _currentMode = modeStr == 'developer' ? UserMode.developer : UserMode.personal;

    final themeSettings = data['themeSettings'] as Map<String, dynamic>?;
    if (themeSettings != null) {
      _personalTheme = themeSettings['personalTheme'] as String? ?? 'classic_blue';
      _darkMode = themeSettings['darkMode'] as bool? ?? true;
      _followSystem = themeSettings['followSystem'] as bool? ?? false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('personalTheme', _personalTheme);
      await prefs.setBool('isDarkMode', _darkMode);
      await prefs.setBool('followSystem', _followSystem);
    } else {
      // Migration: Read local setting and migrate to Firestore
      final prefs = await SharedPreferences.getInstance();
      final localIsDark = prefs.getBool('isDarkMode') ?? false;
      
      _personalTheme = 'classic_blue';
      _darkMode = localIsDark;
      _followSystem = false;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'themeSettings': {
              'personalTheme': _personalTheme,
              'darkMode': _darkMode,
              'followSystem': _followSystem,
            }
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error migrating theme settings to Firestore: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> updateThemeSettings({
    String? personalTheme,
    bool? darkMode,
    bool? followSystem,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_currentMode == UserMode.personal) {
      final updates = <String, dynamic>{};
      if (personalTheme != null) {
        updates['personalTheme'] = personalTheme;
        _personalTheme = personalTheme;
      }
      if (darkMode != null) {
        updates['darkMode'] = darkMode;
        _darkMode = darkMode;
      }
      if (followSystem != null) {
        updates['followSystem'] = followSystem;
        _followSystem = followSystem;
      }

      notifyListeners();

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'themeSettings': updates,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating theme settings in Firestore: $e');
      }
    }
  }

  Future<void> toggleTheme() async {
    if (_currentMode == UserMode.personal) {
      await updateThemeSettings(darkMode: !_darkMode);
    }
  }

  void _resetToDefaults() {
    _currentMode = UserMode.personal;
    _personalTheme = 'classic_blue';
    _darkMode = false;
    _followSystem = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
