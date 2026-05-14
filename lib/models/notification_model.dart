import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  task_shared,
  task_completed,
  invite_accepted,
  invite_rejected,
  workspace_invite,
  workspace_invite_accepted,
  workspace_invite_rejected,
  task_assigned,
  unknown
}

class NotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final String senderName;
  final NotificationType type;
  final String title;
  final String message;
  final String? taskId;
  final String? projectId;
  final bool isRead;
  final Timestamp createdAt;

  NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.title,
    required this.message,
    this.taskId,
    this.projectId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'title': title,
      'message': message,
      if (taskId != null) 'taskId': taskId,
      if (projectId != null) 'projectId': projectId,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    NotificationType parsedType = NotificationType.unknown;
    try {
      parsedType = NotificationType.values.firstWhere((e) => e.name == data['type']);
    } catch (_) {}

    return NotificationModel(
      id: doc.id,
      receiverId: data['receiverId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      type: parsedType,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      taskId: data['taskId'],
      projectId: data['projectId'],
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
