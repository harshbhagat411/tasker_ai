import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sprint.dart';

class SprintService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // Create planned Sprint
  Future<String> createSprint({
    required String projectId,
    required String title,
    required String description,
    required String goal,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (userId == null) throw Exception("User not authenticated");

    final sprintRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('sprints')
        .doc();

    final sprint = Sprint(
      id: sprintRef.id,
      title: title,
      description: description,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
      status: 'planned',
      createdBy: userId!,
      createdAt: DateTime.now(),
    );

    await sprintRef.set(sprint.toMap());
    
    // Automatically trigger rules/maintenance on startup/creation
    await runAutoRulesAndMaintenance(projectId);

    return sprintRef.id;
  }

  // Get project sprints Stream (ordered by createdAt descending)
  Stream<List<Sprint>> getProjectSprints(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('sprints')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Sprint.fromMap(doc.id, doc.data())).toList();
        });
  }

  // Update Sprint status
  Future<void> updateSprintStatus(String projectId, String sprintId, String newStatus) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('sprints')
        .doc(sprintId)
        .update({'status': newStatus});
  }

  // Archive completed Sprint
  Future<void> archiveCompletedSprint(String projectId, String sprintId) async {
    await updateSprintStatus(projectId, sprintId, 'archived');
  }

  // Get currently active Sprint
  Future<Sprint?> getActiveSprint(String projectId) async {
    final query = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('sprints')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return Sprint.fromMap(query.docs.first.id, query.docs.first.data());
  }

  // Dynamic progress calculator based on task links count
  Future<void> calculateSprintProgress(String projectId, String sprintId) async {
    final tasksSnapshot = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .where('sprintId', isEqualTo: sprintId)
        .get();

    final int totalTasks = tasksSnapshot.docs.length;
    final int completedTasks = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      return (data['isDone'] as bool?) ?? false;
    }).length;

    final double progressPercentage = totalTasks > 0
        ? (completedTasks / totalTasks) * 100.0
        : 0.0;

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('sprints')
        .doc(sprintId)
        .update({
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'progressPercentage': progressPercentage,
        });
  }

  // Auto Rules engine (planned -> active -> completed)
  Future<void> runAutoRulesAndMaintenance(String projectId) async {
    try {
      final sprintsSnapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('sprints')
          .get();

      final now = DateTime.now();

      for (var doc in sprintsSnapshot.docs) {
        final sprintId = doc.id;
        final sprint = Sprint.fromMap(sprintId, doc.data());
        
        // Skip archived ones entirely
        if (sprint.status == 'archived') continue;

        String currentStatus = sprint.status;
        bool statusChanged = false;

        // Auto Rule 1: planned -> active if today >= startDate
        // (normalized to date only for robust comparison)
        final todayDateOnly = DateTime(now.year, now.month, now.day);
        final startDateOnly = DateTime(sprint.startDate.year, sprint.startDate.month, sprint.startDate.day);
        final endDateOnly = DateTime(sprint.endDate.year, sprint.endDate.month, sprint.endDate.day);

        if (currentStatus == 'planned' && (todayDateOnly.isAfter(startDateOnly) || todayDateOnly.isAtSameMomentAs(startDateOnly))) {
          currentStatus = 'active';
          statusChanged = true;
        }

        // Auto Rule 2: active -> completed if endDate passed
        if (currentStatus == 'active' && todayDateOnly.isAfter(endDateOnly)) {
          currentStatus = 'completed';
          statusChanged = true;
        }

        if (statusChanged) {
          await _firestore
              .collection('projects')
              .doc(projectId)
              .collection('sprints')
              .doc(sprintId)
              .update({'status': currentStatus});
        }

        // Recalculate metrics for non-archived sprints
        // For completed ones, we recalculate once upon completion and freeze,
        // or recalculate if it remains active / planned to keep live accuracy.
        if (currentStatus == 'active' || (currentStatus == 'completed' && statusChanged) || currentStatus == 'planned') {
          await calculateSprintProgress(projectId, sprintId);
        }
      }
    } catch (e) {
      print("Error running sprint auto-rules: $e");
    }
  }
}
