/// 빌드·실행 시 `--dart-define=FIREBASE_ENV=dev` 또는 `prod` 로 구분합니다.
/// (hnde_home `테스트 실행.md` 와 동일한 방식)
///
/// 기본값은 `prod` 입니다. 값은 대소문자 무시하고 `dev` 만 개발 모드로 처리합니다.
const String kFirebaseEnv = String.fromEnvironment(
  'FIREBASE_ENV',
  defaultValue: 'prod',
);

bool get kIsFirebaseDevBuild => kFirebaseEnv.trim().toLowerCase() == 'dev';

/// Firestore 루트 경로에서 사용하는 appId (`artifacts/{appId}/...`).
/// dev/prod를 동일 코드에서 분기하기 위해 dart-define으로 주입합니다.
///
/// 예)
/// - prod: `--dart-define=FIRESTORE_APP_ID=hnde-work-web`
/// - dev : `--dart-define=FIRESTORE_APP_ID=hnde_work_dev` (사용자 dev 프로젝트/앱ID에 맞게)
const String kFirestoreAppId = String.fromEnvironment(
  'FIRESTORE_APP_ID',
  defaultValue: 'hnde-work-web',
);
