import 'package:flutter/material.dart';
import 'core/firebase.dart';
import 'screens/home_page.dart';
import 'widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🔥 Firebase 초기화 시작...');
  try {
    await initFirebase();
    print('✅ Firebase 초기화 완료');
  } catch (e, stackTrace) {
    print('❌ Firebase 초기화 실패: $e');
    print('스택 트레이스: $stackTrace');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'H&DE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue[900]!,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashWrapper(),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  double _homePageOpacity = 0.0;
  double _splashOpacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 홈페이지 (페이드인 효과, 페이드아웃 시작과 동시에 표시 시작)
        Opacity(
          opacity: _homePageOpacity,
          child: IgnorePointer(
            ignoring: _homePageOpacity < 1.0, // 완전히 표시되기 전까지는 터치 무시
            child: const HomePage(),
          ),
        ),
        // 스플래시 화면 (페이드아웃 애니메이션 적용)
        if (_splashOpacity > 0)
          Opacity(
            opacity: _splashOpacity,
            child: SplashScreen(
              onComplete: () {
                setState(() {
                  _homePageOpacity = 1.0;
                  _splashOpacity = 0.0;
                });
              },
              onHomePageOpacity: (opacity) {
                setState(() {
                  _homePageOpacity = opacity;
                });
              },
              onSplashOpacity: (opacity) {
                setState(() {
                  _splashOpacity = opacity;
                });
              },
            ),
          ),
      ],
    );
  }
}
