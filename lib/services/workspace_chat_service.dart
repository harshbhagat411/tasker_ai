import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workspace_chat_message.dart';

class WorkspaceChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to fetch the current user's profile details.
  Future<Map<String, String?>> _getCurrentSenderInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return {};

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return {
          'uid': currentUser.uid,
          'name': data?['displayName'] ?? data?['name'] ?? currentUser.displayName ?? 'User',
          'photo': data?['avatar'] ?? data?['photoURL'] ?? data?['profileImage'] ?? currentUser.photoURL,
        };
      }
    } catch (e) {
      debugPrint("Error fetching sender details: $e");
    }

    return {
      'uid': currentUser.uid,
      'name': currentUser.displayName ?? 'User',
      'photo': currentUser.photoURL,
    };
  }

  // 1. sendMessage() - Send normal text message
  Future<String?> sendMessage({
    required String projectId,
    required String message,
  }) async {
    try {
      final senderInfo = await _getCurrentSenderInfo();
      final senderId = senderInfo['uid'];
      if (senderId == null) return null;

      final messageId = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc()
          .id;

      final docData = {
        'messageId': messageId,
        'projectId': projectId,
        'senderId': senderId,
        'senderName': senderInfo['name'] ?? 'User',
        'senderPhoto': senderInfo['photo'],
        'message': message,
        'type': ChatMessageType.text.name,
        'taskId': null,
        'taskTitle': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
        'editedAt': null,
      };

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId)
          .set(docData);

      return messageId;
    } catch (e) {
      debugPrint("Error sending message: $e");
      return null;
    }
  }

  // 2. getMessages() - Realtime stream listener
  Stream<List<WorkspaceChatMessage>> getMessages(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('workspace_chat')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => WorkspaceChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  // 3. sendTaskMention() - Future-ready task mention method
  Future<String?> sendTaskMention({
    required String projectId,
    required String taskId,
    required String taskTitle,
    String? customMessage,
  }) async {
    try {
      final senderInfo = await _getCurrentSenderInfo();
      final senderId = senderInfo['uid'];
      if (senderId == null) return null;

      final messageId = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc()
          .id;

      final docData = {
        'messageId': messageId,
        'projectId': projectId,
        'senderId': senderId,
        'senderName': senderInfo['name'] ?? 'User',
        'senderPhoto': senderInfo['photo'],
        'message': customMessage ?? "Mentioned task: $taskTitle",
        'type': ChatMessageType.task_mention.name,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
        'editedAt': null,
      };

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId)
          .set(docData);

      return messageId;
    } catch (e) {
      debugPrint("Error sending task mention message: $e");
      return null;
    }
  }

  // 4. sendSystemMessage() - Future-ready system message method
  Future<String?> sendSystemMessage({
    required String projectId,
    required String message,
  }) async {
    try {
      final messageId = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc()
          .id;

      final docData = {
        'messageId': messageId,
        'projectId': projectId,
        'senderId': 'system',
        'senderName': 'System',
        'senderPhoto': null,
        'message': message,
        'type': ChatMessageType.system.name,
        'taskId': null,
        'taskTitle': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
        'editedAt': null,
      };

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId)
          .set(docData);

      return messageId;
    } catch (e) {
      debugPrint("Error sending system message: $e");
      return null;
    }
  }

  // 5. deleteMessage() - Delete own text/task_mention messages, prevent system deletes
  Future<bool> deleteMessage({
    required String projectId,
    required String messageId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final docRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId);

      final doc = await docRef.get();
      if (!doc.exists) return false;

      final typeStr = doc.data()?['type'];
      final senderId = doc.data()?['senderId'];

      if (typeStr == ChatMessageType.system.name) {
        throw Exception("System messages cannot be deleted.");
      }

      if (senderId != currentUser.uid) {
        throw Exception("You can only delete your own messages.");
      }

      await docRef.delete();
      return true;
    } catch (e) {
      debugPrint("Error deleting message: $e");
      rethrow;
    }
  }

  // Future-ready editMessage() - Edit own text/task_mention messages
  Future<bool> editMessage({
    required String projectId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final docRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId);

      final doc = await docRef.get();
      if (!doc.exists) return false;

      final typeStr = doc.data()?['type'];
      final senderId = doc.data()?['senderId'];

      if (typeStr == ChatMessageType.system.name) {
        throw Exception("System messages cannot be edited.");
      }

      if (senderId != currentUser.uid) {
        throw Exception("You can only edit your own messages.");
      }

      await docRef.update({
        'message': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("Error editing message: $e");
      rethrow;
    }
  }
}
