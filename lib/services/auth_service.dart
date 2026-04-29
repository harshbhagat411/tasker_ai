import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 🔐 Register
  Future<String?> register(String email, String password, String name) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'email': email,
          'displayName': name,
          'joinedAt': FieldValue.serverTimestamp(),
          'name': name, // Keep existing logic as a fallback
        }, SetOptions(merge: true));
        await FCMService.saveToken();
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
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FCMService.saveToken();
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
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'joinedAt': FieldValue.serverTimestamp(),
          'name': user.displayName ?? '',
        }, SetOptions(merge: true));
        await FCMService.saveToken();
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
