/// Cloudinary 설정 파일
///
/// Cloudinary 계정 정보를 여기에 입력하세요.
/// 무료 계정 생성: https://cloudinary.com/users/register/free
class CloudinaryConfig {
  // TODO: Cloudinary Dashboard에서 다음 정보를 입력하세요
  // https://console.cloudinary.com/console

  /// Cloud Name (필수)
  /// Dashboard → Settings → Account details에서 확인
  static const String cloudName = 'ddz9qncy4';

  /// API Key (필수)
  /// Dashboard → Settings → Security에서 확인
  static const String apiKey = '122143887751387';

  /// API Secret (필수 - 서버 측에서 사용, 프론트엔드에서는 Unsigned Preset 사용 권장)
  /// Dashboard → Settings → Security에서 확인
  static const String apiSecret = 'pzpiXhLGRoVFYBAebeR9HCebZsI';

  /// Upload Preset (Unsigned Preset 권장)
  /// Settings → Upload → Upload presets에서 생성
  /// "Add upload preset" 클릭 → Preset name 입력 → Signing mode: Unsigned → Save
  /// 참고: Preset이 없으면 업로드가 실패합니다!
  static const String uploadPreset = 'hnde_home';
}
