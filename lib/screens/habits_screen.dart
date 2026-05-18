import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitService _habitService = HabitService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Habits", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Habits",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Habit>>(
                stream: _habitService.getHabits(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading habits"));
                  }
                  
                  final habits = snapshot.data ?? [];
                  
                  if (habits.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.repeat, size: 64, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text("No habits yet", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitSheet(context),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: habit.isCompleted ? TextDecoration.lineThrough : null,
                    color: habit.isCompleted ? Colors.grey : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (habit.streakCount > 0)
                      Text("🔥 ${habit.streakCount} day streak", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (habit.streakCount > 0 && habit.type != 'daily')
                      const SizedBox(width: 8),
                    if (habit.type != 'daily')
                      Text(
                        "${habit.progress} / ${habit.target} ${habit.type == 'time' ? 'mins' : ''}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Actions based on habit type
          if (habit.type == 'daily')
            IconButton(
              icon: Icon(
                habit.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: habit.isCompleted ? Colors.green : Colors.grey,
                size: 28,
              ),
              onPressed: () => _habitService.toggleDailyHabit(habit.id, habit),
            )
          else if (habit.type == 'count')
            Row(
              children: [
                if (!habit.isCompleted)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                    onPressed: () => _habitService.incrementProgress(habit.id, habit, 1),
                  ),
                if (habit.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
              ],
            )
          else if (habit.type == 'time')
            Row(
              children: [
                if (!habit.isCompleted)
                  ElevatedButton(
                    onPressed: () => _habitService.incrementProgress(habit.id, habit, 10), // Adds 10 mins for Phase 7A
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      foregroundColor: Theme.of(context).primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("+10m"),
                  ),
                if (habit.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
              ],
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
      builder: (context) => const _AddHabitSheet(),
    );
  }
}

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet();

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
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
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Habit", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Habit Title",
                hintText: "e.g., Workout, Drink Water",
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            const Text("Habit Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("Daily (Once)"),
                  selected: _selectedType == 'daily',
                  onSelected: (val) {
                    if (val) setState(() { _selectedType = 'daily'; _target = 1; });
                  },
                ),
                ChoiceChip(
                  label: const Text("Count"),
                  selected: _selectedType == 'count',
                  onSelected: (val) {
                    if (val) setState(() { _selectedType = 'count'; _target = 8; });
                  },
                ),
                ChoiceChip(
                  label: const Text("Time"),
                  selected: _selectedType == 'time',
                  onSelected: (val) {
                    if (val) setState(() { _selectedType = 'time'; _target = 60; });
                  },
                ),
              ],
            ),
            if (_selectedType != 'daily') ...[
              const SizedBox(height: 20),
              Text("Target (${_selectedType == 'time' ? 'minutes' : 'times'})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }
}
