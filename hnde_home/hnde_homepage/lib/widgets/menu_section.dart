import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../models/menu_structure.dart';
import 'submenu_horizontal_scroll.dart';
import 'content_page.dart';

class MenuSection extends StatefulWidget {
  final MenuItem menu;
  final AutoScrollController scrollController;
  final int sectionIndex;
  final Color backgroundColor;
  final String? initialSubMenuId;

  const MenuSection({
    super.key,
    required this.menu,
    required this.scrollController,
    required this.sectionIndex,
    required this.backgroundColor,
    this.initialSubMenuId,
  });

  @override
  State<MenuSection> createState() => _MenuSectionState();
}

class _MenuSectionState extends State<MenuSection> {
  String? _selectedSubMenuId;
  final GlobalKey _subMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // initialSubMenuId가 있으면 사용, 없으면 첫 번째 소메뉴를 자동으로 선택
    if (widget.initialSubMenuId != null &&
        widget.menu.subMenus.any((m) => m.id == widget.initialSubMenuId)) {
      _selectedSubMenuId = widget.initialSubMenuId;
    } else if (widget.menu.subMenus.isNotEmpty) {
      _selectedSubMenuId = widget.menu.subMenus.first.id;
    }
  }

  @override
  void didUpdateWidget(MenuSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 메뉴가 변경되었을 때 또는 initialSubMenuId가 변경되었을 때
    if (widget.menu.id != oldWidget.menu.id) {
      if (widget.initialSubMenuId != null &&
          widget.menu.subMenus.any((m) => m.id == widget.initialSubMenuId)) {
        _selectedSubMenuId = widget.initialSubMenuId;
      } else if (widget.menu.subMenus.isNotEmpty) {
        _selectedSubMenuId = widget.menu.subMenus.first.id;
      }
    } else if (widget.initialSubMenuId != oldWidget.initialSubMenuId) {
      if (widget.initialSubMenuId != null &&
          widget.menu.subMenus.any((m) => m.id == widget.initialSubMenuId)) {
        _selectedSubMenuId = widget.initialSubMenuId;
      }
    }
  }

  void _onSubMenuTap(String subMenuId) async {
    setState(() {
      // 다른 메뉴를 클릭하면 선택 (닫기 기능 제거)
      _selectedSubMenuId = subMenuId;
    });

    // 소메뉴 영역으로 스크롤
    await Future.delayed(const Duration(milliseconds: 50)); // 상태 업데이트 대기
    final context = _subMenuKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0, // 화면 최상단에 위치
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutoScrollTag(
      key: ValueKey(widget.menu.id),
      controller: widget.scrollController,
      index: widget.sectionIndex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 80),
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.menu.title,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 80,
                  height: 4,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 40),
            if (widget.menu.subMenus.isNotEmpty) ...[
              AnimatedContainer(
                key: _subMenuKey,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: SubMenuHorizontalScroll(
                  subMenus: widget.menu.subMenus,
                  menuId: widget.menu.id,
                  backgroundColor: widget.backgroundColor,
                  selectedSubMenuId: _selectedSubMenuId,
                  onSubMenuTap: _onSubMenuTap,
                  isExpanded: false, // 항상 접힌 상태로 표시 (하나가 선택되어 있으므로)
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _selectedSubMenuId != null
                    ? ContentPage(
                        menuId: widget.menu.id,
                        subMenuId: _selectedSubMenuId!,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
