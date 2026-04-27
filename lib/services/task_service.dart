import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> addTask(String title, {String priority = 'low', DateTime? dueDate}) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': title,
      'isDone': false,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc();

    // We don't await this so the UI doesn't hang if the user is offline
    docRef.set(data).catchError((e) => print("Error saving task: \$e"));
  }

  Stream<QuerySnapshot> getTasks() {
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteTask(String id) async {
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .delete();
  }
  Future<void> toggleTask(String id, bool isDone) async {
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .update({
      'isDone': isDone,
    });
  }

  Future<void> updateTask(String id, String newTitle, {String priority = 'low', DateTime? dueDate}) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': newTitle,
      'priority': priority,
    };

    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }
    if (dueDate == null) {
      data['dueDate'] = FieldValue.delete();
    }

    // We don't await this so the UI doesn't hang if the user is offline
    _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .update(data).catchError((e) => print("Error updating task: \$e"));
  }
}
