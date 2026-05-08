import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityService {
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logActivity({
    required String taskId,
    required String type,
    required String message,
    required List<dynamic> members,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User';

    await _firestore.collection('tasks').doc(taskId).collection('activities').add({
      'taskId': taskId,
      'userId': user.uid,
      'userName': userName,
      'type': type,
      'message': message,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTaskActivities(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getRecentActivities({int limit = 5}) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collectionGroup('activities')
        .where('members', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
