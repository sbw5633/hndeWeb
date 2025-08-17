import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      '현재 프로젝트는 Flutter Web만 지원합니다.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyA-RXY6TmeJv7Ka32biQWCkANzpXyvwt_Y",
    authDomain: "hnde-db.firebaseapp.com",
    projectId: "hnde-db",
    storageBucket: "hnde-db.appspot.com",
    messagingSenderId: "1040379386055",
    appId: "1:1040379386055:web:72249ff41cdafba6cc46e2",
    measurementId: "G-6J9TDM83SQ",
  );
} 