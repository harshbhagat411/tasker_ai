import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    
    const AndroidNotificationChannel scheduledChannel = AndroidNotificationChannel(
      'task_reminder_channel',
      'Task Reminders',
      description: 'Notifications for scheduled task deadlines',
      importance: Importance.max,
    );
    
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(scheduledChannel);

    _initialized = true;
  }

  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      
      // Request exact alarm permission (Android 12+)
      // Note: If permission is denied, you should guide the user to enable it manually.
      // To handle devices where user must manually enable "Alarms & reminders":
      // 1. You can use a package like `permission_handler` to check the exact alarm permission status.
      // 2. If denied, show a dialog explaining why exact alarms are needed.
      // 3. To open app settings, you can use: `openAppSettings()` from the `permission_handler` package.
      // Once scheduled, the app will appear in the "Alarms & reminders" settings page.
      await androidImplementation?.requestExactAlarmsPermission();
      
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    print("BEFORE SCHEDULING - Selected time: $scheduledDate");

    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    
    DateTime finalScheduledDate = scheduledDate.add(const Duration(seconds: 5));
    print("Parsed DateTime: $finalScheduledDate");

    final tz.TZDateTime scheduledTzDate = tz.TZDateTime.from(finalScheduledDate, tz.local);
    print("Final scheduled TZDateTime: $scheduledTzDate");

    try {
      await cancelNotification(id);
      
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTzDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminder_channel',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task deadlines',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print("AFTER SCHEDULING - Notification scheduled successfully");
      
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print("Pending notifications count: ${pending.length}");
    } catch (e) {
      print("Failed to schedule notification: $e");
    }
  }

  Future<void> testNotificationIn10Seconds() async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledTzDate = now.add(const Duration(seconds: 10));

    print("Testing Notification - Current time: $now");
    print("Testing Notification - Scheduled time: $scheduledTzDate");

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 9999, // Specific test ID
        title: "Test Notification",
        body: "This is a test notification 10 seconds later!",
        scheduledDate: scheduledTzDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminder_channel',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task deadlines',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print("Notification scheduled successfully");
      
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print("Pending notifications count: ${pending.length}");
    } catch (e) {
      print("Failed to schedule test notification: $e");
    }
  }

  Future<void> triggerImmediateNotification() async {
    try {
      await _notificationsPlugin.show(
        id: 8888,
        title: "Immediate Test",
        body: "This is an instant notification test!",
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminder_channel',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task deadlines',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      print("Immediate notification triggered");
    } catch (e) {
      print("Failed to trigger immediate notification: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
