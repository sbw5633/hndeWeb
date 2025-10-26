import 'package:flutter/material.dart';

const String kLogoHorizontal = 'assets/images/logo_horizontal.png';
const String kLogoVertical = 'assets/images/logo_vertical.png';

enum MenuType {
  dashboard,
  notice,
  board,
  anonymousBoard,
  dataRequest,
  company,
  work,
  admin,
}

class MenuItem {
  final MenuType type;
  final IconData icon;
  final String label;
  final String route;
  final bool requiresAuth;
  final bool requiresAdmin;

  const MenuItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.route,
    this.requiresAuth = false,
    this.requiresAdmin = false,
  });
}

// MenuType에 extension 추가
extension MenuTypeExtension on MenuType {
  MenuItem get menuItem => AppMenus.get(this);
  
  String get route => menuItem.route;
  String get label => menuItem.label;
  IconData get icon => menuItem.icon;
  bool get requiresAuth => menuItem.requiresAuth;
  bool get requiresAdmin => menuItem.requiresAdmin;
}

class WritePage {
  static const Map<MenuType, String> _writePages = {
    MenuType.notice: '/write-notice',
    MenuType.board: '/write-board',
    MenuType.anonymousBoard: '/write-anonymous-board',
    MenuType.dataRequest: '/write-data-request',
  };
  static String get(MenuType type) => _writePages[type]!;
}

class AppMenus {
  static const Map<MenuType, MenuItem> _menus = {
    MenuType.dashboard: MenuItem(
      type: MenuType.dashboard,
      icon: Icons.dashboard,
      label: '대시보드',
      route: '/',
    ),
    MenuType.notice: MenuItem(
      type: MenuType.notice,
      icon: Icons.announcement,
      label: '공지사항',
      route: '/notices',
    ),
    MenuType.board: MenuItem(
      type: MenuType.board,
      icon: Icons.forum,
      label: '게시판',
      route: '/boards',
    ),
    MenuType.anonymousBoard: MenuItem(
      type: MenuType.anonymousBoard,
      icon: Icons.chat,
      label: '익명게시판',
      route: '/anonymous-boards',
    ),
    MenuType.dataRequest: MenuItem(
      type: MenuType.dataRequest,
      icon: Icons.file_present,
      label: '자료요청',
      route: '/data-requests',
    ),
    MenuType.company: MenuItem(
      type: MenuType.company,
      icon: Icons.business,
      label: '회사정보',
      route: '/company',
    ),
    MenuType.work: MenuItem(
      type: MenuType.work,
      icon: Icons.work,
      label: '업무기능',
      route: '/work',
    ),
    MenuType.admin: MenuItem(
      type: MenuType.admin,
      icon: Icons.admin_panel_settings,
      label: '관리자',
      route: '/admin',
      requiresAuth: true,
      requiresAdmin: true,
    ),
  };

  // 메뉴 아이템 가져오기
  static MenuItem get(MenuType type) => _menus[type]!;

  // 모든 메뉴 리스트 가져오기
  static List<MenuItem> getAll() => _menus.values.toList();

  // 인증이 필요한 메뉴만 가져오기
  static List<MenuItem> getAuthRequired() => 
      _menus.values.where((menu) => menu.requiresAuth).toList();

  // 관리자 권한이 필요한 메뉴만 가져오기
  static List<MenuItem> getAdminRequired() => 
      _menus.values.where((menu) => menu.requiresAdmin).toList();

  // 특정 조건에 맞는 메뉴 가져오기
  static List<MenuItem> getFiltered({
    bool? requiresAuth,
    bool? requiresAdmin,
  }) {
    return _menus.values.where((menu) {
      if (requiresAuth != null && menu.requiresAuth != requiresAuth) return false;
      if (requiresAdmin != null && menu.requiresAdmin != requiresAdmin) return false;
      return true;
    }).toList();
  }
}