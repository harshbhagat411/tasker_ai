import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserMode { personal, developer }

class ModeService {
  static UserMode getModeFromString(String? modeString) {
    if (modeString == 'developer') return UserMode.developer;
    return UserMode.personal; // Default
  }

  static String getStringFromMode(UserMode mode) {
    if (mode == UserMode.developer) return 'developer';
    return 'personal';
  }

  static Future<void> updateMode(UserMode mode) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'mode': getStringFromMode(mode),
    });
  }
}
