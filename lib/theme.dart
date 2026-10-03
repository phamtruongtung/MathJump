import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF3B3355);
  static const cream = Color(0xFFFFF9EC);
  static const sun = Color(0xFFFFD43B);
  static const orange = Color(0xFFFF9F43);
  static const pink = Color(0xFFFF7EB3);
  static const purple = Color(0xFF9775FA);
  static const blue = Color(0xFF4DABF7);
  static const green = Color(0xFF40C057);
  static const red = Color(0xFFFA5252);
  static const grass = Color(0xFF82C91E);
  static const dirt = Color(0xFFB07A4F);
  static const facebook = Color(0xFF1877F2);

  static const choices = [orange, blue, pink, purple];
}

/// 12 con giáp (theo lịch Việt Nam: Sửu là trâu, Mão là mèo).
const kZodiac = <({String emoji, String vi, String en})>[
  (emoji: '🐭', vi: 'Tý', en: 'Rat'),
  (emoji: '🐃', vi: 'Sửu', en: 'Buffalo'),
  (emoji: '🐯', vi: 'Dần', en: 'Tiger'),
  (emoji: '🐱', vi: 'Mão', en: 'Cat'),
  (emoji: '🐲', vi: 'Thìn', en: 'Dragon'),
  (emoji: '🐍', vi: 'Tỵ', en: 'Snake'),
  (emoji: '🐴', vi: 'Ngọ', en: 'Horse'),
  (emoji: '🐐', vi: 'Mùi', en: 'Goat'),
  (emoji: '🐵', vi: 'Thân', en: 'Monkey'),
  (emoji: '🐔', vi: 'Dậu', en: 'Rooster'),
  (emoji: '🐶', vi: 'Tuất', en: 'Dog'),
  (emoji: '🐷', vi: 'Hợi', en: 'Pig'),
];

/// Con giáp của năm hiện tại (năm 4 sau Công nguyên là năm Tý).
String zodiacOfYear(int year) => kZodiac[(year - 4) % 12].emoji;

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
    scaffoldBackgroundColor: AppColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}

/// AppBar trong suốt dùng chung cho các màn hình phụ.
AppBar kidAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) =>
    AppBar(
      title: Text(title,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.ink,
      actions: actions,
      bottom: bottom,
    );

BoxDecoration cardDecoration({Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    );
