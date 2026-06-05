import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
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

  // 6. updateLastRead()
  Future<void> updateLastRead(String projectId, String userId) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('chat_last_read')
          .doc(userId)
          .set({
        'lastRead': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating last read: $e");
    }
  }

  // 7. getUnreadCountStream()
  Stream<int> getUnreadCountStream(String projectId, String userId) {
    final lastReadStream = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('chat_last_read')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return doc.data()?['lastRead'] as Timestamp?;
        });

    final messagesStream = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('workspace_chat')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => WorkspaceChatMessage.fromFirestore(d)).toList());

    return Rx.combineLatest2<Timestamp?, List<WorkspaceChatMessage>, int>(
      lastReadStream,
      messagesStream,
      (lastRead, messages) {
        if (lastRead == null) {
          return messages.where((msg) => msg.senderId != userId && msg.type != ChatMessageType.system).length;
        }
        return messages.where((msg) {
          if (msg.senderId == userId) return false;
          if (msg.type == ChatMessageType.system) return false;
          return msg.createdAt.compareTo(lastRead) > 0;
        }).length;
      },
    );
  }

  // 8. setTypingStatus()
  Future<void> setTypingStatus(String projectId, String userId, bool isTyping) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.exists
          ? (userDoc.data()?['displayName'] ?? userDoc.data()?['name'] ?? 'User')
          : 'User';

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('typing')
          .doc(userId)
          .set({
        'userName': userName,
        'isTyping': isTyping,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error setting typing status: $e");
    }
  }

  // 9. getTypingUsersStream()
  Stream<List<Map<String, dynamic>>> getTypingUsersStream(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final currentUserId = _auth.currentUser?.uid;
          final List<Map<String, dynamic>> typing = [];

          for (var doc in snapshot.docs) {
            if (doc.id == currentUserId) continue;

            final data = doc.data();
            final isTyping = data['isTyping'] as bool? ?? false;
            final lastUpdated = data['lastUpdated'] as Timestamp?;

            if (isTyping && lastUpdated != null) {
              final diff = now.difference(lastUpdated.toDate()).inSeconds;
              if (diff < 4) {
                typing.add({
                  'uid': doc.id,
                  'userName': data['userName'] ?? 'User',
                });
              }
            }
          }
          return typing;
        });
  }

  // 10. toggleReaction()
  Future<void> toggleReaction({
    required String projectId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    try {
      final docRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('workspace_chat')
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;

        final data = doc.data() as Map<String, dynamic>;
        final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};

        final Map<String, List<String>> reactions = {};
        reactionsData.forEach((key, value) {
          if (value is List) {
            reactions[key] = List<String>.from(value);
          }
        });

        String? previousReactionEmoji;
        reactions.forEach((e, users) {
          if (users.contains(userId)) {
            previousReactionEmoji = e;
          }
        });

        if (previousReactionEmoji != null) {
          reactions[previousReactionEmoji!]!.remove(userId);
          if (reactions[previousReactionEmoji!]!.isEmpty) {
            reactions.remove(previousReactionEmoji);
          }
        }

        if (previousReactionEmoji != emoji) {
          if (!reactions.containsKey(emoji)) {
            reactions[emoji] = [];
          }
          reactions[emoji]!.add(userId);
        }

        transaction.update(docRef, {
          'reactions': reactions,
        });
      });
    } catch (e) {
      debugPrint("Error toggling reaction: $e");
    }
  }
}
