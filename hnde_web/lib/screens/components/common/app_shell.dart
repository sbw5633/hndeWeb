import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'sidebar.dart';
import 'sidebar_menu_items.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _getSelectedMenuIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = sidebarMenuItems.indexWhere((item) => location == item.routeName);
    return idx >= 0 ? idx : 0;
  }

  void _handleSidebarMenuTap(BuildContext context, int idx) {
    if (idx == -1) {
      // 사이드바 펼침/접힘은 필요시 별도 상태로 관리
    } else if (idx >= 0 && idx < sidebarMenuItems.length) {
      final route = sidebarMenuItems[idx].routeName;
      final current = GoRouterState.of(context).uri.toString();
      if (current != route) {
        context.go(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = _getSelectedMenuIndex(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(sidebarMenuItems[selectedMenu].label),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF336699),
        elevation: 0.5,
      ),
      body: Row(
        children: [
          Sidebar(
            isCollapsed: false, // 펼침/접힘 상태는 필요시 상위에서 관리
            selectedIndex: selectedMenu,
            onMenuTap: (idx) => _handleSidebarMenuTap(context, idx),
          ),
          // 메인 컨텐츠
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
} 