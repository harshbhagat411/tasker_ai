import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/productivity_daily_data.dart';

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
  String classifyDay(double score) {
    if (score == 0) return 'empty';
    if (score >= 90) return 'excellent';
    if (score >= 70) return 'good';
    if (score >= 40) return 'average';
    return 'poor';
  }

  /// Generates and saves the productivity snapshot for today.
  Future<void> generateAndSaveTodaySnapshot() async {
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // 1. Fetch Tasks
    int tasksTotal = 0;
    int tasksCompleted = 0;
    final tasksSnapshot = await _firestore.collection('users').doc(userId).collection('tasks').get();
    for (var doc in tasksSnapshot.docs) {
      tasksTotal++;
      if (doc.data()['isDone'] == true) {
        tasksCompleted++;
      }
    }

    // 2. Fetch Habits
    int habitsTotal = 0;
    int habitsCompleted = 0;
    final habitsSnapshot = await _firestore.collection('users').doc(userId).collection('habits').get();
    for (var doc in habitsSnapshot.docs) {
      habitsTotal++;
      if (doc.data()['isCompleted'] == true) {
        habitsCompleted++;
      }
    }

    // 3. Fetch Goals
    int goalsTotal = 0;
    int goalsCompleted = 0;
    final goalsSnapshot = await _firestore.collection('users').doc(userId).collection('goals').get();
    for (var doc in goalsSnapshot.docs) {
      goalsTotal++;
      if (doc.data()['isCompleted'] == true) {
        goalsCompleted++;
      }
    }

    // 4. Fetch Focus Sessions for Today
    int focusMinutes = 0;
    int focusSessions = 0;
    final focusSnapshot = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('completedAt', isLessThan: Timestamp.fromDate(today.add(const Duration(days: 1))))
        .get();

    for (var doc in focusSnapshot.docs) {
      focusSessions++;
      int durationSeconds = doc.data()['actualDuration'] ?? 0;
      focusMinutes += (durationSeconds ~/ 60);
    }

    // Calculate Score
    double score = calculateDailyScore(
      tasksCompleted: tasksCompleted,
      tasksTotal: tasksTotal,
      habitsCompleted: habitsCompleted,
      habitsTotal: habitsTotal,
      goalsCompleted: goalsCompleted,
      goalsTotal: goalsTotal,
      focusMinutes: focusMinutes,
    );

    String dayType = classifyDay(score);

    // Calculate overall success rate dynamically based on historical data
    double successRate = await getSuccessRate();

    ProductivityDailyData data = ProductivityDailyData(
      date: today,
      tasksCompleted: tasksCompleted,
      tasksTotal: tasksTotal,
      habitsCompleted: habitsCompleted,
      habitsTotal: habitsTotal,
      goalsCompleted: goalsCompleted,
      goalsTotal: goalsTotal,
      focusMinutes: focusMinutes,
      focusSessions: focusSessions,
      productivityScore: score,
      successRate: successRate,
      dayType: dayType,
      streakGroup: await detectStreaks(dayType, todayStr),
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .doc(todayStr)
        .set(data.toMap(), SetOptions(merge: true));
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
}
