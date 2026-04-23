import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔐 Register
  Future<String?> register(String email, String password, String name) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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

  // 🚪 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 👤 Current user
  User? get currentUser => _auth.currentUser;
}