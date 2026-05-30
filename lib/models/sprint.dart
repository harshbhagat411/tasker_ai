import 'package:cloud_firestore/cloud_firestore.dart';

class Sprint {
  final String id;
  final String title;
  final String description;
  final String goal;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'planned', 'active', 'completed', 'archived'
  final String createdBy;
  final DateTime createdAt;
  final int totalTasks;
  final int completedTasks;
  final double progressPercentage;

  Sprint({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.progressPercentage = 0.0,
  });

  factory Sprint.fromMap(String id, Map<String, dynamic> data) {
    return Sprint(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      goal: data['goal'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'planned',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalTasks: data['totalTasks'] ?? 0,
      completedTasks: data['completedTasks'] ?? 0,
      progressPercentage: (data['progressPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'goal': goal,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'progressPercentage': progressPercentage,
    };
  }
}
