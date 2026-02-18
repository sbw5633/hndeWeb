import 'business_type.dart';

class MenuItem {
  final String id;
  final String title;
  final List<SubMenuItem> subMenus;
  final String? route;

  MenuItem({
    required this.id,
    required this.title,
    required this.subMenus,
    this.route,
  });
}

class SubMenuItem {
  final String id;
  final String title;
  final String? route;

  SubMenuItem({
    required this.id,
    required this.title,
    this.route,
  });
}

class MenuData {
  static List<MenuItem> getMainMenus({List<BusinessType>? businessTypes}) {
    // 기본 하위메뉴 (기존 3개)
    final defaultBusinessSubMenus = [
      SubMenuItem(
          id: 'restarea', title: '휴게소사업', route: '/business/restarea'),
      SubMenuItem(
          id: 'manufacturing',
          title: '제조유통사업',
          route: '/business/manufacturing'),
      SubMenuItem(id: 'food', title: '식음료사업', route: '/business/food'),
    ];

    // 동적 사업 타입을 하위메뉴로 추가
    final businessSubMenus = <SubMenuItem>[...defaultBusinessSubMenus];
    if (businessTypes != null) {
      for (final businessType in businessTypes) {
        // 기본 3개와 중복되지 않는 경우만 추가
        final isDefault = businessType.name.contains('휴게소') ||
            businessType.name.contains('제조유통') ||
            businessType.name.contains('식음료');
        if (!isDefault) {
          businessSubMenus.add(SubMenuItem(
            id: businessType.id,
            title: businessType.name,
            route: '/business/${businessType.id}',
          ));
        }
      }
    }

    return [
      MenuItem(
        id: 'home',
        title: '홈',
        subMenus: [],
        route: '/',
      ),
      MenuItem(
        id: 'company',
        title: '회사소개',
        subMenus: [
          SubMenuItem(id: 'ceo', title: 'CEO 인사말', route: '/company/ceo'),
          SubMenuItem(id: 'history', title: '연혁', route: '/company/history'),
          SubMenuItem(
              id: 'vision', title: '경영이념 및 비전', route: '/company/vision'),
          SubMenuItem(
              id: 'location', title: '찾아오시는 길', route: '/company/location'),
        ],
        route: '/company',
      ),
      MenuItem(
        id: 'business',
        title: '사업소개',
        subMenus: businessSubMenus,
        route: '/business',
      ),
      MenuItem(
        id: 'pr',
        title: '홍보센터',
        subMenus: [
          SubMenuItem(id: 'ci', title: 'CI소개', route: '/pr/ci'),
          SubMenuItem(id: 'press', title: '보도자료', route: '/pr/press'),
          SubMenuItem(id: 'events', title: '고객이벤트', route: '/pr/events'),
        ],
        route: '/pr',
      ),
      MenuItem(
        id: 'community',
        title: '커뮤니티',
        subMenus: [
          SubMenuItem(id: 'notice', title: '공지사항', route: '/community/notice'),
          SubMenuItem(
              id: 'stories', title: '고객의 이야기', route: '/community/stories'),
          SubMenuItem(
              id: 'proposal', title: '사업제안', route: '/community/proposal'),
        ],
        route: '/community',
      ),
      MenuItem(
        id: 'recruitment',
        title: '인재채용',
        subMenus: [
          SubMenuItem(id: 'info', title: '채용안내', route: '/recruitment/info'),
        ],
        route: '/recruitment',
      ),
    ];
  }
}
