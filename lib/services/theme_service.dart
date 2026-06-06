import 'package:flutter/material.dart';

class ThemeService {
  // Accent colors mapping for Personal Mode (Light and Dark primary colors)
  static const Map<String, Color> personalAccentColorsLight = {
    'blue': Color(0xFF0D47A1),
    'green': Color(0xFF2E7D32),
    'purple': Color(0xFF673AB7),
    'orange': Color(0xFFE65100),
    'red': Color(0xFFC62828),
    'cyan': Color(0xFF00838F),
  };

  static const Map<String, Color> personalAccentColorsDark = {
    'blue': Color(0xFF1976D2),
    'green': Color(0xFF4CAF50),
    'purple': Color(0xFF9C27B0),
    'orange': Color(0xFFFF9800),
    'red': Color(0xFFEF5350),
    'cyan': Color(0xFF00ACC1),
  };

  // Accent colors mapping for Developer Mode (Light and Dark primary colors)
  static const Map<String, Color> devAccentColorsLight = {
    'teal': Color(0xFF0F766E),
    'indigo': Color(0xFF3F51B5),
    'green': Color(0xFF16A34A),
    'amber': Color(0xFFD97706),
    'crimson': Color(0xFFBE123C),
  };

  static const Map<String, Color> devAccentColorsDark = {
    'teal': Color(0xFF14B8A6),
    'indigo': Color(0xFF6366F1),
    'green': Color(0xFF22C55E),
    'amber': Color(0xFFF59E0B),
    'crimson': Color(0xFFF43F5E),
  };

  // Dark styles backgrounds and cards mapping for Personal Mode
  static const Map<String, Color> darkStyleScaffold = {
    'soft_dark': Color(0xFF1E2026),
    'matte_black': Color(0xFF121212),
    'amoled': Color(0xFF000000),
  };

  static const Map<String, Color> darkStyleCard = {
    'soft_dark': Color(0xFF282B36),
    'matte_black': Color(0xFF1E1E1E),
    'amoled': Color(0xFF121212),
  };

  // Dark styles backgrounds and cards mapping for Developer Mode
  static const Map<String, Color> devDarkStyleScaffold = {
    'soft_dark': Color(0xFF1E222B),
    'matte_black': Color(0xFF0D1117), // GitHub Dark
    'amoled': Color(0xFF000000),
  };

  static const Map<String, Color> devDarkStyleCard = {
    'soft_dark': Color(0xFF282D37),
    'matte_black': Color(0xFF161B22), // GitHub Dark card
    'amoled': Color(0xFF121212),
  };

  // Static Developer Mode Theme fallback
  static final ThemeData developerTheme = _buildThemeData(
    primaryColor: const Color(0xFF0F766E), // teal-700
    scaffoldBackgroundColor: const Color(0xFF090D16), // engineering dark
    cardColor: const Color(0xFF161B22), // GitHub Dark card
    brightness: Brightness.dark,
    isDeveloper: true,
  );

  // Core builder to dynamically generate light/dark theme data
  static ThemeData buildTheme({
    required String accentColor,
    required String darkStyle,
    required bool isDark,
    required bool isDeveloper,
  }) {
    // Falls back to defaults to ensure safety and prevent crashes
    final resolvedAccent = accentColor.toLowerCase();
    final resolvedDarkStyle = darkStyle.toLowerCase();

    Color primaryColor;
    Color scaffoldBg;
    Color cardBg;

    if (isDeveloper) {
      if (isDark) {
        primaryColor = devAccentColorsDark[resolvedAccent] ?? devAccentColorsDark['teal']!;
        scaffoldBg = devDarkStyleScaffold[resolvedDarkStyle] ?? devDarkStyleScaffold['matte_black']!;
        cardBg = devDarkStyleCard[resolvedDarkStyle] ?? devDarkStyleCard['matte_black']!;
      } else {
        primaryColor = devAccentColorsLight[resolvedAccent] ?? devAccentColorsLight['teal']!;
        scaffoldBg = const Color(0xFFF1F5F9); // slate gray
        cardBg = const Color(0xFFFFFFFF);
      }
    } else {
      if (isDark) {
        primaryColor = personalAccentColorsDark[resolvedAccent] ?? personalAccentColorsDark['blue']!;
        scaffoldBg = darkStyleScaffold[resolvedDarkStyle] ?? darkStyleScaffold['matte_black']!;
        cardBg = darkStyleCard[resolvedDarkStyle] ?? darkStyleCard['matte_black']!;
      } else {
        primaryColor = personalAccentColorsLight[resolvedAccent] ?? personalAccentColorsLight['blue']!;
        scaffoldBg = const Color(0xFFF5F6FA);
        cardBg = const Color(0xFFFFFFFF);
      }
    }

    return _buildThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      brightness: isDark ? Brightness.dark : Brightness.light,
      isDeveloper: isDeveloper,
    );
  }

  // Base builder to generate ThemeData with standardized settings
  static ThemeData _buildThemeData({
    required Color primaryColor,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Brightness brightness,
    required bool isDeveloper,
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
        selectionColor: primaryColor.withOpacity(0.2),
        selectionHandleColor: primaryColor,
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
        titleTextStyle: TextStyle(
          fontFamily: isDeveloper ? 'Courier New' : 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDeveloper
              ? BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5)
              : BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        shape: isDeveloper
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: primaryColor.withOpacity(0.4), width: 1.0),
              )
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: brightness == Brightness.dark
          ? Typography.material2021().white.apply(
                fontFamily: isDeveloper ? 'Courier New' : 'Inter',
              )
          : Typography.material2021().black.apply(
                fontFamily: isDeveloper ? 'Courier New' : 'Inter',
              ),
    );
  }
}
