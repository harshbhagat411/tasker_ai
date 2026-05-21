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
  
  final String dayType; // excellent, good, average, poor, empty
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
    return ProductivityDailyData(
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tasksCompleted: data['tasksCompleted'] ?? 0,
      tasksTotal: data['tasksTotal'] ?? 0,
      habitsCompleted: data['habitsCompleted'] ?? 0,
      habitsTotal: data['habitsTotal'] ?? 0,
      goalsCompleted: data['goalsCompleted'] ?? 0,
      goalsTotal: data['goalsTotal'] ?? 0,
      focusMinutes: data['focusMinutes'] ?? 0,
      focusSessions: data['focusSessions'] ?? 0,
      productivityScore: (data['productivityScore'] ?? 0).toDouble(),
      successRate: (data['successRate'] ?? 0).toDouble(),
      dayType: data['dayType'] ?? 'empty',
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
      'dayType': dayType,
      'streakGroup': streakGroup,
    };
  }
}
