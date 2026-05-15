import 'package:flutter/material.dart';
import '../screens/focus_mode_screen.dart';

class FocusSetupSheet extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;
  final String? projectName;

  const FocusSetupSheet({
    super.key,
    this.taskId,
    this.taskTitle,
    this.projectName,
  });

  @override
  State<FocusSetupSheet> createState() => _FocusSetupSheetState();
}

class _FocusSetupSheetState extends State<FocusSetupSheet> {
  int _selectedDurationIndex = 1; // Default to 25m
  final List<int> _durations = [15, 25, 45, 60];
  int _customDuration = 90;
  bool _isCustom = false;

  int _selectedSoundIndex = 0;
  final List<Map<String, dynamic>> _sounds = [
    {'name': 'None', 'icon': Icons.music_off},
    {'name': 'Rain', 'icon': Icons.water_drop},
    {'name': 'Cafe', 'icon': Icons.local_cafe},
    {'name': 'White Noise', 'icon': Icons.waves},
    {'name': 'Lofi', 'icon': Icons.headphones},
  ];

  void _enterFocusSpace() {
    final int durationInMinutes = _isCustom ? _customDuration : _durations[_selectedDurationIndex];
    final String selectedSound = _sounds[_selectedSoundIndex]['name'];

    Navigator.pop(context); // Close sheet
    
    // Animate transition to Focus Space
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => FocusModeScreen(
          taskId: widget.taskId,
          taskTitle: widget.taskTitle,
          projectName: widget.projectName,
          durationInSeconds: durationInMinutes * 60,
          ambientSound: selectedSound == 'None' ? null : selectedSound,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Focus Setup", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Task Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: isDark ? Colors.grey : Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.taskTitle ?? "Deep Focus",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.projectName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.projectName!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Duration
          const Text("Duration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...List.generate(_durations.length, (index) {
                final isSelected = !_isCustom && _selectedDurationIndex == index;
                return ChoiceChip(
                  label: Text("${_durations[index]}m"),
                  selected: isSelected,
                  selectedColor: isDark ? Colors.white : const Color(0xFF0D47A1),
                  labelStyle: TextStyle(
                    color: isSelected 
                        ? (isDark ? Colors.black : Colors.white) 
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCustom = false;
                        _selectedDurationIndex = index;
                      });
                    }
                  },
                );
              }),
              ChoiceChip(
                label: const Text("Custom"),
                selected: _isCustom,
                selectedColor: isDark ? Colors.white : const Color(0xFF0D47A1),
                labelStyle: TextStyle(
                  color: _isCustom 
                      ? (isDark ? Colors.black : Colors.white) 
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: _isCustom ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _isCustom = true);
                },
              )
            ],
          ),
          
          if (_isCustom) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _customDuration.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: isDark ? Colors.white : const Color(0xFF0D47A1),
                    onChanged: (val) => setState(() => _customDuration = val.toInt()),
                  ),
                ),
                Text("${_customDuration}m", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
          
          const SizedBox(height: 24),

          // Ambience
          const Text("Ambient Sound", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_sounds.length, (index) {
                final isSelected = _selectedSoundIndex == index;
                final sound = _sounds[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSoundIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? Colors.white.withOpacity(0.15) : Colors.blue.withOpacity(0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? (isDark ? Colors.white54 : Colors.blue) 
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sound['icon'], size: 18, color: isSelected ? (isDark ? Colors.white : Colors.blue) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            sound['name'],
                            style: TextStyle(
                              color: isSelected ? (isDark ? Colors.white : Colors.blue) : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 40),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enterFocusSpace,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF0D47A1),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("Enter Focus Space", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

void showFocusSetupSheet(BuildContext context, {String? taskId, String? taskTitle, String? projectName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FocusSetupSheet(
      taskId: taskId,
      taskTitle: taskTitle,
      projectName: projectName,
    ),
  );
}
