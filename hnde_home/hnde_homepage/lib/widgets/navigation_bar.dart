import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class CustomNavigationBar extends StatelessWidget {
  final AutoScrollController scrollController;

  const CustomNavigationBar({
    super.key,
    required this.scrollController,
  });

  Future<void> _scrollToIndex(int index) async {
    await scrollController.scrollToIndex(
      index,
      preferPosition: AutoScrollPosition.begin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'H&DE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            if (!isMobile)
              Row(
                children: [
                  _NavItem(
                    label: '홈',
                    onTap: () => _scrollToIndex(0),
                  ),
                  const SizedBox(width: 32),
                  _NavItem(
                    label: '회사소개',
                    onTap: () => _scrollToIndex(1),
                  ),
                  const SizedBox(width: 32),
                  _NavItem(
                    label: '사업분야',
                    onTap: () => _scrollToIndex(2),
                  ),
                  const SizedBox(width: 32),
                  _NavItem(
                    label: '프로젝트',
                    onTap: () => _scrollToIndex(3),
                  ),
                  const SizedBox(width: 32),
                  _NavItem(
                    label: '공지사항',
                    onTap: () => _scrollToIndex(4),
                  ),
                  const SizedBox(width: 32),
                  _NavItem(
                    label: '연락처',
                    onTap: () => _scrollToIndex(5),
                  ),
                ],
              )
            else
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  // 모바일 메뉴 표시
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}
