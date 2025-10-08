import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/firebase/post_stats_service.dart';

void main() async {
  // 환경변수 로드
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Flutter 오류 처리 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    // Navigator 관련 오류는 무시 (앱 크래시 방지)
    if (details.exception.toString().contains('_debugLocked') ||
        details.exception.toString().contains('deactivated widget')) {
      print('Navigator 오류 무시됨: ${details.exception}');
      return;
    }
    
    // 다른 오류는 기본 처리
    FlutterError.presentError(details);
  };
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // PostStatsService 초기화 (전체 통계 캐싱)
  PostStatsService.initializeStats();
  
  // 임시 관리자 계정 생성 (개발용)
  // await _createTemporaryAdmin();
  
  runApp(const App());
}

// /// 임시 관리자 계정 생성 (개발용)
// Future<void> _createTemporaryAdmin() async {
//   try {
//     final authProvider = AuthProvider();
//     await authProvider.createTemporaryAdmin();
//     print('임시 관리자 계정 생성 완료');
//     print('이메일: admin@hnde.com');
//     print('비밀번호: 1234 (Firebase Auth에서 수동 설정 필요)');
//   } catch (e) {
//     print('관리자 계정 생성 실패: $e');
//   }
// }