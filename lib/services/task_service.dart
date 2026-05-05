import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'package:rxdart/rxdart.dart';
class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> addTask(String title, {String priority = 'low', DateTime? dueDate, List<Map<String, dynamic>>? subtasks}) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': title,
      'isDone': false,
      'isPinned': false,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
      'notifiedLocally': false,
    };

    if (subtasks != null && subtasks.isNotEmpty) {
      data['subtasks'] = subtasks;
    }

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
    print("Task created with ID: \${docRef.id}");

    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: docRef.id.hashCode,
        title: 'Task Reminder',
        body: 'Your task "\$title" is due!',
        scheduledDate: dueDate,
      );
    }
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
        
    await NotificationService().cancelNotification(id.hashCode);
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
    
    if (isDone) {
      await NotificationService().cancelNotification(id.hashCode);
    }
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

  Future<void> updateTask(String id, String newTitle, {String priority = 'low', DateTime? dueDate, List<Map<String, dynamic>>? subtasks}) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': newTitle,
      'priority': priority,
    };

    if (subtasks != null) {
      data['subtasks'] = subtasks;
    } else {
      data['subtasks'] = FieldValue.delete();
    }

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

    await NotificationService().cancelNotification(id.hashCode);
    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: id.hashCode,
        title: 'Task Reminder',
        body: 'Your task "\$newTitle" is due!',
        scheduledDate: dueDate,
      );
    }
  }

  Future<void> updateSubtasks(String id, List<Map<String, dynamic>> subtasks) async {
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .update({
      'subtasks': subtasks,
    });
  }

  // --- SHARED TASKS ---
  
  Future<void> createSharedTask(String title, {DateTime? dueDate}) async {
    if (userId == null) return;
    
    final Map<String, dynamic> data = {
      'title': title,
      'ownerId': userId,
      'members': [userId],
      'permissions': {
        userId!: 'owner',
      },
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }
    
    await _firestore.collection('tasks').add(data);
  }

  Stream<QuerySnapshot> getSharedTasks() {
    if (userId == null) return const Stream.empty();
    print("Fetching shared tasks for user: $userId");
    
    return _firestore
        .collection('tasks')
        .where('members', arrayContains: userId)
        .snapshots();
  }

  Future<void> shareTask(String taskId, String email) async {
    if (userId == null) return;
    
    // Find user by email
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
        
    if (snapshot.docs.isEmpty) {
      print("User with email $email not found");
      throw Exception("User not found");
    }
    
    final targetUserId = snapshot.docs.first.id;
    
    await _firestore.collection('tasks').doc(taskId).update({
      'members': FieldValue.arrayUnion([targetUserId]),
      'permissions.$targetUserId': 'editor',
    });
  }

  Stream<List<QueryDocumentSnapshot>> getAllTasks() {
    if (userId == null) return Stream.value([]);
    print("Combining personal and shared tasks for user: $userId");

    final personalStream = getTasks();
    final sharedStream = getSharedTasks();

    return Rx.combineLatest2(
      personalStream,
      sharedStream,
      (QuerySnapshot personal, QuerySnapshot shared) {
        final List<QueryDocumentSnapshot> allDocs = [];
        allDocs.addAll(personal.docs);
        allDocs.addAll(shared.docs);
        
        // Sort combined list by createdAt descending
        allDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
          final dataB = b.data() as Map<String, dynamic>?;
          
          final tA = dataA?['createdAt'] as Timestamp?;
          final tB = dataB?['createdAt'] as Timestamp?;
          
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          
          return tB.compareTo(tA);
        });
        
        return allDocs;
      },
    );
  }
}
