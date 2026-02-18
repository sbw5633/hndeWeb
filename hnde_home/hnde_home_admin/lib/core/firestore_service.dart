import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase.dart';

// Firestore 컬렉션 이름 상수
class FirestoreCollections {
  static const String ceoGreeting = 'ceo_greeting';
  static const String history = 'history';
  static const String vision = 'vision';
  static const String location = 'location';
  static const String restAreas = 'rest_areas';
  static const String ciInfo = 'ci_info';
  static const String pressReleases = 'press_releases';
  static const String customerEvents = 'customer_events';
  static const String notices = 'notices';
  static const String customerStories = 'customer_stories';
  static const String businessProposals = 'business_proposals';
  static const String recruitment = 'recruitment';
  static const String homePage = 'home_page';
  static const String restAreaManagers = 'rest_area_managers';
  static const String admins = 'admins';
  static const String manufacturingBusiness = 'manufacturing_business';
  static const String foodBeverageBusiness = 'food_beverage_business';
  static const String businessTypes = 'business_types';
  static const String businessData = 'business_data'; // 동적 사업 데이터 저장용
}

// Firestore 서비스 기본 클래스
class FirestoreService {
  final FirebaseFirestore _db = firestore;

  // 단일 문서 가져오기
  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId) async {
    try {
      final doc = await _db.collection(collection).doc(docId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      print('문서 가져오기 오류: $e');
      return null;
    }
  }

  // 컬렉션의 모든 문서 가져오기
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    try {
      final snapshot = await _db.collection(collection).get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('컬렉션 가져오기 오류: $e');
      return [];
    }
  }

  // 문서 저장 (ID가 있으면 업데이트, 없으면 생성)
  Future<String> saveDocument(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    try {
      if (docId != null) {
        await _db
            .collection(collection)
            .doc(docId)
            .set(data, SetOptions(merge: true));
        return docId;
      } else {
        final docRef = await _db.collection(collection).add(data);
        return docRef.id;
      }
    } catch (e) {
      print('문서 저장 오류: $e');
      rethrow;
    }
  }

  // 문서 삭제
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _db.collection(collection).doc(docId).delete();
    } catch (e) {
      print('문서 삭제 오류: $e');
      rethrow;
    }
  }

  // 단일 문서 업데이트 (ID 필수)
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.collection(collection).doc(docId).update(data);
    } catch (e) {
      print('문서 업데이트 오류: $e');
      rethrow;
    }
  }
}
