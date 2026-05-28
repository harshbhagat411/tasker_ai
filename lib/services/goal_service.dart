import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal.dart';
import 'productivity_tracking_service.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> performMaintenance() async {
    if (userId == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Check Daily Goals
    final dailySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_goals')
        .get();
        
    for (var doc in dailySnapshot.docs) {
      final goalDateTs = doc.data()['date'] as Timestamp?;
      if (goalDateTs != null) {
        final goalDate = goalDateTs.toDate();
        final goalDay = DateTime(goalDate.year, goalDate.month, goalDate.day);
        
        if (goalDay.isBefore(today)) {
          // Archive old daily goal
          await _archiveGoal(doc.id, doc.data());
          await doc.reference.delete();
        }
      }
    }
    
    // 2. Check Weekly Goals
    final weeklySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_goals')
        .get();
        
    for (var doc in weeklySnapshot.docs) {
      final endDateTs = doc.data()['weekEndDate'] as Timestamp?;
      if (endDateTs != null) {
        final endDate = endDateTs.toDate();
        final endDay = DateTime(endDate.year, endDate.month, endDate.day);
        
        if (endDay.isBefore(today)) {
          // Archive old weekly goal
          await _archiveGoal(doc.id, doc.data());
          await doc.reference.delete();
        }
      }
    }
  }

  Future<void> _archiveGoal(String originalId, Map<String, dynamic> data) async {
    if (userId == null) return;
    data['archivedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goal_history')
        .doc(originalId)
        .set(data);
  }

  Future<void> addDailyGoal(String title, int target) async {
    if (userId == null) return;
    final now = DateTime.now();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_goals')
        .add({
      'title': title,
      'type': 'daily',
      'target': target,
      'progress': 0,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
    });

    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }

  Future<void> addWeeklyGoal(String title, int target) async {
    if (userId == null) return;
    final now = DateTime.now();
    
    // Calculate current week's Monday and Sunday
    int currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final monday = now.subtract(Duration(days: currentWeekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_goals')
        .add({
      'title': title,
      'type': 'weekly',
      'target': target,
      'progress': 0,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'weekStartDate': Timestamp.fromDate(DateTime(monday.year, monday.month, monday.day)),
      'weekEndDate': Timestamp.fromDate(DateTime(sunday.year, sunday.month, sunday.day)),
    });

    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }

  Future<void> incrementGoalProgress(String id, String type, int currentProgress, int target) async {
    if (userId == null) return;
    
    final newProgress = currentProgress + 1;
    final isCompleted = newProgress >= target;
    
    final collection = type == 'daily' ? 'daily_goals' : 'weekly_goals';
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .update({
      'progress': newProgress,
      'isCompleted': isCompleted,
    });

    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }
  
  Future<void> toggleGoalComplete(String id, String type, bool currentCompleted) async {
    if (userId == null) return;
    
    final collection = type == 'daily' ? 'daily_goals' : 'weekly_goals';
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .update({
      'isCompleted': !currentCompleted,
    });

    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }

  Future<void> deleteGoal(String id, String type) async {
    if (userId == null) return;
    final collection = type == 'daily' ? 'daily_goals' : 'weekly_goals';
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .delete();

    await ProductivityTrackingService.updateDailyProductivity(userId!);
  }

  Stream<List<Goal>> getDailyGoals() {
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Goal.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<Goal>> getWeeklyGoals() {
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Goal.fromMap(doc.id, doc.data())).toList());
  }
}
