import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';
import '../services/workspace_service.dart';
import '../services/in_app_notification_service.dart';
import '../models/notification_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'task_details_screen.dart';
import 'workspace_details_screen.dart';
import '../models/workspace_model.dart';

class CollaborationRequestsScreen extends StatefulWidget {
  const CollaborationRequestsScreen({super.key});

  @override
  State<CollaborationRequestsScreen> createState() => _CollaborationRequestsScreenState();
}

class _CollaborationRequestsScreenState extends State<CollaborationRequestsScreen> {
  final TaskService _taskService = TaskService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final InAppNotificationService _inAppNotificationService = InAppNotificationService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Collaboration Requests', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          bottom: TabBar(
            labelColor: Theme.of(context).textTheme.bodyLarge?.color,
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0D47A1),
            tabs: [
              StreamBuilder<QuerySnapshot>(
                stream: _taskService.getPendingInvites(),
                builder: (context, snapshot) {
                  int count = snapshot.data?.docs.length ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Tasks"),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _workspaceService.getPendingProjectInvites(),
                builder: (context, snapshot) {
                  int count = snapshot.data?.docs.length ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Projects"),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _inAppNotificationService.getUnreadNotifications(),
                builder: (context, snapshot) {
                  int count = snapshot.data?.docs.length ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Updates"),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTaskInvitesTab(),
            _buildProjectInvitesTab(),
            _buildUpdatesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInvitesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _taskService.getPendingInvites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red)));
        }

        final invites = snapshot.data?.docs ?? [];

        if (invites.isEmpty) {
          return _buildEmptyState("No task invites");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteDoc = invites[index];
            final data = inviteDoc.data() as Map<String, dynamic>;
            final String fromUserName = data['fromUserName'] ?? 'Someone';
            final String taskTitle = data['taskTitle'] ?? 'A Task';

            return Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.person, size: 18, color: Colors.blue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                              children: [
                                TextSpan(text: fromUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const TextSpan(text: " invited you to collaborate"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.task_alt, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              taskTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.shade100),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async => await _taskService.rejectInvite(inviteDoc.id),
                            child: const Text("Decline"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await _taskService.acceptInvite(inviteDoc.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task invite accepted')));
                              }
                            },
                            child: const Text("Accept"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectInvitesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _workspaceService.getPendingProjectInvites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red)));
        }

        var invites = snapshot.data?.docs ?? [];
        
        // Sort client-side to avoid composite index requirement
        invites = invites.toList();
        invites.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['timestamp'] as Timestamp?;
          final bTime = bData['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (invites.isEmpty) {
          return _buildEmptyState("No project invites");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final inviteDoc = invites[index];
            final data = inviteDoc.data() as Map<String, dynamic>;
            
            final String senderName = data['senderName'] ?? 'Someone';
            final String projectName = data['projectName'] ?? 'A Project';
            final String projectId = data['projectId'];

            return Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.purple.shade50,
                          child: const Icon(Icons.group_add, size: 18, color: Colors.purple),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                              children: [
                                TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const TextSpan(text: " invited you to a project"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('workspaces').doc(projectId).get(),
                        builder: (context, workspaceSnapshot) {
                          int memberCount = 0;
                          if (workspaceSnapshot.hasData && workspaceSnapshot.data!.exists) {
                            final wData = workspaceSnapshot.data!.data() as Map<String, dynamic>;
                            memberCount = (wData['members'] as List<dynamic>? ?? []).length;
                          }
                          return Row(
                            children: [
                              const Icon(Icons.workspaces, size: 18, color: Colors.purple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  projectName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              if (memberCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text("$memberCount members", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          );
                        }
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.shade100),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async => await _workspaceService.rejectProjectInvite(inviteDoc.id),
                            child: const Text("Decline"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await _workspaceService.acceptProjectInvite(inviteDoc.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project invite accepted')));
                              }
                            },
                            child: const Text("Accept"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _inAppNotificationService.getUserNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No recent updates");
        }

        final docs = snapshot.data!.docs;
        // Sort by newest first client-side
        docs.sort((a, b) {
          final tA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final tB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final notification = NotificationModel.fromFirestore(docs[index]);
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.task_shared:
      case NotificationType.task_assigned:
        icon = Icons.assignment_ind;
        color = Colors.blue;
        break;
      case NotificationType.task_completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.workspace_invite:
      case NotificationType.workspace_invite_accepted:
        icon = Icons.business_center;
        color = Colors.purple;
        break;
      case NotificationType.invite_accepted:
        icon = Icons.handshake;
        color = Colors.teal;
        break;
      case NotificationType.invite_rejected:
      case NotificationType.workspace_invite_rejected:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case NotificationType.friend_request:
        icon = Icons.person_add;
        color = Colors.indigo;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: notification.isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!notification.isRead) {
            await _inAppNotificationService.markAsRead(notification.id);
          }
          if (!mounted) return;
          
          if (notification.taskId != null) {
             final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
             Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: notification.taskId!, currentUserId: uid, projectId: notification.projectId)));
          } else if (notification.projectId != null) {
             showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
             try {
                final doc = await FirebaseFirestore.instance.collection('workspaces').doc(notification.projectId).get();
                if (!mounted) return;
                Navigator.pop(context); // hide loading
                if (doc.exists) {
                   final workspace = Workspace.fromFirestore(doc);
                   Navigator.push(context, MaterialPageRoute(builder: (_) => WorkspaceDetailsScreen(workspace: workspace)));
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workspace not found')));
                }
             } catch (e) {
                if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load workspace')));
                }
             }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(notification.createdAt.toDate()),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
