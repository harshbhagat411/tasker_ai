import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings: settings);

    // Request notification permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Create a generic notification channel for immediate tasks
    const AndroidNotificationChannel instantChannel = AndroidNotificationChannel(
      'instant_task_channel',
      'Immediate Task Reminders',
      importance: Importance.max,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(instantChannel);

    _initialized = true;
  }

  static Future<void> showInstantNotification(int id, String title, String body) async {
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_task_channel',
          'Immediate Task Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}
