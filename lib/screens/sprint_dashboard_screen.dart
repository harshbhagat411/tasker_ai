import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workspace_model.dart';
import '../models/sprint.dart';
import '../services/sprint_service.dart';
import '../services/task_service.dart';

class SprintDashboardScreen extends StatefulWidget {
  final Workspace workspace;

  const SprintDashboardScreen({super.key, required this.workspace});

  @override
  State<SprintDashboardScreen> createState() => _SprintDashboardScreenState();
}

class _SprintDashboardScreenState extends State<SprintDashboardScreen> {
  final SprintService _sprintService = SprintService();
  final TaskService _taskService = TaskService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isAllowedToManage() {
    final role = widget.workspace.memberRoles[_currentUserId];
    return role == 'owner' || role == 'admin' || widget.workspace.ownerId == _currentUserId;
  }

  void _showCreateSprintModal(BuildContext context, Sprint? activeSprint, Color themeColor, bool isDark) {
    if (!_isAllowedToManage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Workspace Owners or Admins can create sprints.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _CreateSprintDialog(
              workspace: widget.workspace,
              activeSprint: activeSprint,
              themeColor: themeColor,
              isDark: isDark,
              sprintService: _sprintService,
            );
          },
        );
      },
    );
  }

  void _showLinkBacklogModal(BuildContext context, Sprint sprint, Color themeColor, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LinkBacklogDialog(
          workspace: widget.workspace,
          sprint: sprint,
          themeColor: themeColor,
          isDark: isDark,
          taskService: _taskService,
          sprintService: _sprintService,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Color(int.parse(widget.workspace.color));
    final isAllowed = _isAllowedToManage();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Agile Sprints",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              "Workspace: ${widget.workspace.name}",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: themeColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isAllowed)
            StreamBuilder<List<Sprint>>(
              stream: _sprintService.getProjectSprints(widget.workspace.id),
              builder: (context, snapshot) {
                final sprints = snapshot.data ?? [];
                Sprint? active;
                try {
                  active = sprints.firstWhere((s) => s.status == 'active');
                } catch (_) {}

                return TextButton.icon(
                  onPressed: () => _showCreateSprintModal(context, active, themeColor, isDark),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text("Plan Sprint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Sprint>>(
        stream: _sprintService.getProjectSprints(widget.workspace.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sprints = snapshot.data ?? [];
          final nonArchived = sprints.where((s) => s.status != 'archived').toList();

          if (nonArchived.isEmpty) {
            return _buildEmptyState(context, themeColor, isDark, isAllowed);
          }

          Sprint? activeSprint;
          try {
            activeSprint = nonArchived.firstWhere((s) => s.status == 'active');
          } catch (_) {}

          final plannedSprints = nonArchived.where((s) => s.status == 'planned').toList();
          final completedSprints = nonArchived.where((s) => s.status == 'completed').toList();

          return RefreshIndicator(
            onRefresh: () => _sprintService.runAutoRulesAndMaintenance(widget.workspace.id),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // 1. ACTIVE SPRINT SECTION
                if (activeSprint != null) ...[
                  _buildSectionHeader("Active Sprint", themeColor, isDark),
                  const SizedBox(height: 12),
                  _buildActiveSprintCard(context, activeSprint, themeColor, isDark, isAllowed),
                  const SizedBox(height: 28),
                ] else ...[
                  _buildNoActiveSprintBanner(themeColor, isDark),
                  const SizedBox(height: 28),
                ],

                // 2. PLANNED SPRINTS SECTION
                if (plannedSprints.isNotEmpty) ...[
                  _buildSectionHeader("Planned Sprints (${plannedSprints.length})", themeColor, isDark),
                  const SizedBox(height: 12),
                  ...plannedSprints.map((s) => _buildPlannedSprintCard(context, s, themeColor, isDark, isAllowed)),
                  const SizedBox(height: 28),
                ],

                // 3. COMPLETED SPRINTS SECTION
                if (completedSprints.isNotEmpty) ...[
                  _buildSectionHeader("Completed Cycles (${completedSprints.length})", themeColor, isDark),
                  const SizedBox(height: 12),
                  ...completedSprints.map((s) => _buildCompletedSprintCard(context, s, themeColor, isDark, isAllowed)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color themeColor, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveSprintBanner(Color themeColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: themeColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No active sprint running",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Start a planned sprint below to kick off your team iteration.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSprintCard(BuildContext context, Sprint sprint, Color themeColor, bool isDark, bool isAllowed) {
    final double displayProgress = sprint.progressPercentage / 100.0;
    
    // Days remaining calculations
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDateDate = DateTime(sprint.endDate.year, sprint.endDate.month, sprint.endDate.day);
    final daysLeft = endDateDate.difference(todayDate).inDays;

    String daysText;
    Color daysColor = themeColor;
    if (daysLeft < 0) {
      daysText = "Overdue by ${daysLeft.abs()} days";
      daysColor = Colors.redAccent;
    } else if (daysLeft == 0) {
      daysText = "Ends today";
      daysColor = Colors.orangeAccent;
    } else if (daysLeft == 1) {
      daysText = "1 day remaining";
    } else {
      daysText = "$daysLeft days remaining";
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sprint.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "ACTIVE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Timeline: ${DateFormat('MMM dd').format(sprint.startDate)} - ${DateFormat('MMM dd, yyyy').format(sprint.endDate)}",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          if (sprint.goal.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SPRINT GOAL",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sprint.goal,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (sprint.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sprint.description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${sprint.completedTasks} of ${sprint.totalTasks} tasks completed",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              Text(
                "${sprint.progressPercentage.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: displayProgress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: daysColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: daysColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showLinkBacklogModal(context, sprint, themeColor, isDark),
                    icon: Icon(Icons.link, size: 14, color: themeColor),
                    label: Text("Backlog", style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  if (isAllowed) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Complete Active Sprint"),
                            content: const Text("Are you sure you want to end this active iteration? Uncompleted tasks will remain linked or can be sent back to the backlog."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Complete"),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _sprintService.updateSprintStatus(widget.workspace.id, sprint.id, 'completed');
                          await _sprintService.calculateSprintProgress(widget.workspace.id, sprint.id);
                          await _sprintService.runAutoRulesAndMaintenance(widget.workspace.id);
                        }
                      },
                      child: const Text("Complete", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlannedSprintCard(BuildContext context, Sprint sprint, Color themeColor, bool isDark, bool isAllowed) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sprint.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "PLANNED",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Schedule: ${DateFormat('MMM dd').format(sprint.startDate)} - ${DateFormat('MMM dd, yyyy').format(sprint.endDate)}",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.grey,
            ),
          ),
          if (sprint.goal.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Goal: ${sprint.goal}",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${sprint.totalTasks} backlog items allocated",
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showLinkBacklogModal(context, sprint, themeColor, isDark),
                    icon: Icon(Icons.link, size: 14, color: themeColor),
                    label: Text("Backlog", style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  if (isAllowed) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: themeColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Activate planned Sprint"),
                            content: Text("Are you sure you want to activate '${sprint.title}'? This will make it the active sprint."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Activate"),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _sprintService.updateSprintStatus(widget.workspace.id, sprint.id, 'active');
                          await _sprintService.calculateSprintProgress(widget.workspace.id, sprint.id);
                          await _sprintService.runAutoRulesAndMaintenance(widget.workspace.id);
                        }
                      },
                      child: Text("Start", style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSprintCard(BuildContext context, Sprint sprint, Color themeColor, bool isDark, bool isAllowed) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sprint.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "COMPLETED",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Delivered: ${DateFormat('MMM dd').format(sprint.startDate)} - ${DateFormat('MMM dd, yyyy').format(sprint.endDate)}",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Achieved ${sprint.completedTasks} / ${sprint.totalTasks} Tasks (${sprint.progressPercentage.toStringAsFixed(0)}%)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.grey.shade700),
              ),
              if (isAllowed)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    minimumSize: const Size(0, 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    await _sprintService.archiveCompletedSprint(widget.workspace.id, sprint.id);
                  },
                  child: const Text("Archive", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color themeColor, bool isDark, bool isAllowed) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch,
                size: 48,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Plan Your First Sprint",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Establish planned team iterations, set sprint goals, and link backlog tasks to view dynamic analytics live. High performance delivery starts here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            if (isAllowed)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: themeColor.withOpacity(0.3),
                ),
                onPressed: () => _showCreateSprintModal(context, null, themeColor, isDark),
                icon: const Icon(Icons.rocket_launch_outlined, size: 20),
                label: const Text(
                  "Create Sprint",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Member access: Only Admins/Owners plan sprints",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.redAccent.shade100 : Colors.redAccent.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateSprintDialog extends StatefulWidget {
  final Workspace workspace;
  final Sprint? activeSprint;
  final Color themeColor;
  final bool isDark;
  final SprintService sprintService;

  const _CreateSprintDialog({
    required this.workspace,
    required this.activeSprint,
    required this.themeColor,
    required this.isDark,
    required this.sprintService,
  });

  @override
  State<_CreateSprintDialog> createState() => _CreateSprintDialogState();
}

class _CreateSprintDialogState extends State<_CreateSprintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _goalController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _startDate = DateTime.now();
  late DateTime _endDate;
  String _selectedDuration = '14 Days'; // '3 Days', '7 Days', '14 Days', 'Custom'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _endDate = _startDate.add(const Duration(days: 14));
  }

  void _updateEndDate() {
    if (_selectedDuration == '3 Days') {
      _endDate = _startDate.add(const Duration(days: 3));
    } else if (_selectedDuration == '7 Days') {
      _endDate = _startDate.add(const Duration(days: 7));
    } else if (_selectedDuration == '14 Days') {
      _endDate = _startDate.add(const Duration(days: 14));
    }
  }

  bool _checkOverlap() {
    if (widget.activeSprint == null) return false;
    final active = widget.activeSprint!;
    
    // Normalize to date only
    final s1 = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e1 = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final s2 = DateTime(active.startDate.year, active.startDate.month, active.startDate.day);
    final e2 = DateTime(active.endDate.year, active.endDate.month, active.endDate.day);

    return (s1.isBefore(e2) || s1.isAtSameMomentAs(e2)) && 
           (e1.isAfter(s2) || e1.isAtSameMomentAs(s2));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkOverlap()) return;

    setState(() => _isLoading = true);
    try {
      await widget.sprintService.createSprint(
        projectId: widget.workspace.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        goal: _goalController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sprint created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sprint: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlap = _checkOverlap();

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF16161C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Plan New Sprint",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Sprint Title
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Sprint Name",
                  hintText: "e.g., Sprint 1: Architecture Setup",
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white60 : Colors.grey.shade700),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),

              // Sprint Goal
              TextFormField(
                controller: _goalController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Sprint Goal",
                  hintText: "e.g., Deliver fully responsive layouts",
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white60 : Colors.grey.shade700),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Goal is required" : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Description",
                  hintText: "Details or scope of this sprint iteration...",
                  labelStyle: TextStyle(color: widget.isDark ? Colors.white60 : Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 20),

              // Date pickers row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Start Date", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                                _updateEndDate();
                              });
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_startDate),
                            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("End Date", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _selectedDuration != 'Custom' ? null : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate.add(const Duration(days: 1)),
                              firstDate: _startDate.add(const Duration(days: 1)),
                              lastDate: _startDate.add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDate = picked;
                              });
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_endDate),
                            style: TextStyle(
                              color: _selectedDuration != 'Custom'
                                  ? Colors.grey
                                  : (widget.isDark ? Colors.white : Colors.black87),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Duration chips title
              const Text(
                "Suggested Duration",
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Duration chips row
              Row(
                children: [
                  _buildDurationChip('3 Days'),
                  const SizedBox(width: 8),
                  _buildDurationChip('7 Days'),
                  const SizedBox(width: 8),
                  _buildDurationChip('14 Days'),
                  const SizedBox(width: 8),
                  _buildDurationChip('Custom'),
                ],
              ),

              // Overlap warning indicator
              if (overlap) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Overlap warning: Date range conflicts with the active sprint '${widget.activeSprint!.title}'.",
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Submission Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: overlap ? Colors.grey : widget.themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading || overlap ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Plan Sprint Cycle", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(String duration) {
    final isSelected = _selectedDuration == duration;
    return Expanded(
      child: ChoiceChip(
        label: Text(
          duration,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
        selected: isSelected,
        selectedColor: widget.themeColor,
        backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedDuration = duration;
              _updateEndDate();
            });
          }
        },
      ),
    );
  }
}

class _LinkBacklogDialog extends StatefulWidget {
  final Workspace workspace;
  final Sprint sprint;
  final Color themeColor;
  final bool isDark;
  final TaskService taskService;
  final SprintService sprintService;

  const _LinkBacklogDialog({
    required this.workspace,
    required this.sprint,
    required this.themeColor,
    required this.isDark,
    required this.taskService,
    required this.sprintService,
  });

  @override
  State<_LinkBacklogDialog> createState() => _LinkBacklogDialogState();
}

class _LinkBacklogDialogState extends State<_LinkBacklogDialog> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF16161C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sprint Backlog",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "Scope: ${widget.sprint.title}",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${widget.sprint.totalTasks} Tasks allocated",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.taskService.getWorkspaceTasks(widget.workspace.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No backlog tasks found in this project.",
                      style: TextStyle(color: widget.isDark ? Colors.white30 : Colors.grey, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final task = docs[index];
                    final data = task.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();

                    final isDone = data['isDone'] as bool? ?? false;
                    final title = data['title'] as String? ?? 'Untitled';
                    final taskSprintId = data['sprintId'] as String?;
                    final isLinkedToThis = taskSprintId == widget.sprint.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E1E24) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLinkedToThis
                              ? widget.themeColor.withOpacity(0.3)
                              : (widget.isDark ? Colors.white10 : Colors.transparent),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle : Icons.circle_outlined,
                            color: isDone ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : Colors.black87,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (taskSprintId != null && !isLinkedToThis) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Allocated to other sprint",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.redAccent.shade100,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else if (isLinkedToThis) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Allocated to this sprint",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: widget.themeColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Backlog",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isLinkedToThis)
                            IconButton(
                              onPressed: () async {
                                await widget.taskService.linkTaskToSprint(
                                  projectId: widget.workspace.id,
                                  taskId: task.id,
                                  sprintId: null,
                                );
                                await widget.sprintService.calculateSprintProgress(widget.workspace.id, widget.sprint.id);
                              },
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                              tooltip: "Remove from Sprint",
                            )
                          else if (taskSprintId == null)
                            IconButton(
                              onPressed: () async {
                                await widget.taskService.linkTaskToSprint(
                                  projectId: widget.workspace.id,
                                  taskId: task.id,
                                  sprintId: widget.sprint.id,
                                );
                                await widget.sprintService.calculateSprintProgress(widget.workspace.id, widget.sprint.id);
                              },
                              icon: Icon(Icons.add_circle_outline, color: widget.themeColor, size: 22),
                              tooltip: "Add to Sprint",
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Done Planning", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
