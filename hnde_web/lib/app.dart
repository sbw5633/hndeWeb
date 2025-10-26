import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'const_value.dart';
import 'core/theme.dart';
import 'core/loading_provider.dart';
import 'core/select_info_provider.dart';
import 'core/auth_provider.dart';
import 'core/page_state_provider.dart';
import 'core/employee_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/board/app_write_page.dart';
import 'screens/board/board_page.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/notice/board_post_detail_page.dart';
import 'screens/components/common/app_shell.dart';
import 'screens/admin/admin_page.dart';
import 'screens/company/company_page.dart';
import 'screens/work/work_page.dart';

// 라우터 설정
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
              const NoTransitionPage(child: BoardPage(type: MenuType.notice)),
        ),
        GoRoute(
          path: '/notices/:id',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['id']!;
            return NoTransitionPage(
              child: BoardPostDetailPage(type: MenuType.notice, postId: postId),
            );
          },
        ),
        GoRoute(
          path: '/boards',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BoardPage(type: MenuType.board)),
        ),
        GoRoute(
          path: '/boards/:id',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['id']!;
            return NoTransitionPage(
              child: BoardPostDetailPage(type: MenuType.board, postId: postId),
            );
          },
        ),
        GoRoute(
          path: '/anonymous-boards',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BoardPage(type: MenuType.anonymousBoard)),
        ),
        GoRoute(
          path: '/anonymous-boards/:id',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['id']!;
            return NoTransitionPage(
              child: BoardPostDetailPage(type: MenuType.anonymousBoard, postId: postId),
            );
          },
        ),
        GoRoute(
          path: '/data-requests',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BoardPage(type: MenuType.dataRequest)),
        ),
        GoRoute(
          path: '/data-requests/:id',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['id']!;
            return NoTransitionPage(
              child: BoardPostDetailPage(type: MenuType.dataRequest, postId: postId),
            );
          },
        ),
        GoRoute(
          path: '/write-notice',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AppWritePage(type: MenuType.notice)),
          ),
          GoRoute(
          path: '/write-board',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AppWritePage(type: MenuType.board)),
        ),
        GoRoute(
          path: '/write-anonymous-board',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AppWritePage(type: MenuType.anonymousBoard)),
        ),
        GoRoute(
          path: '/write-data-request',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AppWritePage(type: MenuType.dataRequest)),
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
                  return AdminPage(currentUser: authProvider.appUser!);
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
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
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


