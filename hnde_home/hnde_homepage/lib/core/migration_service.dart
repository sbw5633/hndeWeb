import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase 설정 (Dev)
const Map<String, String> _firebaseConfigDev = {
  'apiKey': 'AIzaSyBChBQLN_ovjGB6V-Znio_T_kgCvm92dBQ',
  'authDomain': 'hnde-homepage-db.firebaseapp.com',
  'projectId': 'hnde-homepage-db',
  'storageBucket': 'hnde-homepage-db.firebasestorage.app',
  'messagingSenderId': '897182023039',
  'appId': '1:897182023039:web:5e8b721c20a883ba38ae4a',
  'measurementId': 'G-CXN9CY1SRT',
};

// Firebase 설정 (Prod)
const Map<String, String> _firebaseConfigProd = {
  'apiKey': 'AIzaSyAYNbgb50N79TNvKOj55y2rqirXKwVwBLU',
  'authDomain': 'hnde-homepage-prod.firebaseapp.com',
  'projectId': 'hnde-homepage-prod',
  'storageBucket': 'hnde-homepage-prod.firebasestorage.app',
  'messagingSenderId': '639763470001',
  'appId': '1:639763470001:web:e0df48613776f5ca687490',
  'measurementId': 'G-P3XD3NZBKM',
};

/// 마이그레이션용: 두 프로젝트 동시 초기화
Future<Map<String, FirebaseApp>> _initFirebaseForMigration() async {
  // Dev 프로젝트 초기화
  final devApp = await Firebase.initializeApp(
    name: 'dev_migration',
    options: FirebaseOptions(
      apiKey: _firebaseConfigDev['apiKey']!,
      authDomain: _firebaseConfigDev['authDomain']!,
      projectId: _firebaseConfigDev['projectId']!,
      storageBucket: _firebaseConfigDev['storageBucket']!,
      messagingSenderId: _firebaseConfigDev['messagingSenderId']!,
      appId: _firebaseConfigDev['appId']!,
      measurementId: _firebaseConfigDev['measurementId']!,
    ),
  );

  // Prod 프로젝트 초기화
  final prodApp = await Firebase.initializeApp(
    name: 'prod_migration',
    options: FirebaseOptions(
      apiKey: _firebaseConfigProd['apiKey']!,
      authDomain: _firebaseConfigProd['authDomain']!,
      projectId: _firebaseConfigProd['projectId']!,
      storageBucket: _firebaseConfigProd['storageBucket']!,
      messagingSenderId: _firebaseConfigProd['messagingSenderId']!,
      appId: _firebaseConfigProd['appId']!,
      measurementId: _firebaseConfigProd['measurementId']!,
    ),
  );

  return {'dev': devApp, 'prod': prodApp};
}

/// 개발서버의 history 컬렉션을 실서버로 마이그레이션
Future<void> migrateHistoryData() async {
  try {
    print('🔄 마이그레이션 시작...');

    // 두 프로젝트 초기화
    final apps = await _initFirebaseForMigration();
    final devDb = FirebaseFirestore.instanceFor(app: apps['dev']!);
    final prodDb = FirebaseFirestore.instanceFor(app: apps['prod']!);

    // 개발서버에서 데이터 읽기
    print('📥 개발서버에서 history 데이터 읽는 중...');
    final snapshot = await devDb.collection('history').get();

    if (snapshot.docs.isEmpty) {
      print('⚠️  개발서버에 history 데이터가 없습니다.');
      return;
    }

    print('📤 실서버로 데이터 쓰는 중... (${snapshot.docs.length}개 문서)');

    // 배치로 처리 (Firestore 배치 제한: 500개)
    int totalCount = 0;
    WriteBatch? batch = prodDb.batch();
    int batchCount = 0;

    for (var doc in snapshot.docs) {
      final docRef = prodDb.collection('history').doc(doc.id);
      batch!.set(docRef, doc.data());
      batchCount++;
      totalCount++;

      // 500개마다 배치 커밋
      if (batchCount == 500) {
        await batch.commit();
        print('  ✅ ${totalCount}개 문서 처리 중...');
        batch = prodDb.batch();
        batchCount = 0;
      }
    }

    // 마지막 배치 커밋
    if (batchCount > 0) {
      await batch!.commit();
    }

    print('✅ 마이그레이션 완료! (총 ${totalCount}개 문서)');
  } catch (e, stackTrace) {
    print('❌ 마이그레이션 오류: $e');
    print('스택 트레이스: $stackTrace');
    rethrow;
  }
}

