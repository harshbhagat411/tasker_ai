import 'package:flutter/material.dart';
import '../screens/focus_mode_screen.dart';
import '../services/focus_service.dart';

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
    
    FocusService().startSession(
      taskId: widget.taskId,
      taskTitle: widget.taskTitle,
      projectName: widget.projectName,
      durationInSeconds: durationInMinutes * 60,
      ambientSound: selectedSound == 'None' ? null : selectedSound,
    );

    // Animate transition to Focus Space
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => const FocusModeScreen(),
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
        color: isDark ? Theme.of(context).cardColor : Colors.white,
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
              color: isDark ? Colors.grey.shade900 : Theme.of(context).primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Theme.of(context).primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: isDark ? Colors.grey : Theme.of(context).primaryColor),
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
                  selectedColor: isDark ? Colors.white : Theme.of(context).primaryColor,
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
                selectedColor: isDark ? Colors.white : Theme.of(context).primaryColor,
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _customDuration > 1 ? () => setState(() => _customDuration--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      Text("$_customDuration min", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        onPressed: _customDuration < 180 ? () => setState(() => _customDuration++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                  Slider(
                    value: _customDuration.toDouble(),
                    min: 1,
                    max: 180,
                    activeColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                    inactiveColor: isDark ? Colors.white24 : Theme.of(context).primaryColor.withOpacity(0.2),
                    onChanged: (val) => setState(() => _customDuration = val.toInt()),
                  ),
                ],
              ),
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
                            ? (isDark ? Colors.white.withOpacity(0.15) : Theme.of(context).primaryColor.withOpacity(0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? (isDark ? Colors.white54 : Theme.of(context).primaryColor) 
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sound['icon'], size: 18, color: isSelected ? (isDark ? Colors.white : Theme.of(context).primaryColor) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            sound['name'],
                            style: TextStyle(
                              color: isSelected ? (isDark ? Colors.white : Theme.of(context).primaryColor) : Colors.grey,
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
                backgroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text("Focus for ${_isCustom ? _customDuration : _durations[_selectedDurationIndex]} min", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
