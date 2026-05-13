import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'firebase.dart';
import 'cache_manager.dart';

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
  static const String homePageConfig = 'home_page_config';
  static const String manufacturingBusiness = 'manufacturing_business';
  static const String foodBeverageBusiness = 'food_beverage_business';
  static const String businessTypes = 'business_types';
  static const String businessData = 'business_data'; // 동적 사업 데이터 저장용
}

// Firestore 서비스 기본 클래스
class FirestoreService {
  final FirebaseFirestore _db = firestore;
  final CacheManager _cache = CacheManager();

  /// 데이터의 해시값을 ETag로 생성
  String _generateEtag(dynamic data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 캐시 키 생성
  String _getCacheKey(String collection, String? docId, {String? orderBy, bool? descending, int? limit}) {
    final parts = [collection];
    if (docId != null) parts.add(docId);
    if (orderBy != null) parts.add('orderBy:$orderBy');
    if (descending != null) parts.add('desc:$descending');
    if (limit != null) parts.add('limit:$limit');
    return parts.join('|');
  }

  // 단일 문서 가져오기 (캐시 지원)
  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId, {bool forceRefresh = false}) async {
    final cacheKey = _getCacheKey(collection, docId);
    
    // 강제 새로고침이 아니고 캐시가 유효하면 캐시 반환
    if (!forceRefresh && _cache.hasValidCache(cacheKey)) {
      print('💾 캐시에서 데이터 반환: $cacheKey');
      return _cache.get<Map<String, dynamic>>(cacheKey);
    }

    try {
      print('📥 Firestore에서 데이터 가져오기 시작: collection=$collection, docId=$docId');
      final doc = await _db.collection(collection).doc(docId).get(
        const GetOptions(source: Source.serverAndCache),
      );
      print('📦 문서 존재 여부: ${doc.exists}');
      if (doc.exists) {
        final data = doc.data();
        final result = {'id': doc.id, ...doc.data()!};
        
        // ETag 생성 및 비교
        final newEtag = _generateEtag(result);
        final cachedEtag = _cache.getEtag(cacheKey);
        
        // 새로고침 시 ETag 비교: 변경되지 않았으면 캐시 유지
        if (forceRefresh && cachedEtag != null && cachedEtag == newEtag) {
          print('🔄 데이터 변경 없음, 캐시 유지: $cacheKey');
          return _cache.get<Map<String, dynamic>>(cacheKey);
        }
        
        // ETag가 다르거나 캐시가 없으면 업데이트
        _cache.set(cacheKey, result, etag: newEtag);
        
        if (forceRefresh && cachedEtag != null) {
          print('🔄 데이터 변경 감지, 캐시 업데이트: $cacheKey');
        } else {
          print('✅ 데이터 가져오기 성공: ${data?.keys}');
        }
        return result;
      }
      print('⚠️ 문서가 존재하지 않음');
      return null;
    } catch (e, stackTrace) {
      print('❌ 문서 가져오기 오류: $e');
      print('스택 트레이스: $stackTrace');
      return null;
    }
  }

  // 컬렉션의 모든 문서 가져오기 (정렬 가능, 캐시 지원)
  Future<List<Map<String, dynamic>>> getCollection(
    String collection, {
    String? orderBy,
    bool descending = false,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(collection, null, orderBy: orderBy, descending: descending, limit: limit);
    
    // 강제 새로고침이 아니고 캐시가 유효하면 캐시 반환
    if (!forceRefresh && _cache.hasValidCache(cacheKey)) {
      print('💾 캐시에서 컬렉션 데이터 반환: $cacheKey');
      return _cache.get<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }

    try {
      Query query = _db.collection(collection);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      final result = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return <String, dynamic>{'id': doc.id, if (data != null) ...data};
      }).toList();
      
      // ETag 생성 및 비교
      final newEtag = _generateEtag({'items': result});
      final cachedEtag = _cache.getEtag(cacheKey);
      
      // 새로고침 시 ETag 비교: 변경되지 않았으면 캐시 유지
      if (forceRefresh && cachedEtag != null && cachedEtag == newEtag) {
        print('🔄 컬렉션 데이터 변경 없음, 캐시 유지: $cacheKey');
        return _cache.get<List<Map<String, dynamic>>>(cacheKey) ?? [];
      }
      
      // ETag가 다르거나 캐시가 없으면 업데이트
      _cache.set(cacheKey, result, etag: newEtag);
      
      if (forceRefresh && cachedEtag != null) {
        print('🔄 컬렉션 데이터 변경 감지, 캐시 업데이트: $cacheKey');
      }
      
      return result;
    } catch (e) {
      print('컬렉션 가져오기 오류: $e');
      return [];
    }
  }

  // 실시간 스트림 가져오기
  Stream<List<Map<String, dynamic>>> getCollectionStream(
    String collection, {
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    try {
      Query query = _db.collection(collection);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return <String, dynamic>{'id': doc.id, if (data != null) ...data};
          }).toList());
    } catch (e) {
      print('스트림 가져오기 오류: $e');
      return Stream.value([]);
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
        // 캐시 무효화 (캐시 키를 삭제)
        final cacheKey = _getCacheKey(collection, null);
        _cache.remove(cacheKey);
        return docRef.id;
      }
    } catch (e) {
      print('문서 저장 오류: $e');
      rethrow;
    }
  }
}
