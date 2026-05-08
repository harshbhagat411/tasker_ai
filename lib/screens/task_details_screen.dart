import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';
import '../services/presence_service.dart';
import '../services/activity_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String currentUserId;

  const TaskDetailsScreen({
    Key? key,
    required this.taskId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> with WidgetsBindingObserver {
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PresenceService().setTaskPresence(widget.taskId, 'viewing');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService().clearTaskPresence(widget.taskId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService().setTaskPresence(widget.taskId, 'viewing');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      PresenceService().clearTaskPresence(widget.taskId);
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Task Details", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .collection('tasks')
            .doc(widget.taskId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Task not found or deleted"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String title = data['title'] ?? 'Untitled Task';
          final String priority = data['priority'] ?? 'low';
          final bool isDone = data['isDone'] ?? false;
          final String description = data['description'] ?? '';
          final bool isShared = data['isShared'] ?? false;
          final String? sharedBy = data['sharedBy'];
          
          DateTime? dueDate;
          TimeOfDay? dueTime;
          if (data['dueDate'] is Timestamp) {
            final dt = (data['dueDate'] as Timestamp).toDate();
            dueDate = dt;
            dueTime = TimeOfDay.fromDateTime(dt);
          }

          final List<dynamic>? subtasks = data['subtasks'] as List<dynamic>?;
          double progress = 0.0;
          int completedSubtasks = 0;
          if (subtasks != null && subtasks.isNotEmpty) {
            completedSubtasks = subtasks.where((s) => s is Map && s['isCompleted'] == true).length;
            progress = completedSubtasks / subtasks.length;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(color: _getPriorityColor(priority), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDone ? "COMPLETED" : "IN PROGRESS",
                        style: TextStyle(color: isDone ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isDone,
                        activeColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (val) {
                          if (val != null) {
                            _taskService.toggleTask(widget.taskId, val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // 🔹 Realtime Presence Indicator
                StreamBuilder<QuerySnapshot>(
                  stream: PresenceService().getTaskPresenceStream(widget.taskId),
                  builder: (context, presenceSnapshot) {
                    if (!presenceSnapshot.hasData || presenceSnapshot.data!.docs.isEmpty) {
                      return const SizedBox(height: 24);
                    }
                    
                    final docs = presenceSnapshot.data!.docs;
                    List<String> viewing = [];
                    List<String> editing = [];
                    
                    for (var doc in docs) {
                      if (doc.id == widget.currentUserId) continue; // Skip self
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'];
                      final userName = data['userName'] ?? 'Someone';
                      
                      if (status == 'editing') editing.add(userName);
                      else viewing.add(userName);
                    }
                    
                    if (editing.isEmpty && viewing.isEmpty) return const SizedBox(height: 24);
                    
                    String presenceText = '';
                    if (editing.isNotEmpty) {
                      presenceText = "${editing.join(', ')} ${editing.length > 1 ? 'are' : 'is'} editing...";
                    } else {
                      presenceText = "${viewing.join(', ')} ${viewing.length > 1 ? 'are' : 'is'} viewing this task";
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Row(
                          children: [
                            Icon(editing.isNotEmpty ? Icons.edit : Icons.visibility, size: 14, color: editing.isNotEmpty ? Colors.blue : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              presenceText,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: editing.isNotEmpty ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Date & Time
                if (dueDate != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today, color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Due Date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "${_formatDate(dueDate)} at ${dueTime?.format(context) ?? ''}",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Shared Info
                if (isShared) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.group, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Shared by", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(sharedBy != null && sharedBy.isNotEmpty ? sharedBy[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                sharedBy ?? 'Unknown',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Description
                const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                  ),
                  child: Text(
                    description.isEmpty ? "No description provided." : description,
                    style: TextStyle(fontSize: 14, color: description.isEmpty ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Subtasks
                if (subtasks != null && subtasks.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Subtasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("$completedSubtasks/${subtasks.length}", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...subtasks.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var sub = entry.value as Map<String, dynamic>;
                    bool isSubDone = sub['isCompleted'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          List<Map<String, dynamic>> updatedSubtasks = subtasks.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                          updatedSubtasks[idx]['isCompleted'] = !isSubDone;
                          _taskService.updateSubtasks(widget.taskId, updatedSubtasks);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                            color: isDark ? Colors.transparent : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSubDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSubDone ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sub['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    decoration: isSubDone ? TextDecoration.lineThrough : null,
                                    color: isSubDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
                const SizedBox(height: 24),
                
                // Activity Timeline
                _buildActivityTimeline(isDark),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityTimeline(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: ActivityService().getTaskActivities(widget.taskId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final docs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Activity Timeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
              ),
              child: docs.isEmpty 
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      "No recent activity.",
                      style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userName = data['userName'] ?? 'Someone';
                  final message = data['message'] ?? 'did something';
                  final type = data['type'] ?? 'edit';
                  
                  IconData icon;
                  Color iconColor;
                  switch (type) {
                    case 'completed': icon = Icons.check_circle; iconColor = Colors.green; break;
                    case 'uncompleted': icon = Icons.remove_circle_outline; iconColor = Colors.orange; break;
                    case 'share': icon = Icons.share; iconColor = Colors.blue; break;
                    case 'accept_invite': icon = Icons.group_add; iconColor = Colors.purple; break;
                    case 'edit': default: icon = Icons.edit; iconColor = Colors.grey; break;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 16, color: iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "$userName ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: message),
                              ],
                            ),
                            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
