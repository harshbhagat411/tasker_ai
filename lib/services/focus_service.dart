import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FocusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save a completed focus session
  Future<void> saveFocusSession({
    required String? taskId,
    required String taskTitle,
    required int durationInSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('focus_sessions').add({
        'userId': user.uid,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'duration': durationInSeconds,
        'completedAt': FieldValue.serverTimestamp(),
      });
      print("Focus session saved successfully.");
    } catch (e) {
      print("Error saving focus session: $e");
    }
  }

  // Get today's focus summary
  Stream<Map<String, dynamic>> getTodayFocusSummary() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({'sessions': 0, 'totalMinutes': 0});

    // Get the start of today
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: user.uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .snapshots()
        .map((snapshot) {
      int totalSeconds = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalSeconds += (data['duration'] as num?)?.toInt() ?? 0;
      }
      return {
        'sessions': snapshot.docs.length,
        'totalMinutes': (totalSeconds / 60).floor(),
      };
    });
  }
}
