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

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add(data);
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
    } else {
      data['dueDate'] = FieldValue.delete();
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .update(data);
  }
}
