import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/task_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class CollaborationRequestsScreen extends StatelessWidget {
  const CollaborationRequestsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TaskService taskService = TaskService();

    print("Current User UID: ${FirebaseAuth.instance.currentUser?.uid}");

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Collaboration Requests', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: taskService.getPendingInvites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          print("Invite count: ${snapshot.data?.docs.length}");

          final invites = snapshot.data?.docs ?? [];

          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text("No collaboration requests", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final inviteDoc = invites[index];
              final data = inviteDoc.data() as Map<String, dynamic>;
              print(data);
              
              final String fromUserName = data['fromUserName'] ?? 'Someone';
              final String taskTitle = data['taskTitle'] ?? 'A Task';
              final String priority = data['taskPriority'] ?? 'low';
              DateTime? dueDate;
              if (data['taskDueDate'] is Timestamp) {
                dueDate = (data['taskDueDate'] as Timestamp).toDate();
              }
              final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            radius: 18,
                            backgroundColor: Colors.blue.withOpacity(0.15),
                            child: Text(
                              fromUserName.isNotEmpty ? fromUserName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
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
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.task_alt, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    taskTitle,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                                  ),
                                ),
                              ],
                            ),
                            if (dueDate != null || priority != 'low') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (dueDate != null) ...[
                                    Icon(Icons.calendar_today, size: 12, color: Colors.redAccent.shade200),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(dueDate),
                                      style: TextStyle(fontSize: 12, color: Colors.redAccent.shade200, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: priority == 'high' ? Colors.red.withOpacity(0.1) : (priority == 'medium' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      priority.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: priority == 'high' ? Colors.red : (priority == 'medium' ? Colors.orange : Colors.green),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ]
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
                                side: BorderSide(color: isDark ? Colors.redAccent.withOpacity(0.5) : Colors.redAccent.shade100),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                await taskService.rejectInvite(inviteDoc.id);
                              },
                              child: const Text("Reject"),
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
                                await taskService.acceptInvite(inviteDoc.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Collaboration request accepted')),
                                  );
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
      ),
    );
  }
}
