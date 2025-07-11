import 'package:flutter/material.dart';
import '../../../const_value.dart';
import 'sidebar_menu_items.dart';

class Sidebar extends StatelessWidget {
  final bool isCollapsed;
  final int selectedIndex;
  final ValueChanged<int>? onMenuTap;
  const Sidebar({
    super.key,
    this.isCollapsed = false,
    required this.selectedIndex,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isCollapsed ? 64 : 220,
              color: const Color(0xFF4DA3D2),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  if (!isCollapsed)
                    Image.asset(kLogoVertical, width: 80, height: 80),
                  if (!isCollapsed) const SizedBox(height: 16),
                  // 메뉴 리스트 스크롤 영역
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...sidebarMenuItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return SidebarNavItem(
                              icon: item.icon,
                              label: item.label,
                              selected: idx == selectedIndex,
                              isCollapsed: isCollapsed,
                              onTap: () => onMenuTap?.call(idx),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  if (!isCollapsed)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('© 2024 회사명', style: TextStyle(color: Colors.white70)),
                    ),
                ],
              ),
            ),
            // 토글 버튼 (세로 중앙, 타원형)
            Positioned(
              top: constraints.maxHeight / 2 - 28,
              right: -18,
              child: _SidebarToggleButton(
                isCollapsed: isCollapsed,
                onToggle: () => onMenuTap?.call(-1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SidebarToggleButton extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggle;
  const _SidebarToggleButton({required this.isCollapsed, this.onToggle});

  @override
  State<_SidebarToggleButton> createState() => _SidebarToggleButtonState();
}

class _SidebarToggleButtonState extends State<_SidebarToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _hovered ? 1.0 : 0.85,
        child: Material(
          color: Colors.transparent,
          elevation: _hovered ? 8 : 4,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovered ? 0.12 : 0.08),
                    blurRadius: _hovered ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              width: 44,
              height: 56,
              child: Center(
                child: Icon(
                  widget.isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: const Color(0xFF4DA3D2),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback? onTap;
  const SidebarNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.isCollapsed = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: selected
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: isCollapsed ? null : Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
        minLeadingWidth: 0,
      ),
    );
  }
} 