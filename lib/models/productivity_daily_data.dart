import 'package:cloud_firestore/cloud_firestore.dart';

class ProductivityDailyData {
  final DateTime date;
  
  final int tasksCompleted;
  final int tasksTotal;
  
  final int habitsCompleted;
  final int habitsTotal;
  
  final int goalsCompleted;
  final int goalsTotal;
  
  final int focusMinutes;
  final int focusSessions;
  
  final double productivityScore; // 0-100
  final double successRate;
  
  final String dayType; // Excellent, Good, Average, Low, empty
  final String streakGroup;

  ProductivityDailyData({
    required this.date,
    this.tasksCompleted = 0,
    this.tasksTotal = 0,
    this.habitsCompleted = 0,
    this.habitsTotal = 0,
    this.goalsCompleted = 0,
    this.goalsTotal = 0,
    this.focusMinutes = 0,
    this.focusSessions = 0,
    this.productivityScore = 0.0,
    this.successRate = 0.0,
    this.dayType = 'empty',
    this.streakGroup = '0 days',
  });

  factory ProductivityDailyData.fromMap(Map<String, dynamic> data) {
    // Parse date safely from Timestamp, DateTime, or yyyy-mm-dd String
    DateTime parsedDate = DateTime.now();
    if (data['date'] != null) {
      if (data['date'] is Timestamp) {
        parsedDate = (data['date'] as Timestamp).toDate();
      } else if (data['date'] is String) {
        parsedDate = DateTime.tryParse(data['date'] as String) ?? DateTime.now();
      } else if (data['date'] is DateTime) {
        parsedDate = data['date'] as DateTime;
      }
    }

    // Support both old and new field names
    int completedTasks = data['completedTasks'] ?? data['tasksCompleted'] ?? 0;
    int totalTasks = data['totalTasks'] ?? data['tasksTotal'] ?? 0;
    
    int completedHabits = data['completedHabits'] ?? data['habitsCompleted'] ?? 0;
    int totalHabits = data['totalHabits'] ?? data['habitsTotal'] ?? 0;
    
    int completedGoals = data['completedGoals'] ?? data['goalsCompleted'] ?? 0;
    int totalGoals = data['totalGoals'] ?? data['goalsTotal'] ?? 0;

    double score = 0.0;
    if (data['productivityScore'] != null) {
      score = (data['productivityScore'] as num).toDouble();
    }

    double success = 0.0;
    if (data['successRate'] != null) {
      success = (data['successRate'] as num).toDouble();
    }

    String status = data['status'] ?? data['dayType'] ?? 'empty';

    return ProductivityDailyData(
      date: parsedDate,
      tasksCompleted: completedTasks,
      tasksTotal: totalTasks,
      habitsCompleted: completedHabits,
      habitsTotal: totalHabits,
      goalsCompleted: completedGoals,
      goalsTotal: totalGoals,
      focusMinutes: data['focusMinutes'] ?? 0,
      focusSessions: data['focusSessions'] ?? 0,
      productivityScore: score,
      successRate: success,
      dayType: status,
      streakGroup: data['streakGroup'] ?? '0 days',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'tasksCompleted': tasksCompleted,
      'tasksTotal': tasksTotal,
      'habitsCompleted': habitsCompleted,
      'habitsTotal': habitsTotal,
      'goalsCompleted': goalsCompleted,
      'goalsTotal': goalsTotal,
      'focusMinutes': focusMinutes,
      'focusSessions': focusSessions,
      'productivityScore': productivityScore,
      'successRate': successRate,
      'dayType': dayType, // excellent, productive, average, poor, empty
      'streakGroup': streakGroup,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
