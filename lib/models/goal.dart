import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String title;
  final String type; // 'daily' or 'weekly'
  final int target;
  final int progress;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? date;
  final DateTime? weekStartDate;
  final DateTime? weekEndDate;

  Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.target,
    this.progress = 0,
    this.isCompleted = false,
    required this.createdAt,
    this.date,
    this.weekStartDate,
    this.weekEndDate,
  });

  factory Goal.fromMap(String id, Map<String, dynamic> data) {
    return Goal(
      id: id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'daily',
      target: data['target'] ?? 1,
      progress: data['progress'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      date: (data['date'] as Timestamp?)?.toDate(),
      weekStartDate: (data['weekStartDate'] as Timestamp?)?.toDate(),
      weekEndDate: (data['weekEndDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'target': target,
      'progress': progress,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      if (date != null) 'date': Timestamp.fromDate(date!),
      if (weekStartDate != null) 'weekStartDate': Timestamp.fromDate(weekStartDate!),
      if (weekEndDate != null) 'weekEndDate': Timestamp.fromDate(weekEndDate!),
    };
  }
}
