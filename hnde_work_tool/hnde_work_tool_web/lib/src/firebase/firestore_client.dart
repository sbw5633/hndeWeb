import 'package:cloud_firestore/cloud_firestore.dart';

/// 웹·모바일 공통: 로컬 영속 캐시로 동일 문서 재조회 비용·체감 지연 감소.
void configureFirestorePersistence() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
