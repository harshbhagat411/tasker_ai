import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../services/activity_service.dart';
import 'workspace_details_screen.dart';
import 'projects_screen.dart';
import 'task_details_screen.dart';
import '../services/workspace_service.dart';
import '../models/workspace_model.dart';
import 'collaboration_requests_screen.dart';
import '../services/in_app_notification_service.dart';
import '../services/realtime_notification_listener.dart';
import 'package:rxdart/rxdart.dart';
import 'focus_mode_screen.dart';
import '../services/focus_service.dart';
import '../widgets/focus_setup_sheet.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import 'habits_screen.dart';
import 'goals_screen.dart';

enum SortType {
  priority,
  createdDate,
  dueDate,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  final TextEditingController _taskController = TextEditingController();
  StreamSubscription<List<QuerySnapshot>>? _inviteSubscription;
  StreamSubscription<String?>? _notificationClickSubscription;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize realtime listeners
    RealtimeNotificationListener().init();
    _handleNotificationClicks();
    
    checkDueTasks();
    _listenForInvites();
  }

  void _handleNotificationClicks() {
    _notificationClickSubscription = _notificationService.onNotificationClick.listen((payload) {
      if (payload == null || payload.isEmpty) return;
      
      // Payload format: "notificationId|taskId|projectId"
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final notificationId = parts[0];
        final taskId = parts[1];
        final projectId = parts[2];
        
        // Mark as read immediately
        InAppNotificationService().markAsRead(notificationId);
        
        if (taskId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(
                taskId: taskId,
                currentUserId: FirebaseAuth.instance.currentUser!.uid,
                projectId: projectId.isNotEmpty ? projectId : null,
              ),
            ),
          );
        } else if (projectId.isNotEmpty) {
          // Navigate to projects screen or workspace details. To be safe we navigate to collaboration requests or projects.
          // Let's navigate to collaboration requests to see the update.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CollaborationRequestsScreen()),
          );
        }
      }
    });
  }

  void _listenForInvites() {
    final combinedStream = Rx.combineLatest2(
      _taskService.getPendingInvites(),
      WorkspaceService().getPendingProjectInvites(),
      (QuerySnapshot tasks, QuerySnapshot projects) => [tasks, projects],
    );

    _inviteSubscription = combinedStream.listen((snapshots) {
      if (_isInitialLoad) {
        _isInitialLoad = false;
        return; // Don't show snackbars for existing invites on load
      }

      // Handle Task Invites
      for (var change in snapshots[0].docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null && mounted) {
            final String fromUserName = data['fromUserName'] ?? 'Someone';
            final String taskTitle = data['taskTitle'] ?? 'a task';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$fromUserName invited you to collaborate on "$taskTitle"'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollaborationRequestsScreen()),
                    );
                  },
                ),
              ),
            );
          }
        }
      }

      // Handle Project Invites
      for (var change in snapshots[1].docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null && mounted) {
            final String senderName = data['senderName'] ?? 'Someone';
            final String projectName = data['projectName'] ?? 'a project';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$senderName invited you to project "$projectName"'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollaborationRequestsScreen()),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel();
    _notificationClickSubscription?.cancel();
    RealtimeNotificationListener().dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkDueTasks();
    }
  }

  Future<void> checkDueTasks() async {
    print("Checking tasks...");
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .get();

    bool foundAny = false;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['isDone'] == true || data['dueDate'] == null) continue;

      final bool notificationSent = data['notifiedLocally'] ?? false;
      if (notificationSent) continue;

      final dueDate = (data['dueDate'] as Timestamp).toDate();
      
      if (dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now)) {
        final title = data['title'] ?? 'Task';
        print("Task due → notification sent");
        await _notificationService.triggerImmediateNotificationWithDetails(
          id: doc.id.hashCode,
          title: "Task Reminder",
          body: "Your task is due now: '$title'",
        );
        await doc.reference.update({'notifiedLocally': true});
        foundAny = true;
      } else if (dueDate.isBefore(now.add(const Duration(minutes: 10)))) {
        final title = data['title'] ?? 'Task';
        print("Task due → notification sent");
        await _notificationService.triggerImmediateNotificationWithDetails(
          id: doc.id.hashCode,
          title: "Task due soon",
          body: "Task '$title' is due in less than 10 minutes",
        );
        await doc.reference.update({'notifiedLocally': true});
        foundAny = true;
      }
    }

    if (!foundAny) {
      print("No tasks due");
    }
  }

  String _searchQuery = '';
  String _filter = 'All'; // 'All', 'Completed', 'Pending'
  String _selectedPriority = 'low';
  SortType _selectedSortType = SortType.createdDate;
  bool _isAscending = false;
  Set<String> _expandedTaskIds = {};

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _showTaskDialog({DocumentSnapshot? task, String? taskId, String? currentTitle, String? currentPriority, DateTime? currentDueDate, List<dynamic>? currentSubtasks}) {
    if (taskId != null) {
      PresenceService().setTaskPresence(taskId, 'editing');
    }

    if (currentTitle != null) {
      _taskController.text = currentTitle;
      _selectedPriority = currentPriority ?? 'low';
    } else {
      _taskController.clear();
      _selectedPriority = 'low';
    }
    
    DateTime? tempDate = currentDueDate;
    TimeOfDay? tempTime = currentDueDate != null ? TimeOfDay.fromDateTime(currentDueDate) : null;

    List<Map<String, dynamic>> localSubtasks = [];
    if (currentSubtasks != null) {
      for (var sub in currentSubtasks) {
        if (sub is Map) {
          localSubtasks.add({
            'controller': TextEditingController(text: sub['title'] ?? ''),
            'isCompleted': sub['isCompleted'] ?? false,
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(taskId == null ? "Add Task" : "Edit Task"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _taskController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Enter task details...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                        child: Text("Priority", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['High', 'Medium', 'Low'].map((priority) {
                          final value = priority.toLowerCase();
                          final isSelected = _selectedPriority == value;
                          return ChoiceChip(
                            label: Text(priority),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => _selectedPriority = value);
                              }
                            },
                            selectedColor: const Color(0xFF0D47A1),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey[300]!),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tempDate == null ? "No due date" : _formatDate(tempDate!),
                                  style: TextStyle(color: tempDate == null ? Colors.grey : Colors.black87),
                                ),
                                if (tempTime != null)
                                  Text(
                                    tempTime!.format(context),
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: tempDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                setDialogState(() => tempDate = pickedDate);
                              }
                            },
                            child: const Text("Date"),
                          ),
                          if (tempDate != null)
                            TextButton(
                              onPressed: () async {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: tempTime ?? TimeOfDay.now(),
                                );
                                if (pickedTime != null) {
                                  setDialogState(() => tempTime = pickedTime);
                                }
                              },
                              child: const Text("Time"),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Subtasks", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                localSubtasks.add({
                                  'controller': TextEditingController(),
                                  'isCompleted': false,
                                });
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add Step"),
                          ),
                        ],
                      ),
                    ),
                    ...localSubtasks.asMap().entries.map((entry) {
                      int index = entry.key;
                      var subtask = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              subtask['isCompleted'] ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: subtask['isCompleted'] ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: subtask['controller'] as TextEditingController,
                                decoration: InputDecoration(
                                  hintText: "Subtask title...",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  localSubtasks.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (taskId != null) PresenceService().clearTaskPresence(taskId);
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final title = _taskController.text.trim();
                    if (title.isEmpty) return;

                    DateTime? finalDate;
                    if (tempDate != null) {
                      if (tempTime != null) {
                        finalDate = DateTime(
                          tempDate!.year,
                          tempDate!.month,
                          tempDate!.day,
                          tempTime!.hour,
                          tempTime!.minute,
                        );
                      } else {
                        // User picked a date but no time, default to 9 AM
                        finalDate = DateTime(
                          tempDate!.year,
                          tempDate!.month,
                          tempDate!.day,
                        ).add(const Duration(hours: 9));
                      }
                    }

                    List<Map<String, dynamic>> finalSubtasks = [];
                    for (var sub in localSubtasks) {
                      String subTitle = (sub['controller'] as TextEditingController).text.trim();
                      if (subTitle.isNotEmpty) {
                        finalSubtasks.add({
                          'title': subTitle,
                          'isCompleted': sub['isCompleted'],
                        });
                      }
                    }

                    if (taskId == null) {
                      await _taskService.addTask(title, priority: _selectedPriority, dueDate: finalDate, subtasks: finalSubtasks);
                    } else {
                      await _taskService.updateTask(taskId, title, priority: _selectedPriority, dueDate: finalDate, subtasks: finalSubtasks);
                      PresenceService().clearTaskPresence(taskId);
                    }
                    
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(taskId == null ? "Add" : "Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showShareDialog(String taskId) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Share Task"),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: "Enter email",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                Navigator.pop(context); // Close dialog

                try {
                  await _taskService.shareTask(taskId, email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Task shared successfully"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User not found"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text("Share"),
            ),
          ],
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.green;
    }
  }

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.orange.shade200; // Yellow/Orange
      case 'medium':
        return Colors.blue.shade100; // Blue
      case 'low':
      default:
        return Colors.green.shade100; // Green
    }
  }

  void _showHabitsGoalsExplanationSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
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
              // Pull bar indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "What's the difference?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Habit Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🔁", style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Habit",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "A habit is something you repeat regularly.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Examples:\n• Drink water daily\n• Go to gym\n• Study 30 mins every day",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Habits help build consistency.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),

              // Goal Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🎯", style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Goal",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "A goal is something you want to achieve.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Examples:\n• Lose 5kg\n• Finish syllabus\n• Save money",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Goals help track progress.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),

              // Summary / Simple Rule
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Text("💡", style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF334155),
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(text: "Simple rule:\n"),
                            TextSpan(
                              text: "Habits",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " = repeat   |   "),
                            TextSpan(
                              text: "Goals",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " = achieve"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Got it button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Got it",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalsDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Text(
                "Habits & Goals",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showHabitsGoalsExplanationSheet(context),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<dynamic>>(
                stream: HabitService().getHabits(),
                builder: (context, snapshot) {
                  int total = 0;
                  int completed = 0;
                  if (snapshot.hasData) {
                    total = snapshot.data!.length;
                    completed = snapshot.data!.where((h) => h.isCompleted || (h.progress >= h.target)).length;
                  }
                  
                  final progressVal = total > 0 ? completed / total : 0.0;
                  
                  return InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsScreen()));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text("Today's Habits", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            total > 0 ? "$completed/$total completed" : "No habits set",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? progressVal : 0,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<dynamic>>(
                stream: HabitService().getHabits(),
                builder: (context, snapshot) {
                  int total = 0;
                  int activeStreaks = 0;
                  if (snapshot.hasData) {
                    total = snapshot.data!.length;
                    activeStreaks = snapshot.data!.where((h) => h.streakCount > 0).length;
                  }
                  
                  int percentage = total > 0 ? ((activeStreaks / total) * 100).round() : 0;
                  final progressVal = total > 0 ? activeStreaks / total : 0.0;
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_fire_department, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            const Text("Active Streaks", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          total > 0 ? "$percentage% active" : "Start a streak",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? progressVal : 0,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Goal>>(
          stream: GoalService().getDailyGoals(),
          builder: (context, snapshot) {
            final dailyGoals = snapshot.data ?? [];
            return StreamBuilder<List<Goal>>(
              stream: GoalService().getWeeklyGoals(),
              builder: (context, weeklySnapshot) {
                final weeklyGoals = weeklySnapshot.data ?? [];
                final total = dailyGoals.length + weeklyGoals.length;
                final completed = dailyGoals.where((g) => g.isCompleted).length +
                    weeklyGoals.where((g) => g.isCompleted).length;
                
                final progressVal = total > 0 ? completed / total : 0.0;
                
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GoalsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            const Text("My Target Goals", style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          total > 0 
                              ? "$completed of $total goals achieved" 
                              : "No active goals or weekly goals set yet. Tap to add!",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressVal,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        _buildMiniStatsRow(),
      ],
    );
  }

  Widget _buildMiniStatsRow() {
    return StreamBuilder<List<dynamic>>(
      stream: Rx.combineLatest3(
        FocusService().getTodayFocusSummary(),
        GoalService().getWeeklyGoals(),
        HabitService().getHabits(),
        (focus, weeklyGoals, habits) => [focus, weeklyGoals, habits],
      ),
      builder: (context, snapshot) {
        int focusMins = 0;
        int weeklyGoalsCount = 0;
        int highestStreak = 0;
        
        if (snapshot.hasData) {
          final focusData = snapshot.data![0] as Map<String, dynamic>;
          focusMins = focusData['totalMinutes'] ?? 0;
          
          final wGoals = snapshot.data![1] as List<Goal>;
          weeklyGoalsCount = wGoals.length;
          
          final habs = snapshot.data![2] as List<dynamic>;
          for (var h in habs) {
            if (h.streakCount > highestStreak) highestStreak = h.streakCount;
          }
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStatItem("🔥", "$highestStreak day streak"),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  );
                },
                child: _buildMiniStatItem("🎯", "$weeklyGoalsCount goals"),
              ),
              _buildMiniStatItem("⏱", "${focusMins}m focused"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatItem(String emoji, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSmartFocusDashboard(BuildContext context) {
    return StreamBuilder<FocusSessionState>(
      stream: FocusService().activeSessionStream,
      builder: (context, sessionSnapshot) {
        final sessionState = sessionSnapshot.data ?? FocusSessionState();
        
        return StreamBuilder<Map<String, dynamic>>(
          stream: FocusService().getTodayFocusSummary(),
          builder: (context, summarySnapshot) {
            final summary = summarySnapshot.data ?? {'sessions': 0, 'totalMinutes': 0, 'streak': 0};
            
            Widget dashboardCard;
            
            if (sessionState.status == FocusSessionStatus.running || sessionState.status == FocusSessionStatus.paused) {
              // STATE 2: ACTIVE SESSION
              int remaining = sessionState.remainingSeconds;
              int minutes = remaining ~/ 60;
              int seconds = remaining % 60;
              String timeStr = '${minutes}m ${seconds}s remaining';
              double progress = 0;
              if (sessionState.targetDurationInSeconds > 0) {
                progress = sessionState.elapsedSeconds / sessionState.targetDurationInSeconds;
              }
              
              String metadataStr = "";
              if (sessionState.ambientSound != null && sessionState.ambientSound != 'None') {
                metadataStr += "${sessionState.ambientSound} • ";
              }
              metadataStr += sessionState.taskTitle.isNotEmpty ? sessionState.taskTitle : "Deep Focus";

              int minsToday = summary['totalMinutes'] ?? 0;
              
              dashboardCard = InkWell(
                key: const ValueKey('running'),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 800),
                      pageBuilder: (context, animation, secondaryAnimation) => const FocusModeScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut), child: child);
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6A1B9A).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Focus Running 🔥", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                            child: const Text("Resume", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.track_changes, color: Colors.white70, size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: Text(metadataStr, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          Text("$minsToday min focused today", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } else if (sessionState.status == FocusSessionStatus.completed) {
              // STATE 3: COMPLETED
              int minsToday = summary['totalMinutes'] ?? 0;
              int sessionsToday = summary['sessions'] ?? 0;
              int streak = summary['streak'] ?? 0;
              
              dashboardCard = InkWell(
                key: const ValueKey('completed'),
                onTap: () => showFocusSetupSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Great Work 🎉", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                            child: const Text("Start Again", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("${sessionState.targetDurationInSeconds ~/ 60} min completed", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text("$minsToday min focused today", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const Text("•", style: TextStyle(color: Colors.white54)),
                          Text("$sessionsToday sessions completed", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          if (streak > 0) ...[
                            const Text("•", style: TextStyle(color: Colors.white54)),
                            Text("🔥 $streak day streak", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } else {
              // STATE 1: IDLE
              int minsToday = summary['totalMinutes'] ?? 0;
              int sessionsToday = summary['sessions'] ?? 0;
              int lastDurationMins = summary['lastDuration'] ?? 25;
              if (lastDurationMins == 0) lastDurationMins = 25;
              
              dashboardCard = InkWell(
                key: const ValueKey('idle'),
                onTap: () => showFocusSetupSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E35B1), Color(0xFF311B92)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF5E35B1).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Ready for Deep Work?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text("Stay focused for $lastDurationMins minutes", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                          const SizedBox(height: 12),
                          Text("$minsToday min focused today", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          if (sessionsToday > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text("$sessionsToday sessions completed today", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Color(0xFF311B92), size: 28),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: dashboardCard,
              ),
            );
          }
        );
      }
    );
  }


  Widget _buildTaskAvatars(List<String> memberIds) {
    if (memberIds.isEmpty) return const SizedBox.shrink();
    
    // limit to 10 for whereIn clause
    List<String> queryIds = memberIds.length > 10 ? memberIds.sublist(0, 10) : memberIds;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: queryIds).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        var docs = snapshot.data!.docs;
        
        // Sort: online first, then offline
        docs.sort((a, b) {
          bool aOnline = (a.data() as Map<String, dynamic>)['isOnline'] ?? false;
          bool bOnline = (b.data() as Map<String, dynamic>)['isOnline'] ?? false;
          if (aOnline && !bOnline) return -1;
          if (!aOnline && bOnline) return 1;
          return 0;
        });

        int maxAvatars = 4;
        int displayCount = docs.length > maxAvatars ? maxAvatars : docs.length;
        int extraCount = memberIds.length > maxAvatars ? memberIds.length - maxAvatars : 0;
        
        double width = 28.0 + ((displayCount - 1) * 20.0);
        if (extraCount > 0) width += 28.0; 

        return SizedBox(
          width: width,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < displayCount; i++)
                Builder(
                  builder: (context) {
                    final userData = docs[i].data() as Map<String, dynamic>;
                    String initial = "?";
                    final name = userData['displayName'] ?? userData['name'] ?? userData['email'] ?? "User";
                    if (name.isNotEmpty) initial = name[0].toUpperCase();
                    bool isOnline = userData['isOnline'] ?? false;
                    
                    Color bgColor = i == 0 ? Colors.blue : Colors.grey.shade400;

                    return Positioned(
                      left: i * 20.0,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bgColor,
                            border: Border.all(
                              color: isOnline ? Colors.green.shade400 : Theme.of(context).cardColor, 
                              width: isOnline ? 1.5 : 2
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                ),
              if (extraCount > 0)
                Positioned(
                  left: displayCount * 20.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      border: Border.all(color: Theme.of(context).cardColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        "+$extraCount",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTaskList(BuildContext context, List<DocumentSnapshot> tasks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final data = task.data() as Map<String, dynamic>?;
        
        final bool isDone = (data?['isDone'] as bool?) ?? false;
        final String title = data?['title']?.toString() ?? 'Untitled Task';
        final String priority = data?['priority']?.toString() ?? 'low';
        final bool isShared = (data?['isShared'] as bool?) ?? false;
        final String? sharedBy = data?['sharedBy'] as String?;
        
        final List<dynamic>? memberIdsRaw = data?['members'] as List<dynamic>?;
        List<String> memberIds = [];
        if (memberIdsRaw != null && memberIdsRaw.isNotEmpty) {
          memberIds = memberIdsRaw.map((e) => e.toString()).toList();
        } else if (isShared && data?['sharedById'] != null) {
          memberIds = [data!['sharedById'].toString(), FirebaseAuth.instance.currentUser!.uid];
        }
        
        bool isOwner = (data?['userId'] == FirebaseAuth.instance.currentUser?.uid) || !isShared;
        bool showSharedPill = isShared || (isOwner && memberIds.length > 1);
        
        final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
        final String realOwnerId = data?['ownerId']?.toString() ?? data?['userId']?.toString() ?? '';
        String? assignedToId;
        if (data?['assignedTo'] is String) {
          assignedToId = data?['assignedTo'];
        } else if (data?['assignedTo'] is Map) {
          assignedToId = data?['assignedTo']['uid'];
        }
        final permissions = data?['permissions'] as Map<String, dynamic>?;
        
        bool canEdit = false;
        if (data?['projectId'] == null) {
          canEdit = true; // Automatically allow modifications for personal and shared tasks
        } else if (realOwnerId == currentUserId) {
          canEdit = true;
        } else if (permissions != null && (permissions[currentUserId] == 'owner' || permissions[currentUserId] == 'admin')) {
          canEdit = true;
        } else if (assignedToId == currentUserId) {
          canEdit = true;
        }
        
        DateTime? dueDate;
        if (data != null && data['dueDate'] is Timestamp) {
          dueDate = (data['dueDate'] as Timestamp).toDate();
        }

        final bool isPinned = (data?['isPinned'] as bool?) ?? false;
        final bool isExpanded = _expandedTaskIds.contains(task.id);

        final List<dynamic>? subtasks = data?['subtasks'] as List<dynamic>?;
        double progress = 0.0;
        if (subtasks != null && subtasks.isNotEmpty) {
          int completed = subtasks.where((s) => s is Map && s['isCompleted'] == true).length;
          progress = completed / subtasks.length;
        }

        return Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
          color: isPinned 
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.amber.withOpacity(0.1) : Colors.orange.shade50) 
              : Theme.of(context).cardColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade100, width: 1.5),
          ),
          margin: const EdgeInsets.only(bottom: 14),
          child: Dismissible(
            key: Key(task.id),
            background: Container(
              color: Colors.green,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (!canEdit) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to modify this task.')));
                return false;
              }
              if (direction == DismissDirection.startToEnd) {
                _taskService.toggleTask(task.id, true);
                return false;
              }
              return true;
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart && canEdit) {
                _taskService.deleteTask(task.id);
              }
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final tData = task.data() as Map<String, dynamic>?;
                final pId = tData?['projectId']?.toString();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailsScreen(
                      taskId: task.id,
                      currentUserId: FirebaseAuth.instance.currentUser!.uid,
                      projectId: pId,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Checkbox, Title, and Pin
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isDone,
                            activeColor: const Color(0xFF0D47A1),
                            side: BorderSide(color: isDone ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade500 : const Color(0xFF0D47A1).withOpacity(0.5)), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onChanged: canEdit ? (val) {
                              if (val != null) {
                                _taskService.toggleTask(task.id, val);
                              }
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                color: isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: isPinned ? Colors.orange : Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => _taskService.togglePinTask(task.id, !isPinned),
                          tooltip: isPinned ? 'Unpin task' : 'Pin task',
                        ),
                      ],
                    ),
                    
                    // All content below title indented to align with text
                    Padding(
                      padding: const EdgeInsets.only(left: 34.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dueDate != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: isDone ? Colors.grey : Colors.redAccent),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _formatDate(dueDate),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDone ? Colors.grey : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPriorityBackgroundColor(priority),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  priority.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getPriorityColor(priority),
                                  ),
                                ),
                              ),
                              if (showSharedPill) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.group, size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      const Text(
                                        "Shared",
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (data?['projectId'] != null) ...[
                                const SizedBox(width: 8),
                                StreamBuilder<Workspace?>(
                                  stream: WorkspaceService().getWorkspace(data!['projectId'].toString()),
                                  builder: (context, wsSnapshot) {
                                    final wsName = wsSnapshot.data?.name ?? 'Project';
                                    final wsColorHex = wsSnapshot.data?.color ?? '0xFF0D47A1';
                                    final wsColor = Color(int.parse(wsColorHex));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: wsColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(wsSnapshot.data?.iconData ?? Icons.business_center, size: 14, color: wsColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            wsName,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: wsColor),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                ),
                              ],
                              if (memberIds.isNotEmpty) ...[
                                const Spacer(),
                                _buildTaskAvatars(memberIds),
                              ],
                            ],
                          ),
                          if (subtasks != null && subtasks.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF0D47A1),
                              minHeight: 2,
                              borderRadius: BorderRadius.circular(1),
                            ),
                            const SizedBox(height: 6),
                            ...subtasks.take(isExpanded ? subtasks.length : 2).toList().asMap().entries.map((entry) {
                              int subIndex = entry.key;
                              var sub = entry.value as Map<String, dynamic>;
                              bool isSubDone = sub['isCompleted'] == true;
                              return InkWell(
                                onTap: () {
                                  List<Map<String, dynamic>> updatedSubtasks = subtasks.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                                  updatedSubtasks[subIndex]['isCompleted'] = !isSubDone;
                                  _taskService.updateSubtasks(task.id, updatedSubtasks);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSubDone ? Icons.check_box : Icons.check_box_outline_blank,
                                        size: 14,
                                        color: isSubDone ? Colors.grey : const Color(0xFF0D47A1),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          sub['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSubDone ? Colors.grey : Colors.black87,
                                            decoration: isSubDone ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            if (subtasks.length > 2)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedTaskIds.remove(task.id);
                                    } else {
                                      _expandedTaskIds.add(task.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                                  child: Text(
                                    isExpanded ? "Show less" : "+${subtasks.length - 2} more",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => _showShareDialog(task.id),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.share_outlined, size: 16, color: Colors.blueGrey),
                                      SizedBox(width: 4),
                                      Text("Share", style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () => _showTaskDialog(
                                  taskId: task.id, 
                                  currentTitle: title, 
                                  currentPriority: priority,
                                  currentDueDate: dueDate,
                                  currentSubtasks: subtasks,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16, color: Colors.blueGrey),
                                      SizedBox(width: 4),
                                      Text("Edit", style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () => _taskService.deleteTask(task.id),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                      SizedBox(width: 4),
                                      Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "User";
    final displayName = email.split('@').first;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : null,
          builder: (context, userSnapshot) {
            String displayStr = email.split('@').first;
            String userMode = 'personal';
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
              displayStr = data?['displayName']?.toString() ?? data?['name']?.toString() ?? displayStr;
              userMode = data?['mode']?.toString() ?? 'personal';
            }
            final currentInitial = displayStr.isNotEmpty ? displayStr[0].toUpperCase() : "?";
            final bool isDeveloper = userMode == 'developer';

            return RefreshIndicator(
              onRefresh: () async {
                // Can add some delay to simulate refresh if needed
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Header

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF0D47A1),
                              child: Text(currentInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Hey 👋", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                Text(displayStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            StreamBuilder<List<QuerySnapshot>>(
                              stream: Rx.combineLatest3(
                                _taskService.getPendingInvites(),
                                WorkspaceService().getPendingProjectInvites(),
                                InAppNotificationService().getUnreadNotifications(),
                                (QuerySnapshot tasks, QuerySnapshot projects, QuerySnapshot unreadNotifs) => [tasks, projects, unreadNotifs],
                              ),
                              builder: (context, snapshot) {
                                int pendingCount = 0;
                                if (snapshot.hasData) {
                                  pendingCount = snapshot.data![0].docs.length + snapshot.data![1].docs.length + snapshot.data![2].docs.length;
                                }
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.notifications_none, color: Theme.of(context).textTheme.bodyLarge?.color),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const CollaborationRequestsScreen()),
                                        );
                                      },
                                    ),
                                    if (pendingCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            '$pendingCount',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            IconButton(
                              onPressed: () => setState(() => _isAscending = !_isAscending),
                              icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Theme.of(context).textTheme.bodyLarge?.color),
                              tooltip: _isAscending ? 'Ascending' : 'Descending',
                            ),
                            PopupMenuButton<SortType>(
                              icon: Icon(Icons.sort, color: Theme.of(context).textTheme.bodyLarge?.color),
                              tooltip: 'Sort by',
                              onSelected: (option) => setState(() => _selectedSortType = option),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: SortType.priority, child: Text('Priority')),
                                const PopupMenuItem(value: SortType.createdDate, child: Text('Created Date')),
                                const PopupMenuItem(value: SortType.dueDate, child: Text('Due Date')),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                const SizedBox(height: 30),                
                // SECTION 2: Title & Start Focus Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tasker", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        Text("Manage your tasks", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // SECTION 2.5: Today's Focus
                _buildSmartFocusDashboard(context),

                // SECTION 3: Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12.0, right: 8.0),
                        child: Icon(Icons.search, color: Color(0xFF0D47A1)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4: Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Today', 'Completed'].map((filter) {
                      final isSelected = _filter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _filter = filter);
                          },
                          selectedColor: const Color(0xFF0D47A1),
                          backgroundColor: Theme.of(context).cardColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey[300]!),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4.5: Upcoming Tasks (Next 1 Hour)
                StreamBuilder<QuerySnapshot>(
                  stream: _taskService.getTasks(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    
                    final now = DateTime.now();
                    final inOneHour = now.add(const Duration(hours: 1));
                    
                    final upcomingTasks = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null || data['isDone'] == true || data['dueDate'] == null) return false;
                      
                      final dueDate = (data['dueDate'] as Timestamp).toDate();
                      return dueDate.isAfter(now) && dueDate.isBefore(inOneHour);
                    }).toList();

                    if (upcomingTasks.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Upcoming (Next 1 Hour)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcomingTasks.length,
                            itemBuilder: (context, index) {
                          final data = upcomingTasks[index].data() as Map<String, dynamic>;
                          final title = data['title'] ?? 'Task';
                          final time = TimeOfDay.fromDateTime((data['dueDate'] as Timestamp).toDate()).format(context);
                          
                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12, bottom: 24),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Color(0xFF0D47A1)),
                                    const SizedBox(width: 4),
                                    Text("Due at $time", style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )],
                    );
                  },
                ),

                // SECTION 4.6: Habits & Goals and Recent Activity
                _buildGoalsDashboard(context),
                const SizedBox(height: 24),
                if (isDeveloper) _buildRecentActivity(),

                // Task Stream
                StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _taskService.getAllTasks(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("Error loading tasks"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty && !isDeveloper) {
                      return _buildEmptyState("No tasks yet", "Tap + to add a new task");
                    }

                    // Base tasks applied with global Search filter
                    var baseTasks = snapshot.data!.where((task) {
                      final data = task.data() as Map<String, dynamic>?;
                      final String title = data?['title']?.toString() ?? '';
                      if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) {
                        return false;
                      }
                      return true;
                    }).toList();

                    // Apply Sorting logic to baseTasks
                    baseTasks.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>?;
                      final dataB = b.data() as Map<String, dynamic>?;

                      switch (_selectedSortType) {
                        case SortType.priority:
                          final pA = dataA?['priority']?.toString() ?? 'low';
                          final pB = dataB?['priority']?.toString() ?? 'low';
                          
                          int valA = pA == 'high' ? 3 : (pA == 'medium' ? 2 : 1);
                          int valB = pB == 'high' ? 3 : (pB == 'medium' ? 2 : 1);
                          
                          int cmp = _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                          
                          if (cmp == 0) {
                            final tA = dataA?['createdAt'] as Timestamp?;
                            final tB = dataB?['createdAt'] as Timestamp?;
                            if (tA == null && tB == null) return 0;
                            if (tA == null) return 1;
                            if (tB == null) return -1;
                            return tB.compareTo(tA);
                          }
                          return cmp;
                              
                        case SortType.createdDate:
                          final tA = dataA?['createdAt'] as Timestamp?;
                          final tB = dataB?['createdAt'] as Timestamp?;
                          
                          if (tA == null && tB == null) return 0;
                          if (tA == null) return 1;
                          if (tB == null) return -1;
                          
                          return _isAscending ? tA.compareTo(tB) : tB.compareTo(tA);
                              
                        case SortType.dueDate:
                          final dA = dataA?['dueDate'] as Timestamp?;
                          final dB = dataB?['dueDate'] as Timestamp?;
                          
                          if (dA == null && dB == null) return 0;
                          if (dA == null) return 1;
                          if (dB == null) return -1;
                          
                          return _isAscending ? dA.compareTo(dB) : dB.compareTo(dB);
                      }
                    });

                    // Derive Horizontal Tasks (High Priority or Today, not completed)
                    var horizontalTasks = baseTasks.where((task) {
                       final data = task.data() as Map<String, dynamic>?;
                       final String priority = data?['priority']?.toString() ?? 'low';
                       final bool isDone = (data?['isDone'] as bool?) ?? false;
                       if (isDone) return false;
                       
                       DateTime? dueDate;
                       if (data != null && data['dueDate'] is Timestamp) {
                         dueDate = (data['dueDate'] as Timestamp).toDate();
                       }
                       
                       bool isToday = false;
                       if (dueDate != null) {
                         final now = DateTime.now();
                         if (dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day) {
                           isToday = true;
                         }
                       }
                       
                       return priority == 'high' || isToday;
                    }).toList();

                    // Derive Vertical Tasks based on Filter
                    var verticalTasks = baseTasks.where((task) {
                      final data = task.data() as Map<String, dynamic>?;
                      final bool isDone = (data?['isDone'] as bool?) ?? false;
                      
                      DateTime? dueDate;
                      if (data != null && data['dueDate'] is Timestamp) {
                        dueDate = (data['dueDate'] as Timestamp).toDate();
                      }

                      if (_filter == 'Completed' && !isDone) return false;
                      if (_filter == 'All' && isDone) return false; // Show pending mostly in All
                      if (_filter == 'Today') {
                         if (dueDate == null) return false;
                         final now = DateTime.now();
                         if (dueDate.year != now.year || dueDate.month != now.month || dueDate.day != now.day) return false;
                      }

                      return true;
                    }).toList();
                    
                    // If filter is all, we just show all pending
                    if (_filter == 'All') {
                      verticalTasks = baseTasks.where((task) => !((task.data() as Map<String, dynamic>?)?['isDone'] ?? false)).toList();
                    }

                    // Sort so pinned tasks appear first
                    int sortTasks(DocumentSnapshot a, DocumentSnapshot b) {
                      final dataA = a.data() as Map<String, dynamic>?;
                      final dataB = b.data() as Map<String, dynamic>?;
                      final bool isPinnedA = (dataA?['isPinned'] as bool?) ?? false;
                      final bool isPinnedB = (dataB?['isPinned'] as bool?) ?? false;
                      if (isPinnedA && !isPinnedB) return -1;
                      if (!isPinnedA && isPinnedB) return 1;
                      return 0; // maintain default date sorting if both are same
                    }

                    horizontalTasks.sort(sortTasks);
                    verticalTasks.sort(sortTasks);

                    if (horizontalTasks.isEmpty && verticalTasks.isEmpty && !isDeveloper) {
                      return _buildEmptyState("No matching tasks", "Try changing filters");
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 5: Horizontal Task Cards
                        if (horizontalTasks.isNotEmpty && _filter != 'Completed') ...[
                          Text("Priority & Today", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: horizontalTasks.length,
                              itemBuilder: (context, index) {
                                final task = horizontalTasks[index];
                                final data = task.data() as Map<String, dynamic>?;
                                final String title = data?['title']?.toString() ?? 'Untitled Task';
                                final String priority = data?['priority']?.toString() ?? 'low';
                                
                                DateTime? dueDate;
                                if (data != null && data['dueDate'] is Timestamp) {
                                  dueDate = (data['dueDate'] as Timestamp).toDate();
                                }
                                
                                final List<dynamic>? subtasks = data?['subtasks'] as List<dynamic>?;
                                double progress = 0.0;
                                if (subtasks != null && subtasks.isNotEmpty) {
                                  int completed = subtasks.where((s) => s is Map && s['isCompleted'] == true).length;
                                  progress = completed / subtasks.length;
                                }
                                
                                return Container(
                                  width: 240,
                                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                                  decoration: BoxDecoration(
                                    color: _getPriorityBackgroundColor(priority),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 6)),
                                    ]
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      final tData = task.data() as Map<String, dynamic>?;
                                      final pId = tData?['projectId']?.toString();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TaskDetailsScreen(
                                            taskId: task.id,
                                            currentUserId: FirebaseAuth.instance.currentUser!.uid,
                                            projectId: pId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.6),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  priority.toUpperCase(), 
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _taskService.togglePinTask(task.id, !((data?['isPinned'] as bool?) ?? false)),
                                                    child: Icon(
                                                      ((data?['isPinned'] as bool?) ?? false) ? Icons.push_pin : Icons.push_pin_outlined,
                                                      size: 18,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      value: progress,
                                                      strokeWidth: 3,
                                                      backgroundColor: Colors.white.withOpacity(0.5),
                                                      color: Colors.black87,
                                                    ),
                                                    const Center(
                                                      child: Icon(Icons.show_chart, size: 12, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (dueDate != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 16, color: Colors.black54),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatDate(dueDate), 
                                                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)
                                                ),
                                              ],
                                            )
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],

                        // SECTION 6 & 7 & 8: Vertical lists
                        ...(() {
                          final myTasks = <DocumentSnapshot>[];
                          final sharedByMeTasks = <DocumentSnapshot>[];
                          final sharedWithMeTasks = <DocumentSnapshot>[];
                          
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                          for (var t in verticalTasks) {
                            final data = t.data() as Map<String, dynamic>? ?? {};
                            
                            bool isReceivedShare = (data['isShared'] == true && data['sharedById'] != currentUserId);
                            bool isWorkspaceTask = (data['projectId'] != null);
                            
                            bool isOwner = false;
                            if (data['ownerId'] == currentUserId) {
                              isOwner = true;
                            } else if (data['permissions'] != null && data['permissions'][currentUserId] == 'owner') {
                              isOwner = true;
                            } else if (!isReceivedShare && !isWorkspaceTask) {
                              isOwner = true;
                            }
                            
                            final members = data['members'] as List<dynamic>? ?? [];
                            bool hasMultipleMembers = members.length > 1;
                            
                            if (isReceivedShare || isWorkspaceTask) {
                              sharedWithMeTasks.add(t);
                            } else if (isOwner && hasMultipleMembers) {
                              sharedByMeTasks.add(t);
                            } else {
                              myTasks.add(t);
                            }
                          }
                          
                          final sections = <Widget>[];
                          
                          // Filter assignedToMe dynamically considering both String and Map types
                          final assignedToMe = sharedWithMeTasks.where((t) {
                            final d = t.data() as Map<String, dynamic>? ?? {};
                            final assigned = d['assignedTo'];
                            if (assigned is String) {
                              return assigned == currentUserId;
                            } else if (assigned is Map) {
                              return assigned['uid'] == currentUserId;
                            }
                            return false;
                          }).toList();

                          final sharedWithMeFiltered = sharedWithMeTasks.where((t) => !assignedToMe.contains(t)).toList();
                          
                          if (!isDeveloper) {
                            if (assignedToMe.isNotEmpty) {
                              sections.add(Text("Assigned To You", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, assignedToMe));
                              sections.add(const SizedBox(height: 24));
                            }
                            if (myTasks.isNotEmpty) {
                              sections.add(Text("My Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, myTasks));
                            }
                            if (assignedToMe.isEmpty && myTasks.isEmpty) {
                              sections.add(const Text("No tasks found.", style: TextStyle(color: Colors.grey)));
                            }
                          } else {
                            // Developer Mode: Projects, Assigned Tasks, Shared
                            sections.add(_buildYourProjects(context));
                            sections.add(const SizedBox(height: 24));
                            
                            if (assignedToMe.isNotEmpty) {
                              sections.add(Text("Assigned To You", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, assignedToMe));
                              sections.add(const SizedBox(height: 24));
                            }
                            
                            if (sharedWithMeFiltered.isNotEmpty) {
                              sections.add(Text("Shared With Me", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, sharedWithMeFiltered));
                              sections.add(const SizedBox(height: 24));
                            }
                            
                            if (sharedByMeTasks.isNotEmpty) {
                              sections.add(Text("Shared By Me", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, sharedByMeTasks));
                              sections.add(const SizedBox(height: 24));
                            }
                            
                            if (myTasks.isNotEmpty) {
                              sections.add(Text("My Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)));
                              sections.add(const SizedBox(height: 16));
                              sections.add(_buildTaskList(context, myTasks));
                            }
                            
                            if (assignedToMe.isEmpty && sharedWithMeFiltered.isEmpty && sharedByMeTasks.isEmpty && myTasks.isEmpty) {
                              final text = (_searchQuery.isNotEmpty || _filter != 'All')
                                  ? "No matching tasks found."
                                  : "No tasks found.";
                              sections.add(Text(text, style: const TextStyle(color: Colors.grey)));
                            }
                          }
                          
                          return sections;
                        }())
                      ],
                    );
                  },
                ),
                SizedBox(height: 56.0 + 12.0 + MediaQuery.of(context).padding.bottom + 16.0),
              ],
            ),
          ),
        ),
      );
    },
  ),
),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: ActivityService().getRecentActivities(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        final docs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200),
              ),
              child: Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userName = data['userName'] ?? 'Someone';
                  final message = data['message'] ?? 'did something';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blue.withOpacity(0.2),
                          child: Text(userName[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "$userName $message",
                            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildYourProjects(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Your Projects", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
              },
              child: const Text("View All", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: StreamBuilder<List<Workspace>>(
            stream: WorkspaceService().getUserWorkspaces(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final workspaces = snapshot.data ?? [];
              if (workspaces.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.business_center_outlined, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("No projects yet. Create one from the Projects tab.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: workspaces.length,
                itemBuilder: (context, index) {
                  final ws = workspaces[index];
                  final color = Color(int.parse(ws.color));
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WorkspaceDetailsScreen(workspace: ws)),
                      );
                    },
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(ws.iconData, color: color, size: 20),
                          ),
                          const Spacer(),
                          Text(ws.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text("${ws.members.length} members", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

}
