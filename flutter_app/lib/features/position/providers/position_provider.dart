import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

/// 账户总览(与后端 /trading/account 字段一致)
class AccountOverview {
  final String currency;
  final double totalAsset;
  final double available;
  final double positionValue;
  final double totalPnl;
  final double totalPnlPct;
  final int positionCount;

  AccountOverview.fromJson(Map<String, dynamic> j)
      : currency = j['currency'] ?? 'USDT',
        totalAsset = (j['total_asset'] as num).toDouble(),
        available = (j['available'] as num).toDouble(),
        positionValue = (j['position_value'] as num).toDouble(),
        totalPnl = (j['total_pnl'] as num).toDouble(),
        totalPnlPct = (j['total_pnl_pct'] as num).toDouble(),
        positionCount = j['position_count'] ?? 0;
}

/// 持仓(与后端 Position 实体一致)
class PositionItem {
  final String symbol;
  final String side;
  final double amount;
  final double entryPrice;
  final double currentPrice;
  final double pnl;
  final double pnlPct;
  final String? strategyName;

  PositionItem.fromJson(Map<String, dynamic> j)
      : symbol = j['symbol'],
        side = j['side'],
        amount = (j['amount'] as num).toDouble(),
        entryPrice = (j['entryPrice'] as num).toDouble(),
        currentPrice = (j['currentPrice'] as num).toDouble(),
        pnl = (j['pnl'] as num).toDouble(),
        pnlPct = (j['pnlPct'] as num).toDouble(),
        strategyName = j['strategyName'];
}

/// 委托订单(与后端 Order 实体一致)
class OrderItem {
  final String orderId;
  final String symbol;
  final String side; // buy/sell
  final String orderType; // market/limit
  final double? price;
  final double amount;
  final double filledAmount;
  final String status; // pending/filled/cancelled
  final String createdAt;

  OrderItem.fromJson(Map<String, dynamic> j)
      : orderId = j['orderId'],
        symbol = j['symbol'],
        side = j['side'],
        orderType = j['orderType'],
        price = (j['price'] as num?)?.toDouble(),
        amount = (j['amount'] as num).toDouble(),
        filledAmount = (j['filledAmount'] as num).toDouble(),
        status = j['status'],
        createdAt = j['createdAt'] ?? '';
}

class PositionProvider extends ChangeNotifier {
  AccountOverview? account;
  AccountOverview? cnyAccount;
  List<PositionItem> positions = [];
  List<OrderItem> orders = [];
  bool loading = false;
  String? error;

  Dio get _dio => ApiClient().dio;

  /// 业务错误消息提取(后端 GlobalExceptionHandler 统一 {code,message})
  String _errMsg(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? '请求失败';
    }
    return '网络异常,请稍后再试';
  }

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        _dio.get('/trading/account'),
        _dio.get('/trading/account', queryParameters: {'currency': 'CNY'}),
        _dio.get('/trading/positions'),
        _dio.get('/trading/orders', queryParameters: {'limit': 100}),
      ]);
      account = AccountOverview.fromJson(res[0].data['data']);
      cnyAccount = AccountOverview.fromJson(res[1].data['data']);
      positions = (res[2].data['data'] as List)
          .map((e) => PositionItem.fromJson(e))
          .toList();
      orders = (res[3].data['data'] as List)
          .map((e) => OrderItem.fromJson(e))
          .toList();
    } catch (e) {
      error = _errMsg(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 下单;成功返回 null,失败返回错误消息
  Future<String?> placeOrder({
    required String symbol,
    required String side,
    required String orderType,
    double? price,
    required double amount,
  }) async {
    try {
      await _dio.post('/trading/orders', data: {
        'symbol': symbol,
        'side': side,
        'order_type': orderType,
        if (price != null) 'price': price,
        'amount': amount,
      });
      await loadAll();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 撤销挂单;成功返回 null
  Future<String?> cancelOrder(String orderId) async {
    try {
      await _dio.delete('/trading/orders/$orderId');
      await loadAll();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }
}
