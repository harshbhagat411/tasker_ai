import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/notification_model.dart';
import 'in_app_notification_service.dart';

enum FriendshipStatus { notFriend, requestSent, requestReceived, friend }

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

    // Prepare clean tasker ID queries (supporting both '@username' and 'username')
    final queryWithAt = cleanQuery.startsWith('@') ? cleanQuery : '@$cleanQuery';
    final queryWithoutAt = cleanQuery.startsWith('@') ? cleanQuery.substring(1) : cleanQuery;

    // 1. Search by taskerId exact match (case-insensitive via taskerIdLower)
    final taskerQuerySnapshot = await _firestore
        .collection('users')
        .where('taskerIdLower', whereIn: [queryWithAt, queryWithoutAt])
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
    final String senderTaskerId = senderData['taskerId'] ?? '';

    // Fetch Receiver (Target User) info
    final receiverDoc = await _firestore.collection('users').doc(targetUid).get();
    if (!receiverDoc.exists) return "Target user not found";
    
    final receiverData = receiverDoc.data()!;
    final String receiverName = receiverData['displayName'] ?? receiverData['name'] ?? 'User';
    final String receiverPhoto = receiverData['photoURL'] ?? receiverData['profileImage'] ?? receiverData['avatar'] ?? '';
    final String receiverTaskerId = receiverData['taskerId'] ?? '';

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
      'senderTaskerId': senderTaskerId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'receiverTaskerId': receiverTaskerId,
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
      'senderTaskerId': senderTaskerId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'receiverTaskerId': receiverTaskerId,
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

  // Accept Friend Request
  Future<void> acceptFriendRequest(String senderUid) async {
    final currentUserId = userId;
    if (currentUserId == null) throw Exception("User not authenticated");

    // Fetch details for both users
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final senderDoc = await _firestore.collection('users').doc(senderUid).get();

    if (!currentUserDoc.exists || !senderDoc.exists) {
      throw Exception("User data not found");
    }

    final currentUserData = currentUserDoc.data()!;
    final senderData = senderDoc.data()!;

    final String currentName = currentUserData['displayName'] ?? currentUserData['name'] ?? 'User';
    final String currentPhoto = currentUserData['photoURL'] ?? currentUserData['profileImage'] ?? currentUserData['avatar'] ?? '';
    final String currentTaskerId = currentUserData['taskerId'] ?? '';
    final String currentEmail = currentUserData['email'] ?? '';

    final String senderName = senderData['displayName'] ?? senderData['name'] ?? 'User';
    final String senderPhoto = senderData['photoURL'] ?? senderData['profileImage'] ?? senderData['avatar'] ?? '';
    final String senderTaskerId = senderData['taskerId'] ?? '';
    final String senderEmail = senderData['email'] ?? '';

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    // Friend doc 1: users/{currentUid}/friends/{senderUid}
    final friend1Ref = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(senderUid);

    batch.set(friend1Ref, {
      'uid': senderUid,
      'friendId': senderUid,
      'displayName': senderName,
      'taskerId': senderTaskerId,
      'photoURL': senderPhoto,
      'email': senderEmail,
      'addedAt': now,
      'acceptedAt': now,
      'status': 'accepted',
    });

    // Friend doc 2: users/{senderUid}/friends/{currentUid}
    final friend2Ref = _firestore
        .collection('users')
        .doc(senderUid)
        .collection('friends')
        .doc(currentUserId);

    batch.set(friend2Ref, {
      'uid': currentUserId,
      'friendId': currentUserId,
      'displayName': currentName,
      'taskerId': currentTaskerId,
      'photoURL': currentPhoto,
      'email': currentEmail,
      'addedAt': now,
      'acceptedAt': now,
      'status': 'accepted',
    });

    // Delete pending request docs:
    // 1. Users/{currentUid}/friend_requests_received/{senderUid}
    final receivedRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .doc(senderUid);
    batch.delete(receivedRef);

    // 2. Users/{senderUid}/friend_requests_sent/{currentUid}
    final sentRef = _firestore
        .collection('users')
        .doc(senderUid)
        .collection('friend_requests_sent')
        .doc(currentUserId);
    batch.delete(sentRef);

    await batch.commit();

    // Dispatch notification
    try {
      await InAppNotificationService().createNotification(
        receiverId: senderUid,
        type: NotificationType.friend_request,
        title: "Friend Request Accepted",
        message: "$currentName accepted your friend request.",
        senderPhoto: currentPhoto,
      );
    } catch (e) {
      print("Error creating notification: $e");
    }
  }

  // Decline Friend Request
  Future<void> declineFriendRequest(String senderUid) async {
    final currentUserId = userId;
    if (currentUserId == null) throw Exception("User not authenticated");

    final batch = _firestore.batch();

    // Delete pending request docs:
    // 1. Users/{currentUid}/friend_requests_received/{senderUid}
    final receivedRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .doc(senderUid);
    batch.delete(receivedRef);

    // 2. Users/{senderUid}/friend_requests_sent/{currentUid}
    final sentRef = _firestore
        .collection('users')
        .doc(senderUid)
        .collection('friend_requests_sent')
        .doc(currentUserId);
    batch.delete(sentRef);

    await batch.commit();
  }


  // Stream accepted friends
  Stream<QuerySnapshot> getFriendsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  // Stream friend requests received (Incoming)
  Stream<QuerySnapshot> getIncomingRequestsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .snapshots();
  }

  // Stream friend requests sent (Sent)
  Stream<QuerySnapshot> getSentRequestsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_sent')
        .snapshots();
  }

  // Stream of list of friend UIDs
  Stream<List<String>> getFriendIdsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Stream of list of sent request receiver UIDs
  Stream<List<String>> getSentRequestIdsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_sent')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Stream of list of received request sender UIDs
  Stream<List<String>> getReceivedRequestIdsStream() {
    final currentUserId = userId;
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Stream relationship status in real-time
  Stream<FriendshipStatus> getFriendshipStatusStream(String targetUid) {
    final currentUserId = userId;
    if (currentUserId == null) return Stream.value(FriendshipStatus.notFriend);

    final friendStream = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(targetUid)
        .snapshots();

    final sentStream = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_sent')
        .doc(targetUid)
        .snapshots();

    final receivedStream = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friend_requests_received')
        .doc(targetUid)
        .snapshots();

    return Rx.combineLatest3<
        DocumentSnapshot,
        DocumentSnapshot,
        DocumentSnapshot,
        FriendshipStatus>(
      friendStream,
      sentStream,
      receivedStream,
      (friendSnap, sentSnap, receivedSnap) {
        if (friendSnap.exists) {
          return FriendshipStatus.friend;
        } else if (sentSnap.exists) {
          return FriendshipStatus.requestSent;
        } else if (receivedSnap.exists) {
          return FriendshipStatus.requestReceived;
        } else {
          return FriendshipStatus.notFriend;
        }
      },
    );
  }

  // Remove friendship from both users
  Future<void> removeFriend(String friendUid) async {
    final currentUserId = userId;
    if (currentUserId == null) throw Exception("User not authenticated");

    final batch = _firestore.batch();

    // 1. Delete users/{currentUid}/friends/{friendUid}
    final friend1Ref = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendUid);
    batch.delete(friend1Ref);

    // 2. Delete users/{friendUid}/friends/{currentUid}
    final friend2Ref = _firestore
        .collection('users')
        .doc(friendUid)
        .collection('friends')
        .doc(currentUserId);
    batch.delete(friend2Ref);

    await batch.commit();
  }
}

