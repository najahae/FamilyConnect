import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SIGN UP
  Future<User?> signUpWithEmail(String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user role in Firestore
      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "email": email,
        "role": role,
      });

      return userCredential.user;
    } catch (e) {
      print("Sign-up error: $e");
      return null;
    }
  }

  // LOGIN
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  // GET USER ROLE
  Future<String?> getUserRole(String uid) async {
    DocumentSnapshot doc = await _firestore.collection("users").doc(uid).get();
    return doc.exists ? doc["role"] : null;
  }

  // LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
