import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workspace_model.dart';
import '../services/workspace_service.dart';
import '../services/task_service.dart';
import '../widgets/task_card.dart';

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
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _showCreateTaskModal() {
    final titleController = TextEditingController();
    String? selectedAssignee;

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
                      fillColor: Colors.grey.shade50,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text("Assign To:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedAssignee,
                    hint: const Text("Unassigned"),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: widget.workspace.members.map((memberId) {
                      return DropdownMenuItem(
                        value: memberId,
                        child: Text(memberId == currentUserId ? "Me" : "Member ($memberId)"), // Ideally fetch names
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedAssignee = val),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          _taskService.createSharedTask(
                            titleController.text.trim(),
                            workspaceId: widget.workspace.id,
                            assignedTo: selectedAssignee,
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
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Invite Member"),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: "User Email",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Look up user by email and add to workspace
                final snapshot = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: emailController.text.trim()).get();
                if (snapshot.docs.isNotEmpty) {
                  final newMemberId = snapshot.docs.first.id;
                  await _workspaceService.addMember(widget.workspace.id, newMemberId);
                  if (mounted) Navigator.pop(context);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found.")));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(int.parse(widget.workspace.color)),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Invite"),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(widget.workspace.color));
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(IconData(widget.workspace.icon, fontFamily: 'MaterialIcons'), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.workspace.name, overflow: TextOverflow.ellipsis)),
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
          _buildTasksTab(),
          _buildMembersTab(),
          _buildActivityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskModal,
        backgroundColor: color,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _taskService.getWorkspaceTasks(widget.workspace.id),
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
                Text("Create the first task for this workspace.", style: TextStyle(color: Colors.grey[500])),
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
            // Reusing existing TaskCard logic, passing data
            // We pass an empty Map or dummy data if TaskCard expects specific formats
            // Or we can just adapt TaskCard or build a simple tile
            // For now, let's use a simple ListTile to avoid TaskCard refactoring conflicts, 
            // but the prompt says "Reuse existing collaboration system".
            // TaskCard expects id, data.
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TaskCard(
                task: doc,
                onEdit: () {
                  // TODO: Implement Edit
                },
                onShare: () {
                  // TODO: Implement Share
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTab() {
    return StreamBuilder<Workspace?>(
      stream: _workspaceService.getWorkspace(widget.workspace.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final ws = snapshot.data!;
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Team Members (${ws.members.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (ws.ownerId == currentUserId)
                  TextButton.icon(
                    onPressed: _showInviteMemberModal,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text("Invite"),
                    style: TextButton.styleFrom(foregroundColor: Color(int.parse(ws.color))),
                  ),
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
                  final isOwner = memberId == ws.ownerId;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(int.parse(ws.color)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("Owner", style: TextStyle(fontSize: 10, color: Color(int.parse(ws.color)), fontWeight: FontWeight.bold)),
                          )
                        ]
                      ],
                    ),
                    subtitle: Text(email),
                    trailing: (ws.ownerId == currentUserId && !isOwner) 
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
    );
  }

  Widget _buildActivityTab() {
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
}
