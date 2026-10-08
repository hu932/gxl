import 'package:flutter/material.dart';

/// 黄油可颂配色：奶油 + 黄油金 + 焦糖棕
class ButterColors {
  static const cream = Color(0xFFFFF7EC);      // 奶油背景
  static const creamDeep = Color(0xFFFFF0DA); // 深一档奶油
  static const butter = Color(0xFFF0A93C);     // 黄油金
  static const butterDark = Color(0xFFD98E1F); // 深黄油
  static const caramel = Color(0xFFB8771E);    // 焦糖
  static const brown = Color(0xFF4A3520);      // 暖棕正文
  static const brownLight = Color(0xFF8A6A48); // 浅棕次要
  static const bubbleUser = Color(0xFFF0A93C);
  static const bubbleUserText = Color(0xFFFFFFFF);
  static const bubbleBot = Color(0xFFFFFFFF);
  static const bubbleBotText = Color(0xFF4A3520);
  static const bubbleBotBorder = Color(0xFFF0E0C4);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ButterColors.butter,
      primary: ButterColors.butter,
      secondary: ButterColors.caramel,
      surface: ButterColors.cream,
    ),
    scaffoldBackgroundColor: ButterColors.cream,
    fontFamily: null,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: ButterColors.butter,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      hintStyle: const TextStyle(color: ButterColors.brownLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: ButterColors.butter, width: 1.4),
      ),
    ),
  );
}
