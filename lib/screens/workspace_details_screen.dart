import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workspace_model.dart';
import '../services/workspace_service.dart';
import '../services/task_service.dart';
import '../services/activity_service.dart';
import '../widgets/project_task_card.dart';
import 'package:timeago/timeago.dart' as timeago;

class WorkspaceDetailsScreen extends StatefulWidget {
  final Workspace workspace;

  const WorkspaceDetailsScreen({super.key, required this.workspace});

  @override
  State<WorkspaceDetailsScreen> createState() => _WorkspaceDetailsScreenState();
}

class _WorkspaceDetailsScreenState extends State<WorkspaceDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskService _taskService = TaskService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final ActivityService _activityService = ActivityService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, Map<String, dynamic>> _memberDetails = {};
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchMemberDetails();
  }

  Future<void> _fetchMemberDetails() async {
    Map<String, Map<String, dynamic>> details = {};
    for (String uid in widget.workspace.members) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        details[uid] = {
          'uid': uid,
          'name': doc.data()?['displayName'] ?? doc.data()?['name'] ?? 'User',
          'email': doc.data()?['email'] ?? '',
          'avatar': doc.data()?['avatar'] ?? '',
        };
      }
    }
    if (mounted) {
      setState(() {
        _memberDetails = details;
        _isLoadingMembers = false;
      });
    }
  }

  void _showCreateTaskModal() {
    final titleController = TextEditingController();
    String? selectedAssigneeUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("New Workspace Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: "Task title",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text("Assign To:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedAssigneeUid,
                    hint: const Text("Unassigned"),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: widget.workspace.members.map((memberId) {
                      final details = _memberDetails[memberId];
                      final name = details?['name'] ?? 'User';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return DropdownMenuItem(
                        value: memberId,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(initial, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                            ),
                            const SizedBox(width: 8),
                            Text(memberId == currentUserId ? "Me ($name)" : name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedAssigneeUid = val),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          _taskService.createProjectTask(
                            projectId: widget.workspace.id,
                            title: titleController.text.trim(),
                            assignedTo: selectedAssigneeUid != null ? _memberDetails[selectedAssigneeUid] : null,
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(int.parse(widget.workspace.color)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Create Task"),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showInviteMemberModal() {
    final emailController = TextEditingController();
    bool isInviting = false;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Invite Member"),
              content: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: "User Email",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              actions: [
                TextButton(
                  onPressed: isInviting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isInviting ? null : () async {
                    setDialogState(() => isInviting = true);
                    try {
                      await _workspaceService.sendProjectInvite(widget.workspace.id, emailController.text.trim());
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite sent!")));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                        setDialogState(() => isInviting = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(int.parse(widget.workspace.color)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isInviting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Invite"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showReassignModal(DocumentSnapshot taskDoc) {
    final isOwner = widget.workspace.ownerId == currentUserId;
    final currentUserRole = widget.workspace.memberRoles[currentUserId];
    if (!isOwner && currentUserRole != 'owner' && currentUserRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("You don't have permission to reassign tasks."),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final data = taskDoc.data() as Map<String, dynamic>?;
    final String taskId = taskDoc.id;
    final String taskTitle = data?['title'] ?? 'Task';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Reassign Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Text("Select a team member to reassign this task to:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.workspace.members.length,
                  itemBuilder: (context, index) {
                    final memberId = widget.workspace.members[index];
                    final details = _memberDetails[memberId];
                    if (details == null) return const SizedBox.shrink();

                    final name = details['name'] ?? 'User';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    final email = details['email'] ?? '';
                    final isCurrentUser = memberId == currentUserId;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(int.parse(widget.workspace.color)).withOpacity(0.2),
                        child: Text(initial, style: TextStyle(color: Color(int.parse(widget.workspace.color)), fontWeight: FontWeight.bold)),
                      ),
                      title: Text(isCurrentUser ? "$name (You)" : name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      onTap: () async {
                        Navigator.pop(context); // close bottom sheet
                        try {
                          await _taskService.reassignProjectTask(
                            projectId: widget.workspace.id,
                            taskId: taskId,
                            newAssigneeDetails: details,
                            taskTitle: taskTitle,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Task reassigned successfully"), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Workspace?>(
      stream: _workspaceService.getWorkspace(widget.workspace.id),
      builder: (context, snapshot) {
        final ws = snapshot.data ?? widget.workspace;
        final color = Color(int.parse(ws.color));
        
        return Scaffold(
          appBar: AppBar(
            backgroundColor: color,
            elevation: 0,
            foregroundColor: Colors.white,
            title: Row(
              children: [
                Icon(ws.iconData, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(ws.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: "Tasks"),
                Tab(text: "Members"),
                Tab(text: "Activity"),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTasksTab(ws),
              _buildMembersTab(ws),
              _buildActivityTab(ws),
            ],
          ),
          floatingActionButton: _buildSmartFAB(ws, color),
        );
      }
    );
  }

  Widget? _buildSmartFAB(Workspace ws, Color color) {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        onPressed: _showCreateTaskModal,
        backgroundColor: color,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (_tabController.index == 1) {
      // Allow any member of the workspace to invite others
      if (ws.members.contains(currentUserId)) {
        return FloatingActionButton.extended(
          onPressed: _showInviteMemberModal,
          backgroundColor: color,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text("Invite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      }
    }
    return null; // Hide FAB on Activity tab or if no permission
  }

  Widget _buildTasksTab(Workspace ws) {
    return StreamBuilder<QuerySnapshot>(
      stream: _taskService.getWorkspaceTasks(ws.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No tasks yet", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Create the first task for this project.", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            return ProjectTaskCard(
              task: doc,
              projectId: ws.id,
              workspace: ws,
              onEdit: () {
                // Not fully implemented yet, navigate or show dialog
              },
              onShare: () {
                _showReassignModal(doc);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTab(Workspace ws) {
    final currentUserRole = ws.memberRoles[currentUserId] ?? 'viewer';
    final canRemove = currentUserRole == 'owner' || currentUserRole == 'admin';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Team Members (${ws.members.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...ws.members.map((memberId) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const ListTile(title: Text("Loading..."));
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final name = userData?['name'] ?? userData?['displayName'] ?? 'Unknown User';
              final email = userData?['email'] ?? '';
              final role = ws.memberRoles[memberId] ?? 'member';
              final isOnline = userData?['isOnline'] ?? false;
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(int.parse(ws.color)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: Color(int.parse(ws.color)), fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                subtitle: Text(email),
                trailing: (canRemove && role != 'owner' && memberId != currentUserId) 
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => _workspaceService.removeMember(ws.id, memberId),
                    )
                  : null,
              );
            }
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActivityTab(Workspace ws) {
    return StreamBuilder<QuerySnapshot>(
      stream: _activityService.getProjectActivities(ws.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No recent activity", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Activity feed will appear here.", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final userName = data['userName'] ?? 'User';
            final type = data['type'] ?? '';
            final taskTitle = data['taskTitle'];
            final message = data['message'] ?? '';
            
            DateTime timestamp = DateTime.now();
            if (data['timestamp'] is Timestamp) {
              timestamp = (data['timestamp'] as Timestamp).toDate();
            }

            IconData icon = Icons.info_outline;
            Color iconColor = Colors.blue;

            if (type == ActivityType.taskCreated) {
              icon = Icons.add_circle_outline;
              iconColor = Colors.green;
            } else if (type == ActivityType.memberInvited) {
              icon = Icons.person_add_alt;
              iconColor = Colors.orange;
            } else if (type == ActivityType.memberJoined) {
              icon = Icons.person_add;
              iconColor = Colors.green;
            } else if (type == ActivityType.taskEdited || type == ActivityType.taskCompleted) {
              icon = Icons.edit_note;
              iconColor = Colors.purple;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                            children: [
                              TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: " $message"),
                              if (taskTitle != null) ...[
                                const TextSpan(text: " "),
                                TextSpan(text: '"$taskTitle"', style: const TextStyle(fontStyle: FontStyle.italic)),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(timeago.format(timestamp), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
