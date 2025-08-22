import '../../models/user_model.dart';
import '../../const_value.dart';

class PermissionUtils {
  /// 사용자가 특정 메뉴에 접근할 수 있는지 확인
  static bool hasAccess(AppUser user, MenuType menuType) {
    // 관리자는 모든 메뉴 접근 가능
    if (user.isMainAdmin) return true;
    
    // 승인된 사용자만 접근 가능
    if (!user.approved) return false;
    
    // 메뉴별 권한 체크
    switch (menuType) {
      case MenuType.notice:
        return user.role == 'admin' || user.role == 'manager';
      case MenuType.board:
        return true; // 모든 승인된 사용자
      case MenuType.anonymousBoard:
        return true; // 모든 승인된 사용자
      case MenuType.dataRequest:
        return true; // 모든 승인된 사용자
      case MenuType.work:
        return user.role == 'admin' || user.role == 'manager' || user.role == 'worker';
      case MenuType.company:
        return user.role == 'admin' || user.role == 'manager';
      default:
        return false;
    }
  }

  /// 사용자가 특정 메뉴에 글을 쓸 수 있는지 확인
  static bool hasWritePermission(AppUser user, MenuType menuType) {
    // 기본 접근 권한이 있어야 함
    if (!hasAccess(user, menuType)) return false;
    
    // 메뉴별 쓰기 권한 체크
    switch (menuType) {
      case MenuType.notice:
        return user.role == 'admin' || user.role == 'manager';
      case MenuType.board:
        return true; // 모든 승인된 사용자
      case MenuType.anonymousBoard:
        return true; // 모든 승인된 사용자
      case MenuType.dataRequest:
        return true; // 모든 승인된 사용자
      case MenuType.work:
        return user.role == 'admin' || user.role == 'manager' || user.role == 'worker';
      case MenuType.company:
        return user.role == 'admin' || user.role == 'manager';
      default:
        return false;
    }
  }
}
