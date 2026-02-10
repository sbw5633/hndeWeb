import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase.dart';
import '../core/firestore_service.dart';

final isLoggedInProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(firebaseAuth.currentUser != null) {
    firebaseAuth.authStateChanges().listen((User? user) {
      state = user != null;
    });
  }
}

// 사용자 정보 모델
class UserInfo {
  final String email;
  final String? restAreaId;
  final String? restAreaName;
  final String role; // 'admin' or 'rest_area_manager'

  UserInfo({
    required this.email,
    this.restAreaId,
    this.restAreaName,
    required this.role,
  });

  bool get isRestAreaManager => role == 'rest_area_manager';
  bool get isAdmin => role == 'admin';
}

// 현재 사용자 정보 Provider
final currentUserInfoProvider = FutureProvider.autoDispose<UserInfo?>((ref) async {
  final user = firebaseAuth.currentUser;
  if (user == null) return null;

  final email = user.email!;
  
  // 관리자 이메일 체크 (admin@hnde.co.kr, hnde@hnde.co.kr)
  if (email == 'admin@hnde.co.kr' || email == 'hnde@hnde.co.kr') {
    return UserInfo(
      email: email,
      role: 'admin',
    );
  }

  // Firestore에서 관리자 정보 확인
  try {
    final firestoreService = FirestoreService();
    final adminData = await firestoreService.getDocument(
      FirestoreCollections.admins,
      email.split('@')[0],
    );
    
    if (adminData != null && adminData['role'] == 'admin') {
      return UserInfo(
        email: email,
        role: 'admin',
      );
    }
  } catch (e) {
    print('관리자 정보 확인 오류: $e');
  }

  // @hnde.co.kr 도메인인 경우 휴게소 관리자로 처리 (관리자 이메일 제외)
  if (email.endsWith('@hnde.co.kr')) {
    try {
      final firestoreService = FirestoreService();
      final restAreaId = email.split('@')[0];
    final data = await firestoreService.getDocument(
      FirestoreCollections.restAreaManagers,
      restAreaId,
    );

    if (data != null) {
      return UserInfo(
          email: email,
        restAreaId: data['restAreaId'] as String?,
        restAreaName: data['restAreaName'] as String?,
        role: data['role'] as String? ?? 'rest_area_manager',
      );
    }
  } catch (e) {
    print('사용자 정보 가져오기 오류: $e');
  }

  // 기본값: 휴게소 관리자로 간주
  return UserInfo(
      email: email,
      restAreaId: email.split('@')[0],
    role: 'rest_area_manager',
    );
  }

  // 그 외의 경우는 관리자로 간주 (기존 호환성)
  return UserInfo(
    email: email,
    role: 'admin',
  );
});

final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this.ref);
  final Ref ref;

  Future<void> signIn(String email, String password) async {
    await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // 상태가 자동으로 업데이트됨 (AuthNotifier의 listen이 처리)
    ref.invalidate(currentUserInfoProvider);
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
    // 상태가 자동으로 업데이트됨
    ref.invalidate(currentUserInfoProvider);
  }

  Future<void> signUp(String email, String password) async {
    await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
