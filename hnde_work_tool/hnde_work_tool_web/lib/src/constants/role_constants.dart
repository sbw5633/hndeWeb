/// 권한 순번(roleIdx) 상수
/// 0: 메인관리자, 1: 인사관리자, 2: 본사관리자, 3: 사업소관리자
/// 4: 본사직원, 5: 사업소직원, 6: 기타, 7: 미지정
class RoleConstants {
  RoleConstants._();

  static const int mainAdmin = 0;
  static const int hrAdmin = 1;
  static const int hqAdmin = 2;
  static const int branchAdmin = 3;
  static const int hqStaff = 4;
  static const int branchStaff = 5;
  static const int other = 6;
  static const int unspecified = 7;

  /// 4대보험 메뉴 접근 가능 (roleIdx <= 3)
  static bool canAccessInsurance(int roleIdx) => roleIdx <= branchAdmin;

  /// 본사+사업소 전체 현황 조회 가능 (메인관리자, 인사관리자만)
  static bool canViewAllBranches(int roleIdx) =>
      roleIdx <= hrAdmin;

  /// 본사만 조회 (본사관리자)
  static bool isHqAdminOnly(int roleIdx) => roleIdx == hqAdmin;

  /// 본인 사업소만 조회 (사업소관리자)
  static bool isBranchAdminOnly(int roleIdx) => roleIdx == branchAdmin;
}
