import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';

class TaskPickerSheet extends StatefulWidget {
  final String projectId;

  const TaskPickerSheet({super.key, required this.projectId});

  @override
  State<TaskPickerSheet> createState() => _TaskPickerSheetState();
}

class _TaskPickerSheetState extends State<TaskPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TaskService _taskService = TaskService();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            "Mention Task",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search tasks...",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tasks Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _taskService.getWorkspaceTasks(widget.projectId),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                // Retrieve all sprints to resolve sprint names in real-time
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .collection('sprints')
                      .snapshots(),
                  builder: (context, sprintSnapshot) {
                    final Map<String, String> sprintNames = {};
                    if (sprintSnapshot.hasData) {
                      for (var doc in sprintSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        sprintNames[doc.id] = data['title'] ?? 'Sprint';
                      }
                    }

                    final allTasks = taskSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery);
                    }).toList();

                    if (allTasks.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    // Split into Assigned to Me vs Others
                    final myTasks = <QueryDocumentSnapshot>[];
                    final otherTasks = <QueryDocumentSnapshot>[];

                    for (var doc in allTasks) {
                      final data = doc.data() as Map<String, dynamic>;
                      String? assignedUid;
                      if (data['assignedTo'] is Map) {
                        assignedUid = data['assignedTo']['uid'];
                      }
                      
                      if (assignedUid != null && assignedUid == currentUserId) {
                        myTasks.add(doc);
                      } else {
                        otherTasks.add(doc);
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        if (myTasks.isNotEmpty) ...[
                          _buildSectionHeader("My Assigned Tasks", isDark),
                          ...myTasks.map((doc) => _buildTaskTile(doc, sprintNames, isDark)),
                        ],
                        if (otherTasks.isNotEmpty) ...[
                          _buildSectionHeader("Other Project Tasks", isDark),
                          ...otherTasks.map((doc) => _buildTaskTile(doc, sprintNames, isDark)),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildTaskTile(QueryDocumentSnapshot doc, Map<String, String> sprintNames, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['title'] ?? 'Untitled Task';
    final String priority = data['priority'] ?? 'low';
    final String? sprintId = data['sprintId'];
    final bool isDone = data['isDone'] ?? false;

    // Resolve sprint/backlog tag
    final String sprintTag = sprintId != null ? (sprintNames[sprintId] ?? 'Sprint') : 'Backlog';

    // Resolve assignee name
    String assigneeName = "Unassigned";
    if (data['assignedTo'] is Map) {
      assigneeName = data['assignedTo']['name'] ?? 'User';
    }

    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDark 
                ? (isDone ? Colors.white30 : Colors.white)
                : (isDone ? Colors.grey : Colors.black87),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Priority Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              // Sprint / Backlog tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sprintTag,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Assignee name
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline, 
                    size: 11, 
                    color: isDark ? Colors.white38 : Colors.grey.shade500
                  ),
                  const SizedBox(width: 2),
                  Text(
                    assigneeName,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 12,
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
        onTap: () {
          Navigator.pop(context, {
            'id': doc.id,
            'title': title,
          });
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rtl_outlined,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            "No tasks found",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
