import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

/// 策略广场条目(后端 StrategyPublish,JSON 为 camelCase)
class PublishedStrategy {
  final int id;
  final int monitorId;
  final String title;
  final String description;
  final String strategy;
  final String symbol;
  final String status;
  final String leaderName;
  final int followers;
  final bool isBot;

  PublishedStrategy.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        monitorId = j['monitorId'],
        title = j['title'] ?? '',
        description = j['description'] ?? '',
        strategy = j['strategy'] ?? '',
        symbol = j['symbol'] ?? '',
        status = j['status'] ?? '',
        leaderName = j['leaderName'] ?? '匿名',
        followers = j['followers'] ?? 0,
        isBot = j['isBot'] == 1;
}

/// 我的发布(含审核状态)
class MyPublish {
  final int id;
  final int monitorId;
  final String title;
  final String strategy;
  final String symbol;
  final String status; // pending/published/rejected/offline

  MyPublish.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        monitorId = j['monitorId'],
        title = j['title'] ?? '',
        strategy = j['strategy'] ?? '',
        symbol = j['symbol'] ?? '',
        status = j['status'] ?? 'pending';
}

/// 我的跟单
class FollowItem {
  final int id;
  final int publishId;
  final int ratio;
  final String status; // active/paused/stopped
  final String? mode; // ratio=固定比例/balance=本金比例/fixed=固定倍数(null=旧数据按固定比例)
  final double? fixedMultiplier; // 固定倍数模式的倍数
  final String title;
  final String strategy;
  final String symbol;
  final String leaderName;
  final String publishStatus;
  final int tradeCount; // 已复制笔数
  final double totalPnl; // 已实现盈亏合计(USDT/CNY 视标的)

  FollowItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        publishId = j['publishId'],
        ratio = j['ratio'] ?? 10,
        status = j['status'] ?? 'active',
        mode = j['mode'] as String?,
        fixedMultiplier = (j['fixedMultiplier'] as num?)?.toDouble(),
        title = j['title'] ?? '(发布已删除)',
        strategy = j['strategy'] ?? '',
        symbol = j['symbol'] ?? '',
        leaderName = j['leaderName'] ?? '匿名',
        publishStatus = j['publishStatus'] ?? '',
        tradeCount = j['tradeCount'] ?? 0,
        totalPnl = (j['totalPnl'] as num?)?.toDouble() ?? 0.0;

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';

  /// 跟单模式文案:固定比例 X% / 本金比例 / 固定倍数 X
  String get modeText {
    switch (mode) {
      case 'balance':
        return '本金比例';
      case 'fixed':
        final m = fixedMultiplier;
        if (m != null) {
          final s = m % 1 == 0 ? m.toStringAsFixed(0) : m.toString();
          return '固定倍数 $s';
        }
        return '固定倍数';
      default:
        return '固定比例 $ratio%';
    }
  }
}

/// 站内告警(后端 Alert,camelCase)
class AlertItem {
  final int id;
  final String type; // copy_skip/risk/system
  final String title;
  final String content;
  final int readFlag; // 0=未读 1=已读
  final String createdAt;

  AlertItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        type = j['type'] ?? 'system',
        title = j['title'] ?? '',
        content = j['content'] ?? '',
        readFlag = j['readFlag'] ?? 0,
        createdAt = j['createdAt']?.toString() ?? '';

  bool get isUnread => readFlag == 0;

  /// 已读副本(全部标读后本地刷新用)
  AlertItem copyAsRead() => AlertItem.fromJson({
        'id': id,
        'type': type,
        'title': title,
        'content': content,
        'readFlag': 1,
        'createdAt': createdAt,
      });
}

/// 信号动作中文名
String personalActionName(String action) =>
    const {
      'open_long': '开多',
      'add_long': '加仓',
      'partial_close': '部分平仓',
      'close_all': '全部平仓',
      'open_short': '开空',
    }[action] ??
    action;

/// 个人策略信号流水(后端 PersonalSignal,camelCase)
class PersonalSignalItem {
  final int id;
  final int monitorId;
  final String action; // open_long/add_long/partial_close/close_all/open_short
  final double? amount;
  final int? ratioPct;
  final int? leverage;
  final int okCount;
  final int skipCount;
  final String detail;
  final String createdAt;

  PersonalSignalItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        monitorId = j['monitorId'],
        action = j['action'] ?? '',
        amount = (j['amount'] as num?)?.toDouble(),
        ratioPct = j['ratioPct'] as int?,
        leverage = j['leverage'] as int?,
        okCount = j['okCount'] ?? 0,
        skipCount = j['skipCount'] ?? 0,
        detail = j['detail'] ?? '',
        createdAt = j['createdAt']?.toString() ?? '';

  /// 动作中文名
  String get actionName => personalActionName(action);
}

/// 信号下发结果
class SignalResult {
  final String? error; // 非 null=失败
  final int executed;
  final int skipped;
  const SignalResult(
      {this.error, required this.executed, required this.skipped});
  bool get ok => error == null;
}

/// 跟单系统:策略广场(审核通过的发布) + 我的发布 + 我的跟单
class CopyProvider extends ChangeNotifier {
  List<PublishedStrategy> published = [];
  List<MyPublish> myPublishes = [];
  List<FollowItem> follows = [];
  List<AlertItem> alerts = []; // 个人策略站内告警
  List<PersonalSignalItem> signals = []; // 个人策略信号历史(信号台)
  int unreadAlerts = 0; // 未读告警数
  bool copyPaused = false; // 全局跟单风控暂停
  bool loading = false;

  Dio get _dio => ApiClient().dio;

  String _errMsg(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? '请求失败';
    }
    return '网络异常,请稍后再试';
  }

  /// 我的监控 monitorId → 发布状态(pending/published/rejected/offline);未发布为 null
  String? publishStatusOf(int monitorId) {
    for (final p in myPublishes) {
      if (p.monitorId == monitorId) return p.status;
    }
    return null;
  }

  Future<void> loadPublished() async {
    try {
      final res = await _dio.get('/copy/published');
      published = (res.data['data'] as List)
          .map((e) => PublishedStrategy.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {
      // 广场拉取失败保持旧数据
    }
  }

  Future<void> loadMyPublishes() async {
    try {
      final res = await _dio.get('/copy/my-publish');
      myPublishes = (res.data['data'] as List)
          .map((e) => MyPublish.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadFollows() async {
    loading = true;
    notifyListeners();
    try {
      final res = await _dio.get('/copy/follows');
      follows = (res.data['data'] as List)
          .map((e) => FollowItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// AI 页统一刷新(广场 + 我的发布 + 我的跟单)
  Future<void> loadAll() async {
    await Future.wait([loadPublished(), loadMyPublishes(), loadFollows()]);
  }

  /// 申请发布(已有记录则重新提交审核);成功返回 null
  Future<String?> publish(
      int monitorId, String title, String description) async {
    try {
      await _dio.post('/copy/publish', data: {
        'monitor_id': monitorId,
        'title': title,
        'description': description,
      });
      await loadMyPublishes();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 下架我的发布;成功返回 null
  Future<String?> unpublish(int publishId) async {
    try {
      await _dio.delete('/copy/publish/$publishId');
      await loadAll();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 跟单(mode: ratio=固定比例(配 ratio) / balance=本金比例 / fixed=固定倍数(配 multiplier);
  /// mode 为空时后端按旧规则固定比例兼容);成功返回 null
  Future<String?> follow(int publishId, int ratio,
      {String mode = 'ratio', double? multiplier}) async {
    try {
      await _dio.put('/copy/follow', data: {
        'publish_id': publishId,
        'ratio': ratio,
        'mode': mode,
        if (multiplier != null) 'multiplier': multiplier,
      });
      await loadAll();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 暂停/恢复跟单(status: active/paused);成功后用返回数据本地更新,返回 null
  Future<String?> setFollowStatus(int id, String status) async {
    try {
      final res = await _dio
          .put('/personal/follows/$id/status', data: {'status': status});
      final d = res.data['data'];
      if (d is Map) {
        final item = FollowItem.fromJson(Map<String, dynamic>.from(d));
        follows = [
          for (final f in follows)
            if (f.id == id) item else f
        ];
        notifyListeners();
      }
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 拉取站内告警(列表 + 未读数 + 全局风控状态;copy_paused 为后端手工 Map 键,snake_case)
  Future<void> fetchAlerts() async {
    try {
      final res = await _dio.get('/personal/alerts');
      final d = Map<String, dynamic>.from(res.data['data']);
      alerts = ((d['alerts'] as List?) ?? [])
          .map((e) => AlertItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      unreadAlerts = (d['unread'] as num?)?.toInt() ?? 0;
      copyPaused = d['copy_paused'] == true || d['copyPaused'] == true;
      notifyListeners();
    } catch (_) {
      // 拉取失败保持旧数据
    }
  }

  /// 全部标为已读;成功后本地清零未读
  Future<void> readAlerts() async {
    try {
      await _dio.put('/personal/alerts/read');
      unreadAlerts = 0;
      alerts = [for (final a in alerts) a.copyAsRead()];
      notifyListeners();
    } catch (_) {}
  }

  /// 信号历史(分页, 默认 50 条)
  Future<void> fetchSignals(int monitorId, {int limit = 50, int offset = 0}) async {
    try {
      final res = await _dio.get('/personal/monitors/$monitorId/signals',
          queryParameters: {'limit': limit, 'offset': offset});
      final d = res.data['data'];
      // 兼容新格式 {signals: [...], total: N} 和旧格式 [...]
      final list = d is List ? d : (d['signals'] as List? ?? []);
      signals = list
          .map((e) => PersonalSignalItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// 开空预检
  Future<Map<String, dynamic>> preCheckShort(int monitorId) async {
    try {
      final res = await _dio.get('/personal/monitors/$monitorId/precheck-short');
      return Map<String, dynamic>.from(res.data['data']);
    } catch (_) {
      return {'canShort': false, 'warning': '预检请求失败'};
    }
  }

  /// 下发人工信号;成功返回含执行/跳过数的结果,失败 error 非空
  Future<SignalResult> sendSignal(int monitorId, String action,
      {double? amount, int? ratioPct, int? leverage}) async {
    try {
      final res =
          await _dio.post('/personal/monitors/$monitorId/signal', data: {
        'action': action,
        if (amount != null) 'amount': amount,
        if (ratioPct != null) 'ratio_pct': ratioPct,
        if (leverage != null) 'leverage': leverage,
      });
      final d = Map<String, dynamic>.from(res.data['data']);
      return SignalResult(
        executed: (d['executed'] as num?)?.toInt() ?? 0,
        skipped: (d['skipped'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return SignalResult(error: _errMsg(e), executed: 0, skipped: 0);
    }
  }

  /// 停止跟单;成功返回 null
  Future<String?> stopFollow(int followId) async {
    try {
      await _dio.delete('/copy/follow/$followId');
      await loadFollows();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }
}
