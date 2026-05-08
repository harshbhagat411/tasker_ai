import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _debounceTimer;
  String? _currentTaskId;

  PresenceService._internal() {
    WidgetsBinding.instance.addObserver(this);
    setOnlineStatus(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      setOnlineStatus(false);
      if (_currentTaskId != null) {
        clearTaskPresence(_currentTaskId!);
      }
    } else if (state == AppLifecycleState.resumed) {
      setOnlineStatus(true);
      // Re-apply presence if needed, but it's handled by TaskDetailsScreen for now
    }
  }

  // Global Presence
  Future<void> setOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore.collection('users').doc(user.uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Task Presence (typing/viewing)
  Future<void> setTaskPresence(String taskId, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    _currentTaskId = taskId;

    // Debounce to prevent too many writes
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User';

      await _firestore
          .collection('task_presence')
          .doc(taskId)
          .collection('users')
          .doc(user.uid)
          .set({
        'status': status,
        'userName': userName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> clearTaskPresence(String taskId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    if (_currentTaskId == taskId) {
      _currentTaskId = null;
    }

    await _firestore
        .collection('task_presence')
        .doc(taskId)
        .collection('users')
        .doc(user.uid)
        .delete();
  }

  Stream<QuerySnapshot> getTaskPresenceStream(String taskId) {
    return _firestore
        .collection('task_presence')
        .doc(taskId)
        .collection('users')
        .snapshots();
  }
}
