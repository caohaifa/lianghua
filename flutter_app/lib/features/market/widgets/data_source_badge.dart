import 'package:flutter/material.dart';

/// 行情数据来源徽标:模仿来源网站品牌风格
/// crypto  → 币安 Binance(品牌黄 #F0B90B + 45° 菱形标志)
/// a-share → 新浪财经(品牌红 #E6162D + 圆点)
class DataSourceBadge extends StatelessWidget {
  final String market; // 'crypto' / 'a-share'
  final double fontSize;
  const DataSourceBadge({super.key, required this.market, this.fontSize = 10});

  /// 来源名称(供文字场景使用)
  static String sourceName(String market) =>
      market == 'crypto' ? '币安 Binance' : '新浪财经';

  @override
  Widget build(BuildContext context) {
    final isCrypto = market == 'crypto';
    final brandColor =
        isCrypto ? const Color(0xFFF0B90B) : const Color(0xFFE6162D);
    final size = fontSize * 0.9;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isCrypto
            // 币安菱形标志
            ? Transform.rotate(
                angle: 0.785398, // π/4
                child: Container(width: size, height: size, color: brandColor),
              )
            // 新浪红圆点
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    color: brandColor, shape: BoxShape.circle),
              ),
        const SizedBox(width: 4),
        Text(
          isCrypto ? 'Binance' : '新浪财经',
          style: TextStyle(
              color: brandColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
