import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppShell {
  static const Color deepBlue = Color(0xFF1E3A8A);
  static const Color surface = Color(0xFF0B1220);

  /// AppThemeData 기반으로 통일된 테마 생성. 설정 변경 시 전체 UI가 한 속성으로 일괄 반영됨.
  static ThemeData buildThemeFromAppTheme(AppThemeData appTheme) {
    final String ff = appTheme.fontFamily.trim().isEmpty ? 'NotoSansKR' : appTheme.fontFamily.trim();
    final bool isLight = appTheme.bg.computeLuminance() > 0.5;
    final Color cardColor = isLight
        ? (Color.lerp(appTheme.bg, Colors.white, 0.95) ?? Colors.white)
        : (Color.lerp(appTheme.bg, Colors.white, 0.08) ?? appTheme.bg);
    final Color borderColor = Color.lerp(appTheme.primary, Colors.black, 0.85) ?? appTheme.primary;
    final Color inputFillColor = Color.lerp(appTheme.bg, Colors.black, isLight ? 0.02 : 0.08) ?? appTheme.bg;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: appTheme.primary,
      brightness: isLight ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: appTheme.primary,
      surface: appTheme.bg,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: appTheme.bg,
      fontFamily: ff,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(appTheme.radius)),
          side: BorderSide(color: borderColor.withOpacity(0.2)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(appTheme.radius)),
          side: BorderSide(color: borderColor.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radius),
          borderSide: BorderSide(color: borderColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radius),
          borderSide: BorderSide(color: borderColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radius),
          borderSide: BorderSide(color: appTheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radius)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
    return base;
  }

  /// 스플래시/로그인 화면용 기본 테마 (Provider 없을 때)
  static ThemeData buildTheme() =>
      buildThemeFromAppTheme(ThemePresets.signature[0].data);
}

