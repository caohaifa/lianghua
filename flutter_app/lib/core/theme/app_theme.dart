import 'package:flutter/material.dart';

/// 全局金融深色主题
/// 参照 Bloomberg Terminal / TradingView / 同花顺专业版风格
class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════
  // 核心色板 (对应设计文档 2.2 色彩系统)
  // ══════════════════════════════════════════════

  /// 主背景 - 深空黑
  static const Color backgroundPrimary = Color(0xFF0D1117);
  /// 次背景 - 暗石板 (卡片背景)
  static const Color backgroundSecondary = Color(0xFF161B22);
  /// 三级背景 - 暗蓝灰 (输入框/选中态)
  static const Color backgroundTertiary = Color(0xFF1C2333);

  /// 主品牌色 - 金融蓝
  static const Color brandPrimary = Color(0xFF2E7CF6);
  /// 涨色/盈利 - 亮涨绿
  static const Color bull = Color(0xFF00C853);
  /// 跌色/亏损 - 警示红
  static const Color bear = Color(0xFFFF3B30);
  /// 成功色 - 青绿
  static const Color success = Color(0xFF00BFA5);
  /// 警示色 - 琥珀金
  static const Color warning = Color(0xFFFFB300);

  /// 文字主色 - 亮灰白
  static const Color textPrimary = Color(0xFFE6EDF3);
  /// 文字次色 - 暗灰
  static const Color textSecondary = Color(0xFF8B949E);
  /// 分割线 - 深灰线
  static const Color divider = Color(0xFF30363D);

  // ══════════════════════════════════════════════
  // 渐变色
  // ══════════════════════════════════════════════

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7CF6), Color(0xFF1A5BBF)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF3B30), Color(0xFFCC2E2A)],
  );

  static const LinearGradient profitGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C853), Color(0xFF00897B)],
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

  static const TextStyle display = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 36 / 28, color: textPrimary);
  static const TextStyle headline = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 30 / 22, color: textPrimary);
  static const TextStyle title = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 24 / 17, color: textPrimary);
  static const TextStyle body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 22 / 15, color: textPrimary);
  static const TextStyle caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 18 / 13, color: textSecondary);
  static const TextStyle numberL = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 32 / 24, color: textPrimary, fontFamily: 'RobotoMono');
  static const TextStyle numberM = TextStyle(fontSize: 17, fontWeight: FontWeight.w500, height: 24 / 17, color: textPrimary, fontFamily: 'RobotoMono');
  static const TextStyle numberS = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 18 / 13, color: textPrimary, fontFamily: 'RobotoMono');

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
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
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
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5, space: 1),
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
