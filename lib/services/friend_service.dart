import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import 'in_app_notification_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // 1. Search User (Exact match only, case-insensitive, priorities: 1. taskerId, 2. email)
  Future<List<Map<String, dynamic>>> searchUser(String query) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    // Self-search check on email
    if (currentUser.email != null && cleanQuery == currentUser.email!.toLowerCase()) {
      return [];
    }

    // Fetch self details to perform self-search check on taskerId
    try {
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data()!;
        final selfTaskerIdLower = (currentUserData['taskerIdLower'] as String?)?.toLowerCase();
        final selfTaskerId = (currentUserData['taskerId'] as String?)?.toLowerCase();
        
        if ((selfTaskerIdLower != null && cleanQuery == selfTaskerIdLower) ||
            (selfTaskerId != null && cleanQuery == selfTaskerId)) {
          return [];
        }
        
        // Check if query is query without @ but self is with @
        final queryWithAt = cleanQuery.startsWith('@') ? cleanQuery : '@$cleanQuery';
        if ((selfTaskerIdLower != null && queryWithAt == selfTaskerIdLower) ||
            (selfTaskerId != null && queryWithAt == selfTaskerId)) {
          return [];
        }
      }
    } catch (e) {
      print("Error fetching current user details for self-search verification: $e");
    }

    // Prepare clean tasker ID query (supporting both '@username' and 'username')
    final taskerIdQuery = cleanQuery.startsWith('@') ? cleanQuery : '@$cleanQuery';

    // 1. Search by taskerId exact match (case-insensitive via taskerIdLower)
    final taskerQuerySnapshot = await _firestore
        .collection('users')
        .where('taskerIdLower', isEqualTo: taskerIdQuery)
        .limit(1)
        .get();

    List<DocumentSnapshot> matches = taskerQuerySnapshot.docs;

    // 2. Search by email exact match (case-insensitive via emailLower) if taskerId search had no results
    if (matches.isEmpty) {
      final emailQuerySnapshot = await _firestore
          .collection('users')
          .where('emailLower', isEqualTo: cleanQuery)
          .limit(1)
          .get();
      matches = emailQuerySnapshot.docs;
    }

    final List<Map<String, dynamic>> results = [];

    for (var doc in matches) {
      // Exclude self (Self-search safety)
      if (doc.id == currentUser.uid) continue;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      results.add({
        'uid': doc.id,
        'name': data['displayName'] ?? data['name'] ?? 'User',
        'email': data['email'] ?? '',
        'taskerId': data['taskerId'] ?? '',
        'profileImage': data['photoURL'] ?? data['profileImage'] ?? data['avatar'] ?? '',
      });
    }

    return results;
  }

  // 2. Send Friend Request (Check friendship, duplicate requests, and transactionally save requests + notification)
  Future<String> sendFriendRequest(String targetUid) async {
    final currentUserId = userId;
    if (currentUserId == null) return "User not authenticated";
    if (currentUserId == targetUid) return "Cannot send friend request to yourself";

    // 1. Check if already friends
    final friendDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(targetUid)
        .get();
        
    if (friendDoc.exists) {
      return "You are already friends with this user";
    }

    // 2. Check if duplicate request exists (already sent)
    final sentDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_sent')
        .doc(targetUid)
        .get();
        
    if (sentDoc.exists) {
      return "Friend request already sent";
    }

    // 3. Check if reverse request exists (already received)
    final receivedDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .doc(targetUid)
        .get();
        
    if (receivedDoc.exists) {
      return "This user already sent you a request";
    }

    // Fetch Sender (Current User) info for rich metadata
    final senderDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!senderDoc.exists) return "Sender profile not found";
    
    final senderData = senderDoc.data()!;
    final String senderName = senderData['displayName'] ?? senderData['name'] ?? 'Someone';
    final String senderPhoto = senderData['photoURL'] ?? senderData['profileImage'] ?? senderData['avatar'] ?? '';

    // Fetch Receiver (Target User) info
    final receiverDoc = await _firestore.collection('users').doc(targetUid).get();
    if (!receiverDoc.exists) return "Target user not found";

    final now = FieldValue.serverTimestamp();

    // 4. Create request records using a batch
    final batch = _firestore.batch();

    // Sender side
    final sentRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_sent')
        .doc(targetUid);
        
    batch.set(sentRef, {
      'senderId': currentUserId,
      'receiverId': targetUid,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'createdAt': now,
      'status': 'pending',
    });

    // Receiver side
    final receivedRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('friend_requests_received')
        .doc(currentUserId);
        
    batch.set(receivedRef, {
      'senderId': currentUserId,
      'receiverId': targetUid,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'createdAt': now,
      'status': 'pending',
    });

    await batch.commit();

    // 5. Create in-app notification event with rich metadata
    try {
      await InAppNotificationService().createNotification(
        receiverId: targetUid,
        type: NotificationType.friend_request,
        title: "Friend Request",
        message: "$senderName sent you a friend request.",
        senderPhoto: senderPhoto,
      );
    } catch (e) {
      print("Error creating friend request notification: $e");
    }

    return "Friend request sent successfully";
  }
}
