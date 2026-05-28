import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/productivity_daily_data.dart';
import 'productivity_tracking_service.dart';
import 'dart:math';

class ProductivityEngine {
  static final ProductivityEngine _instance = ProductivityEngine._internal();
  factory ProductivityEngine() => _instance;
  ProductivityEngine._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  /// Generates the productivity score for a given set of metrics.
  /// Dynamically distributes weights if a category has no items.
  double calculateDailyScore({
    required int tasksCompleted,
    required int tasksTotal,
    required int habitsCompleted,
    required int habitsTotal,
    required int goalsCompleted,
    required int goalsTotal,
    required int focusMinutes,
    int focusTargetMinutes = 60,
  }) {
    double earned = 0.0;
    double totalWeight = 0.0;

    // Tasks = 35%
    if (tasksTotal > 0) {
      totalWeight += 35;
      earned += (tasksCompleted / tasksTotal) * 35;
    }

    // Habits = 25%
    if (habitsTotal > 0) {
      totalWeight += 25;
      earned += (habitsCompleted / habitsTotal) * 25;
    }

    // Goals = 20%
    if (goalsTotal > 0) {
      totalWeight += 20;
      earned += (goalsCompleted / goalsTotal) * 20;
    }

    // Focus = 20% (Always active, scaled up to focusTargetMinutes)
    totalWeight += 20;
    double focusRatio = (focusMinutes / focusTargetMinutes).clamp(0.0, 1.0);
    earned += focusRatio * 20;

    if (totalWeight == 0) return 0.0;

    // Scale to 100 based on active categories
    return (earned / totalWeight) * 100;
  }

  /// Classifies a day based on the score.
  String classifyDay(double score, {bool hasActivity = true}) {
    if (!hasActivity) return 'empty';
    int rounded = score.round();
    if (rounded >= 81) return 'excellent';
    if (rounded >= 61) return 'productive';
    if (rounded >= 31) return 'average';
    return 'poor';
  }

  /// Automatically creates today's productivity document if it does not exist.
  Future<void> initializeTodayDocument() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('productivity_data')
          .doc(todayStr);

      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        await docRef.set({
          'date': FieldValue.serverTimestamp(),
          'tasksCompleted': 0,
          'tasksTotal': 0,
          'habitsCompleted': 0,
          'habitsTotal': 0,
          'goalsCompleted': 0,
          'goalsTotal': 0,
          'focusMinutes': 0,
          'focusSessions': 0,
          'productivityScore': 0,
          'successRate': 0,
          'dayType': 'empty',
          'streakGroup': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("PRODUCTIVITY LOG CREATED - userId: $uid, date: $todayStr");
      }
    } catch (e) {
      print("Silent Fallback: Error initializing today productivity document: $e");
    }
  }

  /// Generates and saves the productivity snapshot for today.
  Future<void> generateAndSaveTodaySnapshot({String? triggerType}) async {
    if (userId == null) return;

    try {
      if (triggerType == 'TASK') {
        print("Task completed → updating productivity");
      } else if (triggerType == 'HABIT') {
        print("Habit completed → updating productivity");
      } else if (triggerType == 'FOCUS') {
        print("Focus session saved for userId: $userId");
      }

      await ProductivityTrackingService.updateDailyProductivity(userId!);
    } catch (e) {
      // Debug safety: Never crash the application, silent fallback
      print("Silent Fallback: Error creating daily productivity record: $e");
    }
  }

  /// Detects consecutive days of a certain type to group them (e.g. "4 productive days").
  /// Evaluates past days by looking at the DB and computes the streak including today.
  Future<String> detectStreaks(String currentDayType, String todayStr) async {
    if (userId == null) return "0 days";

    // We consider 'excellent' and 'good' as productive.
    // 'poor' is non-productive.
    // 'average' might be neutral or its own group.
    
    bool isProductive(String type) => type == 'excellent' || type == 'good';
    bool isPoor(String type) => type == 'poor';

    // Fetch the last 30 days to calculate the streak
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    List<Map<String, dynamic>> pastDays = snapshot.docs.map((d) {
      var data = d.data();
      data['id'] = d.id; // The YYYY-MM-DD string
      return data;
    }).toList();

    // If today is already saved, remove it from past analysis to avoid double counting, 
    // or we can just prepend today if it's not saved yet.
    pastDays.removeWhere((day) => day['id'] == todayStr);

    int count = 1; // Including today

    if (isProductive(currentDayType)) {
      for (var day in pastDays) {
        String type = day['dayType'] ?? 'empty';
        if (isProductive(type)) {
          count++;
        } else {
          break;
        }
      }
      return "$count productive days";
    } else if (isPoor(currentDayType)) {
      for (var day in pastDays) {
        String type = day['dayType'] ?? 'empty';
        if (isPoor(type)) {
          count++;
        } else {
          break;
        }
      }
      return "$count poor days";
    } else {
      // For average or empty, just say "1 average day" etc.
      for (var day in pastDays) {
        String type = day['dayType'] ?? 'empty';
        if (type == currentDayType) {
          count++;
        } else {
          break;
        }
      }
      return "$count $currentDayType days";
    }
  }

  /// Gets monthly productivity data for a specific month.
  Future<List<ProductivityDailyData>> getMonthlyProductivity(DateTime month) async {
    if (userId == null) return [];

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => ProductivityDailyData.fromMap(doc.data())).toList();
  }

  /// Gets the total focus time recorded in all productivity days.
  Future<int> getTotalFocusTime() async {
    if (userId == null) return 0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .get();
        
    int totalMinutes = 0;
    for (var doc in snapshot.docs) {
      totalMinutes += (doc.data()['focusMinutes'] as num? ?? 0).toInt();
    }
    return totalMinutes;
  }

  /// Gets the average productivity percentage across all tracked days.
  Future<double> getProductivityPercentage() async {
    if (userId == null) return 0.0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .get();
        
    if (snapshot.docs.isEmpty) return 0.0;

    double totalScore = 0.0;
    int trackedDays = 0;
    for (var doc in snapshot.docs) {
      String type = doc.data()['dayType'] ?? 'empty';
      if (type != 'empty') {
        totalScore += (doc.data()['productivityScore'] as num? ?? 0).toDouble();
        trackedDays++;
      }
    }
    
    return trackedDays > 0 ? (totalScore / trackedDays) : 0.0;
  }

  /// Gets the success rate: (excellent + good days) / total tracked days.
  Future<double> getSuccessRate() async {
    if (userId == null) return 0.0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .get();
        
    if (snapshot.docs.isEmpty) return 0.0;

    int successfulDays = 0;
    int trackedDays = 0;
    for (var doc in snapshot.docs) {
      String type = doc.data()['dayType'] ?? 'empty';
      if (type != 'empty') {
        trackedDays++;
        if (type == 'excellent' || type == 'good') {
          successfulDays++;
        }
      }
    }
    
    return trackedDays > 0 ? (successfulDays / trackedDays) * 100 : 0.0;
  }

  /// Seeds realistic mock productivity data for the past 30 days for testing.
  Future<void> seedMockDataForTesting() async {
    if (userId == null) return;
    final now = DateTime.now();
    final random = Random();
    
    // We'll seed the last 30 days
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Let's create realistic streaks!
      // i = 0 represents today, i = 29 is 29 days ago.
      // We will define specific day types based on date offset to form perfect horizontal streaks:
      // May 1-4: excellent/good
      // May 5-6: average
      // May 7-8: poor
      // May 9: empty
      // May 10-14: excellent/good
      // May 15: empty
      // May 16-20: excellent/good
      // May 21-22: poor
      // May 23-28: excellent/good
      
      String dayType;
      double score;
      
      int dayOffset = i % 12;
      if (dayOffset >= 0 && dayOffset <= 3) {
        // Excellent/good streak (4 days)
        dayType = dayOffset % 2 == 0 ? 'excellent' : 'good';
        score = 75.0 + random.nextDouble() * 20.0;
      } else if (dayOffset == 4 || dayOffset == 5) {
        // Average streak (2 days)
        dayType = 'average';
        score = 45.0 + random.nextDouble() * 20.0;
      } else if (dayOffset == 6 || dayOffset == 7) {
        // Poor streak (2 days)
        dayType = 'poor';
        score = 15.0 + random.nextDouble() * 20.0;
      } else if (dayOffset == 8) {
        // Empty day
        dayType = 'empty';
        score = 0.0;
      } else {
        // Excellent/good streak (3 days)
        dayType = dayOffset % 2 == 0 ? 'excellent' : 'good';
        score = 72.0 + random.nextDouble() * 23.0;
      }
      
      if (dayType == 'empty') {
        // Delete or clear so it represents an empty day
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('productivity_data')
            .doc(dateStr)
            .delete();
        continue;
      }
      
      int tasksTotal = 3 + random.nextInt(5);
      int tasksCompleted = (tasksTotal * (score / 100)).round().clamp(0, tasksTotal);
      
      int habitsTotal = 2 + random.nextInt(3);
      int habitsCompleted = (habitsTotal * (score / 100)).round().clamp(0, habitsTotal);
      
      int goalsTotal = 1;
      int goalsCompleted = random.nextDouble() > 0.4 ? 1 : 0;
      
      int focusMinutes = (score * 0.8).round().clamp(10, 90);
      int focusSessions = (focusMinutes / 30).ceil();
      
      ProductivityDailyData data = ProductivityDailyData(
        date: DateTime(date.year, date.month, date.day),
        tasksCompleted: tasksCompleted,
        tasksTotal: tasksTotal,
        habitsCompleted: habitsCompleted,
        habitsTotal: habitsTotal,
        goalsCompleted: goalsCompleted,
        goalsTotal: goalsTotal,
        focusMinutes: focusMinutes,
        focusSessions: focusSessions,
        productivityScore: score,
        successRate: 75.0,
        dayType: dayType,
        streakGroup: dayType == 'excellent' || dayType == 'good' 
            ? "Productive Streak" 
            : (dayType == 'poor' ? "Poor Streak" : "Average Streak"),
      );
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('productivity_data')
          .doc(dateStr)
          .set(data.toMap(), SetOptions(merge: true));
    }
  }
}

