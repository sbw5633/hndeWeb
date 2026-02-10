import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../models/menu_structure.dart';
import '../services/data_service.dart';
import '../models/home_page_config.dart';

class MainNavigationBar extends StatefulWidget {
  final AutoScrollController scrollController;
  final Function(String menuId) onMenuTap;
  final String? selectedMenuId;

  const MainNavigationBar({
    super.key,
    required this.scrollController,
    required this.onMenuTap,
    this.selectedMenuId,
  });

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  final DataService _dataService = DataService();
  HomePageConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      print('🔝 MainNavigationBar: 설정 로딩 시작');
      final config = await _dataService.getHomePageConfig();
      print('🔝 MainNavigationBar: 받은 설정 = $config');
      print('🔝 MainNavigationBar: topLogoUrl = ${config?.topLogoUrl}');
      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
        print(
            '🔝 MainNavigationBar: 상태 업데이트 완료, topLogoUrl=${_config?.topLogoUrl}');
      }
    } catch (e, stackTrace) {
      print('❌ MainNavigationBar: 설정 로딩 오류: $e');
      print('스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menus = MenuData.getMainMenus();
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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  widget.onMenuTap('home');
                },
                child: _isLoading
                  ? const SizedBox(
                      height: 50,
                      width: 100,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _config?.topLogoUrl != null &&
                          _config!.topLogoUrl!.isNotEmpty
                      ? Hero(
                          tag: 'app_logo',
                          child: Image.network(
                            _config!.topLogoUrl!,
                            height: 50,
                            fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              print('🔝 로고 이미지 로드 완료: ${_config!.topLogoUrl}');
                              return child;
                            }
                            return const SizedBox(
                              height: 50,
                              width: 100,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ 로고 이미지 로드 실패: $error');
                            return Hero(
                              tag: 'app_logo',
                              child: Text(
                                'H&DE',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                      : Hero(
                          tag: 'app_logo',
                          child: Text(
                            'H&DE',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
              ),
            ),
            if (!isMobile)
              Row(
                children: menus.map((menu) {
                  final isSelected = (menu.id == 'home' && widget.selectedMenuId == null) ||
                      (menu.id != 'home' && widget.selectedMenuId == menu.id);
                  return Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: _NavItem(
                      label: menu.title,
                      isSelected: isSelected,
                      onTap: () {
                        widget.onMenuTap(menu.id);
                      },
                    ),
                  );
                }).toList(),
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
  final bool isSelected;

  const _NavItem({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.orange : Colors.black87,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 20,
                color: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }
}
