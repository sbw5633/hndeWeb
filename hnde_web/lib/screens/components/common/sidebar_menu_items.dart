import 'package:flutter/material.dart';
import 'sidebar.dart';

class SidebarMenuItemData {
  final IconData icon;
  final String label;
  final String routeName;
  const SidebarMenuItemData({required this.icon, required this.label, required this.routeName});
}

const List<SidebarMenuItemData> sidebarMenuItems = [
  SidebarMenuItemData(icon: Icons.dashboard, label: '대시보드', routeName: '/'),
  SidebarMenuItemData(icon: Icons.campaign, label: '공지사항', routeName: '/notices'),
  SidebarMenuItemData(icon: Icons.forum, label: '게시판', routeName: '/boards'),
  SidebarMenuItemData(icon: Icons.file_present, label: '자료요청', routeName: '/data-requests'),
  SidebarMenuItemData(icon: Icons.business, label: '회사정보', routeName: '/company'),
  SidebarMenuItemData(icon: Icons.work, label: '업무기능', routeName: '/work'),
  SidebarMenuItemData(icon: Icons.admin_panel_settings, label: '관리자', routeName: '/admin'),
]; 