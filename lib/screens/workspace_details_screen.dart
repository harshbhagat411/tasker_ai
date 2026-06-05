import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/workspace_model.dart';
import '../services/workspace_service.dart';
import '../services/task_service.dart';
import '../services/activity_service.dart';
import '../widgets/project_task_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../models/sprint.dart';
import '../services/sprint_service.dart';
import 'sprint_dashboard_screen.dart';
import 'user_profile_screen.dart';
import 'workspace_chat_screen.dart';

enum WorkspaceTab {
  overview,
  tasks,
  backlog,
  team,
  activity,
  chat,
}

class WorkspaceDetailsScreen extends StatefulWidget {
  final Workspace workspace;

  const WorkspaceDetailsScreen({super.key, required this.workspace});

  @override
  State<WorkspaceDetailsScreen> createState() => _WorkspaceDetailsScreenState();
}

class _WorkspaceDetailsScreenState extends State<WorkspaceDetailsScreen> with SingleTickerProviderStateMixin {
  final List<WorkspaceTab> _tabs = [
    WorkspaceTab.overview,
    WorkspaceTab.tasks,
    WorkspaceTab.backlog,
    WorkspaceTab.team,
    WorkspaceTab.activity,
    WorkspaceTab.chat,
  ];

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
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchMemberDetails();
    // Auto status checks and progress re-calculation on load
    SprintService().runAutoRulesAndMaintenance(widget.workspace.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMemberDetails() async {
    Map<String, Map<String, dynamic>> details = {};
    for (String uid in widget.workspace.members) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          details[uid] = {
            'uid': uid,
            'name': doc.data()?['displayName'] ?? doc.data()?['name'] ?? 'User',
            'email': doc.data()?['email'] ?? '',
            'avatar': doc.data()?['avatar'] ?? '',
          };
        } else {
          details[uid] = {
            'uid': uid,
            'name': 'Unknown Member',
            'email': 'No profile details yet',
            'avatar': '',
          };
        }
      } catch (e) {
        print("Error fetching details for member $uid: $e");
        details[uid] = {
          'uid': uid,
          'name': 'Restricted Profile',
          'email': 'Protected by security rules',
          'avatar': '',
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

  void _showWorkspaceSettingsModal(Workspace ws) {
    final nameController = TextEditingController(text: ws.name);
    final descController = TextEditingController(text: ws.description);
    final isOwner = ws.ownerId == currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                      const Text("Project Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Project Name",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Settings Button (for Owner & Admin)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty) {
                          // Update project settings!
                          await FirebaseFirestore.instance.collection('workspaces').doc(ws.id).update({
                            'name': nameController.text.trim(),
                            'description': descController.text.trim(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(int.parse(ws.color)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  // Delete Workspace and Transfer Ownership (Owner ONLY!)
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text("Danger Zone", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Transfer Ownership
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text("Transfer", style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context); // Close settings
                              _showTransferOwnershipModal(ws);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              side: const BorderSide(color: Colors.orangeAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Delete Workspace
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text("Delete", style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context); // Close settings
                              _showDeleteConfirmationDialog(ws);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showDeleteConfirmationDialog(Workspace ws) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Workspace?"),
          content: Text("Are you sure you want to permanently delete '${ws.name}'? This will erase all tasks, activities, and cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // exit workspace screen back to projects
                await _workspaceService.deleteWorkspace(ws.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("Delete"),
            ),
          ],
        );
      }
    );
  }

  void _showTransferOwnershipModal(Workspace ws) {
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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Transfer Ownership", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Select a member to transfer ownership to. You will become an Admin.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ws.members.length,
                  itemBuilder: (context, index) {
                    final memberId = ws.members[index];
                    if (memberId == currentUserId) return const SizedBox.shrink();
                    final details = _memberDetails[memberId];
                    final name = details?['name'] ?? 'User';
                    final email = details?['email'] ?? '';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(int.parse(ws.color)).withOpacity(0.2),
                        child: Text(initial, style: TextStyle(color: Color(int.parse(ws.color)), fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      onTap: () async {
                        Navigator.pop(context); // close sheet
                        await FirebaseFirestore.instance.collection('workspaces').doc(ws.id).update({
                          'ownerId': memberId,
                          'memberRoles.$memberId': 'owner',
                          'memberRoles.$currentUserId': 'admin',
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Ownership successfully transferred to $name!")),
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
    );
  }

  void _showCreateTaskModal() async {
    final titleController = TextEditingController();
    String? selectedAssigneeUid;
    String selectedSprintOption = 'backlog'; // 'backlog' or 'active'

    // Fetch the active sprint asynchronously
    final activeSprint = await SprintService().getActiveSprint(widget.workspace.id);

    if (!mounted) return;

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
                  const SizedBox(height: 16),
                  const Text("Sprint:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedSprintOption,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'backlog',
                        child: Text("Backlog"),
                      ),
                      if (activeSprint != null)
                        DropdownMenuItem(
                          value: 'active',
                          child: Text("Active Sprint (${activeSprint.title})"),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedSprintOption = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isNotEmpty) {
                          final sprintId = (selectedSprintOption == 'active' && activeSprint != null) ? activeSprint.id : null;
                          await _taskService.createProjectTask(
                            projectId: widget.workspace.id,
                            title: titleController.text.trim(),
                            assignedTo: selectedAssigneeUid != null ? _memberDetails[selectedAssigneeUid] : null,
                            sprintId: sprintId,
                          );

                          if (sprintId != null) {
                            await SprintService().calculateSprintProgress(widget.workspace.id, sprintId);
                          }

                          if (context.mounted) Navigator.pop(context);
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
      }
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
        final currentUserRole = ws.memberRoles[currentUserId] ?? 'member';
        
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
            actions: [
              if (currentUserRole == 'owner' || currentUserRole == 'admin')
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showWorkspaceSettingsModal(ws),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: _tabs.map((tab) {
                switch (tab) {
                  case WorkspaceTab.overview:
                    return const Tab(text: "Overview");
                  case WorkspaceTab.tasks:
                    return const Tab(text: "Tasks");
                  case WorkspaceTab.backlog:
                    return const Tab(text: "Backlog");
                  case WorkspaceTab.team:
                    return const Tab(text: "Team");
                  case WorkspaceTab.activity:
                    return const Tab(text: "Activity");
                  case WorkspaceTab.chat:
                    return const Tab(text: "Chat");
                }
              }).toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              switch (tab) {
                case WorkspaceTab.overview:
                  return _buildOverviewTab(ws);
                case WorkspaceTab.tasks:
                  return _buildTasksTab(ws);
                case WorkspaceTab.backlog:
                  return _buildBacklogTab(ws);
                case WorkspaceTab.team:
                  return _buildMembersTab(ws);
                case WorkspaceTab.activity:
                  return _buildActivityTab(ws);
                case WorkspaceTab.chat:
                  return WorkspaceChatScreen(workspace: ws);
              }
            }).toList(),
          ),
          floatingActionButton: _buildSmartFAB(ws, color),
        );
      }
    );
  }

  Widget? _buildSmartFAB(Workspace ws, Color color) {
    final currentUserRole = ws.memberRoles[currentUserId] ?? 'member';
    if (currentUserRole == 'member') {
      return null;
    }
    if (_tabController.index >= _tabs.length) {
      return null;
    }
    final currentTab = _tabs[_tabController.index];
    if (currentTab == WorkspaceTab.tasks || currentTab == WorkspaceTab.backlog) {
      return FloatingActionButton.extended(
        onPressed: _showCreateTaskModal,
        backgroundColor: color,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (currentTab == WorkspaceTab.team) {
      return FloatingActionButton.extended(
        onPressed: _showInviteMemberModal,
        backgroundColor: color,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Invite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
    return null; // Hide FAB on other tabs
  }

  Widget _buildOverviewTab(Workspace ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildProjectSummaryCard(ws, isDark),
        const SizedBox(height: 20),
        _buildProgressSection(ws, isDark),
        const SizedBox(height: 20),
        _buildMemberStatsCard(ws, isDark),
        const SizedBox(height: 20),
        _buildRecentActivityPreview(ws, isDark),
        const SizedBox(height: 20),
        _buildSprintPlaceholderCard(ws, isDark),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMemberStatsCard(Workspace ws, bool isDark) {
    final workspaceColor = Color(int.parse(ws.color));
    
    final membersStream = FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: ws.members.take(30).toList())
        .snapshots();
        
    final invitesStream = FirebaseFirestore.instance
        .collection('project_invites')
        .where('projectId', isEqualTo: ws.id)
        .where('status', isEqualTo: 'pending')
        .snapshots();
        
    return StreamBuilder<List<QuerySnapshot>>(
      stream: Rx.combineLatest2(
        membersStream,
        invitesStream,
        (QuerySnapshot members, QuerySnapshot invites) => [members, invites],
      ),
      builder: (context, snapshot) {
        int activeNow = 0;
        int pendingInvites = 0;
        
        if (snapshot.hasData) {
          final membersSnap = snapshot.data![0];
          final invitesSnap = snapshot.data![1];
          
          for (var doc in membersSnap.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data['isOnline'] == true) {
              activeNow++;
            }
          }
          
          pendingInvites = invitesSnap.docs.length;
        }
        
        final totalMembers = ws.members.length;
        final adminCount = ws.memberRoles.values.where((role) => role == 'admin' || role == 'owner').length;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Active Members Statistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(Icons.analytics_outlined, size: 20, color: workspaceColor),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildProgressMetric("Total Members", totalMembers.toString(), workspaceColor),
                  _buildProgressMetric("Active Now", activeNow.toString(), Colors.green),
                  _buildProgressMetric("Admins", adminCount.toString(), Colors.blue),
                  _buildProgressMetric("Pending Invites", pendingInvites.toString(), Colors.orange),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildProjectSummaryCard(Workspace ws, bool isDark) {
    final formattedDate = DateFormat.yMMMd().format(ws.createdAt.toDate());
    final color = Color(int.parse(ws.color));
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [color.withOpacity(0.3), color.withOpacity(0.1)]
              : [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(ws.iconData, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ws.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Created: $formattedDate • Owner: ${ws.ownerName}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ws.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              ws.description,
              style: TextStyle(
                fontSize: 14, 
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.group_outlined, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                "${ws.members.length} team ${ws.members.length == 1 ? 'member' : 'members'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Workspace ws, bool isDark) {
    final color = Color(int.parse(ws.color));
    
    return StreamBuilder<QuerySnapshot>(
      stream: _taskService.getWorkspaceTasks(ws.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 140,
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: color),
          );
        }
        
        final docs = snapshot.data?.docs ?? [];
        final totalTasks = docs.length;
        final completedTasks = docs.where((d) => (d.data() as Map<String, dynamic>?)?['isDone'] == true).length;
        final pendingTasks = totalTasks - completedTasks;
        
        final now = DateTime.now();
        int overdueTasks = 0;
        for (var d in docs) {
          final data = d.data() as Map<String, dynamic>?;
          if (data != null && data['isDone'] != true && data['dueDate'] != null) {
            final due = (data['dueDate'] as Timestamp).toDate();
            if (due.isBefore(now)) {
              overdueTasks++;
            }
          }
        }
        
        final double progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
        final percent = (progress * 100).toInt();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Workspace Progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("$percent% Done", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProgressMetric("Total", totalTasks.toString(), Colors.blue),
                      _buildProgressMetric("Completed", completedTasks.toString(), Colors.green),
                      _buildProgressMetric("Pending", pendingTasks.toString(), Colors.orange),
                      _buildProgressMetric("Overdue", overdueTasks.toString(), Colors.red, isAlert: overdueTasks > 0),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTeamStatsSection(ws, docs, isDark),
          ],
        );
      },
    );
  }

  Widget _buildProgressMetric(String label, String value, Color color, {bool isAlert = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: isAlert ? Colors.redAccent : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTeamStatsSection(Workspace ws, List<DocumentSnapshot> taskDocs, bool isDark) {
    final assignedCount = taskDocs.where((d) => (d.data() as Map<String, dynamic>?)?['assignedTo'] != null).length;
    final totalTasks = taskDocs.length;
    final completedTasks = taskDocs.where((d) => (d.data() as Map<String, dynamic>?)?['isDone'] == true).length;
    final color = Color(int.parse(ws.color));
    
    final velocity = totalTasks > 0 ? (completedTasks * 100 ~/ totalTasks) : 0;
    String ratingLabel = "Idle";
    Color ratingColor = Colors.grey;
    if (totalTasks > 0) {
      if (velocity >= 80) {
        ratingLabel = "Excellent";
        ratingColor = Colors.green;
      } else if (velocity >= 50) {
        ratingLabel = "Steady";
        ratingColor = Colors.orange;
      } else {
        ratingLabel = "Needs Focus";
        ratingColor = Colors.redAccent;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: "Assigned Tasks",
            value: "$assignedCount / $totalTasks",
            subtitle: "tasks delegated",
            icon: Icons.assignment_turned_in_outlined,
            isDark: isDark,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: "Team Velocity",
            value: totalTasks > 0 ? "$velocity%" : "N/A",
            subtitle: ratingLabel,
            subtitleColor: ratingColor,
            icon: Icons.speed_outlined,
            isDark: isDark,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required Color color,
    Color? subtitleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
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
                  title, 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: subtitleColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityPreview(Workspace ws, bool isDark) {
    final color = Color(int.parse(ws.color));
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(3); // Switch to Activity tab (index 3)
                },
                child: Row(
                  children: [
                    Text("View All", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: color),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _activityService.getProjectActivities(ws.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: color));
              }
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text("No activity logged yet.", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                );
              }
              
              final previewDocs = docs.take(3).toList();
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: previewDocs.length,
                itemBuilder: (context, index) {
                  final doc = previewDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final userName = data['userName'] ?? 'User';
                  final type = data['type'] ?? '';
                  final message = data['message'] ?? '';
                  final taskTitle = data['taskTitle'];
                  
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
                          radius: 14,
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(icon, size: 14, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyLarge?.color, 
                                    fontSize: 13,
                                  ),
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
                              const SizedBox(height: 2),
                              Text(timeago.format(timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSprintPlaceholderCard(Workspace ws, bool isDark) {
    final color = Color(int.parse(ws.color));

    return StreamBuilder<List<Sprint>>(
      stream: SprintService().getProjectSprints(ws.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final sprints = snapshot.data ?? [];
        final nonArchived = sprints.where((s) => s.status != 'archived').toList();
        final activeSprints = nonArchived.where((s) => s.status == 'active').toList();
        final completedSprints = nonArchived.where((s) => s.status == 'completed').toList();
        final plannedSprints = nonArchived.where((s) => s.status == 'planned').toList();

        Sprint? displaySprint;
        String badgeText = "SPRINT PLANNER";
        String mainTitle = "Agile Sprint Cycles";
        String description = "Break backlog items down into dynamic, time-boxed milestones and track achievements.";
        double progress = 0.0;
        String? footerText;

        if (activeSprints.isNotEmpty) {
          displaySprint = activeSprints.first;
          badgeText = "ACTIVE SPRINT";
          mainTitle = displaySprint.title;
          description = displaySprint.goal.isNotEmpty ? displaySprint.goal : displaySprint.description;
          progress = displaySprint.progressPercentage / 100.0;

          final now = DateTime.now();
          final todayDateOnly = DateTime(now.year, now.month, now.day);
          final endDateOnly = DateTime(displaySprint.endDate.year, displaySprint.endDate.month, displaySprint.endDate.day);
          final diff = endDateOnly.difference(todayDateOnly).inDays;

          if (diff < 0) {
            footerText = "Ended";
          } else if (diff == 0) {
            footerText = "Ends today";
          } else if (diff == 1) {
            footerText = "1 day left";
          } else {
            footerText = "$diff days left";
          }
        } else if (completedSprints.isNotEmpty) {
          displaySprint = completedSprints.first;
          badgeText = "LAST COMPLETED";
          mainTitle = "Last Sprint Completed";
          description = "Deliverable '${displaySprint.title}' completed! Archive this sprint to launch the next agile cycle.";
          progress = displaySprint.progressPercentage / 100.0;
          footerText = "100% Achieved";
        } else if (plannedSprints.isNotEmpty) {
          displaySprint = plannedSprints.first;
          badgeText = "UPCOMING SPRINT";
          mainTitle = displaySprint.title;
          description = "Planned to start on ${DateFormat('MMM d').format(displaySprint.startDate)}. Goal: ${displaySprint.goal.isNotEmpty ? displaySprint.goal : displaySprint.description}";
          footerText = "Planned";
        } else {
          badgeText = "STEP 1 FOUNDATION";
          mainTitle = "Create Your First Sprint";
          description = "Establish planned bi-weekly team iterations, set sprint goals, and link backlog tasks to verify auto-analytics calculations live.";
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SprintDashboardScreen(workspace: ws),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                style: BorderStyle.solid,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDark ? 0.1 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                    Row(
                      children: [
                        Icon(Icons.rocket_launch_outlined, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Agile Sprints",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? color.withOpacity(0.9) : color,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mainTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (displaySprint != null && displaySprint.status != 'planned') ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                            color: color,
                          ),
                        ),
                      ),
                      if (footerText != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          footerText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${displaySprint.completedTasks} of ${displaySprint.totalTasks} tasks completed (${displaySprint.progressPercentage.toStringAsFixed(0)}%)",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ] else if (footerText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    footerText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern interactive Planner popup dialog overlay to verify Agile Sprints backend CRUD, linking and auto calculations
  void _showSprintPlannerDialog(Workspace ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(int.parse(ws.color));

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final goalController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 14));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                int activeTab = 0; // 0: Sprints, 1: Create Sprint, 2: Link Tasks

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15151A) : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Drag indicator
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        "Agile Sprint Planner",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Phase 9 Step 1 Foundation Panel",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tabs selector
                      Row(
                        children: [
                          _buildTabHeader(setModalState, "Sprints", 0, activeTab, color, isDark),
                          const SizedBox(width: 8),
                          _buildTabHeader(setModalState, "Plan Sprint", 1, activeTab, color, isDark),
                          const SizedBox(width: 8),
                          _buildTabHeader(setModalState, "Link Backlog", 2, activeTab, color, isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Divider
                      Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                      const SizedBox(height: 16),
                      // Tab contents
                      Expanded(
                        child: activeTab == 0
                            ? _buildSprintsTabContent(ws, color, isDark, scrollController, setModalState)
                            : activeTab == 1
                                ? _buildCreateSprintTabContent(ws, color, isDark, titleController, descController, goalController, startDate, endDate, setModalState)
                                : _buildLinkTasksTabContent(ws, color, isDark, scrollController, setModalState),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTabHeader(void Function(void Function()) setModalState, String title, int index, int activeIndex, Color color, bool isDark) {
    final isSelected = index == activeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() {
            // update tab state
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSprintsTabContent(Workspace ws, Color color, bool isDark, ScrollController scrollController, void Function(void Function()) setModalState) {
    return StreamBuilder<List<Sprint>>(
      stream: SprintService().getProjectSprints(ws.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sprints = snapshot.data ?? [];
        final nonArchived = sprints.where((s) => s.status != 'archived').toList();

        if (nonArchived.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch_outlined, size: 54, color: isDark ? Colors.white10 : Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  "No active or planned sprints",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Text(
                  "Switch to the 'Plan Sprint' tab to get started.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: nonArchived.length,
          itemBuilder: (context, index) {
            final sprint = nonArchived[index];
            final displayProgress = sprint.progressPercentage / 100.0;

            Color statusColor;
            switch (sprint.status) {
              case 'active': statusColor = Colors.green; break;
              case 'completed': statusColor = Colors.blue; break;
              case 'planned': statusColor = Colors.orange; break;
              default: statusColor = Colors.grey; break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sprint.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (sprint.goal.isNotEmpty) ...[
                    Text(
                      "Goal: ${sprint.goal}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    "Dates: ${DateFormat('MMM dd').format(sprint.startDate)} - ${DateFormat('MMM dd, yyyy').format(sprint.endDate)}",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: displayProgress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${sprint.progressPercentage.toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${sprint.completedTasks} of ${sprint.totalTasks} linked tasks completed",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  // Sprint management actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (sprint.status == 'planned')
                        TextButton(
                          onPressed: () async {
                            await SprintService().updateSprintStatus(ws.id, sprint.id, 'active');
                            await SprintService().calculateSprintProgress(ws.id, sprint.id);
                            setModalState(() {});
                          },
                          child: const Text("Start Sprint", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      if (sprint.status == 'active')
                        TextButton(
                          onPressed: () async {
                            await SprintService().updateSprintStatus(ws.id, sprint.id, 'completed');
                            await SprintService().calculateSprintProgress(ws.id, sprint.id);
                            setModalState(() {});
                          },
                          child: const Text("Complete Sprint", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      if (sprint.status == 'completed')
                        TextButton(
                          onPressed: () async {
                            await SprintService().archiveCompletedSprint(ws.id, sprint.id);
                            setModalState(() {});
                          },
                          child: const Text("Archive Sprint", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateSprintTabContent(
    Workspace ws, 
    Color color, 
    bool isDark,
    TextEditingController titleCtrl,
    TextEditingController descCtrl,
    TextEditingController goalCtrl,
    DateTime startDate,
    DateTime endDate,
    void Function(void Function()) setModalState
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Plan a New Agile Iteration",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 12),
          // Title Field
          TextField(
            controller: titleCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Sprint Title",
              hintText: "e.g. Sprint 1: Foundation Setup",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          // Description Field
          TextField(
            controller: descCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Description",
              hintText: "Sprint deliverables scope...",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          // Goal Field
          TextField(
            controller: goalCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Sprint Goal",
              hintText: "e.g. Set up dynamic metrics and Firestore pathing",
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          // Date selection Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Start Date", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            // Update local startDate state
                          });
                        }
                      },
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(startDate),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
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
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            // Update local endDate state
                          });
                        }
                      },
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(endDate),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Plan Sprint submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final goal = goalCtrl.text.trim();
                final desc = descCtrl.text.trim();

                if (title.isNotEmpty) {
                  await SprintService().createSprint(
                    projectId: ws.id,
                    title: title,
                    description: desc,
                    goal: goal,
                    startDate: startDate,
                    endDate: endDate,
                  );
                  // Reset form fields
                  titleCtrl.clear();
                  descCtrl.clear();
                  goalCtrl.clear();

                  // Automatically return back to overview Sprints list
                  setModalState(() {
                    // Update tab state to Sprints List (index 0)
                  });
                }
              },
              child: const Text("Plan Sprint Cycle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTasksTabContent(Workspace ws, Color color, bool isDark, ScrollController scrollController, void Function(void Function()) setModalState) {
    String? selectedSprintId;
    String? selectedTaskId;

    return StreamBuilder<List<Sprint>>(
      stream: SprintService().getProjectSprints(ws.id),
      builder: (context, sprintsSnapshot) {
        if (sprintsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sprints = sprintsSnapshot.data ?? [];
        final eligibleSprints = sprints.where((s) => s.status != 'archived').toList();

        if (eligibleSprints.isEmpty) {
          return Center(
            child: Text(
              "No non-archived sprints planned or active. Create a sprint first.",
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _taskService.getWorkspaceTasks(ws.id),
          builder: (context, tasksSnapshot) {
            if (tasksSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasksDocs = tasksSnapshot.data?.docs ?? [];

            if (tasksDocs.isEmpty) {
              return Center(
                child: Text(
                  "No tasks found in this project's backlog. Add a task to backlog first.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                ),
              );
            }

            return StatefulBuilder(
              builder: (context, setSubState) {
                // Initialize default selections safely
                if (selectedSprintId == null && eligibleSprints.isNotEmpty) {
                  selectedSprintId = eligibleSprints.first.id;
                }
                if (selectedTaskId == null && tasksDocs.isNotEmpty) {
                  selectedTaskId = tasksDocs.first.id;
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Orchestrate Task Assignments",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Assign backlog items directly to sprints or send them back to backlog.",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      // Target Sprint dropdown
                      const Text("1. Select Sprint Destination", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSprintId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            onChanged: (val) {
                              setSubState(() {
                                selectedSprintId = val;
                              });
                            },
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text("None (Back to Backlog)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ),
                              ...eligibleSprints.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text("${s.title} (${s.status})"),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Target Task dropdown
                      const Text("2. Select Backlog Task to Link", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTaskId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            onChanged: (val) {
                              setSubState(() {
                                selectedTaskId = val;
                              });
                            },
                            items: tasksDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['title'] ?? 'Untitled';
                              final currentSprintId = data['sprintId'] as String?;

                              String locationLabel = "(Backlog)";
                              if (currentSprintId != null) {
                                final matchingSprint = eligibleSprints.where((s) => s.id == currentSprintId);
                                if (matchingSprint.isNotEmpty) {
                                  locationLabel = "(${matchingSprint.first.title})";
                                }
                              }

                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text("$title $locationLabel", overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Link Task Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (selectedTaskId != null) {
                              final targetSprintId = selectedSprintId == '' ? null : selectedSprintId;
                              await _taskService.linkTaskToSprint(
                                projectId: ws.id,
                                taskId: selectedTaskId!,
                                sprintId: targetSprintId,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Task sprint linkage updated successfully!")),
                              );
                            }
                          },
                          child: const Text("Update Sprint Assignment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTasksTab(Workspace ws) {
    final tasksStream = _taskService.getWorkspaceTasks(ws.id);
    final sprintsStream = SprintService().getProjectSprints(ws.id);

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: Rx.combineLatest2<QuerySnapshot, List<Sprint>, List<QueryDocumentSnapshot>>(
        tasksStream,
        sprintsStream,
        (tasksSnap, sprints) {
          final activeSprintIds = sprints.where((s) => s.status == 'active').map((s) => s.id).toSet();
          return tasksSnap.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final sprintId = data['sprintId'] as String?;
            return sprintId != null && activeSprintIds.contains(sprintId);
          }).toList();
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text("Error Loading Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "This is typically due to Firestore Security Rules. Ensure your rules allow reading '/projects/${ws.id}/tasks'.\n\nError details: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }
        
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No active tasks", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Active sprint tasks will appear here.", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final doc = tasks[index];
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

  Widget _buildBacklogTab(Workspace ws) {
    final tasksStream = _taskService.getWorkspaceTasks(ws.id);
    final sprintsStream = SprintService().getProjectSprints(ws.id);

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: Rx.combineLatest2<QuerySnapshot, List<Sprint>, List<QueryDocumentSnapshot>>(
        tasksStream,
        sprintsStream,
        (tasksSnap, sprints) {
          final activeSprintIds = sprints.where((s) => s.status == 'active').map((s) => s.id).toSet();
          return tasksSnap.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final sprintId = data['sprintId'] as String?;
            return sprintId == null || !activeSprintIds.contains(sprintId);
          }).toList();
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text("Error Loading Backlog", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "Error details: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }
        
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.backpack_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Backlog is empty", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("No backlog or planned tasks found in this project.", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final doc = tasks[index];
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

  Widget? _buildMemberTrailing(Workspace ws, String memberId, String role, String name) {
    if (memberId == currentUserId || role == 'owner') return null;

    final currentUserRole = ws.memberRoles[currentUserId] ?? 'member';

    if (currentUserRole == 'owner') {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          if (value == 'admin') {
            await _workspaceService.updateMemberRole(ws.id, memberId, 'admin');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name is now an Admin.")));
            }
          } else if (value == 'member') {
            await _workspaceService.updateMemberRole(ws.id, memberId, 'member');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name is now a Member.")));
            }
          } else if (value == 'remove') {
            await _workspaceService.removeMember(ws.id, memberId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name removed from workspace.")));
            }
          }
        },
        itemBuilder: (context) => [
          if (role == 'member')
            const PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(Icons.shield, size: 18),
                  SizedBox(width: 8),
                  Text("Promote to Admin"),
                ],
              ),
            ),
          if (role == 'admin')
            const PopupMenuItem(
              value: 'member',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18),
                  SizedBox(width: 8),
                  Text("Demote to Member"),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 18, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Remove Member", style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ],
      );
    } else if (currentUserRole == 'admin') {
      if (role == 'member') {
        return IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
          onPressed: () async {
            await _workspaceService.removeMember(ws.id, memberId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name removed from workspace.")));
            }
          },
        );
      }
    }
    return null;
  }

  Widget _buildMembersTab(Workspace ws) {
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
              final color = Color(int.parse(ws.color));
              
              if (userSnapshot.hasError) {
                final role = ws.memberRoles[memberId] ?? 'member';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.push(context, UserProfileScreen.route(memberId)),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(memberId.isNotEmpty ? memberId[0].toUpperCase() : '?', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      const Text("Restricted Profile", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  subtitle: const Text("Protected by Firestore security rules"),
                  trailing: _buildMemberTrailing(ws, memberId, role, "Restricted Profile"),
                );
              }
              if (!userSnapshot.hasData) return const ListTile(title: Text("Loading..."));
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final name = userData?['name'] ?? userData?['displayName'] ?? 'Unknown User';
              final email = userData?['email'] ?? '';
              final role = ws.memberRoles[memberId] ?? 'member';
              final isOnline = userData?['isOnline'] ?? false;
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.push(context, UserProfileScreen.route(memberId)),
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
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                subtitle: Text(email),
                trailing: _buildMemberTrailing(ws, memberId, role, name),
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

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text("Error Loading Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "This is typically due to Firestore Security Rules. Ensure your rules allow reading '/projects/${ws.id}/activity'.\n\nError details: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          );
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
