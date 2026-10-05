import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

/// 用户自建监控(与后端 Monitor 实体一致)
class MonitorItem {
  final int id;
  final String symbol;
  final String strategy;
  final String status; // running/paused
  final String signal;

  MonitorItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        symbol = j['symbol'],
        strategy = j['strategy'],
        status = j['status'],
        signal = j['signal'] ?? '等待信号';

  bool get isRunning => status == 'running';
}

/// Python AI Agent 运行状态(/agents/status)
/// Python 返回 agents 为数组,元素形如 {name, status, tasks_done, tasks_pending}
class AgentStatus {
  final String name;
  final String status;
  final Map<String, dynamic> raw;

  AgentStatus.fromJson(Map<String, dynamic> j)
      : name = j['name']?.toString() ?? '未知 Agent',
        status = j['status']?.toString() ?? 'unknown',
        raw = Map<String, dynamic>.from(j);
}

class MonitorProvider extends ChangeNotifier {
  /// 可选策略(与后端白名单一致)
  static const strategies = ['趋势追踪', '网格区间', '多因子轮动', '日内T+0'];

  List<MonitorItem> monitors = [];
  List<AgentStatus> agents = [];
  bool loading = false;
  String? error;

  Dio get _dio => ApiClient().dio;

  String _errMsg(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? '请求失败';
    }
    return '网络异常,请稍后再试';
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.get('/monitors');
      monitors = (res.data['data'] as List)
          .map((e) => MonitorItem.fromJson(e))
          .toList();
    } catch (e) {
      error = _errMsg(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 拉取 AI Agent 状态(经 Java 后端代理,Python AI 保持内网,避免浏览器跨域)
  Future<void> loadAgents() async {
    try {
      final res = await _dio.get('/monitors/agents-status');
      final list = res.data['data']['agents'];
      if (list is List) {
        agents = list
            .whereType<Map>()
            .map((e) => AgentStatus.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      }
    } catch (_) {
      // AI 服务离线时保持空列表,页面显示占位
    }
  }

  /// 新建监控;成功返回 null,失败返回错误消息
  Future<String?> create(String symbol, String strategy) async {
    try {
      await _dio
          .post('/monitors', data: {'symbol': symbol, 'strategy': strategy});
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 暂停/恢复
  Future<void> toggle(MonitorItem m) async {
    try {
      await _dio.put('/monitors/${m.id}/status',
          data: {'status': m.isRunning ? 'paused' : 'running'});
      await load();
    } catch (_) {}
  }

  Future<void> remove(MonitorItem m) async {
    try {
      await _dio.delete('/monitors/${m.id}');
      await load();
    } catch (_) {}
  }
}
