import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friend_service.dart';
import 'user_profile_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _hasSearched = false;

  // Request handling state
  final Set<String> _processingUids = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {}); // Rebuild search input bar to update clear button visibility
  }

  // Perform search
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _friendService.searchUser(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error searching: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Send request
  Future<void> _sendFriendRequest(String targetUid) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text("Sending friend request..."),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final message = await _friendService.sendFriendRequest(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: message.contains("successfully") ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send request: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _onAcceptRequest(String senderUid) async {
    setState(() {
      _processingUids.add(senderUid);
    });

    try {
      await _friendService.acceptFriendRequest(senderUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Friend added"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingUids.remove(senderUid);
        });
      }
    }
  }

  Future<void> _onDeclineRequest(String senderUid) async {
    setState(() {
      _processingUids.add(senderUid);
    });

    try {
      await _friendService.declineFriendRequest(senderUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request declined"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingUids.remove(senderUid);
        });
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInstruction(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 80,
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                "Find your friends",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Search using their exact email address or @taskerId to send a connection request.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24).withOpacity(0.5) : Colors.grey[50]!,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200]!,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildUserCard({
    required String name,
    required String taskerId,
    required String photoUrl,
    required bool isDark,
    required String statusText,
    required Color statusColor,
    Widget? actionWidget,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAvatar(name, photoUrl, radius: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taskerId.startsWith('@') ? taskerId : '@$taskerId',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (actionWidget != null)
              actionWidget
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFriendSinceDate(Timestamp? timestamp) {
    if (timestamp == null) return "recently";
    final date = timestamp.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Widget _buildFriendsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.people_outline,
            title: "No friends yet",
            subtitle: "Add friends to quickly share tasks.",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final friendDoc = docs[index];
            final friendId = friendDoc.id;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(friendId).snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerTile(isDark);
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final name = userData['displayName'] ?? userData['name'] ?? 'User';
                final taskerId = userData['taskerId'] ?? '';
                final photoUrl = userData['photoURL'] ?? userData['profileImage'] ?? userData['avatar'] ?? '';
                final isOnline = userData['isOnline'] ?? false;

                // Extract friend since date from friendDoc
                final friendData = friendDoc.data() as Map<String, dynamic>?;
                final addedAt = friendData?['acceptedAt'] as Timestamp? ?? friendData?['addedAt'] as Timestamp?;
                final friendSince = _formatFriendSinceDate(addedAt);

                return Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: friendId),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Profile Photo with Hero and Online Indicator
                          Stack(
                            children: [
                              Hero(
                                tag: 'avatar-$friendId',
                                child: _buildAvatar(name, photoUrl, radius: 24),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  taskerId.startsWith('@') ? taskerId : '@$taskerId',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Friend since date
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Friend since",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white38 : Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                friendSince,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getIncomingRequestsStream(),
      builder: (context, incomingSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _friendService.getSentRequestsStream(),
          builder: (context, sentSnapshot) {
            if (incomingSnapshot.connectionState == ConnectionState.waiting ||
                sentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final incomingDocs = incomingSnapshot.data?.docs ?? [];
            final sentDocs = sentSnapshot.data?.docs ?? [];

            if (incomingDocs.isEmpty && sentDocs.isEmpty) {
              return _buildEmptyState(
                context,
                icon: Icons.mark_email_unread_outlined,
                title: "No pending requests",
                subtitle: "Your incoming and outgoing friend requests will show up here.",
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                if (incomingDocs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      "Incoming Requests (${incomingDocs.length})",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  ...incomingDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['senderName'] ?? 'User';
                    final taskerId = data['senderTaskerId'] ?? '';
                    final photoUrl = data['senderPhoto'] ?? '';
                    final senderUid = data['senderId'] ?? doc.id;
                    final isProcessing = _processingUids.contains(senderUid);

                    final actionButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: isProcessing ? null : () => _onDeclineRequest(senderUid),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            disabledForegroundColor: Colors.redAccent.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text("Decline"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isProcessing ? null : () => _onAcceptRequest(senderUid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
                            disabledForegroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          child: const Text("Accept"),
                        ),
                      ],
                    );

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: senderUid),
                          ),
                        );
                      },
                      child: _buildUserCard(
                        name: name,
                        taskerId: taskerId,
                        photoUrl: photoUrl,
                        isDark: isDark,
                        statusText: "",
                        statusColor: Colors.transparent,
                        actionWidget: actionButtons,
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                if (sentDocs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      "Sent Requests (${sentDocs.length})",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  ...sentDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['receiverName'] ?? 'User';
                    final taskerId = data['receiverTaskerId'] ?? '';
                    final photoUrl = data['receiverPhoto'] ?? '';
                    final receiverUid = data['receiverId'] ?? doc.id;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: receiverUid),
                          ),
                        );
                      },
                      child: _buildUserCard(
                        name: name,
                        taskerId: taskerId,
                        photoUrl: photoUrl,
                        isDark: isDark,
                        statusText: "Pending",
                        statusColor: Colors.blueGrey,
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddFriendTab(bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Search by email or @taskerId",
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _performSearch,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : !_hasSearched
                  ? _buildSearchInstruction(isDark)
                  : _searchResults.isEmpty
                      ? _buildEmptyState(
                          context,
                          icon: Icons.search_off_outlined,
                          title: "No users found",
                          subtitle: "Check the spelling or try searching by exact email or @taskerId.",
                        )
                      : StreamBuilder<List<String>>(
                          stream: _friendService.getFriendIdsStream(),
                          builder: (context, friendSnapshot) {
                            final friendIds = friendSnapshot.data ?? [];
                            return StreamBuilder<List<String>>(
                              stream: _friendService.getSentRequestIdsStream(),
                              builder: (context, sentSnapshot) {
                                final sentIds = sentSnapshot.data ?? [];
                                return StreamBuilder<List<String>>(
                                  stream: _friendService.getReceivedRequestIdsStream(),
                                  builder: (context, receivedSnapshot) {
                                    final receivedIds = receivedSnapshot.data ?? [];

                                    return ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _searchResults.length,
                                      itemBuilder: (context, index) {
                                        final user = _searchResults[index];
                                        final uid = user['uid'] as String;
                                        final name = user['name'] as String;
                                        final taskerId = user['taskerId'] as String;
                                        final photoUrl = user['profileImage'] as String;

                                        final isFriend = friendIds.contains(uid);
                                        final hasSentRequest = sentIds.contains(uid);
                                        final hasReceivedRequest = receivedIds.contains(uid);

                                        Widget actionButton;
                                        if (isFriend) {
                                          actionButton = const Text(
                                            "Connected",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        } else if (hasSentRequest) {
                                          actionButton = ElevatedButton(
                                            onPressed: null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey,
                                              disabledBackgroundColor: isDark
                                                  ? Colors.white10
                                                  : Colors.grey[200],
                                              disabledForegroundColor: isDark
                                                  ? Colors.white30
                                                  : Colors.grey[500],
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text("Pending"),
                                          );
                                        } else if (hasReceivedRequest) {
                                          actionButton = Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              "Received",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        } else {
                                          actionButton = ElevatedButton(
                                            onPressed: () => _sendFriendRequest(uid),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context).primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text("Add Friend"),
                                          );
                                        }

                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => UserProfileScreen(userId: uid),
                                              ),
                                            );
                                          },
                                          child: _buildUserCard(
                                            name: name,
                                            taskerId: taskerId,
                                            photoUrl: photoUrl,
                                            isDark: isDark,
                                            statusText: "",
                                            statusColor: Colors.transparent,
                                            actionWidget: actionButton,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Connections", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).primaryColor,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: "Friends"),
                Tab(text: "Requests"),
                Tab(text: "Add Friend"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(isDark),
                _buildRequestsTab(isDark),
                _buildAddFriendTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
