import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/menu_structure.dart';

class SubMenuHorizontalScroll extends StatefulWidget {
  final List<SubMenuItem> subMenus;
  final String menuId;
  final Color backgroundColor;
  final String? selectedSubMenuId;
  final Function(String subMenuId) onSubMenuTap;
  final bool isExpanded;

  const SubMenuHorizontalScroll({
    super.key,
    required this.subMenus,
    required this.menuId,
    required this.backgroundColor,
    this.selectedSubMenuId,
    required this.onSubMenuTap,
    this.isExpanded = true,
  });

  @override
  State<SubMenuHorizontalScroll> createState() =>
      _SubMenuHorizontalScrollState();
}

class _SubMenuHorizontalScrollState extends State<SubMenuHorizontalScroll> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    // 각 카드에 대한 GlobalKey 생성
    for (var subMenu in widget.subMenus) {
      _cardKeys[subMenu.id] = GlobalKey();
    }
    _scrollController.addListener(_updateArrowVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateArrowVisibility();
      _scrollToSelectedCard();
    });
  }

  @override
  void didUpdateWidget(SubMenuHorizontalScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 선택된 소메뉴가 변경되면 해당 카드로 스크롤
    if (oldWidget.selectedSubMenuId != widget.selectedSubMenuId &&
        widget.selectedSubMenuId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedCard();
      });
    }
  }

  void _scrollToSelectedCard() {
    if (widget.selectedSubMenuId == null || !_scrollController.hasClients)
      return;

    final selectedIndex = widget.subMenus.indexWhere(
      (menu) => menu.id == widget.selectedSubMenuId,
    );

    if (selectedIndex == -1) return;

    // 카드 너비 + 간격 계산
    final cardWidth = 300.0;
    final cardSpacing = 24.0;
    final padding = 80.0;

    // 선택된 카드의 위치 계산
    final targetScroll = (selectedIndex * (cardWidth + cardSpacing)) - padding;

    // 스크롤 범위 확인
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;

    final finalScroll = targetScroll.clamp(minScroll, maxScroll);

    _scrollController.animateTo(
      finalScroll,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrowVisibility() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _showLeftArrow = currentScroll > 0;
      _showRightArrow = currentScroll < maxScroll - 10;
    });
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      math.max(0, _scrollController.offset - 300),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      math.min(
        _scrollController.position.maxScrollExtent,
        _scrollController.offset + 300,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Color get _backgroundColor => widget.backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.isExpanded ? null : 100,
      width: double.infinity,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: 80,
              vertical: widget.isExpanded ? 24 : 12,
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.subMenus.asMap().entries.map((entry) {
                  final index = entry.key;
                  final subMenu = entry.value;
                  return Padding(
                    key: _cardKeys[subMenu.id],
                    padding: EdgeInsets.only(
                        right: index < widget.subMenus.length - 1 ? 24 : 0),
                    child: _SubMenuCard(
                      subMenu: subMenu,
                      menuId: widget.menuId,
                      isSelected: widget.selectedSubMenuId == subMenu.id,
                      isExpanded: widget.isExpanded,
                      onTap: () => widget.onSubMenuTap(subMenu.id),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_showLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _backgroundColor,
                      _backgroundColor.withOpacity(0),
                    ],
                  ),
                ),
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    onPressed: _scrollLeft,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          if (_showRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      _backgroundColor,
                      _backgroundColor.withOpacity(0),
                    ],
                  ),
                ),
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    onPressed: _scrollRight,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubMenuCard extends StatelessWidget {
  final SubMenuItem subMenu;
  final String menuId;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SubMenuCard({
    required this.subMenu,
    required this.menuId,
    this.isSelected = false,
    this.isExpanded = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 300,
      height: isExpanded ? 400 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.orange : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.15 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isExpanded ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: isExpanded ? 24 : 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.orange : Colors.blue[900],
                ),
                child: Text(
                  subMenu.title,
                  maxLines: isExpanded ? null : 1,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: Text(
                    '${subMenu.title} 콘텐츠를 확인하려면 클릭하세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
