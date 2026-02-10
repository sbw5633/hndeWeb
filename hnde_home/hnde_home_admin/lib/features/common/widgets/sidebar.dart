import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfoAsync = ref.watch(currentUserInfoProvider);
    
    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('HNDE Admin',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            userInfoAsync.when(
              data: (userInfo) {
                final isRestAreaManager = userInfo?.isRestAreaManager ?? false;
                
                // 휴게소 관리자인 경우: 홈화면, 휴게소 사업, 커뮤니티만 표시
                if (isRestAreaManager) {
                  return Column(
                    children: [
                      _NavButton(
                          icon: Icons.home, label: '홈화면', onTap: () => context.go('/')),
                      _NavButton(
                          icon: Icons.restaurant,
                          label: '휴게소 사업',
                          onTap: () => context.go('/rest-areas')),
                      _NavButton(
                          icon: Icons.people,
                          label: '커뮤니티',
                          onTap: () => context.go('/community')),
                    ],
                  );
                }
                
                // 관리자인 경우: 모든 메뉴 표시
                return Column(
                  children: [
                    _NavButton(
                        icon: Icons.home, label: '홈화면', onTap: () => context.go('/')),
                    _NavButton(
                        icon: Icons.business,
                        label: '회사소개',
                        onTap: () => context.go('/company')),
                    _NavButton(
                        icon: Icons.restaurant,
                        label: '휴게소 사업',
                        onTap: () => context.go('/rest-areas')),
                    _NavButton(
                        icon: Icons.factory,
                        label: '제조유통사업',
                        onTap: () => context.go('/manufacturing-business')),
                    _NavButton(
                        icon: Icons.restaurant_menu,
                        label: '식음료사업',
                        onTap: () => context.go('/food-beverage-business')),
                    _NavButton(
                        icon: Icons.campaign,
                        label: '홍보센터',
                        onTap: () => context.go('/pr')),
                    _NavButton(
                        icon: Icons.people,
                        label: '커뮤니티',
                        onTap: () => context.go('/community')),
                    _NavButton(
                        icon: Icons.work,
                        label: '인재채용',
                        onTap: () => context.go('/recruitment')),
                    _NavButton(
                        icon: Icons.account_circle,
                        label: '계정관리',
                        onTap: () => context.go('/account-management')),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const Spacer(),
            userInfoAsync.when(
              data: (userInfo) {
                if (userInfo?.isRestAreaManager ?? false) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${userInfo?.restAreaName ?? ''} 관리자',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox();
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authControllerProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('로그아웃'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}
