import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class AdminSetupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 임시 관리자 계정 생성 (한 번만 실행)
  static Future<void> createTemporaryAdmin() async {
    try {
      // 이미 존재하는지 확인
      final existingAdmin = await _firestore
          .collection('Users')
          .where('email', isEqualTo: 'admin@hnde.com')
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        print('관리자 계정이 이미 존재합니다.');
        return;
      }

      // 임시 관리자 계정 생성
      final adminUser = AppUser(
        uid: 'temp_admin_uid',
        name: '관리자',
        email: 'admin@hnde.com',
        affiliation: '본사',
        role: '관리자',
        permissionLevel: PermissionLevel.appAdmin,
        approved: true,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      // Firestore에 저장
      await _firestore
          .collection('Users')
          .doc('temp_admin_uid')
          .set(adminUser.toJson());

      print('임시 관리자 계정이 생성되었습니다.');
      print('이메일: admin@hnde.com');
      print('비밀번호: 1234 (Firebase Auth에서 수동 설정 필요)');
    } catch (e) {
      print('관리자 계정 생성 실패: $e');
    }
  }

  /// 사용자 정보 조회
  static Future<AppUser?> getUserByEmail(String email) async {
    try {
      final doc = await _firestore
          .collection('Users')
          .where('email', isEqualTo: email)
          .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        return AppUser.fromJson(data, uid: doc.docs.first.id);
      }
      return null;
    } catch (e) {
      print('사용자 조회 실패: $e');
      return null;
    }
  }
} 