import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'dart:convert';

class EmployeeSelectInfoService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> fetchCollectionWithCache(String collection) async {
    final localKey = 'selectinfo_$collection';
    final localVerKey = 'selectinfo_${collection}_ver';
    // 1. 로컬에 데이터와 버전이 있는지 확인
    final localData = html.window.localStorage[localKey];
    final localVer = html.window.localStorage[localVerKey];

    // 2. Firestore에서 최신 updatedAt 확인
    final snapshot = await _firestore.collection(collection).orderBy('updatedAt', descending: true).limit(1).get();
    final latest = snapshot.docs.isNotEmpty ? snapshot.docs.first.data()['updatedAt']?.toString() : null;

    // 3. 버전이 같으면 로컬 데이터 사용
    if (localData != null && localVer != null && latest != null && localVer == latest) {
      try {
        final List<dynamic> list = List<Map<String, dynamic>>.from(
          (localData as String).isNotEmpty ? (jsonDecode(localData) as List) : []
        );
        return List<Map<String, dynamic>>.from(list);
      } catch (_) {}
    }

    // 4. Firestore에서 전체 데이터 받아오기
    final docs = await _firestore.collection(collection).orderBy('name').get();
    final result = docs.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    // 5. 로컬에 저장
    html.window.localStorage[localKey] = jsonEncode(result);
    if (latest != null) html.window.localStorage[localVerKey] = latest;
    return result;
  }

  static Future<List<Map<String, dynamic>>> getBranches() => fetchCollectionWithCache('branches');
  static Future<List<Map<String, dynamic>>> getPositions() => fetchCollectionWithCache('positions');
  static Future<List<Map<String, dynamic>>> getRanks() => fetchCollectionWithCache('ranks');
} 