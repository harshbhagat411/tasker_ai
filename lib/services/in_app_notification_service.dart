import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class InAppNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new notification
  Future<void> createNotification({
    required String receiverId,
    required NotificationType type,
    required String title,
    required String message,
    String? taskId,
    String? projectId,
    String? senderPhoto,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      // Don't send notification to self
      if (receiverId == currentUser.uid) return;

      final docRef = _firestore.collection('notifications').doc();
      
      final notification = NotificationModel(
        id: docRef.id,
        receiverId: receiverId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'Someone',
        senderPhoto: senderPhoto,
        type: type,
        title: title,
        message: message,
        taskId: taskId,
        projectId: projectId,
        isRead: false,
        createdAt: Timestamp.now(),
      );

      await docRef.set(notification.toMap());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Get user's notifications stream
  Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots();
  }

  // Get unread notifications count
  Stream<QuerySnapshot> getUnreadNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots();
  }

  // Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all user's notifications as read
  Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
