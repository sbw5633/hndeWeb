import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase 설정
const firebaseConfig = {
  'apiKey': 'AIzaSyBChBQLN_ovjGB6V-Znio_T_kgCvm92dBQ',
  'authDomain': 'hnde-homepage-db.firebaseapp.com',
  'projectId': 'hnde-homepage-db',
  'storageBucket': 'hnde-homepage-db.firebasestorage.app',
  'messagingSenderId': '897182023039',
  'appId': '1:897182023039:web:5e8b721c20a883ba38ae4a',
  'measurementId': 'G-CXN9CY1SRT',
};

Future<void> initFirebase() async {
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
}

// Firebase 인스턴스 접근
FirebaseAuth get firebaseAuth => FirebaseAuth.instance;
FirebaseFirestore get firestore => FirebaseFirestore.instance;

