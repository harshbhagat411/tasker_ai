import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> init() async {
    // 1. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
      return;
    }

    // 2. Get and Print FCM Token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    if (token != null) {
      await saveToken();
    }

    // 3. Listen to Token Refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      print('FCM Token refreshed: $newToken');
      await saveToken();
    });

    // 4. Foreground Message Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received');
      print('Data: ${message.data}');

      if (message.notification != null) {
        print('Notification Title: ${message.notification!.title}');
      }
    });
  }

  static Future<void> saveToken() async {
    final user = _auth.currentUser;

    if (user == null) {
      print('No user logged in, skipping token save');
      return;
    }

    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));

        print('Saved token for user: ${user.uid}');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}