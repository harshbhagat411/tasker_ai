import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';
import '../screens/task_details_screen.dart';
import '../models/workspace_model.dart';

class ProjectTaskCard extends StatefulWidget {
  final DocumentSnapshot task;
  final String projectId;
  final Workspace workspace;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const ProjectTaskCard({
    super.key,
    required this.task,
    required this.projectId,
    required this.workspace,
    required this.onEdit,
    required this.onShare,
  });

  @override
  State<ProjectTaskCard> createState() => _ProjectTaskCardState();
}

class _ProjectTaskCardState extends State<ProjectTaskCard> {
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
    final bool isPinned = (data['isPinned'] as bool?) ?? false;
    final String ownerId = data['ownerId']?.toString() ?? '';
    
    DateTime? dueDate;
    if (data['dueDate'] is Timestamp) {
      dueDate = (data['dueDate'] as Timestamp).toDate();
    }

    final Map<String, dynamic>? assignedTo = data['assignedTo'] as Map<String, dynamic>?;
    final String? assignedUid = assignedTo?['uid'];
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isAssignee = currentUserId == assignedUid;
    final bool isProjectAdminOrOwner = widget.workspace.memberRoles[currentUserId] == 'admin' || widget.workspace.memberRoles[currentUserId] == 'owner' || currentUserId == widget.workspace.ownerId;
    final bool canEdit = isAssignee || isProjectAdminOrOwner || currentUserId == ownerId;
    final bool canShare = isProjectAdminOrOwner;

    final List<dynamic>? subtasks = data['subtasks'] as List<dynamic>?;
    double progress = 0.0;
    if (subtasks != null && subtasks.isNotEmpty) {
      int completed = subtasks.where((s) => s is Map && s['isCompleted'] == true).length;
      progress = completed / subtasks.length;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isPinned 
          ? (isDark ? Colors.amber.withValues(alpha: 0.05) : Colors.amber.shade50) 
          : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isPinned ? Colors.amber.shade300 : (isDark ? Colors.grey.shade800 : Colors.grey.shade200), width: 1),
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
                currentUserId: currentUserId ?? '',
                projectId: widget.projectId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP: Checkbox, Title, Pin
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
                      onChanged: (value) {
                        if (canEdit) {
                          if (value != null) {
                            _taskService.toggleTask(context, widget.task.id, value, projectId: widget.projectId);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only assigned member can modify this task.')));
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
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned ? Colors.amber.shade700 : Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      if (canEdit) {
                        _taskService.togglePinTask(widget.task.id, !isPinned, projectId: widget.projectId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only assigned member can modify this task.')));
                      }
                    },
                    tooltip: isPinned ? 'Unpin task' : 'Pin task',
                  ),
                  if (!canEdit) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "Only assigned member can modify this task",
                      child: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // SECOND ROW: Due Date, Priority Pill, Assigned User
              Row(
                children: [
                  if (dueDate != null) ...[
                    Icon(Icons.calendar_today, size: 14, color: isDone ? Colors.grey : Colors.redAccent.shade200),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDone ? Colors.grey : Colors.redAccent.shade200,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(priority),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (assignedTo != null)
                    _buildAssigneeAvatar(assignedTo, isDark)
                  else
                    Text("Unassigned", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              ),

              // THIRD ROW: Progress Line & Subtask count
              if (subtasks != null && subtasks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "${(progress * subtasks.length).toInt()}/${subtasks.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          color: progress == 1.0 ? Colors.green : const Color(0xFF0D47A1),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // BOTTOM: Action buttons
              if (canEdit || canShare) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canShare)
                      TextButton.icon(
                        onPressed: widget.onShare,
                        icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.blueGrey),
                        label: const Text("Reassign", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blueGrey),
                        label: const Text("Edit", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _taskService.deleteTask(widget.task.id, projectId: widget.projectId),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ]
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatar(Map<String, dynamic> assignedTo, bool isDark) {
    String name = assignedTo['name'] ?? 'User';
    String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    String uid = assignedTo['uid'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        bool isOnline = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          isOnline = userData?['isOnline'] ?? false;
          if (userData?['displayName'] != null || userData?['name'] != null) {
            name = userData?['displayName'] ?? userData?['name'];
            if (name.isNotEmpty) initial = name[0].toUpperCase();
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(initial, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
