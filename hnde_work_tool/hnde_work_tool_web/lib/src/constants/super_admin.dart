import 'role_constants.dart';

/// 하드코딩 전체관리자(클라이언트·규칙 보조용).
class SuperAdmin {
  SuperAdmin._();

  static const String bypassEmail = 'hndebw@gmail.com';

  static bool isSuperAdminEmail(String? email) {
    final String e = (email ?? '').trim().toLowerCase();
    return e == bypassEmail;
  }

  /// Firestore·REST 등에서 `true`가 아닌 타입으로 들어오는 경우 보정.
  static bool coerceFirestoreBool(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String s = value.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  /// `mainAdmin` 플래그, [RoleConstants.mainAdmin] 역할, 또는 예외 이메일이면 전체관리자로 본다.
  static bool effectiveMainAdmin({
    dynamic profileMainAdmin,
    String? profileEmail,
    String? authEmail,
    int? roleIdx,
  }) {
    if (coerceFirestoreBool(profileMainAdmin)) {
      return true;
    }
    if (roleIdx != null && roleIdx == RoleConstants.mainAdmin) {
      return true;
    }
    if (isSuperAdminEmail(authEmail)) {
      return true;
    }
    if (isSuperAdminEmail(profileEmail)) {
      return true;
    }
    return false;
  }
}
