import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class FocusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save a focus session
  Future<void> saveFocusSession({
    required String? taskId,
    required String taskTitle,
    required int durationInSeconds, // Planned duration
    required int actualDurationInSeconds, // Actual focused duration
    required String status, // 'completed' or 'interrupted'
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      await _firestore.collection('focus_sessions').add({
        'userId': user.uid,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'targetDuration': durationInSeconds,
        'actualDuration': actualDurationInSeconds,
        'status': status,
        'completedAt': Timestamp.fromDate(now),
      });

      if (status == 'completed') {
        await _updateStreak(user.uid, now);
      }
      
      print("Focus session saved successfully.");
    } catch (e) {
      print("Error saving focus session: $e");
    }
  }

  Future<void> _updateStreak(String userId, DateTime now) async {
    final statRef = _firestore.collection('user_focus_stats').doc(userId);
    final doc = await statRef.get();
    
    final today = DateTime(now.year, now.month, now.day);
    
    if (!doc.exists) {
      await statRef.set({
        'currentStreak': 1,
        'lastFocusDate': Timestamp.fromDate(today),
      });
      return;
    }

    final data = doc.data()!;
    final lastDateTs = data['lastFocusDate'] as Timestamp?;
    
    if (lastDateTs == null) {
      await statRef.update({'currentStreak': 1, 'lastFocusDate': Timestamp.fromDate(today)});
      return;
    }
    
    final lastDate = lastDateTs.toDate();
    final lastDateNormalized = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final difference = today.difference(lastDateNormalized).inDays;
    
    if (difference == 1) {
      // Focused yesterday, streak continues
      await statRef.update({
        'currentStreak': FieldValue.increment(1),
        'lastFocusDate': Timestamp.fromDate(today),
      });
    } else if (difference > 1) {
      // Streak broken
      await statRef.update({
        'currentStreak': 1,
        'lastFocusDate': Timestamp.fromDate(today),
      });
    }
    // If difference == 0, already focused today, don't increment streak
  }

  // Get advanced focus summary
  Stream<Map<String, dynamic>> getTodayFocusSummary() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({'sessions': 0, 'totalMinutes': 0, 'streak': 0, 'interrupted': 0});

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final sessionsStream = _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .snapshots();

    final statsStream = _firestore.collection('user_focus_stats').doc(user.uid).snapshots();

    return Rx.combineLatest2(sessionsStream, statsStream, (QuerySnapshot sessionsSnapshot, DocumentSnapshot statsSnapshot) {
      int totalSeconds = 0;
      int completedSessions = 0;
      int interruptedSessions = 0;

      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'completed') {
          completedSessions++;
          totalSeconds += (data['actualDuration'] as num?)?.toInt() ?? (data['duration'] as num?)?.toInt() ?? 0;
        } else if (status == 'interrupted') {
          interruptedSessions++;
        } else {
          // Legacy support
          completedSessions++;
          totalSeconds += (data['duration'] as num?)?.toInt() ?? 0;
        }
      }

      int streak = 0;
      if (statsSnapshot.exists && statsSnapshot.data() != null) {
        final statsData = statsSnapshot.data() as Map<String, dynamic>;
        streak = statsData['currentStreak'] ?? 0;
      }

      return {
        'sessions': completedSessions,
        'totalMinutes': (totalSeconds / 60).floor(),
        'streak': streak,
        'interrupted': interruptedSessions,
      };
    });
  }
}
