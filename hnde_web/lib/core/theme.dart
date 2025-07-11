import 'package:flutter/material.dart';

final appTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF4DA3D2),
  scaffoldBackgroundColor: const Color(0xFFD0E8F2),
  fontFamily: 'NotoSansKR',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF4DA3D2),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: const Color(0xFF4DA3D2),
    secondary: const Color(0xFF336699),
  ),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    elevation: 2,
    color: Colors.white,
  ),
); 