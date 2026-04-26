import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatJoinedDate(Timestamp? timestamp) {
    if (timestamp == null) return "Joined recently";
    final date = timestamp.toDate();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return "Joined ${months[date.month - 1]} ${date.year}";
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Profile"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: "Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                      {'name': newName},
                      SetOptions(merge: true),
                    );
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "No Email Available";
    
    // Default values if no user or loading
    String displayName = email.split('@').first;
    String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("Please login to view profile"))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                String joinedDateString = "Joined recently";

                if (snapshot.hasData) {
                  final doc = snapshot.data!;
                  final data = doc.data() as Map<String, dynamic>?;

                  Timestamp? joinedTimestamp;
                  
                  if (data != null) {
                    if (data['createdAt'] is Timestamp) {
                      joinedTimestamp = data['createdAt'] as Timestamp;
                    } else if (data['joinedAt'] is Timestamp) {
                      joinedTimestamp = data['joinedAt'] as Timestamp;
                    }
                  }

                  if (joinedTimestamp != null) {
                    joinedDateString = _formatJoinedDate(joinedTimestamp);
                    
                    // If old user only has createdAt, sync it to joinedAt
                    if (data != null && data['joinedAt'] == null && data['createdAt'] != null) {
                      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'joinedAt': data['createdAt'],
                      }, SetOptions(merge: true));
                    }
                  } else {
                    joinedDateString = _formatJoinedDate(Timestamp.now());
                    FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'joinedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  }

                  if (data != null) {
                    if (data.containsKey('name') && data['name'] != null && data['name'].toString().trim().isNotEmpty) {
                      displayName = data['name'].toString().trim();
                      initial = displayName[0].toUpperCase();
                    } else if (data.containsKey('displayName') && data['displayName'] != null && data['displayName'].toString().trim().isNotEmpty) {
                      displayName = data['displayName'].toString().trim();
                      initial = displayName[0].toUpperCase();
                    }
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Profile Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF0D47A1),
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // User Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Color(0xFF0D47A1)),
                            onPressed: () => _showEditProfileDialog(context, displayName),
                            tooltip: "Edit Profile",
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // User Email
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      if (joinedDateString.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          joinedDateString,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),

                      // 🔹 Task Summary Section
                      StreamBuilder<QuerySnapshot>(
                        stream: TaskService().getTasks(),
                        builder: (context, taskSnapshot) {
                          if (taskSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          int total = 0;
                          int completed = 0;
                          int pending = 0;

                          if (taskSnapshot.hasData && taskSnapshot.data != null) {
                            final docs = taskSnapshot.data!.docs;
                            total = docs.length;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>?;
                              final isDone = (data?['isDone'] as bool?) ?? false;
                              if (isDone) {
                                completed++;
                              } else {
                                pending++;
                              }
                            }
                          }

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem("Total", total, const Color(0xFF0D47A1)),
                                  _buildDivider(),
                                  _buildStatItem("Completed", completed, Colors.green),
                                  _buildDivider(),
                                  _buildStatItem("Pending", pending, Colors.orange),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            // AuthWrapper handles navigation automatically
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
