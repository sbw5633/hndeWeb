import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/board_post_model.dart';

class BoardPostService {
  static final _firestore = FirebaseFirestore.instance;
  static final _collection = _firestore.collection('posts');

  /// 게시물 등록
  static Future<void> addBoardPost(BoardPost post) async {
    await _collection.doc(post.id).set(post.toJson());
  }

  /// 게시물 목록 조회 (최신순)
  static Future<List<BoardPost>> getBoardPosts({int limit = 20}) async {
    final snapshot = await _collection.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map((doc) => BoardPost.fromJson(doc.data(), id: doc.id)).toList();
  }

  /// 단일 게시물 조회
  static Future<BoardPost?> getBoardPostById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return BoardPost.fromJson(doc.data()!, id: doc.id);
  }
} 