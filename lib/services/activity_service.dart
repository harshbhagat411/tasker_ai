import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityType {
  static const String taskCreated = 'task_created';
  static const String taskAssigned = 'task_assigned';
  static const String taskCompleted = 'task_completed';
  static const String taskEdited = 'task_edited';
  static const String memberJoined = 'member_joined';
  static const String memberInvited = 'member_invited';
  static const String memberAcceptedInvite = 'member_accepted_invite';
}

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

  Future<void> logProjectActivity({
    required String projectId,
    required String type,
    String? taskTitle,
    String? message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User';

    await _firestore.collection('projects').doc(projectId).collection('activity').add({
      'type': type,
      'userId': user.uid,
      'userName': userName,
      'taskTitle': taskTitle,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
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

  Stream<QuerySnapshot> getProjectActivities(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(30)
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
