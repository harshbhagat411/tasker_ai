import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';

class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> performMaintenance() async {
    if (userId == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .get();
        
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lastCompletedTs = data['lastCompletedDate'] as Timestamp?;
      
      bool needsUpdate = false;
      int newStreak = data['streakCount'] ?? 0;
      bool newIsCompleted = data['isCompleted'] ?? false;
      int newProgress = data['progress'] ?? 0;
      
      if (lastCompletedTs != null) {
        final lastDate = lastCompletedTs.toDate();
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        
        final difference = today.difference(lastDay).inDays;
        
        if (difference == 1) {
          // It was completed yesterday. Reset progress for today, keep streak.
          if (newIsCompleted || newProgress > 0) {
            newIsCompleted = false;
            newProgress = 0;
            needsUpdate = true;
          }
        } else if (difference > 1) {
          // Missed a day. Reset streak and progress.
          if (newStreak > 0 || newIsCompleted || newProgress > 0) {
            newStreak = 0;
            newIsCompleted = false;
            newProgress = 0;
            needsUpdate = true;
          }
        }
      } else {
        // Never completed, just make sure progress is 0 for a new day if somehow set
        // Actually, if it was created yesterday and not completed, streak is already 0.
        // We only reset progress/isCompleted if it's a new day since creation.
        final createdTs = data['createdAt'] as Timestamp?;
        if (createdTs != null) {
          final createdDate = createdTs.toDate();
          final createdDay = DateTime(createdDate.year, createdDate.month, createdDate.day);
          if (today.isAfter(createdDay)) {
            if (newIsCompleted || newProgress > 0) {
              newIsCompleted = false;
              newProgress = 0;
              needsUpdate = true;
            }
          }
        }
      }
      
      if (needsUpdate) {
        await doc.reference.update({
          'streakCount': newStreak,
          'isCompleted': newIsCompleted,
          'progress': newProgress,
        });
      }
    }
  }

  Future<void> addHabit(String title, String type, {int target = 1}) async {
    if (userId == null) return;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .add({
      'title': title,
      'type': type,
      'target': target,
      'progress': 0,
      'isCompleted': false,
      'streakCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementProgress(String id, Habit habit, int amount) async {
    if (userId == null) return;
    
    final newProgress = habit.progress + amount;
    final isCompleted = newProgress >= habit.target;
    
    Map<String, dynamic> updates = {
      'progress': newProgress,
      'isCompleted': isCompleted,
    };
    
    if (isCompleted && !habit.isCompleted) {
      final now = DateTime.now();
      updates['lastCompletedDate'] = Timestamp.fromDate(now);
      
      // Calculate streak
      final today = DateTime(now.year, now.month, now.day);
      int currentStreak = habit.streakCount;
      
      if (habit.lastCompletedDate != null) {
        final last = habit.lastCompletedDate!;
        final lastDay = DateTime(last.year, last.month, last.day);
        final diff = today.difference(lastDay).inDays;
        
        if (diff == 1) {
          currentStreak += 1;
        } else if (diff > 1) {
          currentStreak = 1;
        } // If diff == 0, already completed today, streak remains same (handled by !habit.isCompleted check above, but safe)
      } else {
        currentStreak = 1; // First time
      }
      
      updates['streakCount'] = currentStreak;
      
      // Log to history
      _logHabitHistory(id, habit.title);
    }
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(id)
        .update(updates);
  }
  
  Future<void> toggleDailyHabit(String id, Habit habit) async {
    if (userId == null) return;
    
    if (!habit.isCompleted) {
      // Completing it
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      int currentStreak = habit.streakCount;
      if (habit.lastCompletedDate != null) {
        final last = habit.lastCompletedDate!;
        final lastDay = DateTime(last.year, last.month, last.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 1) {
          currentStreak += 1;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      } else {
        currentStreak = 1;
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(id)
          .update({
        'isCompleted': true,
        'progress': 1,
        'lastCompletedDate': Timestamp.fromDate(now),
        'streakCount': currentStreak,
      });
      
      _logHabitHistory(id, habit.title);
    } else {
      // Un-completing it (mistake)
      // We decrement streak if we completed it today and uncheck it today.
      int newStreak = habit.streakCount;
      if (habit.lastCompletedDate != null) {
         final now = DateTime.now();
         final today = DateTime(now.year, now.month, now.day);
         final lastDay = DateTime(habit.lastCompletedDate!.year, habit.lastCompletedDate!.month, habit.lastCompletedDate!.day);
         if (today.isAtSameMomentAs(lastDay)) {
             newStreak = (newStreak > 0) ? newStreak - 1 : 0;
         }
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(id)
          .update({
        'isCompleted': false,
        'progress': 0,
        'streakCount': newStreak,
        // Optional: revert lastCompletedDate to previous, but for simplicity we keep it or nullify it if streak is 0
        if (newStreak == 0) 'lastCompletedDate': FieldValue.delete(),
      });
    }
  }

  Future<void> _logHabitHistory(String habitId, String title) async {
    if (userId == null) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('habit_history')
        .add({
      'habitId': habitId,
      'title': title,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHabit(String id) async {
    if (userId == null) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(id)
        .delete();
  }

  Stream<List<Habit>> getHabits() {
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Habit.fromMap(doc.id, doc.data())).toList());
  }
}
