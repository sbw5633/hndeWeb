import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hnde_web/const_value.dart';
import 'package:provider/provider.dart';
import '../../../core/loading_provider.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/sidebar_menu_items.dart';
import 'loading_widget.dart';

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
    var idx =
        sidebarMenuItems.indexWhere((item) => location == item.routeName);
            
    // 글쓰기 페이지일 경우 해당 메뉴 선택 표시(공지사항, 게시판 등등)
    if(location == '/write-notice') {
      idx = sidebarMenuItems.indexWhere((item) => item.routeName == '/notices');
    }
    // 공지사항 상세 페이지일 경우 공지사항 메뉴 선택 표시
    if(location.startsWith('/notices/')) {
      idx = sidebarMenuItems.indexWhere((item) => item.routeName == '/notices');
    }
    
    return idx >= 0 ? idx : 0;
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
                child: widget.child,
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
