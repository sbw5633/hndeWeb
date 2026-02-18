import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/login_page.dart';
import 'features/auth/account_creation_page.dart';
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
import 'features/business/business_type_list_page.dart';
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
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/account-creation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AccountCreationPage(
            email: extra?['email'] ?? '',
            isGoogleAccount: extra?['isGoogleAccount'] ?? false,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final userInfo = ref.watch(currentUserInfoProvider);
              final showBanner = userInfo.valueOrNull != null &&
                  !userInfo.valueOrNull!.isApproved;
              return Scaffold(
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      if (showBanner) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ApprovalBanner(),
                            Expanded(child: child),
                          ],
                        );
                      }
                      return child;
                    }
                    return Row(
                      children: [
                        const AdminSidebar(),
                        Expanded(
                          child: showBanner
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const _ApprovalBanner(),
                                    Expanded(child: child),
                                  ],
                                )
                              : child,
                        ),
                      ],
                    );
                  },
                ),
              );
            },
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
          GoRoute(
              path: '/business-types',
              builder: (context, state) => const BusinessTypeListPage()),
        ],
      ),
    ],
    redirect: redirectLogic,
  );
}

/// 미승인 사용자 상단 배너
class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '관리자 승인이 필요합니다. 관리자에게 문의해주세요.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
