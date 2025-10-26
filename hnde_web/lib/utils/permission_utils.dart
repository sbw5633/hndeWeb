import '../../models/user_model.dart';
import '../../const_value.dart';

class PermissionUtils {
  /// 사용자가 특정 메뉴에 접근할 수 있는지 확인
  static bool hasAccess(AppUser user, MenuType menuType) {
    print('=== 접근 권한 체크 시작 ===');
    print('사용자: ${user.name} (${user.email})');
    print('권한 레벨: ${user.permissionLevel.level} (${user.permissionLevel.description})');
    print('승인 상태: ${user.approved}');
    print('메뉴 타입: $menuType');
    
    // 앱 관리자는 모든 메뉴 접근 가능
    if (user.permissionLevel == PermissionLevel.appAdmin) {
      print('앱 관리자 - 모든 메뉴 접근 가능');
      return true;
    }
    
    // 승인된 사용자만 접근 가능
    if (!user.approved) {
      print('승인되지 않은 사용자 - 접근 거부');
      return false;
    }
    
    // 메뉴별 권한 체크
    bool accessResult = false;
    switch (menuType) {
      case MenuType.notice:
        accessResult = true; // 모든 승인된 사용자
        print('공지사항 접근 권한: $accessResult (모든 승인된 사용자)');
        break;
      case MenuType.board:
        accessResult = true; // 모든 승인된 사용자
        print('게시판 접근 권한: $accessResult');
        break;
      case MenuType.anonymousBoard:
        accessResult = true; // 모든 승인된 사용자
        print('익명게시판 접근 권한: $accessResult');
        break;
      case MenuType.dataRequest:
        accessResult = true; // 모든 승인된 사용자
        print('자료요청 접근 권한: $accessResult');
        break;
      case MenuType.work:
        accessResult = user.permissionLevel >= PermissionLevel.manager; // 팀장급 이상
        print('업무 접근 권한: $accessResult (필요: manager 이상, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.company:
        accessResult = user.permissionLevel >= PermissionLevel.hqAdmin; // 본사 관리자 이상
        print('회사정보 접근 권한: $accessResult (필요: hqAdmin 이상, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.admin:
        accessResult = user.permissionLevel == PermissionLevel.appAdmin; // 앱 관리자만
        print('관리자 접근 권한: $accessResult (필요: appAdmin, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.dashboard:
        accessResult = true; // 모든 승인된 사용자
        print('대시보드 접근 권한: $accessResult');
        break;
    }
    
    print('최종 접근 권한 결과: $accessResult');
    print('=== 접근 권한 체크 종료 ===');
    return accessResult;
  }

  /// 사용자가 특정 메뉴에 글을 쓸 수 있는지 확인
  static bool hasWritePermission(AppUser user, MenuType menuType) {
    print('=== 쓰기 권한 체크 시작 ===');
    print('사용자: ${user.name} (${user.email})');
    print('권한 레벨: ${user.permissionLevel.level} (${user.permissionLevel.description})');
    print('승인 상태: ${user.approved}');
    print('메뉴 타입: $menuType');
    
    // 기본 접근 권한이 있어야 함
    final hasAccessResult = hasAccess(user, menuType);
    print('기본 접근 권한: $hasAccessResult');
    if (!hasAccessResult) {
      print('기본 접근 권한 없음 - 쓰기 권한 거부');
      return false;
    }
    
    // 메뉴별 쓰기 권한 체크
    bool writePermission = false;
    switch (menuType) {
      case MenuType.notice:
        writePermission = user.permissionLevel >= PermissionLevel.hqAdmin; // 본사 관리자 이상
        print('공지사항 쓰기 권한: $writePermission (필요: hqAdmin 이상, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.board:
        writePermission = true; // 모든 승인된 사용자
        print('게시판 쓰기 권한: $writePermission');
        break;
      case MenuType.anonymousBoard:
        writePermission = true; // 모든 승인된 사용자
        print('익명게시판 쓰기 권한: $writePermission');
        break;
      case MenuType.dataRequest:
        writePermission = true; // 모든 승인된 사용자
        print('자료요청 쓰기 권한: $writePermission');
        break;
      case MenuType.work:
        writePermission = user.permissionLevel >= PermissionLevel.manager; // 팀장급 이상
        print('업무 쓰기 권한: $writePermission (필요: manager 이상, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.company:
        writePermission = user.permissionLevel == PermissionLevel.appAdmin; // 앱 관리자만
        print('회사정보 쓰기 권한: $writePermission (필요: appAdmin, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.admin:
        writePermission = user.permissionLevel == PermissionLevel.appAdmin; // 앱 관리자만
        print('관리자 쓰기 권한: $writePermission (필요: appAdmin, 현재: ${user.permissionLevel.description})');
        break;
      case MenuType.dashboard:
        writePermission = false; // 대시보드는 읽기 전용
        print('대시보드 쓰기 권한: $writePermission (읽기 전용)');
        break;
    }
    
    print('최종 쓰기 권한 결과: $writePermission');
    print('=== 쓰기 권한 체크 종료 ===');
    return writePermission;
  }

  /// 권한 레벨에 따른 메뉴 접근 권한 확인
  static bool hasPermissionLevel(AppUser user, PermissionLevel requiredLevel) {
    return user.hasPermission(requiredLevel);
  }

  /// 특정 권한 이상인지 확인
  static bool isAtLeast(AppUser user, PermissionLevel level) {
    return user.isAtLeast(level);
  }
}
