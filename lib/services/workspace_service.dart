import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workspace_model.dart';

class WorkspaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  Future<void> addMember(String workspaceId, String memberId) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayUnion([memberId])
    });
  }

  // Remove member
  Future<void> removeMember(String workspaceId, String memberId) async {
    await _firestore.collection('workspaces').doc(workspaceId).update({
      'members': FieldValue.arrayRemove([memberId])
    });
  }
}
