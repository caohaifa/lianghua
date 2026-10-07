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
  final double high; // 24h最高
  final double low; // 24h最低
  final double quoteVol; // 成交额(USDT/CNY)
  final String currency; // USDT / CNY
  final String market; // crypto / a-share

  const Quote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.volume,
    this.high = 0,
    this.low = 0,
    this.quoteVol = 0,
    required this.currency,
    required this.market,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        symbol: json['symbol'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        change: (json['change'] as num?)?.toDouble() ?? 0,
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
        high: (json['high'] as num?)?.toDouble() ?? 0,
        low: (json['low'] as num?)?.toDouble() ?? 0,
        quoteVol: (json['quoteVol'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] ?? '',
        market: json['market'] ?? '',
      );

  /// 应用 WS tick 增量(更新价格/涨跌幅/成交量/高低价/成交额)
  Quote applyTick({
    double? price,
    double? change,
    double? volume,
    double? high,
    double? low,
    double? quoteVol,
  }) =>
      Quote(
        symbol: symbol,
        name: name,
        price: price ?? this.price,
        change: change ?? this.change,
        volume: volume ?? this.volume,
        high: high ?? this.high,
        low: low ?? this.low,
        quoteVol: quoteVol ?? this.quoteVol,
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

/// 最新成交流水单条(仅加密)
class TradeTick {
  final double price;
  final double qty;
  final int time; // 毫秒时间戳
  final bool isBuyerMaker; // true=主动卖出(显红),false=主动买入(显绿)

  const TradeTick({
    required this.price,
    required this.qty,
    required this.time,
    required this.isBuyerMaker,
  });

  factory TradeTick.fromJson(Map<String, dynamic> json) => TradeTick(
        price: (json['price'] as num?)?.toDouble() ?? 0,
        qty: (json['qty'] as num?)?.toDouble() ?? 0,
        time: (json['time'] as num?)?.toInt() ?? 0,
        isBuyerMaker: json['isBuyerMaker'] == true,
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

  /// 是否启用 WS 实时推送(widget 测试中关闭,避免对本地后端的真实网络依赖)
  final bool wsEnabled;

  // 行情总览(总市值/24h量/BTC占比)+ 币种品牌色
  Map<String, dynamic>? overview;
  Map<String, String> meta = {};

  List<Quote> get quotes => _quotes.values.toList();

  /// 按标的取行情快照(无数据返回 null)
  Quote? quoteOf(String symbol) => _quotes[symbol];
  bool get loading => _loading;
  String? get error => _error;

  MarketProvider({this.wsEnabled = true}) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    await fetchOverview();
    _connectWs();
  }

  /// 行情首页总览数据 + 币种品牌色表
  Future<void> fetchOverview() async {
    try {
      final results = await Future.wait([
        ApiClient().dio.get('/market/overview'),
        ApiClient().dio.get('/market/meta'),
      ]);
      overview = Map<String, dynamic>.from(results[0].data['data'] as Map);
      meta = (results[1].data['data'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
      if (!_disposed) notifyListeners();
    } catch (_) {
      // 总览不阻塞列表
    }
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
      await fetchOverview();
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

  /// 拉取盘口订单簿(仅加密):{'bids': [[price,qty]...], 'asks': [[price,qty]...]}
  /// bids 按价降序(最优买在前),asks 按价升序(最优卖在前)。
  Future<Map<String, List<List<double>>>> fetchDepth(String symbol,
      {int limit = 20}) async {
    final res = await ApiClient().dio.get('/market/depth', queryParameters: {
      'symbol': symbol,
      'limit': limit,
    });
    final data = (res.data['data'] as Map?) ?? {};
    List<List<double>> parse(dynamic v) => ((v as List?) ?? [])
        .whereType<List>()
        .map((e) => <double>[
              (e[0] as num).toDouble(),
              (e[1] as num).toDouble(),
            ])
        .toList();
    return {'bids': parse(data['bids']), 'asks': parse(data['asks'])};
  }

  /// 拉取最新成交流水(仅加密),按时间倒序(最新在前)
  Future<List<TradeTick>> fetchTrades(String symbol, {int limit = 50}) async {
    final res = await ApiClient().dio.get('/market/trades', queryParameters: {
      'symbol': symbol,
      'limit': limit,
    });
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => TradeTick.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 连接行情 WebSocket,接收 2s 周期的 tick 推送;断线自动重连
  void _connectWs() {
    if (_disposed || !wsEnabled) return;
    final wsUrl =
        '${ApiClient.baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws/market';
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
          volume: (tick['volume'] as num?)?.toDouble(),
          high: (tick['high'] as num?)?.toDouble(),
          low: (tick['low'] as num?)?.toDouble(),
          quoteVol: (tick['quoteVol'] as num?)?.toDouble(),
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
