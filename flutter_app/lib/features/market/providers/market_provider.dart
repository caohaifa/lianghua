import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/network/api_client.dart';

/// 行情快照(与后端 Quote 模型一致)
class Quote {
  final String symbol;
  final String name;
  final double price;
  final double change; // 涨跌幅 %
  final double volume; // 成交量
  final String currency; // USDT / CNY
  final String market; // crypto / a-share

  const Quote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.volume,
    required this.currency,
    required this.market,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        symbol: json['symbol'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        change: (json['change'] as num?)?.toDouble() ?? 0,
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] ?? '',
        market: json['market'] ?? '',
      );

  /// 应用 WS tick 增量(只更新价格/涨跌幅)
  Quote applyTick({double? price, double? change}) => Quote(
        symbol: symbol,
        name: name,
        price: price ?? this.price,
        change: change ?? this.change,
        volume: volume,
        currency: currency,
        market: market,
      );
}

/// K 线单根(OHLCV)
class KlineBar {
  final int time; // 毫秒时间戳
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const KlineBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory KlineBar.fromJson(Map<String, dynamic> json) => KlineBar(
        time: (json['time'] as num?)?.toInt() ?? 0,
        open: (json['open'] as num?)?.toDouble() ?? 0,
        high: (json['high'] as num?)?.toDouble() ?? 0,
        low: (json['low'] as num?)?.toDouble() ?? 0,
        close: (json['close'] as num?)?.toDouble() ?? 0,
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
      );
}

/// 行情数据:REST 快照 + WebSocket 实时 tick
class MarketProvider extends ChangeNotifier {
  final Map<String, Quote> _quotes = {};
  bool _loading = true;
  String? _error;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  List<Quote> get quotes => _quotes.values.toList();
  bool get loading => _loading;
  String? get error => _error;

  MarketProvider() {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    _connectWs();
  }

  /// REST 拉取行情快照(首次加载 + 下拉刷新)
  Future<void> refresh() async {
    try {
      final res = await ApiClient().dio.get('/market/quotes');
      final list = (res.data['data'] as List?) ?? [];
      for (final q in list) {
        final quote = Quote.fromJson(q as Map<String, dynamic>);
        _quotes[quote.symbol] = quote;
      }
      _error = null;
    } catch (e) {
      _error = '行情加载失败,请检查网络';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 拉取 K 线历史(无状态,调用方自行缓存;period: 1m/5m/1h/1d)
  Future<List<KlineBar>> fetchKline(String symbol,
      {String period = '1m', int limit = 120}) async {
    final res = await ApiClient().dio.get('/market/kline', queryParameters: {
      'symbol': symbol,
      'period': period,
      'limit': limit,
    });
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => KlineBar.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 连接行情 WebSocket,接收 2s 周期的 tick 推送;断线自动重连
  void _connectWs() {
    if (_disposed) return;
    final wsUrl =
        ApiClient.baseUrl.replaceFirst(RegExp(r'^http'), 'ws') + '/ws/market';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSub = _channel!.stream.listen(
        _onTick,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onTick(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] != 'tick') return;
      final data = (msg['data'] as Map?) ?? {};
      var changed = false;
      data.forEach((symbol, tick) {
        final old = _quotes[symbol];
        if (old == null || tick is! Map) return;
        _quotes[symbol] = old.applyTick(
          price: (tick['price'] as num?)?.toDouble(),
          change: (tick['change'] as num?)?.toDouble(),
        );
        changed = true;
      });
      if (changed && !_disposed) notifyListeners();
    } catch (_) {
      // 单条坏消息不影响后续推送
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      _connectWs();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
