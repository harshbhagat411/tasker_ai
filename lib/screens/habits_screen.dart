import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import 'goals_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitService _habitService = HabitService();
  int _selectedTab = 0; // 0 for Habits, 1 for Goals

  @override
  Widget _buildSegmentedSwitch(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _selectedTab == 0 ? primaryColor : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  "Habits",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _selectedTab == 0
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _selectedTab == 1 ? primaryColor : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  "Goals",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _selectedTab == 1
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? "Habits" : "Goals",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSegmentedSwitch(isDark),
            const SizedBox(height: 12),
            Expanded(
              child: _selectedTab == 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
                          child: Text(
                            "Today's Habits",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<Habit>>(
                            stream: _habitService.getHabits(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                );
                              }
                              
                              if (snapshot.hasError) {
                                return const Center(child: Text("Error loading habits"));
                              }
                              
                              final habits = snapshot.data ?? [];
                              
                              if (habits.isEmpty) {
                                return Center(
                                  child: Container(
                                    margin: const EdgeInsets.all(24),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: isDark
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.repeat,
                                          size: 54,
                                          color: isDark ? Colors.white24 : Colors.black12,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          "Build Healthy Habits",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Create daily consistency loops. Repeat, track streaks, and transform your routine!",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white38 : Colors.black45,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              final double bottomPadding = 56.0 + 12.0 + MediaQuery.of(context).padding.bottom + 16.0;
                              return ListView.builder(
                                padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
                                itemCount: habits.length,
                                itemBuilder: (context, index) {
                                  final habit = habits[index];
                                  return _buildHabitCard(habit, isDark);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : const GoalsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit, bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    final successColor = const Color(0xFF10B981); // Emerald Green
    
    // Define card background and border colors based on completed state
    final Color cardBg = habit.isCompleted
        ? (isDark ? const Color(0xFF142D22) : const Color(0xFFF0FDF4))
        : Theme.of(context).cardColor;
        
    final Color borderCol = habit.isCompleted
        ? (isDark ? Colors.transparent : const Color(0xFFDCFCE7))
        : (isDark ? Colors.white10 : const Color(0xFFF1F5F9));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Completed checkbox
          GestureDetector(
            onTap: habit.type == 'daily'
                ? () => _habitService.toggleDailyHabit(habit.id, habit)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: habit.isCompleted
                    ? successColor
                    : Colors.transparent,
                border: Border.all(
                  color: habit.isCompleted
                      ? successColor
                      : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                  width: 2.0,
                ),
              ),
              child: habit.isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          // Habit Title and Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: habit.isCompleted
                        ? (isDark ? Colors.white30 : const Color(0xFF166534).withOpacity(0.6))
                        : (isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1C1E)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Streak Pill
                    if (habit.streakCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("🔥", style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              "${habit.streakCount} day streak",
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Progress Pill for Count/Time types
                    if (habit.type != 'daily') ...[
                      if (habit.streakCount > 0) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${habit.progress} / ${habit.target}${habit.type == 'time' ? 'm' : ''}",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Action elements based on habit type
          if (habit.type == 'count' && !habit.isCompleted)
            GestureDetector(
              onTap: () => _habitService.incrementProgress(habit.id, habit, 1),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                ),
                child: Icon(Icons.add, color: primaryColor, size: 18),
              ),
            )
          else if (habit.type == 'time' && !habit.isCompleted)
            ElevatedButton(
              onPressed: () => _habitService.incrementProgress(habit.id, habit, 10), // Adds 10 mins
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withOpacity(0.1),
                foregroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("+10m", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  void _showAddHabitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHabitSheet(),
    );
  }
}

class AddHabitSheet extends StatefulWidget {
  const AddHabitSheet({super.key});

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  final TextEditingController _titleController = TextEditingController();
  final HabitService _habitService = HabitService();
  String _selectedType = 'daily';
  int _target = 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Slide indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              "New Habit",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Habit Title",
                hintText: "e.g., Workout, Drink Water",
                labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 24),
            const Text("Habit Type", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeChip("daily", "Daily"),
                const SizedBox(width: 8),
                _buildTypeChip("count", "Count"),
                const SizedBox(width: 8),
                _buildTypeChip("time", "Time"),
              ],
            ),
            if (_selectedType != 'daily') ...[
              const SizedBox(height: 24),
              Text(
                "Target (${_selectedType == 'time' ? 'minutes' : 'times'})",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _target > 1 ? () => setState(() => _target--) : null,
                  ),
                  Text("$_target", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _target++),
                  ),
                ],
              )
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_titleController.text.trim().isNotEmpty) {
                    _habitService.addHabit(
                      _titleController.text.trim(),
                      _selectedType,
                      target: _target,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text("Create Habit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildTypeChip(String type, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedType == type;
    final primaryColor = Theme.of(context).primaryColor;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type == 'daily') _target = 1;
            if (type == 'count') _target = 8;
            if (type == 'time') _target = 60;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
            ),
          ),
        ),
      ),
    );
  }
}
