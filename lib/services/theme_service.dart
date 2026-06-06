import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String name;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const AppTheme({
    required this.id,
    required this.name,
    required this.lightTheme,
    required this.darkTheme,
  });
}

class ThemeService {
  // Theme definitions map
  static final Map<String, AppTheme> personalThemes = {
    'classic_blue': AppTheme(
      id: 'classic_blue',
      name: 'Classic Blue',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF0D47A1),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFF1976D2),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        brightness: Brightness.dark,
      ),
    ),
    'forest_green': AppTheme(
      id: 'forest_green',
      name: 'Forest Green',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFF112211),
        cardColor: const Color(0xFF1B301E),
        brightness: Brightness.dark,
      ),
    ),
    'warm_cream': AppTheme(
      id: 'warm_cream',
      name: 'Warm Cream',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF8D6E63),
        scaffoldBackgroundColor: const Color(0xFFFAF6EE),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFFD7CCC8),
        scaffoldBackgroundColor: const Color(0xFF1C1816),
        cardColor: const Color(0xFF272220),
        brightness: Brightness.dark,
      ),
    ),
    'purple_focus': AppTheme(
      id: 'purple_focus',
      name: 'Purple Focus',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF673AB7),
        scaffoldBackgroundColor: const Color(0xFFF3E5F5),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFF9C27B0),
        scaffoldBackgroundColor: const Color(0xFF140D26),
        cardColor: const Color(0xFF1F1636),
        brightness: Brightness.dark,
      ),
    ),
    'midnight_dark': AppTheme(
      id: 'midnight_dark',
      name: 'Midnight Dark',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF0288D1),
        scaffoldBackgroundColor: const Color(0xFFE0F7FA),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFF03A9F4),
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        cardColor: const Color(0xFF1C2541),
        brightness: Brightness.dark,
      ),
    ),
    'amoled_black': AppTheme(
      id: 'amoled_black',
      name: 'AMOLED Black',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFFECEFF1),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFF64B5F6),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF121212),
        brightness: Brightness.dark,
      ),
    ),
    'cyber_purple': AppTheme(
      id: 'cyber_purple',
      name: 'Cyber Purple',
      lightTheme: _buildThemeData(
        primaryColor: const Color(0xFFD500F9),
        scaffoldBackgroundColor: const Color(0xFFFCE4EC),
        cardColor: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      darkTheme: _buildThemeData(
        primaryColor: const Color(0xFFE040FB),
        scaffoldBackgroundColor: const Color(0xFF0F051D),
        cardColor: const Color(0xFF1A0B2E),
        brightness: Brightness.dark,
      ),
    ),
  };

  // Developer Theme: Fixed premium dark mode (VS Code / GitHub Dark style)
  static final ThemeData developerTheme = _buildThemeData(
    primaryColor: const Color(0xFF0F766E), // teal-700 accent
    scaffoldBackgroundColor: const Color(0xFF090D16), // engineering dark feel
    cardColor: const Color(0xFF161B22), // GitHub Dark card style
    brightness: Brightness.dark,
  ).copyWith(
    // Additional customizations for Developer Mode
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF14B8A6), // teal-500 cursor
      selectionColor: Color(0x3314B8A6),
      selectionHandleColor: Color(0xFF14B8A6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2.0),
      ),
      floatingLabelStyle: const TextStyle(color: Color(0xFF14B8A6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // Helper builder to standardise theme setups across the app
  static ThemeData _buildThemeData({
    required Color primaryColor,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Brightness brightness,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: brightness,
        surface: cardColor,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        floatingLabelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: brightness == Brightness.dark
          ? Typography.material2021().white.apply(
                fontFamily: 'Inter',
              )
          : Typography.material2021().black.apply(
                fontFamily: 'Inter',
              ),
    );
  }
}
