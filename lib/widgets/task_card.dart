import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';
import '../screens/task_details_screen.dart';

class TaskCard extends StatefulWidget {
  final DocumentSnapshot task;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onEdit,
    required this.onShare,
  }) : super(key: key);

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  final TaskService _taskService = TaskService();

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
    final data = widget.task.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    final bool isDone = (data['isDone'] as bool?) ?? false;
    final String title = data['title']?.toString() ?? 'Untitled Task';
    final String priority = data['priority']?.toString() ?? 'low';
    final bool isShared = (data['isShared'] as bool?) ?? false;
    final String? sharedBy = data['sharedBy'] as String?;
    final bool isPinned = (data['isPinned'] as bool?) ?? false;
    
    DateTime? dueDate;
    if (data['dueDate'] is Timestamp) {
      dueDate = (data['dueDate'] as Timestamp).toDate();
    }

    final List<dynamic>? subtasks = data['subtasks'] as List<dynamic>?;
    double progress = 0.0;
    if (subtasks != null && subtasks.isNotEmpty) {
      int completed = subtasks.where((s) => s is Map && s['isCompleted'] == true).length;
      progress = completed / subtasks.length;
    }

    // Avatar for shared tasks (just using initials or a generic avatar if no info)
    List<Widget> avatarWidgets = [];
    if (isShared) {
      final String displayName = sharedBy ?? "S";
      final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";
      final String? sharedById = data['sharedById'] as String?;
      
      Widget avatar = CircleAvatar(
        radius: 12,
        backgroundColor: Colors.blue.shade100,
        child: Text(initial, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
      );

      if (sharedById != null) {
        avatarWidgets.add(
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(sharedById).snapshots(),
            builder: (context, snapshot) {
              bool isOnline = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                isOnline = userData?['isOnline'] ?? false;
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar,
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).cardColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        );
      } else {
        avatarWidgets.add(avatar);
      }
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isPinned 
          ? (isDark ? Colors.amber.withOpacity(0.1) : Colors.orange.shade50) 
          : Theme.of(context).cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade200, width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsScreen(
                taskId: widget.task.id,
                currentUserId: FirebaseAuth.instance.currentUser!.uid,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Checkbox, Title, Pin
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isDone,
                          activeColor: const Color(0xFF0D47A1),
                          side: BorderSide(
                            color: isDone ? Colors.transparent : (isDark ? Colors.grey.shade500 : const Color(0xFF0D47A1).withOpacity(0.5)), 
                            width: 2
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              _taskService.toggleTask(widget.task.id, value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                        onPressed: () => _taskService.togglePinTask(widget.task.id, !isPinned),
                        tooltip: isPinned ? 'Unpin task' : 'Pin task',
                      ),
                    ],
                  ),
                  
                  // Indented details
                  Padding(
                    padding: const EdgeInsets.only(left: 36.0, top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dueDate != null) ...[
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: isDone ? Colors.grey : Colors.redAccent.shade200),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(dueDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDone ? Colors.grey : Colors.redAccent.shade200,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(priority).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
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
                            if (isShared) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.group, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    const Text("Shared", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (avatarWidgets.isNotEmpty) ...avatarWidgets,
                            ],
                          ],
                        ),

                        if (subtasks != null && subtasks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "${(progress * subtasks.length).toInt()}/${subtasks.length} Subtasks",
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade200,
                                  color: const Color(0xFF0D47A1),
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            // Bottom Action Row
            Container(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: widget.onShare,
                    icon: const Icon(Icons.share_outlined, size: 18, color: Colors.blueGrey),
                    label: const Text("Share", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                    label: const Text("Edit", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _taskService.deleteTask(widget.task.id),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
