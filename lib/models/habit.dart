import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String title;
  final String type; // 'daily', 'count', 'time'
  final int target; // For 'count' and 'time'
  final int progress;
  final bool isCompleted;
  final int streakCount;
  final DateTime? lastCompletedDate;
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.title,
    required this.type,
    this.target = 1, // Default to 1 for 'daily'
    this.progress = 0,
    this.isCompleted = false,
    this.streakCount = 0,
    this.lastCompletedDate,
    required this.createdAt,
  });

  factory Habit.fromMap(String id, Map<String, dynamic> data) {
    return Habit(
      id: id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'daily',
      target: data['target'] ?? 1,
      progress: data['progress'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      streakCount: data['streakCount'] ?? 0,
      lastCompletedDate: (data['lastCompletedDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'target': target,
      'progress': progress,
      'isCompleted': isCompleted,
      'streakCount': streakCount,
      if (lastCompletedDate != null) 'lastCompletedDate': Timestamp.fromDate(lastCompletedDate!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
