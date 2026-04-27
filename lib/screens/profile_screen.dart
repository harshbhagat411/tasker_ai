import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../providers/theme_provider.dart';

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

  Widget _buildStatItem(BuildContext context, String label, int count, Color color) {
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
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
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
                        backgroundColor: Theme.of(context).primaryColor,
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
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 20, color: Theme.of(context).primaryColor),
                            onPressed: () => _showEditProfileDialog(context, displayName),
                            tooltip: "Edit Profile",
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // User Email
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      if (joinedDateString.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          joinedDateString,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
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
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(context, "Total", total, Theme.of(context).primaryColor),
                                  _buildDivider(),
                                  _buildStatItem(context, "Completed", completed, Colors.green),
                                  _buildDivider(),
                                  _buildStatItem(context, "Pending", pending, Colors.orange),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // 🔹 Dark Mode Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.dark_mode, color: Theme.of(context).iconTheme.color ?? Colors.grey),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Dark Mode",
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            Switch(
                              value: Provider.of<ThemeProvider>(context).isDarkMode,
                              onChanged: (value) {
                                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                              },
                              activeColor: const Color(0xFF1A237E),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

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
