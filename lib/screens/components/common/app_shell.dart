import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hnde_web/const_value.dart';
import 'package:provider/provider.dart';
import '../../../core/loading_provider.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/sidebar_menu_items.dart';
import 'loading_widget.dart';
import '../../../widgets/permission_guard.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  int _getSelectedMenuIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    
    // AppMenus를 사용해서 자동으로 매핑
    for (int i = 0; i < sidebarMenuItems.length; i++) {
      final item = sidebarMenuItems[i];
      
      // 기본 페이지 매칭
      if (location == item.routeName || location.startsWith('${item.routeName}/')) {
        return i;
      }
      
      // 글쓰기 페이지 매칭
      if (location == '/write-notice' && item.routeName == '/notices') return i;
      if (location == '/write-board' && item.routeName == '/boards') return i;
      if (location == '/write-anonymous-board' && item.routeName == '/anonymous-boards') return i;
      if (location == '/write-data-request' && item.routeName == '/data-requests') return i;
    }

    return 0; // 기본값
  }

  MenuType _getMenuTypeFromRoute(String route) {
    // AppMenus에서 자동으로 매핑
    for (final menu in AppMenus.getAll()) {
      // 기본 페이지 매칭
      if (route == menu.route || route.startsWith('${menu.route}/')) {
        return menu.type;
      }
    }
    
    // 글쓰기 페이지 매칭 (null 체크 추가)
    if (route == '/write-notice') return MenuType.notice;
    if (route == '/write-board') return MenuType.board;
    if (route == '/write-anonymous-board') return MenuType.anonymousBoard;
    if (route == '/write-data-request') return MenuType.dataRequest;
    
    // 기본값
    return MenuType.dashboard;
  }

  bool _requiresWritePermission(String route) {
    return route.startsWith('/write-') || route.startsWith('/admin');
  }

  void _handleSidebarMenuTap(BuildContext context, int idx) async {
    if (idx == -1) {
      setState(() {
        _sidebarCollapsed = !_sidebarCollapsed;
      });
    } else if (idx >= 0 && idx < sidebarMenuItems.length) {
      final route = sidebarMenuItems[idx].routeName;
      final current = GoRouterState.of(context).uri.toString();
      if (current != route) {
        // 모달이 열려있는 경우 닫기
        if (Navigator.of(context).canPop() && context.mounted) {
          Navigator.of(context).pop();
          return;
        }
        
        if (context.mounted) {
          context.go(route);
        }
      }
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Image.asset(
          kLogoHorizontal,
          width: 120,
          height: 48,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF336699),
      elevation: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = _getSelectedMenuIndex(context);
    final loadingProvider = context.watch<LoadingProvider>();
    final currentRoute = GoRouterState.of(context).uri.toString();
    final menuType = _getMenuTypeFromRoute(currentRoute);
    final requiresWrite = _requiresWritePermission(currentRoute);
    
    return Stack(
      children: [
        Scaffold(
          appBar: _buildAppBar(context),
          body: Row(
            children: [
              Sidebar(
                isCollapsed: _sidebarCollapsed,
                selectedIndex: selectedMenu,
                onMenuTap: (idx) => _handleSidebarMenuTap(context, idx),
              ),
              // 메인 컨텐츠
              Expanded(
                child: PermissionGuard(
                  requiredPermission: menuType,
                  requireWritePermission: requiresWrite,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
        if (loadingProvider.isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: LoadingWidget(
                      size: 200,
                      text: loadingProvider.loadingText ?? '처리 중...'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
