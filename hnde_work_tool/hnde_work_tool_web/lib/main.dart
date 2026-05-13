import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'src/app/app_shell.dart';
import 'src/app/main_shell.dart';
import 'src/features/common/loading_widget.dart';
import 'src/firebase/firebase_env.dart';
import 'src/firebase/firebase_options.dart';
import 'src/firebase/firestore_client.dart';
import 'src/constants/firestore_paths.dart';
import 'src/repositories/work_firestore_repository.dart';

bool _isChatOnlyLaunch() {
  final String path = Uri.base.path;
  if (path.startsWith('/chat/')) return true;
  final String frag = Uri.base.fragment;
  return frag.startsWith('/chat/');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  // OAuth 리다이렉트 복귀 URL을 Flutter 첫 프레임 전에 처리해야 세션이 붙습니다.
  if (kIsWeb) {
    try {
      final UserCredential cred = await FirebaseAuth.instance.getRedirectResult();
      if (kDebugMode && cred.user != null) {
        debugPrint('FirebaseAuth redirect: uid=${cred.user!.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getRedirectResult: $e');
      }
    }
  }
  runApp(const SplashGate());
}

/// 웹 최초 실행 시 스플래시 화면을 보여주며 초기화를 수행
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _initDone = false;
  late final bool _chatOnly = _isChatOnlyLaunch();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.getRedirectResult();
        } catch (_) {
          // main()에서 이미 처리했거나 복귀가 아닌 경우
        }
      }
    }
    configureFirestorePersistence();
    await initializeDateFormatting('ko_KR');
    // InitialDataSeeder는 로그인 후(MainShell)에서 실행합니다.
    // 미인증 상태에서 public 컬렉션 read가 막히거나 지연되면 스플래시에서 멈춘 것처럼 보일 수 있습니다.
    if (mounted) {
      setState(() => _initDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Provider<WorkFirestoreRepository>(
      create: (_) => WorkFirestoreRepository(),
      child: MaterialApp(
        debugShowCheckedModeBanner: kIsFirebaseDevBuild,
        title: kIsFirebaseDevBuild ? '[DEV] HNDE 업무 지원 툴' : 'HNDE 업무 지원 툴',
        theme: AppShell.buildTheme(),
        locale: const Locale('ko', 'KR'),
        builder: (BuildContext context, Widget? child) {
          final Widget body = child ?? const SizedBox.shrink();
          if (!kIsFirebaseDevBuild) return body;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Material(
                elevation: 2,
                color: const Color(0xFFE65100),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'FIREBASE_ENV=dev · Firebase 프로젝트: ${firebaseOptions.projectId} · '
                          'Firestore appId: ${FirestorePaths.appId}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          );
        },
        supportedLocales: const <Locale>[
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _initDone
            ? const _AuthGate()
            : (_chatOnly
                ? const Scaffold(backgroundColor: Color(0xFFF1F5F9))
                : const _SplashScreen()),
      ),
    );
  }
}

/// 스플래시 화면
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppShell.surface,
        ),
        child: Center(
          child: LoadingWidget(
            size: 160,
            text: 'HNDE 업무 지원 툴',
            textStyle: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _lastFixedUid;
  late final bool _chatOnly = _isChatOnlyLaunch();
  bool _logoutPopScheduled = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> authSnapshot) {
        final User? user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _chatOnly
              ? const Scaffold(backgroundColor: Color(0xFFF1F5F9))
              : const Scaffold(body: Center(child: LoadingWidget(size: 120)));
        }

        if (user == null) {
          // 로그아웃이 다이얼로그/바텀시트가 열린 상태에서 발생하면,
          // 화면은 로그인으로 바뀌어도 모달 배리어가 남아 클릭이 막히는 경우가 있습니다.
          if (!_logoutPopScheduled) {
            _logoutPopScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _logoutPopScheduled = false;
              if (!mounted) return;
              final NavigatorState nav = Navigator.of(context, rootNavigator: true);
              if (nav.canPop()) {
                nav.popUntil((Route<dynamic> r) => r.isFirst);
              }
            });
          }
          return const AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            child: LoginScreen(key: ValueKey<String>('login')),
          );
        }

        final DocumentReference<Map<String, dynamic>> profileRef =
            FirebaseFirestore.instance
                .collection('artifacts')
                .doc(FirestorePaths.appId)
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .doc('main');

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileRef.snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profileSnapshot,
          ) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return _chatOnly
                  ? const Scaffold(backgroundColor: Color(0xFFF1F5F9))
                  : const Scaffold(body: Center(child: LoadingWidget(size: 120)));
            }

            final bool hasProfile = profileSnapshot.data?.exists ?? false;

            if (hasProfile &&
                profileSnapshot.data != null &&
                _lastFixedUid != user.uid) {
              final Map<String, dynamic> data =
                  profileSnapshot.data!.data() ?? <String, dynamic>{};
              final bool needsFix = !data.containsKey('mainAdmin') ||
                  !data.containsKey('roleIdx') ||
                  !data.containsKey('uid') ||
                  !data.containsKey('hqViewerMode');

              if (needsFix) {
                _lastFixedUid = user.uid;
                final bool roleIsMain =
                    (data['roleIdx'] as num?)?.toInt() == 0;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await profileRef.set(<String, dynamic>{
                      'uid': user.uid,
                      'mainAdmin': data['mainAdmin'] ?? roleIsMain,
                      'roleIdx': (data['roleIdx'] as num?)?.toInt() ?? (roleIsMain ? 0 : 1),
                      'email': data['email'] ?? (user.email ?? ''),
                      'hqViewerMode': data['hqViewerMode'] ?? true,
                    }, SetOptions(merge: true));
                  } catch (_) {
                    // 권한 필드 보정 실패해도 로그인 게이트 자체는 막지 않습니다.
                  }
                });
              } else {
                _lastFixedUid = user.uid;
              }
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: hasProfile
                  ? const MainShell(key: ValueKey<String>('main'))
                  : SignupScreen(
                      key: const ValueKey<String>('profile-setup'),
                      isSocialSignup: true,
                      socialEmail: user.email ?? '',
                    ),
            );
          },
        );
      },
    );
  }
}
