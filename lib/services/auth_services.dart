import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // REGISTER USER WITH ACCOUNT NUMBER
  Future<User?> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String accountNumber,
    required String contactNumber,
    required String address,
  }) async {
    try {
      // Check if account number exists
      QuerySnapshot existingAccount = await _firestore
          .collection('users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (existingAccount.docs.isNotEmpty) {
        throw Exception('Account number already registered');
      }

      // Create user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      // Save to Firestore
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'full_name': fullName,
        'email': email,
        'user_type': role,
        'accountNumber': accountNumber,
        'contactNumber': contactNumber,
        'address': address,
        'created_at': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // LOGIN USER
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // GET USER ROLE
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception("User record not found");
      }

      final data = doc.data();
      return data?['user_type'] ?? 'consumer';
    } catch (e) {
      rethrow;
    }
  }

  // GET USER DATA
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // LOGOUT
  Future<void> logoutUser() async {
    await _auth.signOut();
  }

  // CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}