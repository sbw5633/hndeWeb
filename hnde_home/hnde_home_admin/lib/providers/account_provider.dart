import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firestore_service.dart';
import '../core/firebase.dart';
import '../core/firestore_service.dart' as fs;

// 계정 정보 모델
class AccountInfo {
  final String id; // Firestore doc ID (restAreaId 또는 admin email prefix)
  final String email;
  final String? restAreaId;
  final String? restAreaName;
  final String? managerName; // 담당자명
  final String role; // 'admin' or 'rest_area_manager'

  AccountInfo({
    required this.id,
    required this.email,
    this.restAreaId,
    this.restAreaName,
    this.managerName,
    required this.role,
  });

  factory AccountInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return AccountInfo(
      id: id,
      email: data['email'] as String,
      restAreaId: data['restAreaId'] as String?,
      restAreaName: data['restAreaName'] as String?,
      managerName: data['managerName'] as String?,
      role: data['role'] as String? ?? 'rest_area_manager',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'restAreaId': restAreaId,
      'restAreaName': restAreaName,
      'managerName': managerName,
      'role': role,
    };
  }
}

// 모든 계정 목록 Provider (전체 관리자용)
final accountListProvider =
    FutureProvider.autoDispose<List<AccountInfo>>((ref) async {
  final service = FirestoreService();
  
  // 휴게소 관리자 계정 가져오기
  final restAreaManagers = await service.getCollection(
    fs.FirestoreCollections.restAreaManagers,
  );
  
  // 일반 관리자 계정 가져오기 (전체 관리자 제외)
  final admins = await service.getCollection(
    fs.FirestoreCollections.admins,
  );
  
  final accounts = <AccountInfo>[];
  
  // 휴게소 관리자 계정 추가
  for (var data in restAreaManagers) {
    accounts.add(AccountInfo.fromFirestore(data, data['id'] as String));
  }
  
  // 일반 관리자 계정 추가 (전체 관리자 제외)
  for (var data in admins) {
    final email = data['email'] as String? ?? '';
    if (email != 'admin@hnde.co.kr' && email != 'hnde@hnde.co.kr') {
      accounts.add(AccountInfo.fromFirestore(data, data['id'] as String));
    }
  }
  
  return accounts;
});

// 계정 관리 Controller
final accountControllerProvider =
    Provider((ref) => AccountController(ref));

class AccountController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  AccountController(this.ref);

  // 계정 정보 업데이트
  Future<void> updateAccount(AccountInfo account) async {
    if (account.role == 'rest_area_manager') {
      await _service.updateDocument(
        fs.FirestoreCollections.restAreaManagers,
        account.id,
        account.toFirestore(),
      );
    } else {
      await _service.updateDocument(
        fs.FirestoreCollections.admins,
        account.id,
        account.toFirestore(),
      );
    }
    ref.invalidate(accountListProvider);
  }

  // 비밀번호 재설정 이메일 보내기
  Future<void> sendPasswordResetEmail(String email) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }
}

