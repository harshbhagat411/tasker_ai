import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatJoinedDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "Joined: ${months[date.month - 1]} ${date.year}";
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
                backgroundColor: const Color(0xFF26A69A),
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
        backgroundColor: const Color(0xFF26A69A),
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

                String joinedDateString = "";

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    if (data.containsKey('name') && data['name'] != null && data['name'].toString().trim().isNotEmpty) {
                      displayName = data['name'].toString().trim();
                      initial = displayName[0].toUpperCase();
                    }
                    if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
                      joinedDateString = _formatJoinedDate(data['createdAt'] as Timestamp);
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
                        backgroundColor: Colors.primaries[user.uid.hashCode % Colors.primaries.length],
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
                            icon: const Icon(Icons.edit, size: 20, color: Color(0xFF26A69A)),
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26A69A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            joinedDateString,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF26A69A),
                              fontWeight: FontWeight.w600,
                            ),
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
                                  _buildStatItem("Total", total, const Color(0xFF26A69A)),
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
