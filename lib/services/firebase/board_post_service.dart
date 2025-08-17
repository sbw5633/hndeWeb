import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/board_post_model.dart';

class BoardPostService {
  static final _firestore = FirebaseFirestore.instance;
  static final _collection = _firestore.collection('posts');

  /// 게시물 등록
  static Future<void> addBoardPost(BoardPost post) async {
    try {
      debugPrint("=== Firestore 저장 시작 ===");
      debugPrint("게시물 ID: ${post.id}");
      debugPrint("게시물 타입: ${post.type}");
      debugPrint("게시물 제목: ${post.title}");
      
      // Firestore 연결 상태 확인
      debugPrint("Firestore 네트워크 활성화 중...");
      await _firestore.enableNetwork();
      debugPrint("Firestore 네트워크 활성화 완료");
      
      // 컬렉션 존재 여부 확인
      debugPrint("컬렉션 확인 중...");
      final collectionRef = _firestore.collection('posts');
      debugPrint("컬렉션 참조 생성 완료");
      
      // 데이터 저장
      debugPrint("Firestore에 데이터 저장 시작...");
      final postData = post.toJson();
      debugPrint("저장할 데이터: $postData");
      
      await collectionRef.doc(post.id).set(postData).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint("Firestore 저장 타임아웃!");
          throw Exception('Firestore 저장 타임아웃');
        },
      );
      debugPrint("=== Firestore 데이터 저장 완료! ===");
      
    } catch (e) {
      debugPrint("=== Firestore 저장 오류 ===");
      debugPrint("오류 타입: ${e.runtimeType}");
      debugPrint("오류 메시지: $e");
      
      // 구체적인 오류 처리
      if (e.toString().contains('permission-denied')) {
        throw Exception('Firestore 권한 오류: 보안 규칙을 확인해주세요');
      } else if (e.toString().contains('unavailable')) {
        throw Exception('Firestore 서비스 불가: 네트워크 연결을 확인해주세요');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Firestore 타임아웃: 네트워크 상태를 확인해주세요');
      } else {
        throw Exception('게시물 저장 실패: $e');
      }
    }
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