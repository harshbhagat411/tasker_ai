import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/mode_service.dart';

class ThemeCenterScreen extends StatelessWidget {
  const ThemeCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDeveloper = themeProvider.currentMode == UserMode.developer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine if dark style section should be shown
    // It is active if appearance is forced dark, or if system is dark and follow system is active.
    final isResolvedDark = themeProvider.appearance == 'dark' || 
        (themeProvider.appearance == 'system' && isDark);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Theme Center", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Developer Mode Warning Card
            if (isDeveloper) ...[
              _buildDeveloperInfoCard(context),
              const SizedBox(height: 24),
            ],

            // 🔹 Customization options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Appearance Customizer
                _buildSectionHeader(context, "Appearance"),
                const SizedBox(height: 10),
                _buildAppearanceSelector(context, themeProvider),
                const SizedBox(height: 24),

                // 2. Accent Color Customizer
                _buildSectionHeader(context, "Accent Color"),
                const SizedBox(height: 10),
                _buildAccentColorPicker(context, themeProvider),
                const SizedBox(height: 24),

                // 3. Dark Style Customizer (Only shown if dark mode is active)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: isResolvedDark
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, "Dark Style"),
                            const SizedBox(height: 10),
                            _buildDarkStyleSelector(context, themeProvider),
                            const SizedBox(height: 24),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7) ?? Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDeveloperInfoCard(BuildContext context) {
    final tealAccent = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tealAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tealAccent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.terminal_outlined, color: tealAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Developer Mode Active",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Developer Mode uses a dedicated workspace theme to help distinguish workspaces from personal productivity.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Theme settings are independent between Personal and Developer modes.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: tealAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSelector(BuildContext context, ThemeProvider themeProvider) {
    final appearance = themeProvider.appearance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white10 
                  : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              _buildAppearanceOption(
                context,
                label: "Light",
                icon: Icons.light_mode_outlined,
                isSelected: appearance == 'light',
                onTap: () => themeProvider.updateThemeSettings(appearance: 'light'),
              ),
              _buildVerticalDivider(context),
              _buildAppearanceOption(
                context,
                label: "Dark",
                icon: Icons.dark_mode_outlined,
                isSelected: appearance == 'dark',
                onTap: () => themeProvider.updateThemeSettings(appearance: 'dark'),
              ),
              _buildVerticalDivider(context),
              _buildAppearanceOption(
                context,
                label: "System",
                icon: Icons.settings_suggest_outlined,
                isSelected: appearance == 'system',
                onTap: () => themeProvider.updateThemeSettings(appearance: 'system'),
              ),
            ],
          ),
        ),
        if (appearance == 'system') ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "Using device appearance",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? Colors.grey,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppearanceOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = Theme.of(context).primaryColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Theme.of(context).iconTheme.color?.withOpacity(0.7),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
    );
  }

  Widget _buildAccentColorPicker(BuildContext context, ThemeProvider themeProvider) {
    final activeAccent = themeProvider.accentColor;
    final isDeveloper = themeProvider.currentMode == UserMode.developer;
    
    // Circular chips mapping
    final accentList = isDeveloper
        ? [
            {'id': 'teal', 'color': const Color(0xFF14B8A6), 'name': 'Teal'},
            {'id': 'indigo', 'color': const Color(0xFF6366F1), 'name': 'Indigo'},
            {'id': 'green', 'color': const Color(0xFF22C55E), 'name': 'Green'},
            {'id': 'amber', 'color': const Color(0xFFF59E0B), 'name': 'Amber'},
            {'id': 'crimson', 'color': const Color(0xFFF43F5E), 'name': 'Crimson'},
          ]
        : [
            {'id': 'blue', 'color': const Color(0xFF1976D2), 'name': 'Blue'},
            {'id': 'green', 'color': const Color(0xFF4CAF50), 'name': 'Green'},
            {'id': 'purple', 'color': const Color(0xFF9C27B0), 'name': 'Purple'},
            {'id': 'orange', 'color': const Color(0xFFFF9800), 'name': 'Orange'},
            {'id': 'red', 'color': const Color(0xFFEF5350), 'name': 'Red'},
            {'id': 'cyan', 'color': const Color(0xFF00ACC1), 'name': 'Cyan'},
          ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white10 
              : Colors.black12,
        ),
      ),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: accentList.map((accent) {
            final isSelected = activeAccent == accent['id'];
            final color = accent['color'] as Color;

            return GestureDetector(
              onTap: () => themeProvider.updateThemeSettings(accentColor: accent['id'] as String),
              child: Tooltip(
                message: accent['name'] as String,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDarkStyleSelector(BuildContext context, ThemeProvider themeProvider) {
    final activeDarkStyle = themeProvider.darkStyle;
    final isDeveloper = themeProvider.currentMode == UserMode.developer;

    final styles = [
      {
        'id': 'soft_dark',
        'name': 'Soft Dark',
        'desc': isDeveloper ? 'Slate-charcoal layout' : 'Comfortable charcoal layout',
        'color': isDeveloper ? const Color(0xFF1E222B) : const Color(0xFF1E2026),
        'cardColor': isDeveloper ? const Color(0xFF282D37) : const Color(0xFF282B36),
      },
      {
        'id': 'matte_black',
        'name': 'Matte Black',
        'desc': isDeveloper ? 'VS Code & GitHub Dark style' : 'Premium dark matte background',
        'color': isDeveloper ? const Color(0xFF0D1117) : const Color(0xFF121212),
        'cardColor': isDeveloper ? const Color(0xFF161B22) : const Color(0xFF1E1E1E),
      },
      {
        'id': 'amoled',
        'name': 'AMOLED Black',
        'desc': 'True pure black for OLED devices',
        'color': const Color(0xFF000000),
        'cardColor': const Color(0xFF121212),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white10 
              : Colors.black12,
        ),
      ),
      child: Column(
        children: List.generate(styles.length, (index) {
          final style = styles[index];
          final isSelected = activeDarkStyle == style['id'];
          final isLast = index == styles.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style['color'] as Color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white24 
                          : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  style['name'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                subtitle: Text(
                  style['desc'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                trailing: isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Active",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () => themeProvider.updateThemeSettings(darkStyle: style['id'] as String),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                  indent: 68,
                ),
            ],
          );
        }),
      ),
    );
  }
}
