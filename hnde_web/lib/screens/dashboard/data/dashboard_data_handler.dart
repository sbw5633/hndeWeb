import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/board_post_model.dart';
import '../../../models/user_model.dart';

class DashboardDataHandler {
  // 실시간 리스너들
  StreamSubscription<QuerySnapshot>? _noticesSubscription;
  StreamSubscription<QuerySnapshot>? _dataRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _allDataRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _weeklyNoticesSubscription;
  StreamSubscription<QuerySnapshot>? _weeklyBoardsSubscription;

  // 데이터 리스트들
  List<BoardPost> _recentNotices = [];
  List<BoardPost> _recentDataRequests = [];
  List<BoardPost> _allDataRequests = [];
  List<BoardPost> _weeklyNotices = [];
  List<BoardPost> _weeklyBoards = [];

  // Getters
  List<BoardPost> get recentNotices => _recentNotices;
  List<BoardPost> get recentDataRequests => _recentDataRequests;
  List<BoardPost> get allDataRequests => _allDataRequests;
  List<BoardPost> get weeklyNotices => _weeklyNotices;
  List<BoardPost> get weeklyBoards => _weeklyBoards;

  // 콜백 함수들
  Function(List<BoardPost>)? onRecentNoticesChanged;
  Function(List<BoardPost>)? onRecentDataRequestsChanged;
  Function(List<BoardPost>)? onAllDataRequestsChanged;
  Function(List<BoardPost>)? onWeeklyNoticesChanged;
  Function(List<BoardPost>)? onWeeklyBoardsChanged;
  Function()? onInitialLoadComplete;

  void setupRealtimeListeners(AppUser user) {
    print('실시간 리스너 설정 시작 - 사용자 권한: ${user.permissionLevel.level}');

    // 공지사항 실시간 리스너
    _noticesSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'notice')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleNoticesUpdate(snapshot, user);
    });

    // 자료요청 실시간 리스너
    _dataRequestsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'dataRequest')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleDataRequestsUpdate(snapshot, user);
    });

    // 모든 자료요청 실시간 리스너 (미제출 확인용)
    _allDataRequestsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'dataRequest')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleAllDataRequestsUpdate(snapshot, user);
    });

    // 1주일 이내 공지사항 실시간 리스너 (알림센터용)
    _weeklyNoticesSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'notice')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleWeeklyNoticesUpdate(snapshot, user);
    });

    // 1주일 이내 게시물 실시간 리스너 (알림센터용)
    _weeklyBoardsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'board')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleWeeklyBoardsUpdate(snapshot, user);
    });
  }

  void _handleNoticesUpdate(QuerySnapshot snapshot, AppUser user) {
    print('공지사항 업데이트 감지: ${snapshot.docs.length}개 문서');
    
    final filteredNotices = snapshot.docs
        .map((doc) => BoardPost.fromJson(doc.data() as Map<String, dynamic>))
        .where((post) {
          // 공지사항은 모든 로그인된 사용자가 읽기 가능
          // 권한 레벨 체크는 하지 않음 (쓰기 권한과 별개)
          
          print('공지사항 필터링: ${post.title}');
          print('  - 사용자: ${user.name} (${user.permissionLevel.description})');
          
          // 사업소(소속) 체크만 수행
          final targetGroup = post.targetGroup;
          final userAffiliation = user.affiliation;
          final isTargetGroupMatch = _isTargetGroupMatch(targetGroup, userAffiliation, user);
          
          print('  - 대상 그룹: $targetGroup');
          print('  - 사용자 소속: $userAffiliation');
          print('  - 소속 매치: $isTargetGroupMatch');
          print('  - 최종 결과: $isTargetGroupMatch');
          print('---');
          
          return isTargetGroupMatch;
        })
        .take(2)
        .toList();

    print('필터링된 공지사항 개수: ${filteredNotices.length}');
    _recentNotices = filteredNotices;
    onRecentNoticesChanged?.call(_recentNotices);
    onInitialLoadComplete?.call();
  }

  void _handleDataRequestsUpdate(QuerySnapshot snapshot, AppUser user) {
    print('자료요청 업데이트 감지: ${snapshot.docs.length}개 문서');
    
    final filteredDataRequests = snapshot.docs
        .map((doc) => BoardPost.fromJson(doc.data() as Map<String, dynamic>))
        .where((post) {
          // 1. 권한 레벨 체크
          final requiredLevel = post.extra['requiredPermissionLevel'] as int? ?? 5;
          final hasPermission = user.permissionLevel.level <= requiredLevel;
          
          // 2. 사업소(소속) 체크
          final targetGroup = post.targetGroup;
          final userAffiliation = user.affiliation;
          final isTargetGroupMatch = _isTargetGroupMatch(targetGroup, userAffiliation, user);
          
          return hasPermission && isTargetGroupMatch;
        })
        .take(2)
        .toList();

    _recentDataRequests = filteredDataRequests;
    onRecentDataRequestsChanged?.call(_recentDataRequests);
    onInitialLoadComplete?.call();
  }

  void _handleAllDataRequestsUpdate(QuerySnapshot snapshot, AppUser user) {
    print('모든 자료요청 업데이트 감지: ${snapshot.docs.length}개 문서');
    
    final filteredDataRequests = snapshot.docs
        .map((doc) => BoardPost.fromJson(doc.data() as Map<String, dynamic>))
        .where((post) {
          // 1. 권한 레벨 체크
          final requiredLevel = post.extra['requiredPermissionLevel'] as int? ?? 5;
          final hasPermission = user.permissionLevel.level <= requiredLevel;
          
          // 2. 사업소(소속) 체크
          final targetGroup = post.targetGroup;
          final userAffiliation = user.affiliation;
          final isTargetGroupMatch = _isTargetGroupMatch(targetGroup, userAffiliation, user);
          
          return hasPermission && isTargetGroupMatch;
        })
        .toList();

    _allDataRequests = filteredDataRequests;
    onAllDataRequestsChanged?.call(_allDataRequests);
  }

  void _handleWeeklyNoticesUpdate(QuerySnapshot snapshot, AppUser user) {
    print('1주일 이내 공지사항 업데이트 감지: ${snapshot.docs.length}개 문서');
    
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    final filteredNotices = snapshot.docs
        .map((doc) => BoardPost.fromJson(doc.data() as Map<String, dynamic>))
        .where((post) {
          // 1. 1주일 이내 체크
          if (post.createdAt.isBefore(oneWeekAgo)) return false;
          
          // 2. 권한 레벨 체크
          final requiredLevel = post.extra['requiredPermissionLevel'] as int? ?? 5;
          final hasPermission = user.permissionLevel.level <= requiredLevel;
          
          // 3. 사업소(소속) 체크
          final targetGroup = post.targetGroup;
          final userAffiliation = user.affiliation;
          final isTargetGroupMatch = _isTargetGroupMatch(targetGroup, userAffiliation, user);
          
          return hasPermission && isTargetGroupMatch;
        })
        .toList();

    _weeklyNotices = filteredNotices;
    onWeeklyNoticesChanged?.call(_weeklyNotices);
  }

  void _handleWeeklyBoardsUpdate(QuerySnapshot snapshot, AppUser user) {
    print('1주일 이내 게시물 업데이트 감지: ${snapshot.docs.length}개 문서');
    
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    final filteredBoards = snapshot.docs
        .map((doc) => BoardPost.fromJson(doc.data() as Map<String, dynamic>))
        .where((post) {
          // 1. 1주일 이내 체크
          if (post.createdAt.isBefore(oneWeekAgo)) return false;
          
          // 2. 권한 레벨 체크
          final requiredLevel = post.extra['requiredPermissionLevel'] as int? ?? 5;
          final hasPermission = user.permissionLevel.level <= requiredLevel;
          
          return hasPermission;
        })
        .toList();

    _weeklyBoards = filteredBoards;
    onWeeklyBoardsChanged?.call(_weeklyBoards);
  }

  /// 타겟 그룹과 사용자 소속이 매치되는지 확인
  bool _isTargetGroupMatch(String targetGroup, String userAffiliation, AppUser user) {
    // 앱 관리자는 모든 공지사항 확인 가능
    if (user.permissionLevel == PermissionLevel.appAdmin) {
      return true;
    }
    
    // 본사 관리자는 본사 공지사항과 전체 공지사항 확인 가능
    if (user.permissionLevel == PermissionLevel.hqAdmin) {
      return targetGroup == '전체' || targetGroup == '본사' || targetGroup == userAffiliation;
    }
    
    // 일반 직원은 전체 본인 소속 공지사항만 확인 가능
    return targetGroup == userAffiliation || targetGroup=='전체' || targetGroup=="";
  }

  /// 미제출 자료요청 개수 계산
  int getUnsubmittedDataRequestsCount(String userAffiliation) {
    return _allDataRequests.where((request) {
      final selectedBranches = request.extra['selectedBranches'] as List<dynamic>? ?? [];
      if (!selectedBranches.contains(userAffiliation)) return false;
      
      final responses = request.responses;
      final userResponse = responses[userAffiliation] as Map<String, dynamic>?;
      return userResponse == null || userResponse['submittedAt'] == null;
    }).length;
  }

  void dispose() {
    _noticesSubscription?.cancel();
    _dataRequestsSubscription?.cancel();
    _allDataRequestsSubscription?.cancel();
    _weeklyNoticesSubscription?.cancel();
    _weeklyBoardsSubscription?.cancel();
  }
}
