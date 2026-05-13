import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 시스템 설정에서 변경 가능한 테마
class AppThemeData {
  const AppThemeData({
    required this.primary,
    required this.sidebar,
    required this.bg,
    this.radius = 28.0,
    this.fontFamily = 'NotoSansKR',
  });

  final Color primary;
  final Color sidebar;
  final Color bg;
  final double radius;
  /// 폰트 선택.
  /// pubspec.yaml 에 등록된 asset font family 이름
  final String fontFamily;

  /// 밝기에 따른 텍스트 색상 (밝으면 어두운 글자, 어두우면 밝은 글자)
  Color get sidebarText => _getContrastColor(sidebar);

  static Color _getContrastColor(Color c) {
    final double brightness =
        (c.red * 299 + c.green * 587 + c.blue * 114) / 1000;
    return brightness > 155 ? const Color(0xFF1E293B) : Colors.white;
  }

  AppThemeData copyWith({
    Color? primary,
    Color? sidebar,
    Color? bg,
    double? radius,
    String? fontFamily,
  }) {
    return AppThemeData(
      primary: primary ?? this.primary,
      sidebar: sidebar ?? this.sidebar,
      bg: bg ?? this.bg,
      radius: radius ?? this.radius,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

/// 기본값: 클래식 딥 블루
const AppThemeData _defaultTheme = AppThemeData(
  primary: Color(0xFF1E3A8A),
  sidebar: Color(0xFF1E3A8A),
  bg: Color(0xFFF1F5F9),
  radius: 28.0,
);

class AppThemeNotifier extends ChangeNotifier {
  AppThemeNotifier() {
    unawaited(_loadFromPrefs());
  }

  static const String _kPrefThemePrimary = 'settings.theme.primary';
  static const String _kPrefThemeSidebar = 'settings.theme.sidebar';
  static const String _kPrefThemeBg = 'settings.theme.bg';
  static const String _kPrefThemeRadius = 'settings.theme.radius';
  static const String _kPrefThemeFontFamily = 'settings.theme.fontFamily';

  AppThemeData _theme = _defaultTheme;

  AppThemeData get theme => _theme;

  void setTheme(AppThemeData t) {
    _theme = t;
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  void updatePrimary(Color c) {
    _theme = _theme.copyWith(primary: c);
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  void updateSidebar(Color c) {
    _theme = _theme.copyWith(sidebar: c);
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  void updateBg(Color c) {
    _theme = _theme.copyWith(bg: c);
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  void updateRadius(double r) {
    _theme = _theme.copyWith(radius: r);
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  void updateFontFamily(String fontFamily) {
    _theme = _theme.copyWith(fontFamily: fontFamily.trim().isEmpty ? 'google:NotoSansKR' : fontFamily.trim());
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  Future<void> _loadFromPrefs() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final int? p = sp.getInt(_kPrefThemePrimary);
      final int? s = sp.getInt(_kPrefThemeSidebar);
      final int? b = sp.getInt(_kPrefThemeBg);
      final double? r = sp.getDouble(_kPrefThemeRadius);
      final String? ff = sp.getString(_kPrefThemeFontFamily);

      final AppThemeData next = _theme.copyWith(
        primary: p == null ? null : Color(p),
        sidebar: s == null ? null : Color(s),
        bg: b == null ? null : Color(b),
        radius: r,
        fontFamily: ff,
      );
      _theme = next;
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setInt(_kPrefThemePrimary, _theme.primary.value);
      await sp.setInt(_kPrefThemeSidebar, _theme.sidebar.value);
      await sp.setInt(_kPrefThemeBg, _theme.bg.value);
      await sp.setDouble(_kPrefThemeRadius, _theme.radius);
      await sp.setString(_kPrefThemeFontFamily, _theme.fontFamily);
    } catch (_) {
      return;
    }
  }
}

/// 테마 프리셋 (이름 + 데이터)
class ThemePresetItem {
  const ThemePresetItem(this.name, this.data);
  final String name;
  final AppThemeData data;
}

class ThemePresets {
  ThemePresets._();

  static const List<ThemePresetItem> signature = <ThemePresetItem>[
    ThemePresetItem('클래식 딥 블루', AppThemeData(
      primary: Color(0xFF1E3A8A),
      sidebar: Color(0xFF1E3A8A),
      bg: Color(0xFFF1F5F9),
    )),
    ThemePresetItem('에메랄드 포레스트', AppThemeData(
      primary: Color(0xFF059669),
      sidebar: Color(0xFF064E3B),
      bg: Color(0xFFECFDF5),
    )),
    ThemePresetItem('임페리얼 퍼플', AppThemeData(
      primary: Color(0xFF7C3AED),
      sidebar: Color(0xFF4C1D95),
      bg: Color(0xFFF5F3FF),
    )),
  ];

  static const List<ThemePresetItem> light = <ThemePresetItem>[
    ThemePresetItem('솔리드 화이트', AppThemeData(
      primary: Color(0xFF1E293B),
      sidebar: Color(0xFFFFFFFF),
      bg: Color(0xFFF8FAFC),
    )),
    ThemePresetItem('오션 스카이', AppThemeData(
      primary: Color(0xFF0284C7),
      sidebar: Color(0xFFE0F2FE),
      bg: Color(0xFFF0F9FF),
    )),
    ThemePresetItem('블라썸 핑크', AppThemeData(
      primary: Color(0xFFDB2777),
      sidebar: Color(0xFFFCE7F3),
      bg: Color(0xFFFDF2F8),
    )),
  ];
}
