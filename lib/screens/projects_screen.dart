import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/workspace_service.dart';
import '../services/task_service.dart';
import '../services/activity_service.dart';
import '../models/workspace_model.dart';
import 'create_workspace_screen.dart';
import 'workspace_details_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final ActivityService _activityService = ActivityService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          "Your Projects",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<Workspace>>(
        stream: _workspaceService.getUserWorkspaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading projects."));
          }

          final workspaces = snapshot.data ?? [];

          if (workspaces.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      "No projects yet",
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Create a workspace to collaborate with your team.",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateWorkspaceScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Create Workspace"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 56.0 + 12.0 + MediaQuery.of(context).padding.bottom + 16.0),
            itemCount: workspaces.length,
            itemBuilder: (context, index) {
              final workspace = workspaces[index];
              return _buildProjectCard(workspace);
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectCard(Workspace workspace) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Color(int.parse(workspace.color));
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkspaceDetailsScreen(workspace: workspace),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    workspace.iconData,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              workspace.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: workspace.members.take(30).toList())
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          int activeCount = 0;
                          if (userSnapshot.hasData) {
                            for (var doc in userSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>?;
                              if (data != null && data['isOnline'] == true) {
                                activeCount++;
                              }
                            }
                          }
                          final totalCount = workspace.members.length;
                          return Text(
                            "$activeCount / $totalCount active",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (workspace.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                workspace.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[350] : Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Middle section: Tasks completion progress bar
            StreamBuilder<QuerySnapshot>(
              stream: TaskService().getWorkspaceTasks(workspace.id),
              builder: (context, taskSnapshot) {
                final docs = taskSnapshot.data?.docs ?? [];
                final total = docs.length;
                final completed = docs.where((d) => (d.data() as Map<String, dynamic>?)?['isDone'] == true).length;
                final double progress = total > 0 ? completed / total : 0.0;
                final percent = (progress * 100).toInt();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Progress: $completed/$total Tasks",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        Text(
                          "$percent%",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 16),
            
            // Bottom section: Recent activity text
            StreamBuilder<QuerySnapshot>(
              stream: _activityService.getProjectActivities(workspace.id),
              builder: (context, activitySnapshot) {
                final docs = activitySnapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Row(
                    children: [
                      Icon(Icons.history, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        "No recent activity logged",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                      ),
                    ],
                  );
                }
                
                final data = docs.first.data() as Map<String, dynamic>;
                final userName = data['userName'] ?? 'User';
                final message = data['message'] ?? 'updated project';
                final taskTitle = data['taskTitle'];
                
                DateTime timestamp = DateTime.now();
                if (data['timestamp'] is Timestamp) {
                  timestamp = (data['timestamp'] as Timestamp).toDate();
                }
                
                final text = "$userName $message${taskTitle != null ? ' \"$taskTitle\"' : ''}";
                
                return Row(
                  children: [
                    Icon(Icons.history, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(timestamp),
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}
