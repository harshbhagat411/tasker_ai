import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/task_service.dart';
import '../main.dart';
import 'connections_screen.dart';
import 'theme_center_screen.dart';

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

  Widget _buildStatItem(BuildContext context, String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
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
                backgroundColor: Theme.of(context).primaryColor,
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

  void _showEditTaskerIdBottomSheet(BuildContext context, String currentTaskerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditTaskerIdBottomSheet(currentTaskerId: currentTaskerId);
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
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                String joinedDateString = "Joined recently";
                String currentModeString = 'personal';
                String taskerId = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final doc = snapshot.data!;
                  final data = doc.data() as Map<String, dynamic>?;

                  Timestamp? joinedTimestamp;
                  
                  if (data != null) {
                    taskerId = data['taskerId'] ?? '';
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

                  if (data != null && data.containsKey('mode') && data['mode'] != null) {
                    currentModeString = data['mode'].toString();
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
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 56.0 + 12.0 + MediaQuery.of(context).padding.bottom + 16.0),
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
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
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
                      const SizedBox(height: 24),
                      
                      // 🔹 Tasker ID Section
                      Card(
                        elevation: 4,
                        shadowColor: Colors.black12,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white12 
                                : Colors.black12, 
                            width: 0.5,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 24),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(
                            "Username :",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              taskerId.startsWith('@') ? taskerId : '@$taskerId',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                            onPressed: () => _showEditTaskerIdBottomSheet(context, taskerId),
                            tooltip: "Edit Tasker ID",
                          ),
                        ),
                      ),

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
                          int weeklyTotal = 0;
                          int weeklyCompleted = 0;

                          if (taskSnapshot.hasData && taskSnapshot.data != null) {
                            final docs = taskSnapshot.data!.docs;
                            total = docs.length;
                            final now = DateTime.now();
                            final oneWeekAgo = now.subtract(const Duration(days: 7));

                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>?;
                              final isDone = (data?['isDone'] as bool?) ?? false;
                              if (isDone) {
                                completed++;
                              } else {
                                pending++;
                              }

                              if (data != null && data['createdAt'] is Timestamp) {
                                final createdAt = (data['createdAt'] as Timestamp).toDate();
                                if (createdAt.isAfter(oneWeekAgo)) {
                                  weeklyTotal++;
                                  if (isDone) weeklyCompleted++;
                                }
                              }
                            }
                          }

                          final double progress = total > 0 ? completed / total : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                elevation: 4,
                                shadowColor: Colors.black12,
                                color: Theme.of(context).cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white12 
                                        : Colors.black12, 
                                    width: 0.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatItem(context, "Total", total, Theme.of(context).primaryColor, Icons.assignment),
                                      _buildDivider(),
                                      _buildStatItem(context, "Completed", completed, Colors.green, Icons.check_circle_outline),
                                      _buildDivider(),
                                      _buildStatItem(context, "Pending", pending, Colors.orange, Icons.hourglass_bottom),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Overall Progress",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor: Colors.grey[300],
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    "${(progress * 100).toInt()}%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "You have completed ${(progress * 100).toInt()}% of your tasks.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Weekly Insights",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "$weeklyCompleted of $weeklyTotal tasks created in the last 7 days are completed.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // 🔹 Mode Selection
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white12 
                                : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune, color: Theme.of(context).iconTheme.color ?? Colors.grey),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Current Mode",
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value: currentModeString,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: const [
                                DropdownMenuItem(value: 'personal', child: Text("Personal")),
                                DropdownMenuItem(value: 'developer', child: Text("Developer")),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                    'mode': value,
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Theme Center Navigation Button
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ThemeCenterScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white12 
                                    : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.palette_outlined, color: Theme.of(context).iconTheme.color ?? Colors.grey),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    "Theme Center",
                                    style: TextStyle(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),



                      // 🔹 Connections Button
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white12 
                                    : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.people_outline, color: Theme.of(context).iconTheme.color ?? Colors.grey),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    "Connections",
                                    style: TextStyle(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),

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
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                                (route) => false,
                              );
                            }
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

class _EditTaskerIdBottomSheet extends StatefulWidget {
  final String currentTaskerId;

  const _EditTaskerIdBottomSheet({
    required this.currentTaskerId,
  });

  @override
  State<_EditTaskerIdBottomSheet> createState() => _EditTaskerIdBottomSheetState();
}

class _EditTaskerIdBottomSheetState extends State<_EditTaskerIdBottomSheet> {
  late final TextEditingController _controller;
  late final String _initialId;
  
  Timer? _debounceTimer;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  bool _isValid = false;
  bool _isChecking = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialId = widget.currentTaskerId.startsWith('@')
        ? widget.currentTaskerId.substring(1)
        : widget.currentTaskerId;
    _controller = TextEditingController(text: _initialId);
    _controller.addListener(_onTextChanged);
    if (_initialId.isNotEmpty) {
      _isValid = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    final cleanText = _controller.text.trim();
    
    if (cleanText == _initialId) {
      setState(() {
        _statusMessage = '';
        _isValid = true;
        _isChecking = false;
      });
      return;
    }

    if (cleanText.isEmpty) {
      setState(() {
        _statusMessage = '';
        _isValid = false;
        _isChecking = false;
      });
      return;
    }
    
    final regex = RegExp(r'^[a-z0-9_\.]{4,25}$');
    if (!regex.hasMatch(cleanText)) {
      setState(() {
        _statusMessage = "❌ Invalid format";
        _statusColor = Colors.redAccent;
        _isValid = false;
        _isChecking = false;
      });
      return;
    }
    
    setState(() {
      _statusMessage = "Checking availability...";
      _statusColor = Colors.grey;
      _isChecking = true;
      _isValid = false;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await _checkUsernameAvailability(cleanText);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final queryText = username.toLowerCase();
    final queryTextWithAt = "@$queryText";
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('taskerIdLower', whereIn: [queryText, queryTextWithAt])
          .limit(1)
          .get();
          
      if (!mounted) return;
      
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _statusMessage = "✅ Available";
          _statusColor = Colors.green;
          _isValid = true;
          _isChecking = false;
        });
      } else {
        final matchingDoc = querySnapshot.docs.first;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (matchingDoc.id == currentUserId) {
          setState(() {
            _statusMessage = '';
            _isValid = true;
            _isChecking = false;
          });
        } else {
          setState(() {
            _statusMessage = "❌ Username already taken";
            _statusColor = Colors.redAccent;
            _isValid = false;
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Error checking availability";
        _statusColor = Colors.redAccent;
        _isValid = false;
        _isChecking = false;
      });
    }
  }

  Future<void> _saveTaskerId() async {
    final cleanText = _controller.text.trim();
    if (cleanText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid Tasker ID"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    if (cleanText == _initialId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No changes made"),
          backgroundColor: Colors.grey,
        ),
      );
      Navigator.pop(context);
      return;
    }
    
    final regex = RegExp(r'^[a-z0-9_\.]{4,25}$');
    if (!regex.hasMatch(cleanText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid Tasker ID"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final queryText = cleanText.toLowerCase();
      final queryTextWithAt = "@$queryText";
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('taskerIdLower', whereIn: [queryText, queryTextWithAt])
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty && querySnapshot.docs.first.id != FirebaseAuth.instance.currentUser?.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Username already taken"),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _statusMessage = "❌ Username already taken";
            _statusColor = Colors.redAccent;
            _isValid = false;
            _isSaving = false;
          });
        }
        return;
      }
      
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
          'taskerId': cleanText,
          'taskerIdLower': cleanText.toLowerCase(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tasker ID updated"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to update Tasker ID"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Edit Tasker ID",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Tasker ID",
                prefixText: "@",
                prefixStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[100],
              ),
            ),
            const SizedBox(height: 8),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _statusColor,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: (_isValid && !_isChecking && !_isSaving)
                      ? _saveTaskerId
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
