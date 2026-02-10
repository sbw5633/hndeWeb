import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/home_page.dart';
import 'features/common/widgets/sidebar.dart';
import 'features/company/company_page.dart';
import 'features/rest_area/rest_area_page.dart';
import 'features/pr/pr_page.dart';
import 'features/community/community_page.dart';
import 'features/recruitment/recruitment_page.dart';
import 'features/account/account_management_page.dart';
import 'features/business/manufacturing_business_page.dart';
import 'features/business/food_beverage_business_page.dart';
import 'providers/auth_provider.dart';

GoRouter createRouter(WidgetRef ref) {
  String? redirectLogic(BuildContext context, GoRouterState state) {
    final loggedIn = ref.read(isLoggedInProvider);
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/';
    return null;
  }

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                // 작은 화면에서는 사이드바를 숨기거나 다른 레이아웃 사용
                if (constraints.maxWidth < 600) {
                  return child; // 작은 화면에서는 사이드바 없이 표시
                }
                return Row(
                  children: [
                    const AdminSidebar(),
                    Expanded(child: child),
                  ],
                );
              },
            ),
          );
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
              path: '/company',
              builder: (context, state) => const CompanyPage()),
          GoRoute(
              path: '/rest-areas',
              builder: (context, state) => const RestAreaPage()),
          GoRoute(path: '/pr', builder: (context, state) => const PRPage()),
          GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityPage()),
          GoRoute(
              path: '/recruitment',
              builder: (context, state) => const RecruitmentPage()),
          GoRoute(
              path: '/account-management',
              builder: (context, state) => const AccountManagementPage()),
          GoRoute(
              path: '/manufacturing-business',
              builder: (context, state) => const ManufacturingBusinessPage()),
          GoRoute(
              path: '/food-beverage-business',
              builder: (context, state) => const FoodBeverageBusinessPage()),
        ],
      ),
    ],
    redirect: redirectLogic,
  );
}
