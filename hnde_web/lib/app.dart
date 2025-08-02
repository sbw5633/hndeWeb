import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/loading_provider.dart';
import 'core/select_info_provider.dart';
import 'core/auth_provider.dart';
import 'core/page_state_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/notice/notice_page.dart';
import 'screens/notice/board_post_detail_page.dart';
import 'screens/components/common/app_shell.dart';
import 'screens/admin/admin_settings_page.dart';
import 'screens/board/board_page.dart';
import 'screens/data_request/data_request_page.dart';
import 'screens/company/company_page.dart';
import 'screens/notice/write_notice_page.dart';
import 'screens/work/work_page.dart';

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/notices',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: NoticePage()),
        ),
        GoRoute(
          path: '/notices/:id',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['id']!;
            return NoTransitionPage(
              child: BoardPostDetailPage(postId: postId),
            );
          },
        ),
        GoRoute(
          path: '/boards',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BoardPage()),
        ),
        GoRoute(
          path: '/write-notice',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WriteNoticePage()),
        ),
        GoRoute(
          path: '/data-requests',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DataRequestPage()),
        ),
        GoRoute(
          path: '/company',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CompanyPage()),
        ),
        GoRoute(
          path: '/work',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WorkPage()),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (!authProvider.isLoggedIn || !authProvider.isAdmin) {
                    return const Scaffold(
                      body: Center(child: Text('관리자 권한이 필요합니다.')),
                    );
                  }
                  return AdminSettingsPage(currentUser: authProvider.appUser!);
                },
              ),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoadingProvider()),
        ChangeNotifierProvider(create: (_) => SelectInfoProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PageStateProvider()),
      ],
      child: MaterialApp.router(
        title: '사내 업무 시스템',
        theme: appTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
