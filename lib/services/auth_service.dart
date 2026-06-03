import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'fcm_service.dart';
import 'productivity_engine.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<String> _generateUniqueTaskerId(String baseName) async {
    String cleanName = baseName.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (cleanName.isEmpty) {
      cleanName = "user";
    }
    
    final random = Random();
    String candidateId = "@$cleanName";
    int attempts = 0;
    
    while (true) {
      final query = await _firestore
          .collection('users')
          .where('taskerIdLower', isEqualTo: candidateId.toLowerCase())
          .limit(1)
          .get();
          
      if (query.docs.isEmpty) {
        return candidateId;
      }
      
      attempts++;
      if (attempts == 1) {
        int suffix = random.nextInt(90) + 10; // 10 to 99
        candidateId = "@$cleanName$suffix";
      } else if (attempts == 2) {
        int suffix = random.nextInt(9000) + 1000; // 1000 to 9999
        candidateId = "@$cleanName$suffix";
      } else {
        int suffix = random.nextInt(900000) + 100000; // 100000 to 999999
        candidateId = "@$cleanName$suffix";
      }
    }
  }

  // 🔐 Register
  Future<String?> register(String email, String password, String name) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        final taskerId = await _generateUniqueTaskerId(name);
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'email': email,
          'emailLower': email.toLowerCase(),
          'displayName': name,
          'joinedAt': FieldValue.serverTimestamp(),
          'name': name, // Keep existing logic as a fallback
          'taskerId': taskerId,
          'taskerIdLower': taskerId.toLowerCase(),
        }, SetOptions(merge: true));
        await FCMService.saveToken();
        await ProductivityEngine().initializeTodayDocument();
      }

      return null; // success = no error
    } on FirebaseAuthException catch (e) {
      print("ERROR CODE: ${e.code}");
      print("ERROR MESSAGE: ${e.message}");

      // 🔥 return readable message
      switch (e.code) {
        case 'email-already-in-use':
          return "Email already registered";
        case 'invalid-email':
          return "Invalid email format";
        case 'weak-password':
          return "Password must be at least 6 characters";
        default:
          return e.message ?? "Registration failed";
      }
    } catch (e) {
      print("GENERAL ERROR: $e");
      return "Something went wrong";
    }
  }

  // 🔑 Login
  Future<String?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        final docRef = _firestore.collection('users').doc(credential.user!.uid);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          final updates = <String, dynamic>{};
          
          if (data != null && data['taskerId'] == null) {
            final name = data['displayName'] ?? data['name'] ?? email;
            final taskerId = await _generateUniqueTaskerId(name);
            updates['taskerId'] = taskerId;
            updates['taskerIdLower'] = taskerId.toLowerCase();
          } else if (data != null && data['taskerIdLower'] == null && data['taskerId'] != null) {
            updates['taskerIdLower'] = (data['taskerId'] as String).toLowerCase();
          }
          
          if (data != null && data['emailLower'] == null) {
            updates['emailLower'] = email.toLowerCase();
          }
          
          if (updates.isNotEmpty) {
            await docRef.update(updates);
          }
        }
      }
      await FCMService.saveToken();
      await ProductivityEngine().initializeTodayDocument();
      return null; // success
    } on FirebaseAuthException catch (e) {
      print("LOGIN ERROR: ${e.code}");

      switch (e.code) {
        case 'user-not-found':
          return "User not found";
        case 'wrong-password':
          return "Wrong password";
        case 'invalid-email':
          return "Invalid email";
        default:
          return e.message ?? "Login failed";
      }
    } catch (e) {
      print("GENERAL LOGIN ERROR: $e");
      return "Something went wrong";
    }
  }

  // 🌐 Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // Force account picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        String? existingTaskerId;
        String? existingTaskerIdLower;
        String? existingEmailLower;
        
        if (doc.exists) {
          final data = doc.data();
          existingTaskerId = data?['taskerId'] as String?;
          existingTaskerIdLower = data?['taskerIdLower'] as String?;
          existingEmailLower = data?['emailLower'] as String?;
        }
        
        final taskerId = existingTaskerId ?? await _generateUniqueTaskerId(user.displayName ?? user.email ?? 'user');
        final taskerIdLower = existingTaskerIdLower ?? taskerId.toLowerCase();
        final emailLower = existingEmailLower ?? (user.email ?? '').toLowerCase();
        
        await docRef.set({
          'email': user.email ?? '',
          'emailLower': emailLower,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'joinedAt': FieldValue.serverTimestamp(),
          'name': user.displayName ?? '',
          'taskerId': taskerId,
          'taskerIdLower': taskerIdLower,
        }, SetOptions(merge: true));
        await FCMService.saveToken();
        await ProductivityEngine().initializeTodayDocument();
      }

      return user;
    } catch (e) {
      print("GENERAL GOOGLE ERROR: $e");
      return null;
    }
  }

  // 🚪 Logout
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // 👤 Current user
  User? get currentUser => _auth.currentUser;
}
