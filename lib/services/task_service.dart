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
    
    syncSharedTask(originalTaskId: id, updatedData: {'isDone': isDone});
    
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
        .update(data).catchError((e) => print("Error updating task: $e"));

    syncSharedTask(originalTaskId: id, updatedData: data);

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

    syncSharedTask(originalTaskId: id, updatedData: {'subtasks': subtasks});
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
    try {
      if (userId == null) return;
      final currentUserId = userId!;
      
      print("Task ID: $taskId");
      print("Current User ID: $currentUserId");
      print("Email entered: $email");

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .get();

      print("Users found: ${query.docs.length}");

      if (query.docs.isEmpty) {
        throw Exception("User not found");
      }

      final newUserId = query.docs.first.id;
      print("New User ID: $newUserId");

      final taskRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception("Task not found.");
      }

      // Initialize members and permissions if they don't exist
      final data = taskDoc.data() ?? {};
      if (!data.containsKey('members') || !data.containsKey('permissions')) {
        await taskRef.set({
          'members': [currentUserId],
          'permissions': {
            currentUserId: 'owner',
          }
        }, SetOptions(merge: true));
      }

      // Fetch current user details to get ownerName
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final String ownerName = currentUserDoc.data()?['displayName'] ?? currentUserDoc.data()?['name'] ?? _auth.currentUser?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'Someone';
      final String taskTitle = data['title'] ?? 'Task';

      final inviteId = FirebaseFirestore.instance.collection('task_invites').doc().id;

      await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).set({
        'inviteId': inviteId,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'fromUserId': currentUserId,
        'fromUserName': ownerName,
        'toUserId': newUserId,
        'toUserEmail': email.trim().toLowerCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("Task invite created successfully");
    } catch (e) {
      print("SHARE ERROR: $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot> getPendingInvites() {
    if (userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('task_invites')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptInvite(String inviteId) async {
    try {
      if (userId == null) return;
      final currentUserId = userId!;

      final inviteDoc = await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;

      final inviteData = inviteDoc.data()!;
      final String taskId = inviteData['taskId'];
      final String fromUserId = inviteData['fromUserId'];
      final String fromUserName = inviteData['fromUserName'];

      final taskRef = FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .collection('tasks')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception("Task not found. It may have been deleted.");
      }

      // Update the owner's task document
      await taskRef.update({
        'members': FieldValue.arrayUnion([currentUserId]),
        'permissions.$currentUserId': 'editor',
        'originalTaskId': taskId,
      });

      // Fetch the updated document to copy it
      final updatedTaskDoc = await taskRef.get();
      final Map<String, dynamic> sharedTaskData = updatedTaskDoc.data() ?? {};

      // Add required sharing metadata
      sharedTaskData['isShared'] = true;
      sharedTaskData['sharedBy'] = fromUserName;
      sharedTaskData['sharedById'] = fromUserId;
      sharedTaskData['originalTaskId'] = taskId;
      if (!sharedTaskData.containsKey('ownerId')) {
        sharedTaskData['ownerId'] = fromUserId;
      }

      // Copy the task to the current user's tasks collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('tasks')
          .doc(taskId)
          .set(sharedTaskData, SetOptions(merge: true));

      // Update invite status
      await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).update({
        'status': 'accepted'
      });

      print("Invite accepted and task copied successfully");
    } catch (e) {
      print("ACCEPT INVITE ERROR: $e");
      rethrow;
    }
  }

  Future<void> rejectInvite(String inviteId) async {
    try {
      await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).update({
        'status': 'rejected'
      });
    } catch (e) {
      print("REJECT INVITE ERROR: $e");
    }
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

  Future<void> syncSharedTask({
    required String originalTaskId,
    required Map<String, dynamic> updatedData,
  }) async {
    if (userId == null) return;
    print("Syncing shared task: $originalTaskId");
    
    // Fetch local task to get members
    final localTask = await _firestore.collection('users').doc(userId).collection('tasks').doc(originalTaskId).get();
    if (!localTask.exists) return;
    
    final data = localTask.data()!;
    final List<dynamic> members = data['members'] ?? [];
    if (members.length <= 1) return; // Not shared

    print("Found ${members.length - 1} shared copies to sync");

    final batch = _firestore.batch();
    for (var memberId in members) {
      if (memberId == userId) continue; // Skip self as it's already updated locally
      
      final docRef = _firestore.collection('users').doc(memberId.toString()).collection('tasks').doc(originalTaskId);
      batch.update(docRef, updatedData);
    }
    
    await batch.commit();
    print("Updated shared copy instances");
  }
}
