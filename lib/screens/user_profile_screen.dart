import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friend_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FriendService _friendService = FriendService();
  bool _isProcessing = false;

  String _formatJoinedDate(Timestamp? timestamp) {
    if (timestamp == null) return "Joined recently";
    final date = timestamp.toDate();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return "Joined ${months[date.month - 1]} ${date.year}";
  }

  Widget _buildAvatar(String name, String photoUrl, {required double radius}) {
    final cleanPhoto = photoUrl.trim();
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    if (cleanPhoto.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          cleanPhoto,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return CircleAvatar(
              radius: radius,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            );
          },
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Future<void> _addFriend() async {
    setState(() => _isProcessing = true);
    final result = await _friendService.sendFriendRequest(widget.userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: result.contains("successfully") ? Colors.green : Colors.redAccent,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _isProcessing = true);
    try {
      await _friendService.acceptFriendRequest(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Friend request accepted"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest() async {
    setState(() => _isProcessing = true);
    try {
      await _friendService.declineFriendRequest(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Friend request declined"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmRemoveFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Remove friend?"),
          content: const Text("You will no longer be connected."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Remove", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await _friendService.removeFriend(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Friend removed"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to remove friend: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildRelationshipSection(FriendshipStatus status) {
    if (_isProcessing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case FriendshipStatus.notFriend:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.person_add),
            label: const Text("Add Friend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _addFriend,
          ),
        );

      case FriendshipStatus.requestSent:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              foregroundColor: isDark ? Colors.white30 : Colors.grey[500],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.schedule),
            label: const Text("Request Sent", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: null, // Disabled
          ),
        );

      case FriendshipStatus.requestReceived:
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text("Reject", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _rejectRequest,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text("Accept", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _acceptRequest,
                ),
              ),
            ),
          ],
        );

      case FriendshipStatus.friend:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Friends ✅",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text("Remove Friend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _confirmRemoveFriend,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("User profile not found."));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) {
            return const Center(child: Text("Error reading user data."));
          }

          final name = userData['displayName'] ?? userData['name'] ?? 'User';
          final taskerId = userData['taskerId'] ?? '';
          final photoUrl = userData['photoURL'] ?? userData['profileImage'] ?? userData['avatar'] ?? '';
          final isOnline = userData['isOnline'] ?? false;

          Timestamp? joinedTimestamp;
          if (userData['createdAt'] is Timestamp) {
            joinedTimestamp = userData['createdAt'] as Timestamp;
          } else if (userData['joinedAt'] is Timestamp) {
            joinedTimestamp = userData['joinedAt'] as Timestamp;
          }
          final joinedDateString = _formatJoinedDate(joinedTimestamp);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar Hero
                Center(
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'avatar-${widget.userId}',
                        child: _buildAvatar(name, photoUrl, radius: 60),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Display Name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Tasker ID
                Text(
                  taskerId.startsWith('@') ? taskerId : '@$taskerId',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                // Presence Text & Joined Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? "Online" : "Offline",
                      style: TextStyle(
                        fontSize: 14,
                        color: isOnline ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "•",
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400]),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      joinedDateString,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Relationship State Actions
                StreamBuilder<FriendshipStatus>(
                  stream: _friendService.getFriendshipStatusStream(widget.userId),
                  builder: (context, statusSnapshot) {
                    if (statusSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final status = statusSnapshot.data ?? FriendshipStatus.notFriend;
                    return _buildRelationshipSection(status);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
