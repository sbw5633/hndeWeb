import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FirebaseEnv { dev, prod }

FirebaseEnv _getFirebaseEnv() {
  const value = String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');
  return value.toLowerCase() == 'prod' ? FirebaseEnv.prod : FirebaseEnv.dev;
}

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

Map<String, String> _selectFirebaseConfig() {
  final env = _getFirebaseEnv();
  return env == FirebaseEnv.prod ? _firebaseConfigProd : _firebaseConfigDev;
}

Future<void> initFirebase() async {
  final firebaseConfig = _selectFirebaseConfig();
  final env = _getFirebaseEnv();
  print('🔥 Firebase.initializeApp 호출 중...');
  print('   - env: $env');
  print('   - projectId: ${firebaseConfig['projectId']}');
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: firebaseConfig['apiKey']!,
      authDomain: firebaseConfig['authDomain']!,
      projectId: firebaseConfig['projectId']!,
      storageBucket: firebaseConfig['storageBucket']!,
      messagingSenderId: firebaseConfig['messagingSenderId']!,
      appId: firebaseConfig['appId']!,
      measurementId: firebaseConfig['measurementId']!,
    ),
  );
  print('✅ Firebase 초기화 성공');
}

// Firebase 인스턴스 접근
FirebaseAuth get firebaseAuth => FirebaseAuth.instance;
FirebaseFirestore get firestore => FirebaseFirestore.instance;
