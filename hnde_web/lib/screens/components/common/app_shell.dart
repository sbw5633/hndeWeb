import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/loading_provider.dart';
import 'sidebar.dart';
import 'sidebar_menu_items.dart';
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
    final idx = sidebarMenuItems.indexWhere((item) => location == item.routeName);
    return idx >= 0 ? idx : 0;
  }

  void _handleSidebarMenuTap(BuildContext context, int idx) {
    if (idx == -1) {
      setState(() {
        _sidebarCollapsed = !_sidebarCollapsed;
      });
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
    final loadingProvider = context.watch<LoadingProvider>();
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(sidebarMenuItems[selectedMenu].label),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF336699),
            elevation: 0.5,
          ),
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
                    text: loadingProvider.loadingText ?? '처리 중...'
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
} 