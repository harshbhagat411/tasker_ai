import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType {
  text,
  task_mention,
  system,
}

class WorkspaceChatMessage {
  final String messageId;
  final String projectId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String message;
  final ChatMessageType type;
  final String? taskId;
  final String? taskTitle;
  final Timestamp createdAt;
  final bool isEdited;
  final Timestamp? editedAt;

  WorkspaceChatMessage({
    required this.messageId,
    required this.projectId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.message,
    required this.type,
    this.taskId,
    this.taskTitle,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'projectId': projectId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'message': message,
      'type': type.name,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'createdAt': createdAt,
      'isEdited': isEdited,
      'editedAt': editedAt,
    };
  }

  factory WorkspaceChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    ChatMessageType messageType = ChatMessageType.text;
    try {
      messageType = ChatMessageType.values.firstWhere((e) => e.name == data['type']);
    } catch (_) {}

    return WorkspaceChatMessage(
      messageId: doc.id,
      projectId: data['projectId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhoto: data['senderPhoto'],
      message: data['message'] ?? '',
      type: messageType,
      taskId: data['taskId'],
      taskTitle: data['taskTitle'],
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] as Timestamp?,
    );
  }
}
