import 'package:flutter/material.dart';

/// 全局金融深色主题
/// 参照币安 Binance APP 设计语言
class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════
  // 核心色板 (币安配色)
  // ══════════════════════════════════════════════

  /// 主背景 - 币安深黑
  static const Color backgroundPrimary = Color(0xFF0B0E11);

  /// 次背景 - 币安卡片底
  static const Color backgroundSecondary = Color(0xFF1E2329);

  /// 三级背景 - 输入框/选中态
  static const Color backgroundTertiary = Color(0xFF2B3139);

  /// 主品牌色 - 币安黄
  static const Color brandPrimary = Color(0xFFF0B90B);

  /// 涨色/盈利 - 币安绿
  static const Color bull = Color(0xFF0ECB81);

  /// 跌色/亏损 - 币安红
  static const Color bear = Color(0xFFF6465D);

  /// 成功色 - 同币安绿
  static const Color success = Color(0xFF0ECB81);

  /// 警示色 - 币安黄
  static const Color warning = Color(0xFFF0B90B);

  /// 文字主色 - 币安亮白
  static const Color textPrimary = Color(0xFFEAECEF);

  /// 文字次色 - 币安灰
  static const Color textSecondary = Color(0xFF848E9C);

  /// 文字三级色 - 币安深灰(辅助说明/免责)
  static const Color textTertiary = Color(0xFF5E6673);

  /// 分割线 - 币安深灰线
  static const Color divider = Color(0xFF2B3139);

  /// 品牌黄底上的深色文字/图标
  static const Color onBrand = Color(0xFF0B0E11);

  // ══════════════════════════════════════════════
  // 渐变色
  // ══════════════════════════════════════════════

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0B90B), Color(0xFFCF9A08)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6465D), Color(0xFFCF304A)],
  );

  static const LinearGradient profitGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0ECB81), Color(0xFF0AA66B)],
  );

  // ══════════════════════════════════════════════
  // 间距与圆角 (对应设计文档 2.4)
  // ══════════════════════════════════════════════

  static const double pagePadding = 16.0;
  static const double cardSpacing = 12.0;
  static const double cardPadding = 16.0;
  static const double minListHeight = 56.0;
  static const double cardRadius = 12.0;
  static const double buttonRadius = 8.0;
  static const double tagRadius = 4.0;
  static const double dialogRadius = 16.0;

  // ══════════════════════════════════════════════
  // 字体层级 (对应设计文档 2.3)
  // ══════════════════════════════════════════════

  static const TextStyle display = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 36 / 28,
      color: textPrimary);
  static const TextStyle headline = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 30 / 22,
      color: textPrimary);
  static const TextStyle title = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 24 / 17,
      color: textPrimary);
  static const TextStyle body = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 22 / 15,
      color: textPrimary);
  static const TextStyle caption = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 18 / 13,
      color: textSecondary);
  static const TextStyle numberL = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 32 / 24,
      color: textPrimary,
      fontFamily: 'RobotoMono');
  static const TextStyle numberM = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 24 / 17,
      color: textPrimary,
      fontFamily: 'RobotoMono');
  static const TextStyle numberS = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 18 / 13,
      color: textPrimary,
      fontFamily: 'RobotoMono');

  // ══════════════════════════════════════════════
  // 深色金融主题
  // ══════════════════════════════════════════════

  static ThemeData get darkFinanceTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: backgroundPrimary,
      primaryColor: brandPrimary,
      colorScheme: const ColorScheme.dark(
        primary: brandPrimary,
        secondary: bull,
        error: bear,
        surface: backgroundSecondary,
        onPrimary: onBrand,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundPrimary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      // Flutter 3.27+ 中 cardTheme 参数类型为 CardThemeData
      cardTheme: CardThemeData(
        color: backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: divider, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: onBrand,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: divider),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: brandPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),
      dividerTheme:
          const DividerThemeData(color: divider, thickness: 0.5, space: 1),
      // SnackBar 统一深色浮动样式,底部边距避开浮动胶囊导航(62+18)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: backgroundTertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          side: const BorderSide(color: divider, width: 0.5),
        ),
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundSecondary,
        selectedItemColor: brandPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 14,
      ),
    );
  }
}
