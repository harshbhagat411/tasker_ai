import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GoalService _goalService = GoalService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          "Goals",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
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
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).primaryColor,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: "Today's Goal"),
                Tab(text: "Weekly Goals"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGoalsList(isDaily: true),
          _buildGoalsList(isDaily: false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalSheet(context),
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Goal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildGoalsList({required bool isDaily}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Goal>>(
      stream: isDaily ? _goalService.getDailyGoals() : _goalService.getWeeklyGoals(),
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
          return const Center(child: Text("Error loading goals"));
        }

        final goals = snapshot.data ?? [];

        if (goals.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
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
                    Icons.flag_outlined,
                    size: 54,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isDaily ? "No Today's Goals Set" : "No Weekly Goals Set",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDaily
                        ? "Create simple targets for today to boost your daily productivity score dynamically!"
                        : "Track broader targets over the week to stay disciplined and form long-term streaks.",
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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            return _buildGoalCard(goal);
          },
        );
      },
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          width: 1,
        ),
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
            onTap: () {
              _goalService.toggleGoalComplete(goal.id, goal.type, goal.isCompleted);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goal.isCompleted
                    ? (isDark ? primaryColor : const Color(0xFF2563EB).withOpacity(0.1))
                    : Colors.transparent,
                border: Border.all(
                  color: goal.isCompleted
                      ? (isDark ? primaryColor : const Color(0xFF2563EB))
                      : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                  width: 2.0,
                ),
              ),
              child: goal.isCompleted
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF2563EB),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          // Goal details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                    color: goal.isCompleted
                        ? (isDark ? Colors.white30 : Colors.grey.shade400)
                        : (isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1C1E)),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: goal.type == 'daily'
                        ? (isDark ? const Color(0xFF2E1A47) : const Color(0xFFF3E8FF))
                        : (isDark ? const Color(0xFF1F3A3A) : const Color(0xFFECFDF5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    goal.type == 'daily' ? "Today's Goal" : "Weekly Goal",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: goal.type == 'daily'
                          ? (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE))
                          : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Delete action
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () {
              _goalService.deleteGoal(goal.id, goal.type);
            },
          ),
        ],
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddGoalSheet(),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final TextEditingController _titleController = TextEditingController();
  final GoalService _goalService = GoalService();
  String _selectedType = 'daily';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
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
              "Add New Goal",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),

            // Autofocused input field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Goal Title",
                hintText: "e.g., Read 20 pages, Work out",
                labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 24),

            const Text(
              "Goal Interval",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildTypeChip("daily", "Today's Goal"),
                const SizedBox(width: 12),
                _buildTypeChip("weekly", "Weekly Goal"),
              ],
            ),
            const SizedBox(height: 32),

            // Submit button
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
                  final title = _titleController.text.trim();
                  if (title.isNotEmpty) {
                    if (_selectedType == 'daily') {
                      _goalService.addDailyGoal(title, 1);
                    } else {
                      _goalService.addWeeklyGoal(title, 1);
                    }
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Create Goal",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
