/// 한국관광공사 TourAPI (공공데이터포털) 인증키
///
/// 공공데이터포털에서 **「한국관광공사_국문 관광정보 서비스_GW」** 로 검색해 발급받는 키와 동일합니다.
/// (GW는 포털 상의 서비스명 표기이며, 실제 엔드포인트는
/// `https://apis.data.go.kr/B551011/KorService2/...` — 본 앱의 [TourApiConfig.korServicePath] 와 일치합니다.)
///
/// **로컬:** 프로젝트 루트에 `env.tour` 파일을 두고 ( `env.tour.example` 복사 )
/// `TOUR_API_SERVICE_KEY=디코딩된_일반키` 형식으로 저장합니다.
///
/// **실행:** `run_web.ps1` 또는
/// `flutter run --dart-define-from-file=env.tour` (다른 define 파일과 함께 가능)
///
/// 빌드/CI: `--dart-define=TOUR_API_SERVICE_KEY=...` 또는 env 파일 병합.
class TourApiConfig {
  TourApiConfig._();

  /// 컴파일 타임에 [String.fromEnvironment] 로 주입 (env.tour / dart-define)
  static const String _serviceKey = String.fromEnvironment(
    'TOUR_API_SERVICE_KEY',
    defaultValue: '',
  );

  /// 디코딩된 일반 인증키 (URL 쿼리에 넣으면 [Uri]가 인코딩 처리)
  static String get serviceKey {
    if (_serviceKey.trim().isEmpty) {
      throw StateError(
        'TOUR_API_SERVICE_KEY 가 설정되지 않았습니다. '
        'env.tour.example 을 env.tour 로 복사한 뒤 키를 넣고, '
        'run_web.ps1 로 실행하거나 --dart-define-from-file=env.tour 를 사용하세요.',
      );
    }
    return _serviceKey.trim();
  }

  static const String baseHost = 'apis.data.go.kr';
  static const String korServicePath = '/B551011/KorService2';
}
