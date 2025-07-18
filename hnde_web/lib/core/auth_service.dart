import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 회원가입
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String affiliation,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user != null) {
      final now = DateTime.now();
      await _db.collection('Users').doc(user.uid).set({
        'name': name,
        'email': email,
        'affiliation': affiliation,
        'role': 'employee',
        'approved': false,
        'createdAt': now,
        'lastLoginAt': now,
      });
    }
    return user;
  }

  // 로그인
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user != null) {
      await _db.collection('Users').doc(user.uid).update({
        'lastLoginAt': DateTime.now(),
      });
    }
    return user;
  }

  // 승인여부 확인
  Future<bool> isApproved(String uid) async {
    final doc = await _db.collection('Users').doc(uid).get();
    if (doc.exists) {
      return doc.data()?['approved'] == true;
    }
    return false;
  }

  // 로그아웃
  Future<void> logout() async {
    await _auth.signOut();
  }
} 