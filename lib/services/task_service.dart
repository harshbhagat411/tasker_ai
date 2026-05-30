import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'in_app_notification_service.dart';
import '../models/notification_model.dart';
import 'package:rxdart/rxdart.dart';
import 'activity_service.dart';
import 'productivity_tracking_service.dart';
import 'workspace_service.dart';
import 'sprint_service.dart';


class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InAppNotificationService _inAppNotificationService = InAppNotificationService();

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
    docRef.set(data).then((_) async {
      print("TASK TOGGLED");
      print("Task completion changed");
      print("Calling productivity update");
      await ProductivityTrackingService.updateDailyProductivity(userId!);
    }).catchError((e) {
      print("Error saving task: $e");
      return null;
    });
    print("Task created with ID: ${docRef.id}");

    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: docRef.id.hashCode,
        title: 'Task Reminder',
        body: 'Your task "$title" is due!',
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

  Future<void> deleteTask(String id, {String? projectId}) async {
    if (userId == null) return;

    if (projectId != null) {
      if (!await _canModifyProjectTask(projectId, id)) {
        throw Exception('Unauthorized: Only assigned members or project admins can modify this task.');
      }
      
      // Get sprintId before deleting to recalculate progress
      final taskDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .get();
      final sprintId = taskDoc.data()?['sprintId'] as String?;

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .delete();

      if (sprintId != null) {
        // Recalculate sprint metrics
        SprintService().calculateSprintProgress(projectId, sprintId);
      }
    } else {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .delete();
          
      await NotificationService().cancelNotification(id.hashCode);
    }

    // Recalculate productivity snapshot
    print("TASK TOGGLED");
    print("Task completion changed");
    print("Calling productivity update");
    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }
  Future<void> toggleTask(String id, bool isDone, {String? projectId}) async {
    if (userId == null) return;

    if (projectId != null) {
      if (!await _canModifyProjectTask(projectId, id)) {
        throw Exception('Unauthorized: Only assigned members or project admins can modify this task.');
      }
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .update({
        'isDone': isDone,
      });

      // Recalculate sprint progress if task is linked to a sprint
      final taskDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .get();
      if (taskDoc.exists) {
        final sprintId = taskDoc.data()?['sprintId'] as String?;
        if (sprintId != null) {
          SprintService().calculateSprintProgress(projectId, sprintId);
        }
      }
      
      if (isDone) {
        if (taskDoc.exists) {
           final title = taskDoc.data()!['title'] ?? 'Task';
           final projectDoc = await _firestore.collection('workspaces').doc(projectId).get();
           if (projectDoc.exists) {
              final ownerId = projectDoc.data()!['ownerId'];
              if (ownerId != userId) {
                 await _inAppNotificationService.createNotification(
                    receiverId: ownerId,
                    type: NotificationType.task_completed,
                    title: "Task Completed",
                    message: "${_auth.currentUser?.displayName ?? 'Someone'} completed '$title'",
                    taskId: id,
                    projectId: projectId,
                 );
              }
           }
        }
      }
    } else {
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

    // Recalculate productivity snapshot
    print("TASK TOGGLED");
    print("Task completion changed");
    print("Calling productivity update");
    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }

  Future<void> togglePinTask(String id, bool isPinned, {String? projectId}) async {
    if (userId == null) return;

    if (projectId != null) {
      if (!await _canModifyProjectTask(projectId, id)) {
        throw Exception('Unauthorized: Only assigned members or project admins can modify this task.');
      }
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .update({
        'isPinned': isPinned,
      });
    } else {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .update({
        'isPinned': isPinned,
      });
    }
  }

  Future<void> updateTask(String id, String newTitle, {String priority = 'low', DateTime? dueDate, List<Map<String, dynamic>>? subtasks, String? projectId, Map<String, dynamic>? assignedTo}) async {
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
      if (projectId == null) {
        data['notifiedLocally'] = false; // Reset notification flag when due date changes
      }
    }
    if (dueDate == null) {
      data['dueDate'] = FieldValue.delete();
    }
    
    if (assignedTo != null) {
      data['assignedTo'] = assignedTo;
    }

    if (projectId != null) {
      if (!await _canModifyProjectTask(projectId, id)) {
        throw Exception('Unauthorized: Only assigned members or project admins can modify this task.');
      }
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .update(data).then((_) async {
        print("TASK TOGGLED");
        print("Task completion changed");
        print("Calling productivity update");
        await ProductivityTrackingService.updateDailyProductivity(userId!);
      }).catchError((e) {
        print("Error updating task: $e");
        return null;
      });
    } else {
      // We don't await this so the UI doesn't hang if the user is offline
      _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .update(data).then((_) async {
        print("TASK TOGGLED");
        print("Task completion changed");
        print("Calling productivity update");
        await ProductivityTrackingService.updateDailyProductivity(userId!);
      }).catchError((e) {
        print("Error updating task: $e");
        return null;
      });

      syncSharedTask(originalTaskId: id, updatedData: data);

      await NotificationService().cancelNotification(id.hashCode);
      if (dueDate != null && dueDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: id.hashCode,
          title: 'Task Reminder',
          body: 'Your task "$newTitle" is due!',
          scheduledDate: dueDate,
        );
      }
    }
  }

  Future<void> updateSubtasks(String id, List<Map<String, dynamic>> subtasks, {String? projectId}) async {
    if (userId == null) return;

    if (projectId != null) {
      if (!await _canModifyProjectTask(projectId, id)) {
        throw Exception('Unauthorized: Only assigned members or project admins can modify this task.');
      }
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(id)
          .update({
        'subtasks': subtasks,
      });
    } else {
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
  }

  // --- SHARED TASKS ---
  
  Future<void> createSharedTask(String title, {DateTime? dueDate, String? workspaceId, String? assignedTo}) async {
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
    
    if (workspaceId != null) {
      data['workspaceId'] = workspaceId;
    }
    
    if (assignedTo != null) {
      data['assignedTo'] = assignedTo;
      if (assignedTo != userId) {
        data['members'].add(assignedTo);
      }
    }
    
    await _firestore.collection('tasks').add(data);
  }

  Stream<QuerySnapshot> getSharedTasks() {
    if (userId == null) return const Stream.empty();
    
    return _firestore
        .collection('tasks')
        .where('members', arrayContains: userId)
        // Optionally, we could filter out workspace tasks from normal shared tasks if desired
        .snapshots();
  }

  // --- PROJECT TASKS ---
  
  Future<void> createProjectTask({
    required String projectId,
    required String title,
    String priority = 'low',
    DateTime? dueDate,
    List<Map<String, dynamic>>? subtasks,
    Map<String, dynamic>? assignedTo,
    String? sprintId, // nullable
  }) async {
    if (userId == null) return;

    final Map<String, dynamic> data = {
      'title': title,
      'isDone': false,
      'isPinned': false,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
      'ownerId': userId,
      'projectId': projectId,
      'sprintId': sprintId, // nullable
    };

    if (subtasks != null && subtasks.isNotEmpty) {
      data['subtasks'] = subtasks;
    }

    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }

    if (assignedTo != null) {
      data['assignedTo'] = assignedTo;
    }

    final docRef = await _firestore.collection('projects').doc(projectId).collection('tasks').add(data);
    
    // Trigger notification!
    if (assignedTo != null) {
      final String? assigneeId = assignedTo['uid'];
      if (assigneeId != null) {
        await _sendTaskAssignmentNotification(
          assigneeId: assigneeId,
          taskTitle: title,
          taskId: docRef.id,
          workspaceId: projectId,
        );
      }
    }
  }

  Future<void> reassignProjectTask({
    required String projectId,
    required String taskId,
    required Map<String, dynamic> newAssigneeDetails,
    required String taskTitle,
  }) async {
    final currentUserId = userId;
    if (currentUserId == null) return;

    // 1. Check Permissions
    final workspaceDoc = await _firestore.collection('workspaces').doc(projectId).get();
    if (!workspaceDoc.exists) throw Exception('Workspace not found');
    final workspaceData = workspaceDoc.data()!;
    final String ownerId = workspaceData['ownerId']?.toString() ?? '';
    final memberRoles = workspaceData['memberRoles'] as Map<String, dynamic>?;

    bool hasPermission = (ownerId == currentUserId);
    if (memberRoles != null && (memberRoles[currentUserId] == 'owner' || memberRoles[currentUserId] == 'admin')) {
      hasPermission = true;
    }

    if (!hasPermission) {
      throw Exception('You don\'t have permission to reassign tasks.');
    }

    // 2. Fetch previous assignee
    final taskDocRef = _firestore.collection('projects').doc(projectId).collection('tasks').doc(taskId);
    final taskDoc = await taskDocRef.get();
    if (!taskDoc.exists) throw Exception('Task not found');
    
    final taskData = taskDoc.data()!;
    String? previousAssigneeId;
    if (taskData['assignedTo'] != null) {
      if (taskData['assignedTo'] is Map) {
        previousAssigneeId = taskData['assignedTo']['uid'];
      } else if (taskData['assignedTo'] is String) {
        previousAssigneeId = taskData['assignedTo'];
      }
    }

    final newAssigneeId = newAssigneeDetails['uid'];
    if (newAssigneeId == previousAssigneeId) return; // No change

    // 3. Update Task
    await taskDocRef.update({
      'assignedTo': newAssigneeDetails,
    });

    // 4. Log Activity
    final newAssigneeName = newAssigneeDetails['name'] ?? 'User';
    await ActivityService().logProjectActivity(
      projectId: projectId,
      type: ActivityType.taskAssigned,
      taskTitle: taskTitle,
      message: "reassigned to $newAssigneeName",
    );

    // 5. Send Notifications
    final projectName = workspaceData['name'] ?? 'Project';
    
    // Notify new assignee
    if (newAssigneeId != null && newAssigneeId != currentUserId) {
      await _sendTaskAssignmentNotification(
        assigneeId: newAssigneeId,
        taskTitle: taskTitle,
        taskId: taskId,
        workspaceId: projectId,
      );
    }

    // Notify previous assignee
    if (previousAssigneeId != null && previousAssigneeId != currentUserId && previousAssigneeId != newAssigneeId) {
      await _inAppNotificationService.createNotification(
        receiverId: previousAssigneeId,
        type: NotificationType.task_assigned,
        title: "Task Assignment Updated",
        message: "You are no longer assigned to '$taskTitle' in '$projectName'.",
        projectId: projectId,
        taskId: taskId,
      );
    }
  }

  Future<void> _sendTaskAssignmentNotification({
    required String assigneeId,
    required String taskTitle,
    required String taskId,
    required String workspaceId,
  }) async {
    final currentUserId = userId;
    if (currentUserId == null) return;
    if (assigneeId == currentUserId) return; // Don't notify self

    // Fetch workspace details to get project/workspace name
    final workspaceDoc = await _firestore.collection('workspaces').doc(workspaceId).get();
    final String projectName = workspaceDoc.exists ? (workspaceDoc.data()?['name'] ?? 'Project') : 'Project';

    // Fetch current user details to get display name
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final String senderName = currentUserDoc.data()?['displayName'] ?? currentUserDoc.data()?['name'] ?? _auth.currentUser?.displayName ?? 'Someone';

    final String title = "New Task Assigned";
    final String message = "$senderName assigned you: $taskTitle";

    // 1. Write to users/{userId}/notifications
    await _firestore
        .collection('users')
        .doc(assigneeId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': 'task_assigned',
      'workspaceId': workspaceId,
      'taskId': taskId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 2. Also write standard root in-app notification for Updates tab and push notifications sync!
    await _inAppNotificationService.createNotification(
      receiverId: assigneeId,
      type: NotificationType.task_assigned,
      title: title,
      message: "You were assigned a task in '$projectName': '$taskTitle'",
      projectId: workspaceId,
      taskId: taskId,
    );
  }

  Stream<QuerySnapshot> getWorkspaceTasks(String workspaceId) {
    return _firestore
        .collection('projects')
        .doc(workspaceId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAssignedWorkspaceTasks() {
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection('tasks')
        .where('assignedTo', isEqualTo: userId)
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

      // In-App Notification
      await _inAppNotificationService.createNotification(
        receiverId: newUserId,
        type: NotificationType.task_shared,
        title: "Task Shared",
        message: "$ownerName shared a task with you: '$taskTitle'",
        taskId: taskId,
      );

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

      // In-App Notification to Inviter
      await _inAppNotificationService.createNotification(
        receiverId: fromUserId,
        type: NotificationType.invite_accepted,
        title: "Task Invite Accepted",
        message: "${_auth.currentUser?.displayName ?? 'Someone'} accepted your shared task invite for '${inviteData['taskTitle'] ?? 'Task'}'.",
        taskId: taskId,
      );

      print("Invite accepted and task copied successfully");
    } catch (e) {
      print("ACCEPT INVITE ERROR: $e");
      rethrow;
    }
  }

  Future<void> rejectInvite(String inviteId) async {
    try {
      final inviteDoc = await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;
      final inviteData = inviteDoc.data()!;

      await FirebaseFirestore.instance.collection('task_invites').doc(inviteId).update({
        'status': 'rejected'
      });

      final fromUserId = inviteData['fromUserId'];
      await _inAppNotificationService.createNotification(
        receiverId: fromUserId,
        type: NotificationType.invite_rejected,
        title: "Task Invite Declined",
        message: "${_auth.currentUser?.displayName ?? 'Someone'} declined your shared task invite for '${inviteData['taskTitle'] ?? 'Task'}'.",
        taskId: inviteData['taskId'],
      );
    } catch (e) {
      print("REJECT INVITE ERROR: $e");
    }
  }


  Stream<List<QueryDocumentSnapshot>> getAssignedWorkspaceTasksStream() {
    if (userId == null) return Stream.value([]);
    
    return WorkspaceService().getUserWorkspaces().switchMap((workspaces) {
      if (workspaces.isEmpty) return Stream.value(<QueryDocumentSnapshot>[]);
      
      final streams = workspaces.map((ws) {
        return _firestore
            .collection('projects')
            .doc(ws.id)
            .collection('tasks')
            .snapshots();
      }).toList();
      
      return Rx.combineLatest<QuerySnapshot, List<QueryDocumentSnapshot>>(
        streams,
        (List<QuerySnapshot> snapshots) {
          final List<QueryDocumentSnapshot> assignedTasks = [];
          for (var snap in snapshots) {
            for (var doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) continue;
              
              String? assignedToId;
              if (data['assignedTo'] is String) {
                assignedToId = data['assignedTo'];
              } else if (data['assignedTo'] is Map) {
                assignedToId = data['assignedTo']['uid'];
              }
              
              if (assignedToId == userId) {
                assignedTasks.add(doc);
              }
            }
          }
          return assignedTasks;
        },
      );
    });
  }

  Stream<List<QueryDocumentSnapshot>> getAllTasks() {
    if (userId == null) return Stream.value([]);
    print("Combining personal, shared, and assigned workspace tasks for user: $userId");

    final personalStream = getTasks();
    final sharedStream = getSharedTasks();
    final assignedWorkspaceStream = getAssignedWorkspaceTasksStream();

    return Rx.combineLatest3(
      personalStream,
      sharedStream,
      assignedWorkspaceStream,
      (QuerySnapshot personal, QuerySnapshot shared, List<QueryDocumentSnapshot> assignedWorkspace) {
        final List<QueryDocumentSnapshot> allDocs = [];
        allDocs.addAll(personal.docs);
        allDocs.addAll(shared.docs);
        allDocs.addAll(assignedWorkspace);
        
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

  Future<bool> _canModifyProjectTask(String projectId, String taskId) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      print("Permission denied: No logged in user");
      return false;
    }

    // Check workspace roles
    final workspaceDoc = await _firestore.collection('workspaces').doc(projectId).get();
    if (!workspaceDoc.exists) {
      print("Permission denied: Workspace not found");
      return false;
    }

    final workspaceData = workspaceDoc.data()!;
    final String workspaceOwnerId = workspaceData['ownerId']?.toString() ?? '';
    final memberRoles = workspaceData['memberRoles'] as Map<String, dynamic>?;

    bool isWorkspaceOwnerOrAdmin = (workspaceOwnerId == currentUserId) ||
        (memberRoles != null && (memberRoles[currentUserId] == 'owner' || memberRoles[currentUserId] == 'admin'));

    if (isWorkspaceOwnerOrAdmin) {
      print("Task completion allowed: User is Workspace Owner or Admin");
      return true;
    }

    // Check task details
    final taskDoc = await _firestore.collection('projects').doc(projectId).collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      print("Permission denied: Task not found");
      return false;
    }
    
    final taskData = taskDoc.data()!;
    String? assignedToId;
    if (taskData['assignedTo'] is String) {
      assignedToId = taskData['assignedTo'];
    } else if (taskData['assignedTo'] is Map) {
      assignedToId = taskData['assignedTo']['uid'];
    }

    final taskCreatorId = taskData['ownerId']?.toString() ?? taskData['createdBy']?.toString() ?? '';

    if (assignedToId == currentUserId) {
      print("Task completion allowed: User is Assigned Member");
      return true;
    }

    if (taskCreatorId == currentUserId) {
      print("Task completion allowed: User is Task Creator");
      return true;
    }

    print("Permission denied: User does not have completion permission");
    return false;
  }

  // Link task to a sprint
  Future<void> linkTaskToSprint({
    required String projectId,
    required String taskId,
    required String? sprintId,
  }) async {
    if (userId == null) return;

    // 1. Get task details to find old sprintId
    final taskDoc = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .get();
    if (!taskDoc.exists) throw Exception("Task not found");
    final oldSprintId = taskDoc.data()?['sprintId'] as String?;

    // 2. Update task
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update({'sprintId': sprintId});

    // 3. Recalculate progress for new sprint
    if (sprintId != null) {
      await SprintService().calculateSprintProgress(projectId, sprintId);
    }
    // 4. Recalculate progress for old sprint
    if (oldSprintId != null && oldSprintId != sprintId) {
      await SprintService().calculateSprintProgress(projectId, oldSprintId);
    }
  }
}
