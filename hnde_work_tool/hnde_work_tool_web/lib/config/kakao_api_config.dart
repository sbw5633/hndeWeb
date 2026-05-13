/// 카카오 로컬 API (주소 검색 → 좌표)
///
/// **웹에서는 브라우저→카카오 직접 호출이 403** 인 경우가 많아, `env.worker` 의
/// Worker URL + `/v1/kakao/address` 로 **자동 프록시**합니다 (`run_web.ps1` 가 worker 주입).
///
/// 선택: `env.kakao` 의 `KAKAO_ADDRESS_PROXY_URL` 로 다른 주소를 쓸 수 있습니다.
class KakaoApiConfig {
  KakaoApiConfig._();

  static const String _restKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: '',
  );

  /// `env.worker` — [Secrets] 와 동일 키
  static const String _r2WorkerProd = String.fromEnvironment(
    'R2_WORKER_URL_PROD',
    defaultValue: '',
  );

  static const String _r2WorkerLegacy = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: '',
  );

  static const String _addressProxyUrl = String.fromEnvironment(
    'KAKAO_ADDRESS_PROXY_URL',
    defaultValue: '',
  );

  static const String _keywordProxyUrl = String.fromEnvironment(
    'KAKAO_KEYWORD_PROXY_URL',
    defaultValue: '',
  );

  static String get restApiKey => _restKey.trim();

  static bool get hasRestApiKey => restApiKey.isNotEmpty;

  static String get addressProxyUrl => _addressProxyUrl.trim();

  static String get keywordProxyUrl => _keywordProxyUrl.trim();

  static String get _workerBaseUrl {
    final String p = _r2WorkerProd.trim();
    if (p.isNotEmpty) {
      return p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    }
    final String l = _r2WorkerLegacy.trim();
    if (l.isNotEmpty) {
      return l.endsWith('/') ? l.substring(0, l.length - 1) : l;
    }
    return '';
  }

  /// 명시 프록시 → 없으면 Worker 기준 URL + `/v1/kakao/address`
  static String get effectiveAddressProxyUrl {
    final String explicit = addressProxyUrl;
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final String w = _workerBaseUrl;
    if (w.isEmpty) {
      return '';
    }
    return '$w/v1/kakao/address';
  }

  /// 명시 프록시 → 없으면 Worker 기준 URL + `/v1/kakao/keyword`
  static String get effectiveKeywordProxyUrl {
    final String explicit = keywordProxyUrl;
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final String w = _workerBaseUrl;
    if (w.isEmpty) {
      return '';
    }
    return '$w/v1/kakao/keyword';
  }

  static bool get canSearchAddress =>
      effectiveAddressProxyUrl.isNotEmpty || hasRestApiKey;

  static bool get canSearchKeyword =>
      effectiveKeywordProxyUrl.isNotEmpty || hasRestApiKey;

  static bool get canSearchLocal => canSearchAddress || canSearchKeyword;
}
