enum PermissionLevel {
  appAdmin(0),      // 앱 관리자 (최고 권한)
  hqAdmin(1),       // 본사 관리자
  branchAdmin(2),   // 지점 관리자
  manager(3),       // 팀장/과장급
  supervisor(4),    // 대리급
  employee(5),      // 일반 직원
  intern(6),        // 인턴/계약직
  guest(7),         // 게스트 (제한적 접근)
  suspended(8),     // 정지된 계정
  deleted(9);       // 삭제된 계정

  const PermissionLevel(this.level);
  final int level;

  // 숫자로부터 PermissionLevel 생성
  static PermissionLevel fromLevel(int level) {
    return PermissionLevel.values.firstWhere(
      (e) => e.level == level,
      orElse: () => PermissionLevel.employee,
    );
  }

  // 권한 비교 메서드 (숫자가 작을수록 권한이 높음)
  bool operator >=(PermissionLevel other) => level <= other.level;
  bool operator <=(PermissionLevel other) => level >= other.level;
  bool operator >(PermissionLevel other) => level < other.level;
  bool operator <(PermissionLevel other) => level > other.level;

  // 권한 레벨에 따른 설명
  String get description {
    switch (this) {
      case PermissionLevel.appAdmin:
        return '앱 관리자';
      case PermissionLevel.hqAdmin:
        return '본사 관리자';
      case PermissionLevel.branchAdmin:
        return '지점 관리자';
      case PermissionLevel.manager:
        return '팀장/과장급';
      case PermissionLevel.supervisor:
        return '대리급';
      case PermissionLevel.employee:
        return '일반 직원';
      case PermissionLevel.intern:
        return '인턴/계약직';
      case PermissionLevel.guest:
        return '게스트';
      case PermissionLevel.suspended:
        return '정지된 계정';
      case PermissionLevel.deleted:
        return '삭제된 계정';
    }
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String affiliation;
  final String role;           // 직책: "과장", "대리", "사원" 등
  final PermissionLevel permissionLevel;  // 권한 레벨 (0-9)
  final bool approved;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.affiliation,
    required this.role,
    required this.permissionLevel,
    required this.approved,
    this.createdAt,
    this.lastLoginAt,
  });

  // 기존 isMainAdmin과의 호환성을 위한 getter
  bool get isMainAdmin => permissionLevel == PermissionLevel.appAdmin;
  bool get isAdmin => permissionLevel <= PermissionLevel.hqAdmin;
  bool get isBranchAdmin => permissionLevel <= PermissionLevel.branchAdmin;
  bool get isManager => permissionLevel <= PermissionLevel.manager;

  factory AppUser.fromJson(Map<String, dynamic> json, {String? uid}) {
    // permissionLevel 필드를 우선적으로 확인
    PermissionLevel permissionLevel;
    
    // 1. permissionLevel 필드가 숫자로 저장된 경우 (최신 방식)
    if (json['permissionLevel'] != null) {
      final levelValue = json['permissionLevel'];
      if (levelValue is int) {
        permissionLevel = PermissionLevel.fromLevel(levelValue);
        print('permissionLevel 숫자로 파싱: $levelValue -> ${permissionLevel.description}');
      } else if (levelValue is String && int.tryParse(levelValue) != null) {
        permissionLevel = PermissionLevel.fromLevel(int.parse(levelValue));
        print('permissionLevel 문자열 숫자로 파싱: $levelValue -> ${permissionLevel.description}');
      } else {
        // 기본값으로 설정
        permissionLevel = PermissionLevel.employee;
        print('permissionLevel 파싱 실패, 기본값 사용: ${permissionLevel.description}');
      }
    } else {
      // 2. 기존 role 필드를 permissionLevel로 변환 (하위 호환성)
      final roleValue = json['role'] as String? ?? 'employee';
      print('permissionLevel 필드 없음, role 필드 사용: $roleValue');
      
      switch (roleValue) {
        case 'main_admin':
          permissionLevel = PermissionLevel.appAdmin;
          break;
        case 'hq_admin':
          permissionLevel = PermissionLevel.hqAdmin;
          break;
        case 'branch_admin':
          permissionLevel = PermissionLevel.branchAdmin;
          break;
        case 'employee':
          permissionLevel = PermissionLevel.employee;
          break;
        default:
          // 숫자로 저장된 경우
          if (int.tryParse(roleValue) != null) {
            permissionLevel = PermissionLevel.fromLevel(int.parse(roleValue));
          } else {
            // 기존 직책 문자열인 경우 기본값으로 설정
            permissionLevel = PermissionLevel.employee;
          }
      }
      print('role 필드로 변환된 permissionLevel: ${permissionLevel.description}');
    }

    return AppUser(
      uid: uid ?? json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      affiliation: json['affiliation'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      permissionLevel: permissionLevel,
      approved: json['approved'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.tryParse(json['lastLoginAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'affiliation': affiliation,
    'role': role,
    'permissionLevel': permissionLevel.level, // 숫자로 저장
    'approved': approved,
    'createdAt': createdAt?.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  // 권한 검사 메서드
  bool hasPermission(PermissionLevel requiredLevel) {
    return permissionLevel >= requiredLevel;
  }

  // 특정 권한 이상인지 확인
  bool isAtLeast(PermissionLevel level) {
    return permissionLevel >= level;
  }
} 