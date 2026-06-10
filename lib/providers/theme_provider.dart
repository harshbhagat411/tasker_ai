import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/mode_service.dart';

class ThemeProvider with ChangeNotifier {
  UserMode _currentMode = UserMode.personal;
  
  // Decoupled states for Personal and Developer Modes
  String _personalAppearance = 'system';
  String _personalAccent = 'blue';
  String _personalDarkStyle = 'matte_black';

  String _developerAppearance = 'system';
  String _developerAccent = 'teal';
  String _developerDarkStyle = 'matte_black';

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  UserMode get currentMode => _currentMode;
  String get appearance => _currentMode == UserMode.developer ? _developerAppearance : _personalAppearance;
  String get accentColor => _currentMode == UserMode.developer ? _developerAccent : _personalAccent;
  String get darkStyle => _currentMode == UserMode.developer ? _developerDarkStyle : _personalDarkStyle;

  bool get isDarkMode => appearance == 'dark';
  bool get followSystem => appearance == 'system';

  ThemeProvider() {
    _loadFallbackPreferences().then((_) {
      _initAuthListener();
    });
  }

  ThemeData get themeData {
    return ThemeService.buildTheme(
      accentColor: accentColor,
      darkStyle: darkStyle,
      isDark: false,
      isDeveloper: _currentMode == UserMode.developer,
    );
  }

  ThemeData get darkThemeData {
    return ThemeService.buildTheme(
      accentColor: accentColor,
      darkStyle: darkStyle,
      isDark: true,
      isDeveloper: _currentMode == UserMode.developer,
    );
  }

  ThemeMode get themeMode {
    switch (appearance) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
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
    _personalAppearance = prefs.getString('personal_appearance') ?? 'system';
    _personalAccent = prefs.getString('personal_accent') ?? 'blue';
    _personalDarkStyle = prefs.getString('personal_darkStyle') ?? 'matte_black';

    _developerAppearance = prefs.getString('developer_appearance') ?? 'system';
    _developerAccent = prefs.getString('developer_accent') ?? 'teal';
    _developerDarkStyle = prefs.getString('developer_darkStyle') ?? 'matte_black';
    notifyListeners();
  }

  Future<void> _updateFromFirestoreSnapshot(DocumentSnapshot snapshot) async {
    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>;
    
    final modeStr = data['mode'] as String?;
    final newMode = modeStr == 'developer' ? UserMode.developer : UserMode.personal;

    final personalThemeData = data['personalTheme'] as Map<String, dynamic>?;
    final developerThemeData = data['developerTheme'] as Map<String, dynamic>?;

    String newPersonalAppearance = _personalAppearance;
    String newPersonalAccent = _personalAccent;
    String newPersonalDarkStyle = _personalDarkStyle;

    String newDeveloperAppearance = _developerAppearance;
    String newDeveloperAccent = _developerAccent;
    String newDeveloperDarkStyle = _developerDarkStyle;

    bool needsWrite = false;

    // Load Personal Theme
    if (personalThemeData != null) {
      newPersonalAppearance = personalThemeData['appearance'] as String? ?? 'system';
      newPersonalAccent = personalThemeData['accent'] as String? ?? 'blue';
      newPersonalDarkStyle = personalThemeData['darkStyle'] as String? ?? 'matte_black';
    } else {
      needsWrite = true;
      // Try migrating from legacy themeSettings (Step 2 Refactor format or Step 1 format)
      final themeSettings = data['themeSettings'] as Map<String, dynamic>?;
      if (themeSettings != null) {
        if (themeSettings.containsKey('appearance') || 
            themeSettings.containsKey('accentColor') || 
            themeSettings.containsKey('darkStyle')) {
          newPersonalAppearance = themeSettings['appearance'] as String? ?? 'system';
          newPersonalAccent = themeSettings['accentColor'] as String? ?? 'blue';
          newPersonalDarkStyle = themeSettings['darkStyle'] as String? ?? 'matte_black';
        } else {
          final legacyTheme = themeSettings['personalTheme'] as String? ?? 'classic_blue';
          final legacyDark = themeSettings['darkMode'] as bool? ?? true;
          final legacySystem = themeSettings['followSystem'] as bool? ?? false;

          newPersonalAccent = _mapLegacyThemeToAccent(legacyTheme);
          newPersonalDarkStyle = _mapLegacyThemeToDarkStyle(legacyTheme);
          newPersonalAppearance = legacySystem 
              ? 'system' 
              : (legacyDark ? 'dark' : 'light');
        }
      } else {
        // Fallback defaults
        newPersonalAppearance = 'system';
        newPersonalAccent = 'blue';
        newPersonalDarkStyle = 'matte_black';
      }
    }

    // Load Developer Theme
    if (developerThemeData != null) {
      newDeveloperAppearance = developerThemeData['appearance'] as String? ?? 'system';
      newDeveloperAccent = developerThemeData['accent'] as String? ?? 'teal';
      newDeveloperDarkStyle = developerThemeData['darkStyle'] as String? ?? 'matte_black';
    } else {
      needsWrite = true;
      newDeveloperAppearance = 'system';
      newDeveloperAccent = 'teal';
      newDeveloperDarkStyle = 'matte_black';
    }

    if (needsWrite) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'personalTheme': {
              'appearance': newPersonalAppearance,
              'accent': newPersonalAccent,
              'darkStyle': newPersonalDarkStyle,
            },
            'developerTheme': {
              'appearance': newDeveloperAppearance,
              'accent': newDeveloperAccent,
              'darkStyle': newDeveloperDarkStyle,
            }
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error migrating user theme formats to Firestore: $e');
        }
      }
    }

    final modeChanged = _currentMode != newMode;
    final personalChanged = _personalAppearance != newPersonalAppearance ||
        _personalAccent != newPersonalAccent ||
        _personalDarkStyle != newPersonalDarkStyle;
    final developerChanged = _developerAppearance != newDeveloperAppearance ||
        _developerAccent != newDeveloperAccent ||
        _developerDarkStyle != newDeveloperDarkStyle;

    if (modeChanged || personalChanged || developerChanged) {
      _currentMode = newMode;
      _personalAppearance = newPersonalAppearance;
      _personalAccent = newPersonalAccent;
      _personalDarkStyle = newPersonalDarkStyle;
      _developerAppearance = newDeveloperAppearance;
      _developerAccent = newDeveloperAccent;
      _developerDarkStyle = newDeveloperDarkStyle;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('personal_appearance', _personalAppearance);
      await prefs.setString('personal_accent', _personalAccent);
      await prefs.setString('personal_darkStyle', _personalDarkStyle);
      await prefs.setString('developer_appearance', _developerAppearance);
      await prefs.setString('developer_accent', _developerAccent);
      await prefs.setString('developer_darkStyle', _developerDarkStyle);

      notifyListeners();
    }
  }

  String _mapLegacyThemeToAccent(String legacyTheme) {
    switch (legacyTheme) {
      case 'classic_blue':
      case 'midnight_dark':
      case 'amoled_black':
        return 'blue';
      case 'forest_green':
        return 'green';
      case 'purple_focus':
      case 'cyber_purple':
        return 'purple';
      case 'warm_cream':
        return 'orange';
      default:
        return 'blue';
    }
  }

  String _mapLegacyThemeToDarkStyle(String legacyTheme) {
    switch (legacyTheme) {
      case 'midnight_dark':
        return 'matte_black'; // midnight_dark -> matte black
      case 'amoled_black':
      case 'cyber_purple':
        return 'amoled'; // amoled_black -> amoled
      default:
        return 'matte_black';
    }
  }

  Future<void> updateThemeSettings({
    String? appearance,
    String? accentColor,
    String? darkStyle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool changed = false;

    if (_currentMode == UserMode.personal) {
      if (appearance != null && _personalAppearance != appearance) {
        _personalAppearance = appearance;
        changed = true;
      }
      if (accentColor != null && _personalAccent != accentColor) {
        _personalAccent = accentColor;
        changed = true;
      }
      if (darkStyle != null && _personalDarkStyle != darkStyle) {
        _personalDarkStyle = darkStyle;
        changed = true;
      }

      if (!changed) return;

      notifyListeners();

      unawaited(
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'personalTheme': {
            'appearance': _personalAppearance,
            'accent': _personalAccent,
            'darkStyle': _personalDarkStyle,
          },
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Error updating personal theme settings: $e');
        })
      );
    } else {
      if (appearance != null && _developerAppearance != appearance) {
        _developerAppearance = appearance;
        changed = true;
      }
      if (accentColor != null && _developerAccent != accentColor) {
        _developerAccent = accentColor;
        changed = true;
      }
      if (darkStyle != null && _developerDarkStyle != darkStyle) {
        _developerDarkStyle = darkStyle;
        changed = true;
      }

      if (!changed) return;

      notifyListeners();

      unawaited(
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'developerTheme': {
            'appearance': _developerAppearance,
            'accent': _developerAccent,
            'darkStyle': _developerDarkStyle,
          },
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Error updating developer theme settings: $e');
        })
      );
    }

    unawaited(
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('personal_appearance', _personalAppearance);
        prefs.setString('personal_accent', _personalAccent);
        prefs.setString('personal_darkStyle', _personalDarkStyle);
        prefs.setString('developer_appearance', _developerAppearance);
        prefs.setString('developer_accent', _developerAccent);
        prefs.setString('developer_darkStyle', _developerDarkStyle);
      }).catchError((e) {
        debugPrint('Error saving preferences locally: $e');
      })
    );
  }

  Future<void> toggleTheme() async {
    final nextAppearance = appearance == 'dark' ? 'light' : 'dark';
    await updateThemeSettings(appearance: nextAppearance);
  }

  void _resetToDefaults() {
    _currentMode = UserMode.personal;
    _personalAppearance = 'system';
    _personalAccent = 'blue';
    _personalDarkStyle = 'matte_black';
    _developerAppearance = 'system';
    _developerAccent = 'teal';
    _developerDarkStyle = 'matte_black';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
