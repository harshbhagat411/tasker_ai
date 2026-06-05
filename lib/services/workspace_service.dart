import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workspace_model.dart';
import 'activity_service.dart';
import 'in_app_notification_service.dart';
import '../models/notification_model.dart';
import 'workspace_chat_service.dart';

class WorkspaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ActivityService _activityService = ActivityService();
  final InAppNotificationService _inAppNotificationService = InAppNotificationService();

  // Create Workspace
  Future<String?> createWorkspace({
    required String name,
    required String description,
    required String color,
    required int icon,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final docRef = await _firestore.collection('workspaces').add({
        'name': name,
        'description': description,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? 'Developer',
        'members': [user.uid],
        'memberRoles': { user.uid: 'owner' },
        'createdAt': FieldValue.serverTimestamp(),
        'color': color,
        'icon': icon,
        'type': 'developer',
      });
      return docRef.id;
    } catch (e) {
      print('Error creating workspace: $e');
      return null;
    }
  }

  // Get user's workspaces
  Stream<List<Workspace>> getUserWorkspaces() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('workspaces')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final workspaces = snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList();
          workspaces.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return workspaces;
        });
  }

  // Get single workspace
  Stream<Workspace?> getWorkspace(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .snapshots()
        .map((doc) => doc.exists ? Workspace.fromFirestore(doc) : null);
  }

  // Add member to workspace
  Future<void> addMember(String workspaceId, String memberId, {String role = 'member'}) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayUnion([memberId]),
      'memberRoles.$memberId': role,
    });
  }

  // Update member role
  Future<void> updateMemberRole(String workspaceId, String memberId, String role) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'memberRoles.$memberId': role,
    });

    try {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User';
      final currentUser = _auth.currentUser;
      final ownerName = currentUser?.displayName ?? 'Owner';

      if (role == 'admin') {
        WorkspaceChatService().sendSystemMessage(
          projectId: workspaceId,
          message: '👑 $ownerName promoted $userName to Admin',
        ).catchError((e) {
          debugPrint("Warning: Failed to send promotion system message: $e");
          return null;
        });
      } else if (role == 'member') {
        WorkspaceChatService().sendSystemMessage(
          projectId: workspaceId,
          message: '⬇️ $userName changed to Member',
        ).catchError((e) {
          debugPrint("Warning: Failed to send demotion system message: $e");
          return null;
        });
      }
    } catch (_) {}
  }

  // Remove member
  Future<void> removeMember(String workspaceId, String memberId) async {
    String userName = 'User';
    try {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      userName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User';
    } catch (_) {}

    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayRemove([memberId]),
      'memberRoles.$memberId': FieldValue.delete(),
    });

    try {
      WorkspaceChatService().sendSystemMessage(
        projectId: workspaceId,
        message: '🚪 $userName removed from project',
      ).catchError((e) {
        debugPrint("Warning: Failed to send member removal system message: $e");
        return null;
      });
    } catch (_) {}
  }

  // Delete Workspace
  Future<void> deleteWorkspace(String workspaceId) async {
    try {
      // Delete tasks inside the project
      final tasksSnapshot = await _firestore.collection('projects').doc(workspaceId).collection('tasks').get();
      for (var doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete activity inside the project
      final activitySnapshot = await _firestore.collection('projects').doc(workspaceId).collection('activity').get();
      for (var doc in activitySnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete invites related to this project
      final invitesSnapshot = await _firestore.collection('project_invites').where('projectId', isEqualTo: workspaceId).get();
      for (var doc in invitesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the workspace document
      await _firestore.collection('workspaces').doc(workspaceId).delete();
    } catch (e) {
      print('Error deleting workspace: $e');
    }
  }

  // Send Project Invite
  Future<void> sendProjectInvite(String workspaceId, String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (user.email == email.trim().toLowerCase()) {
        throw Exception("You cannot invite yourself.");
      }

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .get();

      if (query.docs.isEmpty) {
        throw Exception("User not found");
      }

      final newUserId = query.docs.first.id;
      final newUserName = query.docs.first.data()['displayName'] ?? query.docs.first.data()['name'] ?? 'User';

      final workspaceDoc = await _firestore.collection('workspaces').doc(workspaceId).get();
      if (!workspaceDoc.exists) {
        throw Exception("Workspace not found.");
      }

      final data = workspaceDoc.data()!;
      final List<dynamic> members = data['members'] ?? [];
      
      if (members.contains(newUserId)) {
        throw Exception("User is already a member of this workspace.");
      }

      // Check for duplicate pending invites
      final pendingInvites = await _firestore.collection('project_invites')
          .where('projectId', isEqualTo: workspaceId)
          .where('receiverId', isEqualTo: newUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingInvites.docs.isNotEmpty) {
        throw Exception("An invite is already pending for this user.");
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'Someone';

      final inviteId = "${workspaceId}_$newUserId";

      await _firestore.collection('project_invites').doc(inviteId).set({
        'inviteId': inviteId,
        'projectId': workspaceId,
        'projectName': data['name'],
        'senderId': user.uid,
        'senderName': senderName,
        'receiverId': newUserId,
        'receiverName': newUserName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _activityService.logProjectActivity(
        projectId: workspaceId,
        type: ActivityType.memberInvited,
        message: 'invited $newUserName to the project.',
      );

      // Send In-App Notification
      await _inAppNotificationService.createNotification(
        receiverId: newUserId,
        type: NotificationType.workspace_invite,
        title: "Project Invite",
        message: "You were invited to project '${data['name']}'",
        projectId: workspaceId,
      );

    } catch (e) {
      print("SEND PROJECT INVITE ERROR: $e");
      rethrow;
    }
  }

  // Get Pending Project Invites
  Stream<QuerySnapshot> getPendingProjectInvites() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('project_invites')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        // .orderBy('timestamp', descending: true) // Removed to prevent composite index requirement
        .snapshots();
  }

  // Accept Project Invite
  Future<void> acceptProjectInvite(String inviteId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final inviteDoc = await _firestore.collection('project_invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;

      final inviteData = inviteDoc.data()!;
      final String projectId = inviteData['projectId'];

      await addMember(projectId, user.uid);

      await _firestore.collection('project_invites').doc(inviteId).update({
        'status': 'accepted'
      });

      // Run secondary logging and notification triggers in background
      () async {
        try {
          await _activityService.logProjectActivity(
            projectId: projectId,
            type: ActivityType.memberJoined,
            message: 'joined the project.',
          ).catchError((e) {
            debugPrint("Warning: Failed to log project activity for member join: $e");
          });

          final userName = user.displayName ?? 'Someone';
          await WorkspaceChatService().sendSystemMessage(
            projectId: projectId,
            message: '🟢 $userName joined the project',
          ).catchError((e) {
            debugPrint("Warning: Failed to send member joined system message: $e");
            return null;
          });

          // Send In-App Notification to Inviter
          final String senderId = inviteData['senderId'];
          await _inAppNotificationService.createNotification(
            receiverId: senderId,
            type: NotificationType.workspace_invite_accepted,
            title: "Invite Accepted",
            message: "${user.displayName ?? 'Someone'} joined your project.",
            projectId: projectId,
          ).catchError((e) {
            debugPrint("Warning: Failed to send join in-app notification: $e");
            return null;
          });
        } catch (e) {
          debugPrint("Warning: Error in member joined background actions: $e");
        }
      }();

    } catch (e) {
      print("ACCEPT PROJECT INVITE ERROR: $e");
      rethrow;
    }
  }

  // Reject Project Invite
  Future<void> rejectProjectInvite(String inviteId) async {
    try {
      final inviteDoc = await _firestore.collection('project_invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;
      final inviteData = inviteDoc.data()!;
      final senderId = inviteData['senderId'];
      final projectName = inviteData['projectName'];

      await _firestore.collection('project_invites').doc(inviteId).update({
        'status': 'rejected'
      });

      final user = _auth.currentUser;
      await _inAppNotificationService.createNotification(
        receiverId: senderId,
        type: NotificationType.workspace_invite_rejected,
        title: "Invite Declined",
        message: "${user?.displayName ?? 'Someone'} declined your invite to '$projectName'.",
        projectId: inviteData['projectId'],
      );

    } catch (e) {
      print("REJECT PROJECT INVITE ERROR: $e");
      rethrow;
    }
  }
}
