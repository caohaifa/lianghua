import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

/// 合约账户视图(/futures/account)
class FuturesAccountView {
  final double walletBalance;
  final double available;
  final double usedMargin;
  final double unrealizedPnl;
  final double totalEquity;
  final double marginRatio;
  final int positionCount;

  FuturesAccountView.fromJson(Map<String, dynamic> j)
      : walletBalance = (j['wallet_balance'] as num).toDouble(),
        available = (j['available'] as num).toDouble(),
        usedMargin = (j['used_margin'] as num).toDouble(),
        unrealizedPnl = (j['unrealized_pnl'] as num).toDouble(),
        totalEquity = (j['total_equity'] as num).toDouble(),
        marginRatio = (j['margin_ratio'] as num).toDouble(),
        positionCount = j['position_count'] ?? 0;
}

/// 合约持仓(/futures/positions)
class FuturesPositionItem {
  final int id;
  final String symbol;
  final String direction;
  final double amount;
  final double entryPrice;
  final double markPrice;
  final int leverage;
  final double margin;
  final double notional;
  final double unrealizedPnl;
  final double roePct;
  final double liquidationPrice;

  FuturesPositionItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        symbol = j['symbol'],
        direction = j['direction'],
        amount = (j['amount'] as num).toDouble(),
        entryPrice = (j['entry_price'] as num).toDouble(),
        markPrice = (j['mark_price'] as num).toDouble(),
        leverage = j['leverage'] ?? 10,
        margin = (j['margin'] as num).toDouble(),
        notional = (j['notional'] as num).toDouble(),
        unrealizedPnl = (j['unrealized_pnl'] as num).toDouble(),
        roePct = (j['roe_pct'] as num).toDouble(),
        liquidationPrice = (j['liquidation_price'] as num).toDouble();

  bool get isLong => direction == 'long';
}

class FuturesProvider extends ChangeNotifier {
  FuturesAccountView? account;
  List<FuturesPositionItem> positions = [];
  bool loading = false;
  Timer? _timer;
  bool _disposed = false;

  Dio get _dio => ApiClient().dio;

  FuturesProvider() {
    load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => load(silent: true));
  }

  String _errMsg(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? '请求失败';
    }
    return '网络异常,请稍后再试';
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final res = await Future.wait([
        _dio.get('/futures/account'),
        _dio.get('/futures/positions'),
      ]);
      account =
          FuturesAccountView.fromJson(res[0].data['data'] as Map<String, dynamic>);
      positions = (res[1].data['data'] as List)
          .map((e) => FuturesPositionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 轮询失败保留上次数据
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 市价开仓;成功返回 null
  Future<String?> openPosition({
    required String symbol,
    required String direction,
    required int leverage,
    required double amount,
  }) async {
    try {
      await _dio.post('/futures/order', data: {
        'symbol': symbol,
        'direction': direction,
        'leverage': leverage,
        'amount': amount,
      });
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 平仓(amount 省略=全部);成功返回 null
  Future<String?> closePosition(int positionId, {double? amount}) async {
    try {
      await _dio.post('/futures/close', data: {
        'position_id': positionId,
        if (amount != null) 'amount': amount,
      });
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 资金划转 in=现货→合约 / out=合约→现货;成功返回 null
  Future<String?> transfer(String direction, double amount) async {
    try {
      await _dio.post('/futures/transfer',
          data: {'direction': direction, 'amount': amount});
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
