import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 전체 통계 캐시
  static Map<String, int>? _commentCounts;
  static Map<String, int>? _likeCounts;
  static StreamSubscription? _commentsSubscription;
  static StreamSubscription? _likesSubscription;
  
  // 초기화 여부
  static bool _isInitialized = false;

  /// 전체 통계 초기화 (한 번만 실행)
  static void initializeStats() {
    if (_isInitialized) return;
    
    print('=== PostStatsService 초기화 시작 ===');
    
    // 댓글 통계 구독 (전체 댓글을 한 번에 가져와서 postId별로 그룹핑)
    _commentsSubscription = _firestore
        .collection('comments')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _commentCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final postId = doc.data()['postId'] as String;
        _commentCounts![postId] = (_commentCounts![postId] ?? 0) + 1;
      }
      print('=== 댓글 통계 업데이트 ===');
      print('총 댓글 수: ${_commentCounts!.length}개 게시물');
      print('댓글 통계: $_commentCounts');
    });
    
    // 좋아요 통계 구독 (전체 좋아요를 한 번에 가져와서 postId별로 그룹핑)
    _likesSubscription = _firestore
        .collection('likes')
        .snapshots()
        .listen((snapshot) {
      _likeCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isDeleted = data['isDeleted'] as bool? ?? false;
        if (!isDeleted) { // 삭제되지 않은 좋아요만 카운트
          final postId = data['postId'] as String;
          _likeCounts![postId] = (_likeCounts![postId] ?? 0) + 1;
        }
      }
      print('=== 좋아요 통계 업데이트 ===');
      print('총 좋아요 수: ${_likeCounts!.length}개 게시물');
      print('좋아요 통계: $_likeCounts');
    });
    
    _isInitialized = true;
    print('=== PostStatsService 초기화 완료 ===');
  }
  
  /// 게시물의 댓글 수 가져오기 (캐시된 데이터)
  static Stream<int> getCommentCountStream(String postId) {
    // 초기화되지 않았다면 초기화
    if (!_isInitialized) {
      initializeStats();
    }
    
    // 간단한 Stream 생성 - 캐시된 데이터를 기반으로
    return Stream.periodic(const Duration(milliseconds: 100))
        .map((_) => _commentCounts?[postId] ?? 0)
        .distinct(); // 값이 변경될 때만 emit
  }

  /// 게시물의 좋아요 수 가져오기 (캐시된 데이터)
  static Stream<int> getLikeCountStream(String postId) {
    // 초기화되지 않았다면 초기화
    if (!_isInitialized) {
      initializeStats();
    }
    
    // 간단한 Stream 생성 - 캐시된 데이터를 기반으로
    return Stream.periodic(const Duration(milliseconds: 100))
        .map((_) => _likeCounts?[postId] ?? 0)
        .distinct(); // 값이 변경될 때만 emit
  }

  /// 게시물 좋아요/취소 (likes 컬렉션 사용)
  static Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final likeId = '${postId}_$userId';
    final likeRef = _firestore.collection('likes').doc(likeId);
    
    if (isLiked) {
      // 좋아요 추가
      await likeRef.set({
        'postId': postId,
        'userId': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'isDeleted': false,
      });
    } else {
      // 좋아요 제거 (소프트 삭제)
      await likeRef.update({
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// 게시물 좋아요 상태 확인 (likes 컬렉션 사용)
  static Future<bool> isLiked(String postId, String userId) async {
    final likeId = '${postId}_$userId';
    final doc = await _firestore.collection('likes').doc(likeId).get();
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final isDeleted = data['isDeleted'] as bool? ?? false;
    return !isDeleted;
  }
  
  /// 게시물 좋아요 상태 Stream (실시간)
  static Stream<bool> getLikeStatusStream(String postId, String userId) {
    final likeId = '${postId}_$userId';
    return _firestore
        .collection('likes')
        .doc(likeId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final data = doc.data()!;
          final isDeleted = data['isDeleted'] as bool? ?? false;
          return !isDeleted;
        });
  }
  
  /// 모든 캐시 제거 (앱 종료 시 사용)
  static void clearAllCache() {
    _commentsSubscription?.cancel();
    _likesSubscription?.cancel();
    _commentCounts = null;
    _likeCounts = null;
    _isInitialized = false;
  }
  
  /// 캐시 상태 확인 (디버깅용)
  static Map<String, dynamic> getCacheStats() {
    return {
      'isInitialized': _isInitialized,
      'commentCounts': _commentCounts?.length ?? 0,
      'likeCounts': _likeCounts?.length ?? 0,
      'commentsSubscriptionActive': _commentsSubscription != null,
      'likesSubscriptionActive': _likesSubscription != null,
    };
  }
}
