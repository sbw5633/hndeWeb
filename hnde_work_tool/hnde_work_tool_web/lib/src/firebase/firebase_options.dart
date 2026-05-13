import 'package:firebase_core/firebase_core.dart';

import 'firebase_env.dart';

/// 운영 Firebase Web 앱 (`hnde-work-web`).
const FirebaseOptions firebaseOptionsProd = FirebaseOptions(
  apiKey: 'AIzaSyAVOY6i-akAq5eGV4OwpfWpTPIdBNRatVU',
  appId: '1:635135884573:web:b2be7111731802cefe75f4',
  messagingSenderId: '635135884573',
  projectId: 'hnde-work-web',
  authDomain: 'hnde-work-web.firebaseapp.com',
  storageBucket: 'hnde-work-web.firebasestorage.app',
);

/// 개발 빌드용 Firebase Web 앱 (`hnde-work-dev`, `FIREBASE_ENV=dev`).
///
/// 콘솔 Web 앱 설정과 동일한 값이어야 OAuth·Firestore가 같은 GCP 프로젝트에 붙습니다.
/// `FIRESTORE_APP_ID` 는 보통 이 프로젝트 id(`hnde-work-dev`)와 맞춥니다(`deploy_dev.bat` 참고).
const FirebaseOptions firebaseOptionsDev = FirebaseOptions(
  apiKey: 'AIzaSyCOm-50jCmEfjZaWQeOIy3BdN8xfpgdb7Y',
  appId: '1:137593143239:web:205d23e2cee002ea6663e2',
  messagingSenderId: '137593143239',
  projectId: 'hnde-work-dev',
  authDomain: 'hnde-work-dev.firebaseapp.com',
  storageBucket: 'hnde-work-dev.firebasestorage.app',
  measurementId: 'G-4K09DLFGQZ',
);

/// [kIsFirebaseDevBuild] 에 따라 선택된 옵션.
FirebaseOptions get firebaseOptions =>
    kIsFirebaseDevBuild ? firebaseOptionsDev : firebaseOptionsProd;
