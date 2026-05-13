import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app_shell.dart';
import '../features/messenger/messenger_dock_controller.dart';
import '../features/notifications/notifications_dock_controller.dart';
import '../routes/app_router.dart';
import '../services/initial_data_seeder.dart';
import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static bool _seedScheduled = false;

  @override
  void initState() {
    super.initState();
    // 로그인·프로필 게이트 통과 후에만 실행 (Firestore 규칙과 네트워크 대기로 스플래시가 멈춘 것처럼 보이는 것 방지)
    if (!_seedScheduled) {
      _seedScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await InitialDataSeeder.ensureSeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = buildAppRouter();

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppThemeNotifier>(create: (_) => AppThemeNotifier()),
        ChangeNotifierProvider<MessengerDockController>(
          create: (_) => MessengerDockController(),
        ),
        ChangeNotifierProvider<NotificationsDockController>(
          create: (_) => NotificationsDockController(),
        ),
      ],
      child: Consumer<AppThemeNotifier>(
        builder: (BuildContext context, AppThemeNotifier notifier, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            title: 'HNDE 업무 지원 툴',
            theme: AppShell.buildThemeFromAppTheme(notifier.theme),
            locale: const Locale('ko', 'KR'),
            supportedLocales: const <Locale>[
              Locale('ko', 'KR'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}

