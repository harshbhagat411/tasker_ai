import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class RealtimeNotificationListener {
  static final RealtimeNotificationListener _instance = RealtimeNotificationListener._internal();
  factory RealtimeNotificationListener() => _instance;
  RealtimeNotificationListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot>? _subscription;
  
  // Keep track of processed notification IDs to prevent duplicates
  final Set<String> _processedIds = {};
  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    _subscription = _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final notificationId = change.doc.id;
          final senderId = data['senderId'] as String?;
          final title = data['title'] as String? ?? 'New Notification';
          final message = data['message'] as String? ?? '';
          
          // Generate a unique integer ID from the doc ID for the local notification plugin
          final int localNotifId = notificationId.hashCode;

          // Ignore if sent by the current user or already processed
          if (senderId == user.uid || _processedIds.contains(notificationId)) {
            _processedIds.add(notificationId);
            continue;
          }

          _processedIds.add(notificationId);

          // Trigger local device notification
          NotificationService().triggerImmediateCollaborationNotification(
            id: localNotifId,
            title: title,
            body: message,
            payload: '$notificationId|${data['taskId'] ?? ''}|${data['projectId'] ?? ''}',
          );
        }
      }
    });

    _isInitialized = true;
  }

  void dispose() {
    _subscription?.cancel();
    _isInitialized = false;
    _processedIds.clear();
  }
}
