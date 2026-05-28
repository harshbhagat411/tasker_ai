import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'productivity_tracking_service.dart';

enum FocusSessionStatus { idle, running, paused, completed }

class FocusSessionState {
  final FocusSessionStatus status;
  final String? taskId;
  final String taskTitle;
  final String? projectName;
  final int targetDurationInSeconds;
  final int elapsedSeconds;
  final String? ambientSound;

  FocusSessionState({
    this.status = FocusSessionStatus.idle,
    this.taskId,
    this.taskTitle = '',
    this.projectName,
    this.targetDurationInSeconds = 0,
    this.elapsedSeconds = 0,
    this.ambientSound,
  });

  int get remainingSeconds => targetDurationInSeconds - elapsedSeconds;

  FocusSessionState copyWith({
    FocusSessionStatus? status,
    String? taskId,
    String? taskTitle,
    String? projectName,
    int? targetDurationInSeconds,
    int? elapsedSeconds,
    String? ambientSound,
  }) {
    return FocusSessionState(
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      projectName: projectName ?? this.projectName,
      targetDurationInSeconds: targetDurationInSeconds ?? this.targetDurationInSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      ambientSound: ambientSound ?? this.ambientSound,
    );
  }
}

class FocusService {
  static final FocusService _instance = FocusService._internal();
  factory FocusService() => _instance;
  FocusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SharedPreferences? _prefs;

  final BehaviorSubject<FocusSessionState> _sessionSubject = BehaviorSubject<FocusSessionState>.seeded(FocusSessionState());
  Stream<FocusSessionState> get activeSessionStream => _sessionSubject.stream;
  FocusSessionState get currentState => _sessionSubject.value;

  final BehaviorSubject<Map<String, dynamic>> _analyticsSubject = BehaviorSubject<Map<String, dynamic>>.seeded({
    'sessions': 0,
    'totalMinutes': 0,
    'streak': 0,
    'interrupted': 0,
    'lastDuration': 0,
  });

  Timer? _timer;
  AudioPlayer? _audioPlayer;

  final Map<String, String> _soundUrls = {
    'Rain': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/weather/rain_heavy_loud.ogg',
    'Cafe': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
    'White Noise': 'https://web.archive.org/web/20220101120000if_/https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg',
    'Lofi': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _audioPlayer = AudioPlayer();
    _restoreAnalytics();
    _restoreSession();
  }

  void _restoreAnalytics() {
    if (_prefs == null) return;
    final userId = _auth.currentUser?.uid ?? 'guest';
    
    final lastDateStr = _prefs!.getString('focus_analytics_date_$userId');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    if (lastDateStr != todayStr) {
      // Reset daily stats for this user
      _prefs!.setInt('focus_sessions_today_$userId', 0);
      _prefs!.setInt('focus_minutes_today_$userId', 0);
      _prefs!.setString('focus_analytics_date_$userId', todayStr);
    }
    
    int sessions = _prefs!.getInt('focus_sessions_today_$userId') ?? 0;
    int minutes = _prefs!.getInt('focus_minutes_today_$userId') ?? 0;
    int streak = _prefs!.getInt('focus_streak_count_$userId') ?? 0;
    int lastDuration = _prefs!.getInt('focus_last_duration_$userId') ?? 0;
    
    _analyticsSubject.add({
      'sessions': sessions,
      'totalMinutes': minutes,
      'streak': streak,
      'interrupted': 0,
      'lastDuration': lastDuration,
    });
  }

  void _updateLocalAnalyticsOnComplete(int durationInSeconds) {
    if (_prefs == null) return;
    final userId = _auth.currentUser?.uid ?? 'guest';
    
    int sessions = (_prefs!.getInt('focus_sessions_today_$userId') ?? 0) + 1;
    int minutes = (_prefs!.getInt('focus_minutes_today_$userId') ?? 0) + (durationInSeconds ~/ 60);
    int lastDuration = durationInSeconds ~/ 60;
    int streak = _prefs!.getInt('focus_streak_count_$userId') ?? 0; 
    
    _prefs!.setInt('focus_sessions_today_$userId', sessions);
    _prefs!.setInt('focus_minutes_today_$userId', minutes);
    _prefs!.setInt('focus_last_duration_$userId', lastDuration);
    
    _analyticsSubject.add({
      'sessions': sessions,
      'totalMinutes': minutes,
      'streak': streak,
      'interrupted': 0,
      'lastDuration': lastDuration,
    });
  }

  void _restoreSession() {
    if (_prefs == null) return;
    final userId = _auth.currentUser?.uid ?? 'guest';
    final statusStr = _prefs!.getString('focus_status_$userId') ?? 'idle';
    if (statusStr == 'idle') return;

    final status = FocusSessionStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => FocusSessionStatus.idle);
    final taskId = _prefs!.getString('focus_taskId_$userId');
    final taskTitle = _prefs!.getString('focus_taskTitle_$userId') ?? '';
    final projectName = _prefs!.getString('focus_projectName_$userId');
    final targetDurationInSeconds = _prefs!.getInt('focus_targetDuration_$userId') ?? 0;
    final ambientSound = _prefs!.getString('focus_ambientSound_$userId');
    final savedElapsedSeconds = _prefs!.getInt('focus_elapsedSeconds_$userId') ?? 0;
    final lastUpdated = _prefs!.getInt('focus_lastUpdated_$userId') ?? DateTime.now().millisecondsSinceEpoch;

    int currentElapsed = savedElapsedSeconds;
    if (status == FocusSessionStatus.running) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = ((now - lastUpdated) / 1000).floor();
      currentElapsed += diffSeconds;
      if (currentElapsed >= targetDurationInSeconds) {
        currentElapsed = targetDurationInSeconds;
      }
    }

    final state = FocusSessionState(
      status: currentElapsed >= targetDurationInSeconds && status == FocusSessionStatus.running ? FocusSessionStatus.completed : status,
      taskId: taskId,
      taskTitle: taskTitle,
      projectName: projectName,
      targetDurationInSeconds: targetDurationInSeconds,
      elapsedSeconds: currentElapsed,
      ambientSound: ambientSound,
    );

    _sessionSubject.add(state);

    if (state.status == FocusSessionStatus.running) {
      _startInternalTimer();
      _playAudio(ambientSound);
    } else if (state.status == FocusSessionStatus.completed && status == FocusSessionStatus.running) {
      _saveSessionToPrefs(state);
      _onSessionCompleteLocally();
    }
  }

  void _saveSessionToPrefs(FocusSessionState state) {
    if (_prefs == null) return;
    final userId = _auth.currentUser?.uid ?? 'guest';
    _prefs!.setString('focus_status_$userId', state.status.name);
    if (state.taskId != null) _prefs!.setString('focus_taskId_$userId', state.taskId!);
    _prefs!.setString('focus_taskTitle_$userId', state.taskTitle);
    if (state.projectName != null) _prefs!.setString('focus_projectName_$userId', state.projectName!);
    _prefs!.setInt('focus_targetDuration_$userId', state.targetDurationInSeconds);
    _prefs!.setInt('focus_elapsedSeconds_$userId', state.elapsedSeconds);
    if (state.ambientSound != null) _prefs!.setString('focus_ambientSound_$userId', state.ambientSound!);
    _prefs!.setInt('focus_lastUpdated_$userId', DateTime.now().millisecondsSinceEpoch);
  }

  void _clearSessionPrefs() {
    if (_prefs == null) return;
    final userId = _auth.currentUser?.uid ?? 'guest';
    _prefs!.remove('focus_status_$userId');
    _prefs!.remove('focus_taskId_$userId');
    _prefs!.remove('focus_taskTitle_$userId');
    _prefs!.remove('focus_projectName_$userId');
    _prefs!.remove('focus_targetDuration_$userId');
    _prefs!.remove('focus_elapsedSeconds_$userId');
    _prefs!.remove('focus_ambientSound_$userId');
    _prefs!.remove('focus_lastUpdated_$userId');
  }

  Future<void> _playAudio(String? soundName) async {
    if (soundName != null && soundName != 'None' && _soundUrls.containsKey(soundName)) {
      try {
        await _audioPlayer?.setAudioSource(AudioSource.uri(Uri.parse(_soundUrls[soundName]!)));
        await _audioPlayer?.setLoopMode(LoopMode.one);
        await _audioPlayer?.play();
      } catch (e) {
        print("Error playing audio: $e");
      }
    } else {
      await _audioPlayer?.stop();
    }
  }

  Future<void> startSession({
    String? taskId,
    String? taskTitle,
    String? projectName,
    required int durationInSeconds,
    String? ambientSound,
  }) async {
    final state = FocusSessionState(
      status: FocusSessionStatus.running,
      taskId: taskId,
      taskTitle: taskTitle ?? 'Deep Focus',
      projectName: projectName,
      targetDurationInSeconds: durationInSeconds,
      elapsedSeconds: 0,
      ambientSound: ambientSound,
    );

    _sessionSubject.add(state);
    _saveSessionToPrefs(state);
    
    _playAudio(ambientSound);
    _startInternalTimer();
  }

  void _startInternalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final state = _sessionSubject.value;
      if (state.status == FocusSessionStatus.running) {
        final newElapsed = state.elapsedSeconds + 1;
        if (newElapsed >= state.targetDurationInSeconds) {
          timer.cancel();
          final newState = state.copyWith(elapsedSeconds: state.targetDurationInSeconds, status: FocusSessionStatus.completed);
          _sessionSubject.add(newState);
          _saveSessionToPrefs(newState);
          _onSessionCompleteLocally();
        } else {
          final newState = state.copyWith(elapsedSeconds: newElapsed);
          _sessionSubject.add(newState);
          if (newElapsed % 5 == 0) {
            _saveSessionToPrefs(newState);
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  void pauseSession() {
    final state = _sessionSubject.value;
    if (state.status == FocusSessionStatus.running) {
      _timer?.cancel();
      _audioPlayer?.pause();
      final newState = state.copyWith(status: FocusSessionStatus.paused);
      _sessionSubject.add(newState);
      _saveSessionToPrefs(newState);
    }
  }

  void resumeSession() {
    final state = _sessionSubject.value;
    if (state.status == FocusSessionStatus.paused) {
      final newState = state.copyWith(status: FocusSessionStatus.running);
      _sessionSubject.add(newState);
      _saveSessionToPrefs(newState);
      _playAudio(state.ambientSound);
      _startInternalTimer();
    }
  }

  Future<void> endSessionEarly() async {
    _timer?.cancel();
    _audioPlayer?.stop();
    final state = _sessionSubject.value;
    
    await _saveFocusSessionToFirebase(
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      durationInSeconds: state.targetDurationInSeconds,
      actualDurationInSeconds: state.elapsedSeconds,
      status: 'interrupted',
    );

    _clearSessionPrefs();
    _sessionSubject.add(FocusSessionState(status: FocusSessionStatus.idle));
  }

  void _onSessionCompleteLocally() async {
    _timer?.cancel();
    _audioPlayer?.stop();
    final state = _sessionSubject.value;

    _updateLocalAnalyticsOnComplete(state.targetDurationInSeconds);

    await _saveFocusSessionToFirebase(
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      durationInSeconds: state.targetDurationInSeconds,
      actualDurationInSeconds: state.targetDurationInSeconds,
      status: 'completed',
    );
  }

  void resetSession() {
    _timer?.cancel();
    _audioPlayer?.stop();
    _clearSessionPrefs();
    _sessionSubject.add(FocusSessionState(status: FocusSessionStatus.idle));
  }

  // --- Firebase Logging ---
  Future<void> _saveFocusSessionToFirebase({
    required String? taskId,
    required String taskTitle,
    required int durationInSeconds,
    required int actualDurationInSeconds,
    required String status,
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
        print("FOCUS SESSION COMPLETED");
        print("Current user id: ${user.uid}");
        await _updateStreak(user.uid, now);
      }

      await ProductivityTrackingService.updateDailyProductivity(user.uid);
    } catch (e) {
      print("Error saving focus session: $e");
    }
  }

  Future<void> _updateStreak(String userId, DateTime now) async {
    final statRef = _firestore.collection('user_focus_stats').doc(userId);
    final doc = await statRef.get();
    
    final today = DateTime(now.year, now.month, now.day);
    int currentStreak = 1;
    
    if (!doc.exists) {
      await statRef.set({'currentStreak': 1, 'lastFocusDate': Timestamp.fromDate(today)});
    } else {
      final data = doc.data()!;
      final lastDateTs = data['lastFocusDate'] as Timestamp?;
      
      if (lastDateTs == null) {
        await statRef.update({'currentStreak': 1, 'lastFocusDate': Timestamp.fromDate(today)});
      } else {
        final lastDate = lastDateTs.toDate();
        final lastDateNormalized = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final difference = today.difference(lastDateNormalized).inDays;
        
        if (difference == 1) {
          currentStreak = (data['currentStreak'] ?? 0) + 1;
          await statRef.update({
            'currentStreak': currentStreak,
            'lastFocusDate': Timestamp.fromDate(today),
          });
        } else if (difference > 1) {
          await statRef.update({
            'currentStreak': 1,
            'lastFocusDate': Timestamp.fromDate(today),
          });
        } else {
           currentStreak = data['currentStreak'] ?? 1;
        }
      }
    }

    // Update local streak
    _prefs?.setInt('focus_streak_count_$userId', currentStreak);
    final currentStats = Map<String, dynamic>.from(_analyticsSubject.value);
    currentStats['streak'] = currentStreak;
    _analyticsSubject.add(currentStats);
  }

  Stream<Map<String, dynamic>> getTodayFocusSummary() {
    return _analyticsSubject.stream;
  }
}
