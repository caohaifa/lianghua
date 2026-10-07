import '../providers/market_provider.dart';
import 'technical_indicators.dart';

/// K 线多空信号方向
enum KlineSignalSide { long, short }

/// 一根 K 线上的多空预测信号
class KlineSignal {
  /// K 线索引
  final int index;
  final KlineSignalSide side;

  /// 五指标状态投票净值(正多负空,范围 -5..5)
  final int score;

  const KlineSignal(this.index, this.side, this.score);
}

/// K 线指标多空预测(无未来函数:第 i 根信号只使用 0..i 的数据)。
///
/// 每根 K 线统计五个指标的当前多空状态,各 +1/-1/0:
///   MA   MA7 在 MA25 上方为多 / 下方为空
///   MACD DIF 在 DEA 上方为多 / 下方为空
///   KDJ  K 在 D 上方为多 / 下方为空
///   RSI  RSI14 在 50 上方为多 / 下方为空
///   BOLL 收盘价在布林中轨(20)上方为多 / 下方为空
/// 三种以上指标共振(≥3)→ 开多,(≤-3)→ 开空,比全共振更早给出提前判定;
/// 标记落在「进入共振」的首根,同一共振段不重复,方向翻转后再标记。
class KlineSignalGenerator {
  /// 提前判定所需最少同向指标数(三种以上)
  static const int consensus = 3;

  final List<KlineBar> bars;

  KlineSignalGenerator(this.bars);

  List<KlineSignal> generate() => generateWith(TechnicalIndicators(bars));

  /// 复用已计算好的指标实例(避免为画信号重复构建整套 TechnicalIndicators)
  List<KlineSignal> generateWith(TechnicalIndicators ti) {
    final n = bars.length;
    if (n < 35) return const [];

    final ma7 = ti.ma(7);
    final ma25 = ti.ma(25);

    int state(double? a, double? b) {
      if (a == null || b == null) return 0;
      if (a > b) return 1;
      if (a < b) return -1;
      return 0;
    }

    final result = <KlineSignal>[];
    KlineSignalSide? marked;

    for (var i = 0; i < n; i++) {
      final votes = state(ma7[i], ma25[i]) +
          state(ti.dif[i], ti.dea[i]) +
          state(ti.k[i], ti.d[i]) +
          state(ti.rsi14[i], 50) +
          state(ti.closes[i], ti.bollMid[i]);

      if (votes >= consensus && marked != KlineSignalSide.long) {
        result.add(KlineSignal(i, KlineSignalSide.long, votes));
        marked = KlineSignalSide.long;
      } else if (votes <= -consensus && marked != KlineSignalSide.short) {
        result.add(KlineSignal(i, KlineSignalSide.short, votes));
        marked = KlineSignalSide.short;
      }
    }
    return result;
  }
}
