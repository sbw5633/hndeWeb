import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../const_value.dart';
import '../utils/permission_utils.dart';

class PermissionGuard extends StatelessWidget {
  final MenuType requiredPermission;
  final bool requireWritePermission;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.requiredPermission,
    this.requireWritePermission = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 로그인 상태 확인
        if (!authProvider.isLoggedIn) {
          return _buildPermissionDeniedScreen(
            context,
            '로그인이 필요합니다.',
            '로그인 후 이용해주세요.',
            () => context.go('/login'),
            '로그인하기',
          );
        }

        final user = authProvider.appUser;
        if (user == null) {
          return _buildPermissionDeniedScreen(
            context,
            '사용자 정보를 찾을 수 없습니다.',
            '다시 로그인해주세요.',
            () => context.go('/login'),
            '로그인하기',
          );
        }

        // 계정 승인 상태 확인
        if (!user.approved) {
          return _buildPermissionDeniedScreen(
            context,
            '계정 승인 대기 중입니다.',
            '관리자 승인 후 이용할 수 있습니다.',
            () => context.go('/'),
            '대시보드로',
          );
        }

        // 기본 접근 권한 확인
        if (!PermissionUtils.hasAccess(user, requiredPermission)) {
          return _buildPermissionDeniedScreen(
            context,
            '접근 권한이 없습니다.',
            '이 페이지에 접근할 수 있는 권한이 없습니다.',
            () => context.go('/'),
            '대시보드로',
          );
        }

        // 쓰기 권한 확인 (필요한 경우)
        if (requireWritePermission && !PermissionUtils.hasWritePermission(user, requiredPermission)) {
          return _buildPermissionDeniedScreen(
            context,
            '쓰기 권한이 없습니다.',
            '이 페이지에 글을 쓸 수 있는 권한이 없습니다.',
            () => context.go('/'),
            '대시보드로',
          );
        }

        // 권한이 있으면 자식 위젯 표시
        return child;
      },
    );
  }

  Widget _buildPermissionDeniedScreen(
    BuildContext context,
    String title,
    String message,
    VoidCallback onAction,
    String actionText,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('권한 없음'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text(
                  '홈으로 돌아가기',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
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
