import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase.dart' show firebaseAuth;
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
  final bool isApproved; // 관리자 승인 여부
  final bool isGoogleAccount; // 구글 계정 여부

  UserInfo({
    required this.email,
    this.restAreaId,
    this.restAreaName,
    required this.role,
    this.isApproved = true,
    this.isGoogleAccount = false,
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
      isApproved: true,
      isGoogleAccount: false,
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
        isApproved: adminData['isApproved'] as bool? ?? true,
        isGoogleAccount: adminData['isGoogleAccount'] as bool? ?? false,
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
          isApproved: data['isApproved'] as bool? ?? true,
          isGoogleAccount: data['isGoogleAccount'] as bool? ?? false,
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
      isApproved: false, // 새 계정은 승인 필요
      isGoogleAccount: false,
    );
  }

  // 그 외의 경우 (구글 계정 등) - Firestore에서 확인 (계정생성 시와 동일한 docId 규칙)
  try {
    final firestoreService = FirestoreService();
    final emailPrefix = email.replaceAll('.', '_').replaceAll('@', '_at_');

    final restAreaData = await firestoreService.getDocument(
      FirestoreCollections.restAreaManagers,
      emailPrefix,
    );

    if (restAreaData != null) {
      return UserInfo(
        email: email,
        restAreaId: restAreaData['restAreaId'] as String?,
        restAreaName: restAreaData['restAreaName'] as String?,
        role: restAreaData['role'] as String? ?? 'rest_area_manager',
        isApproved: restAreaData['isApproved'] as bool? ?? false,
        isGoogleAccount: restAreaData['isGoogleAccount'] as bool? ?? true,
      );
    }

    final adminData = await firestoreService.getDocument(
      FirestoreCollections.admins,
      emailPrefix,
    );

    if (adminData != null) {
      return UserInfo(
        email: email,
        role: adminData['role'] as String? ?? 'admin',
        isApproved: adminData['isApproved'] as bool? ?? false,
        isGoogleAccount: adminData['isGoogleAccount'] as bool? ?? true,
      );
    }
  } catch (e) {
    print('사용자 정보 확인 오류: $e');
  }

  return UserInfo(
    email: email,
    role: 'rest_area_manager',
    isApproved: false,
    isGoogleAccount: true, // 구글 로그인으로 추정
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
    ref.invalidate(currentUserInfoProvider);
  }

  /// 웹: Firebase Auth signInWithPopup 사용 (플러그인 불필요)
  /// 비웹: 미지원
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('구글 로그인은 웹에서만 지원됩니다.');
    }
    final credential = await firebaseAuth.signInWithPopup(
      GoogleAuthProvider(),
    );
    if (credential.user == null) {
      throw Exception('구글 로그인이 취소되었거나 실패했습니다.');
    }
    ref.invalidate(currentUserInfoProvider);
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
    ref.invalidate(currentUserInfoProvider);
  }

  Future<void> signUp(String email, String password) async {
    await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
