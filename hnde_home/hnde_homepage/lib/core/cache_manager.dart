
/// 캐시 항목 클래스
class CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final String? etag; // 변경 감지를 위한 태그

  CacheItem({
    required this.data,
    required this.timestamp,
    this.etag,
  });

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// 캐시 매니저 클래스
/// 메모리 기반 캐시로 데이터를 관리하고, 타임스탬프를 통해 변경 감지
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // 캐시 저장소: 키 -> CacheItem
  final Map<String, CacheItem<dynamic>> _cache = {};
  
  // 각 메뉴별 최초 접근 여부 추적
  final Set<String> _accessedMenus = {};
  
  // 캐시 만료 시간 (기본 1시간)
  Duration _defaultMaxAge = const Duration(hours: 1);

  /// 캐시에서 데이터 가져오기
  T? get<T>(String key) {
    final item = _cache[key];
    if (item == null) return null;
    
    // 만료된 캐시는 무시
    if (item.isExpired(_defaultMaxAge)) {
      _cache.remove(key);
      return null;
    }
    
    return item.data as T;
  }

  /// 캐시에 데이터 저장
  void set<T>(String key, T data, {String? etag}) {
    _cache[key] = CacheItem<T>(
      data: data,
      timestamp: DateTime.now(),
      etag: etag,
    );
  }

  /// 메뉴가 최초 접근되었는지 확인
  bool isFirstAccess(String menuKey) {
    return !_accessedMenus.contains(menuKey);
  }

  /// 메뉴 접근 기록
  void markAsAccessed(String menuKey) {
    _accessedMenus.add(menuKey);
  }

  /// 캐시된 데이터의 ETag 가져오기
  String? getEtag(String key) {
    return _cache[key]?.etag;
  }

  /// 특정 키의 캐시가 존재하고 유효한지 확인
  bool hasValidCache(String key) {
    final item = _cache[key];
    if (item == null) return false;
    return !item.isExpired(_defaultMaxAge);
  }

  /// 특정 키의 캐시 삭제
  void remove(String key) {
    _cache.remove(key);
  }

  /// 모든 캐시 삭제
  void clear() {
    _cache.clear();
    _accessedMenus.clear();
  }

  /// 만료된 캐시만 삭제
  void clearExpired() {
    final keysToRemove = <String>[];
    for (final entry in _cache.entries) {
      if (entry.value.isExpired(_defaultMaxAge)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// 캐시 만료 시간 설정
  void setMaxAge(Duration maxAge) {
    _defaultMaxAge = maxAge;
  }

  /// 새로고침 시: 변경된 데이터만 업데이트
  /// ETag를 비교하여 변경된 경우에만 true 반환
  bool needsUpdate(String key, String? newEtag) {
    final cachedEtag = getEtag(key);
    if (cachedEtag == null) return true; // 캐시가 없으면 업데이트 필요
    if (newEtag == null) return true; // ETag가 없으면 업데이트 필요
    return cachedEtag != newEtag; // ETag가 다르면 업데이트 필요
  }
}

