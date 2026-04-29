import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> addTask(String title, {String priority = 'low', DateTime? dueDate}) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': title,
      'isDone': false,
      'isPinned': false,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
      'notifiedLocally': false,
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

  Future<void> togglePinTask(String id, bool isPinned) async {
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .update({
      'isPinned': isPinned,
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
      data['notifiedLocally'] = false; // Reset notification flag when due date changes
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

  Future<void> checkDueTasksAndNotify() async {
    if (userId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('isDone', isEqualTo: false)
          .where('notifiedLocally', isEqualTo: false)
          .get();

      final now = DateTime.now();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('dueDate') && data['dueDate'] != null) {
          final dueDate = (data['dueDate'] as Timestamp).toDate();
          if (dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now)) {
            // Task is due, send instant notification
            await NotificationService.showInstantNotification(
              doc.id.hashCode,
              "Task Reminder",
              "Your task '\${data['title'] ?? 'Task'}' is due!",
            );

            // Mark as notified locally
            await doc.reference.update({'notifiedLocally': true});
          }
        }
      }
    } catch (e) {
      print("Error checking due tasks: \$e");
    }
  }
}
