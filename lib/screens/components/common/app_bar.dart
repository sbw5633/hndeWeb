import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    required this.tooltip,
    required this.writePage, // 추가: 이동할 페이지
  });

  final String title;
  final String tooltip;
  final String writePage; // 추가: 이동할 페이지 위젯

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return AppBar(
      title: Text(title),
      actions: [
        // 로그인한 사용자에게만 글쓰기 버튼 표시
        if (authProvider.isLoggedIn)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.edit),
              tooltip: tooltip,
              onPressed: () async {
                // context.go('/write-notice'); // 모달 대신 라우팅
                context.go(writePage);
              },
            ),
          ),
      ],
    );
  }
}
