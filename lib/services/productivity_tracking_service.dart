import 'package:cloud_firestore/cloud_firestore.dart';
import 'productivity_engine.dart';

class ProductivityTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recalculates and updates the daily productivity document under users/{uid}/productivity_data/{date}
  static Future<void> updateDailyProductivity(String userId) async {
    print("RUNNING updateDailyProductivity");
    print("userId: $userId");

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Helper to check if a Timestamp, DateTime or String matches today's date
      bool isToday(dynamic dateField) {
        if (dateField == null) return false;
        DateTime dt;
        if (dateField is Timestamp) {
          dt = dateField.toDate();
        } else if (dateField is DateTime) {
          dt = dateField;
        } else if (dateField is String) {
          dt = DateTime.tryParse(dateField) ?? DateTime.now();
        } else {
          return false;
        }
        return dt.year == today.year && dt.month == today.month && dt.day == today.day;
      }

      // 1. Fetch Tasks (users/{uid}/tasks)
      int tasksTotal = 0;
      int tasksCompleted = 0;
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();

      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        
        // Filter: Task is for today if dueDate is today, or if no dueDate, createdAt is today
        bool isForToday = false;
        final dueDate = data['dueDate'];
        if (dueDate != null) {
          isForToday = isToday(dueDate);
        } else {
          final createdAt = data['createdAt'];
          if (createdAt != null) {
            isForToday = isToday(createdAt);
          }
        }

        if (isForToday) {
          tasksTotal++;
          if (data['isDone'] == true) {
            tasksCompleted++;
          }
        }
      }

      print("Tasks found: $tasksTotal");
      print("Completed tasks: $tasksCompleted");

      // 2. Fetch Habits (users/{uid}/habits)
      final habitsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .get();
      int habitsTotal = habitsSnapshot.docs.length;

      // Habit completion from: users/{uid}/habit_history for today
      final habitHistorySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('habit_history')
          .get();

      final Set<String> completedHabitIds = {};
      for (var doc in habitHistorySnapshot.docs) {
        final data = doc.data();
        final completedAt = data['completedAt'];
        if (completedAt != null && isToday(completedAt)) {
          final habitId = data['habitId']?.toString();
          if (habitId != null) {
            completedHabitIds.add(habitId);
          }
        }
      }
      int habitsCompleted = completedHabitIds.length;

      print("Habits found: $habitsTotal");
      print("Completed habits: $habitsCompleted");

      // 3. Fetch Goals (daily and weekly)
      int goalsTotal = 0;
      int goalsCompleted = 0;
      
      final dailyGoalsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_goals')
          .get();
      for (var doc in dailyGoalsSnapshot.docs) {
        final data = doc.data();
        if (isToday(data['date'])) {
          goalsTotal++;
          if (data['isCompleted'] == true) {
            goalsCompleted++;
          }
        }
      }

      final weeklyGoalsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weekly_goals')
          .get();
      for (var doc in weeklyGoalsSnapshot.docs) {
        final data = doc.data();
        final start = data['weekStartDate'];
        final end = data['weekEndDate'];
        if (start != null && end != null) {
          final startDt = (start is Timestamp) ? start.toDate() : (start as DateTime);
          final endDt = (end is Timestamp) ? end.toDate() : (end as DateTime);
          // Check if today falls in the goal week
          if (today.isAfter(startDt.subtract(const Duration(seconds: 1))) && 
              today.isBefore(endDt.add(const Duration(days: 1)))) {
            goalsTotal++;
            if (data['isCompleted'] == true) {
              goalsCompleted++;
            }
          }
        }
      }

      // 4. Fetch Focus Sessions for Today (focus_sessions WHERE userId == uid AND status == "completed")
      int focusMinutes = 0;
      int focusSessions = 0;
      final focusSnapshot = await _firestore
          .collection('focus_sessions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('completedAt', isLessThan: Timestamp.fromDate(today.add(const Duration(days: 1))))
          .get();

      for (var doc in focusSnapshot.docs) {
        focusSessions++;
        int durationSeconds = doc.data()['actualDuration'] ?? 0;
        focusMinutes += (durationSeconds ~/ 60);
      }

      print("Focus sessions found: $focusSessions");
      print("Focus minutes: $focusMinutes");

      // 5. Calculate Productivity Score dynamically
      double earned = 0.0;
      double totalWeight = 0.0;

      // Determine weights dynamically
      double taskWeight = goalsTotal > 0 ? 35.0 : 40.0;
      double habitWeight = goalsTotal > 0 ? 25.0 : 30.0;
      double focusWeight = goalsTotal > 0 ? 20.0 : 30.0;
      double goalWeight = goalsTotal > 0 ? 20.0 : 0.0;

      if (tasksTotal > 0) {
        totalWeight += taskWeight;
        earned += (tasksCompleted / tasksTotal) * taskWeight;
      }

      if (habitsTotal > 0) {
        totalWeight += habitWeight;
        earned += (habitsCompleted / habitsTotal) * habitWeight;
      }

      if (goalsTotal > 0 && goalWeight > 0) {
        totalWeight += goalWeight;
        earned += (goalsCompleted / goalsTotal) * goalWeight;
      }

      // Focus scaled to standard 60 minutes
      totalWeight += focusWeight;
      double focusRatio = (focusMinutes / 60.0).clamp(0.0, 1.0);
      earned += focusRatio * focusWeight;

      double score = totalWeight > 0 ? (earned / totalWeight) * 100.0 : 0.0;

      // 6. Classify dayType
      bool hasActivity = (tasksTotal > 0 || habitsTotal > 0 || goalsTotal > 0 || focusMinutes > 0);
      String dayType = 'empty';
      int roundedScore = score.round();
      if (roundedScore >= 80) {
        dayType = 'excellent';
      } else if (roundedScore >= 60) {
        dayType = 'productive';
      } else if (roundedScore >= 30) {
        dayType = 'average';
      } else if (hasActivity) {
        dayType = 'low';
      } else {
        dayType = 'empty';
      }

      // Calculate success rate and streaks
      final engine = ProductivityEngine();
      double successRate = await engine.getSuccessRate();
      String streakGroup = await engine.detectStreaks(dayType, todayStr);

      final Map<String, dynamic> dataMap = {
        'date': Timestamp.fromDate(today),
        'tasksCompleted': tasksCompleted,
        'tasksTotal': tasksTotal,
        'habitsCompleted': habitsCompleted,
        'habitsTotal': habitsTotal,
        'goalsCompleted': goalsCompleted,
        'goalsTotal': goalsTotal,
        'focusMinutes': focusMinutes,
        'focusSessions': focusSessions,
        'productivityScore': score,
        'successRate': successRate,
        'dayType': dayType,
        'streakGroup': streakGroup,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 7. Save / Merge into users/{uid}/productivity_data/{date}
      print("WRITING PRODUCTIVITY DATA");
      print(dataMap);

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('productivity_data')
          .doc(todayStr);

      await docRef.set(dataMap, SetOptions(merge: true));

      print("PRODUCTIVITY UPDATED SUCCESSFULLY");
      print("Updated productivity_data for $todayStr");
    } catch (e, stackTrace) {
      print("ERROR IN updateDailyProductivity: $e");
      print(stackTrace);
      rethrow;
    }
  }
}
