import 'package:flutter/material.dart';
import 'package:hnde_web/const_value.dart';

class SidebarMenuItemData {
  final IconData icon;
  final String label;
  final String routeName;
  const SidebarMenuItemData({required this.icon, required this.label, required this.routeName});
}

final List<SidebarMenuItemData> sidebarMenuItems = [
  ...AppMenus.getAll().map((menu) => SidebarMenuItemData(
    icon: menu.icon,
    label: menu.label,
    routeName: menu.route,
  )),
]; 