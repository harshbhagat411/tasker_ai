import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workspace_model.dart';
import 'activity_service.dart';

class WorkspaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ActivityService _activityService = ActivityService();

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
  Future<void> addMember(String workspaceId, String memberId, {String role = 'editor'}) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayUnion([memberId]),
      'memberRoles.$memberId': role,
    });
  }

  // Remove member
  Future<void> removeMember(String workspaceId, String memberId) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayRemove([memberId]),
      'memberRoles.$memberId': FieldValue.delete(),
    });
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

      final inviteId = _firestore.collection('project_invites').doc().id;

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

      await _activityService.logProjectActivity(
        projectId: projectId,
        type: ActivityType.memberJoined,
        message: 'joined the project.',
      );

    } catch (e) {
      print("ACCEPT PROJECT INVITE ERROR: $e");
      rethrow;
    }
  }

  // Reject Project Invite
  Future<void> rejectProjectInvite(String inviteId) async {
    try {
      await _firestore.collection('project_invites').doc(inviteId).update({
        'status': 'rejected'
      });
    } catch (e) {
      print("REJECT PROJECT INVITE ERROR: $e");
      rethrow;
    }
  }
}
