import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/comment_model.dart';

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 댓글 목록 가져오기 (실시간)
  static Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson(doc.data(), id: doc.id))
            .toList());
  }

  /// 댓글 작성
  static Future<Comment> createComment({
    required String postId,
    String? parentId,
    required String authorId,
    required String authorName,
    required String content,
    bool isAnonymous = false,
  }) async {
    print('=== CommentService.createComment 시작 ===');
    print('postId: $postId');
    print('parentId: $parentId');
    print('authorId: $authorId');
    print('authorName: $authorName');
    print('content: $content');
    print('isAnonymous: $isAnonymous');

    final now = DateTime.now();
    final comment = Comment(
      id: '', // Firestore에서 자동 생성
      postId: postId,
      parentId: parentId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      createdAt: now,
      updatedAt: now,
      isAnonymous: isAnonymous,
    );

    print('=== Comment 객체 생성 완료 ===');
    print('toJson(): ${comment.toJson()}');

    try {
      print('=== Firestore에 댓글 추가 시작 ===');
      final docRef = await _firestore.collection('comments').add(comment.toJson());
      print('=== Firestore 댓글 추가 성공 ===');
      print('생성된 문서 ID: ${docRef.id}');
      
      final result = comment.copyWith(id: docRef.id);
      print('=== 최종 댓글 객체 ===');
      print('ID: ${result.id}');
      
      return result;
    } catch (e) {
      print('=== Firestore 댓글 추가 실패 ===');
      print('오류: $e');
      print('오류 타입: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 댓글 수정
  static Future<void> updateComment({
    required String commentId,
    required String content,
  }) async {
    await _firestore.collection('comments').doc(commentId).update({
      'content': content,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 댓글 삭제 (소프트 삭제)
  static Future<void> deleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'isDeleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 댓글 좋아요/취소
  static Future<void> toggleLike({
    required String commentId,
    required String userId,
    required bool isLiked,
  }) async {
    final docRef = _firestore.collection('comments').doc(commentId);
    
    if (isLiked) {
      // 좋아요 추가
      await docRef.update({
        'likes': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      // 좋아요 제거
      await docRef.update({
        'likes': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// 댓글 개수 가져오기
  static Future<int> getCommentCount(String postId) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .where('isDeleted', isEqualTo: false)
        .get();
    
    return snapshot.docs.length;
  }
}
