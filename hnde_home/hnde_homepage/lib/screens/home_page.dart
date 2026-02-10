import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/hero_section.dart';
import '../widgets/menu_section.dart';
import '../widgets/home_sections/minimal_home_content.dart';
import '../widgets/footer.dart';
import '../models/menu_structure.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AutoScrollController _scrollController = AutoScrollController();
  final List<MenuItem> _menus = MenuData.getMainMenus();
  String? _selectedMenuId; // 선택된 메뉴 ID (null이면 홈)
  String? _selectedSubMenuId; // 선택된 서브메뉴 ID

  final List<List<Color>> _sectionGradients = [
    [const Color(0xFFF5F7FF), Colors.white], // Hero
    [const Color(0xFFF5F7FF), const Color(0xFFEAF3FF)],
    [const Color(0xFFFFF7F2), Colors.white],
    [const Color(0xFFF2FBF7), Colors.white],
    [const Color(0xFFFFF5F5), Colors.white],
    [const Color(0xFFF5F4FF), Colors.white],
  ];

  List<Color> _getGradient(int index) {
    if (_sectionGradients.isEmpty) {
      return [Colors.white, Colors.white];
    }
    return _sectionGradients[index % _sectionGradients.length];
  }

  Widget _buildSectionContainer({
    required int sectionIndex,
    required Widget child,
  }) {
    final gradientColors = _getGradient(sectionIndex);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final horizontalPadding = isMobile ? 24.0 : 80.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1920),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onMenuTap(String menuId) {
    setState(() {
      if (menuId == 'home') {
        _selectedMenuId = null;
      } else {
        _selectedMenuId = menuId;
      }
    });
  }

  void _onMenuAndSubMenuTap(String menuId, String? subMenuId) {
    setState(() {
      _selectedMenuId = menuId;
      _selectedSubMenuId = subMenuId;
    });
  }

  Widget _buildMenuContent() {
    if (_selectedMenuId == null) {
      // 홈 화면: Hero 섹션 + 미니멀 콘텐츠
      return Column(
        children: [
          _buildSectionContainer(
            sectionIndex: 0,
            child: const HeroSection(),
          ),
          _buildSectionContainer(
            sectionIndex: 1,
            child: MinimalHomeContent(
              onMenuTap: _onMenuAndSubMenuTap,
            ),
          ),
        ],
      );
    }

    // 선택된 메뉴의 내용 표시
    final selectedMenu = _menus.firstWhere(
      (m) => m.id == _selectedMenuId,
      orElse: () => _menus.first,
    );

    final menuIndex = _menus.indexWhere((m) => m.id == _selectedMenuId);
    final sectionIndex = menuIndex >= 0 ? menuIndex : 0;

    return _buildSectionContainer(
      sectionIndex: sectionIndex,
      child: MenuSection(
        menu: selectedMenu,
        scrollController: _scrollController,
        sectionIndex: sectionIndex,
        backgroundColor: _getGradient(sectionIndex).first,
        initialSubMenuId: _selectedSubMenuId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MainNavigationBar(
            scrollController: _scrollController,
            onMenuTap: _onMenuTap,
            selectedMenuId: _selectedMenuId,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMenuContent(),
                  Footer(
                    onMenuTap: _onMenuAndSubMenuTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
