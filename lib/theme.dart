import 'package:flutter/material.dart';

/// 黄油可颂配色：奶油 + 黄油金 + 焦糖棕
class ButterColors {
  // 亮色
  static const cream = Color(0xFFFFF7EC);
  static const creamDeep = Color(0xFFFFF0DA);
  static const butter = Color(0xFFF0A93C);
  static const butterDark = Color(0xFFD98E1F);
  static const caramel = Color(0xFFB8771E);
  static const brown = Color(0xFF4A3520);
  static const brownLight = Color(0xFF8A6A48);
  static const bubbleBot = Color(0xFFFFFFFF);
  static const bubbleBotText = Color(0xFF4A3520);
  static const bubbleBotBorder = Color(0xFFF0E0C4);

  // 暗色
  static const darkBg = Color(0xFF1E1A15);
  static const darkCard = Color(0xFF2A241C);
  static const darkBorder = Color(0xFF3A3226);
  static const darkText = Color(0xFFEDE3D4);
  static const darkSub = Color(0xFFA89279);
}

ThemeData buildTheme({bool dark = false}) {
  final scheme = dark
      ? ColorScheme.fromSeed(
          seedColor: ButterColors.butter,
          brightness: Brightness.dark,
          primary: ButterColors.butter,
          secondary: ButterColors.caramel,
          surface: ButterColors.darkCard,
        )
      : ColorScheme.fromSeed(
          seedColor: ButterColors.butter,
          primary: ButterColors.butter,
          secondary: ButterColors.caramel,
          surface: ButterColors.cream,
        );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? ButterColors.darkBg : ButterColors.cream,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? ButterColors.darkCard : ButterColors.butter,
      foregroundColor: dark ? ButterColors.darkText : Colors.white,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: dark ? ButterColors.darkCard : Colors.white,
    dividerColor: dark ? ButterColors.darkBorder : ButterColors.bubbleBotBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF332C22) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      hintStyle: TextStyle(color: dark ? ButterColors.darkSub : ButterColors.brownLight),
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
