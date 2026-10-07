import 'dart:math' as math;

import '../providers/market_provider.dart';

/// 技术指标集合:对一组 K 线一次计算全部经典指标,
/// 供 K 线图主/副图绘制与多空信号投票共用,保证口径唯一。
///
/// 无未来函数:索引 i 的值只使用 0..i 的数据。
class TechnicalIndicators {
  final List<KlineBar> bars;
  late final List<double> closes = [for (final b in bars) b.close];

  // 主图:MA
  late final List<double?> ma5 = _maCache[5]!;
  late final List<double?> ma10 = _maCache[10]!;
  late final List<double?> ma20 = _maCache[20]!;
  late final List<double?> ma60 = _maCache[60]!;

  // MACD(12,26,9):DIF/DEA/柱
  late final List<double?> dif;
  late final List<double?> dea;
  late final List<double?> macdHist;

  // KDJ(9,3,3)
  late final List<double?> k;
  late final List<double?> d;
  late final List<double?> j;

  // RSI(14)
  late final List<double?> rsi14;

  // BOLL(20,2)
  late final List<double?> bollMid;
  late final List<double?> bollUpper;
  late final List<double?> bollLower;

  final Map<int, List<double?>> _maCache = {};
  final Map<int, List<double?>> _emaCache = {};

  TechnicalIndicators(this.bars) {
    final n = bars.length;
    _maCache[5] = ma(5);
    _maCache[10] = ma(10);
    _maCache[20] = ma(20);
    _maCache[60] = ma(60);

    // MACD
    final e12 = ema(12);
    final e26 = ema(26);
    dif = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      if (e12[i] != null && e26[i] != null) {
        dif[i] = e12[i]! - e26[i]!;
      }
    }
    dea = _emaNullable(dif, 9);
    macdHist = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      if (dif[i] != null && dea[i] != null) {
        macdHist[i] = 2 * (dif[i]! - dea[i]!);
      }
    }

    // KDJ
    k = List<double?>.filled(n, null);
    d = List<double?>.filled(n, null);
    j = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      if (i < 8) {
        k[i] = 50;
        d[i] = 50;
      } else {
        var hh = -double.infinity, ll = double.infinity;
        for (var t = i - 8; t <= i; t++) {
          if (bars[t].high > hh) hh = bars[t].high;
          if (bars[t].low < ll) ll = bars[t].low;
        }
        final rsv = hh == ll ? 50.0 : (closes[i] - ll) / (hh - ll) * 100;
        k[i] = 2 / 3 * k[i - 1]! + 1 / 3 * rsv;
        d[i] = 2 / 3 * d[i - 1]! + 1 / 3 * k[i]!;
      }
      j[i] = 3 * k[i]! - 2 * d[i]!;
    }

    // RSI
    rsi14 = _rsi(14);

    // BOLL
    bollMid = ma(20);
    bollUpper = List<double?>.filled(n, null);
    bollLower = List<double?>.filled(n, null);
    for (var i = 19; i < n; i++) {
      final mid = bollMid[i]!;
      var v = 0.0;
      for (var t = i - 19; t <= i; t++) {
        v += (closes[t] - mid) * (closes[t] - mid);
      }
      final sd = math.sqrt(v / 20);
      bollUpper[i] = mid + 2 * sd;
      bollLower[i] = mid - 2 * sd;
    }
  }

  /// 简单移动平均(period)
  List<double?> ma(int period) {
    final cached = _maCache[period];
    if (cached != null) return cached;
    final n = closes.length;
    final out = List<double?>.filled(n, null);
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += closes[i];
      if (i >= period) s -= closes[i - period];
      if (i >= period - 1) out[i] = s / period;
    }
    _maCache[period] = out;
    return out;
  }

  /// 指数移动平均(period):前 period 根以 SMA 起步
  List<double?> ema(int period) {
    final cached = _emaCache[period];
    if (cached != null) return cached;
    final n = closes.length;
    final out = List<double?>.filled(n, null);
    var s = 0.0;
    final k = 2 / (period + 1);
    for (var i = 0; i < n; i++) {
      if (i < period) {
        s += closes[i];
        if (i == period - 1) out[i] = s / period;
      } else {
        out[i] = closes[i] * k + out[i - 1]! * (1 - k);
      }
    }
    _emaCache[period] = out;
    return out;
  }

  /// 含 null 序列的 EMA:跳过 null,前 period 个非空值以 SMA 起步
  List<double?> _emaNullable(List<double?> v, int period) {
    final n = v.length;
    final out = List<double?>.filled(n, null);
    var s = 0.0;
    var count = 0;
    final k = 2 / (period + 1);
    for (var i = 0; i < n; i++) {
      final x = v[i];
      if (x == null) continue;
      if (count < period) {
        s += x;
        count++;
        if (count == period) out[i] = s / period;
      } else {
        out[i] = x * k + out[i - 1]! * (1 - k);
      }
    }
    return out;
  }

  /// Wilder RSI
  List<double?> _rsi(int period) {
    final n = closes.length;
    final out = List<double?>.filled(n, null);
    var ag = 0.0, al = 0.0;
    for (var i = 1; i < n; i++) {
      final diff = closes[i] - closes[i - 1];
      final g = diff > 0 ? diff : 0.0;
      final l = diff < 0 ? -diff : 0.0;
      if (i <= period) {
        ag += g;
        al += l;
        if (i == period) {
          ag /= period;
          al /= period;
          out[i] = al == 0 ? 100.0 : 100 - 100 / (1 + ag / al);
        }
      } else {
        ag = (ag * (period - 1) + g) / period;
        al = (al * (period - 1) + l) / period;
        out[i] = al == 0 ? 100.0 : 100 - 100 / (1 + ag / al);
      }
    }
    return out;
  }
}

/// 副图指标类型
enum SubIndicator { vol, macd, kdj, rsi }
