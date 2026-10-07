import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP 客户端单例
class ApiClient {
  /// API 基地址:开发默认 localhost,生产通过 --dart-define=API_BASE_URL=xxx 注入
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:8080/api/v1');
  static const Duration timeout = Duration(seconds: 15);

  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late Dio _dio;
  Dio get dio => _dio;

  late SharedPreferences _prefs;
  String _deviceFp = '';
  Future<bool>? _refreshing; // 刷新锁:并发 401 只刷新一次

  /// 设备指纹(首次生成后持久化,用于异地登录风控)
  String get deviceFp => _deviceFp;

  String? get accessToken => _prefs.getString('access_token');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceFp = await _loadOrCreateDeviceFp();

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 自动注入 Token + 设备指纹
        final token = _prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Device-Fp'] = _deviceFp;
        handler.next(options);
      },
      onError: (error, handler) async {
        // 401 → 用 RefreshToken(7d) 换新 JWT(2h) 并重试原请求
        final isRefreshReq = error.requestOptions.path == '/auth/refresh';
        if (error.response?.statusCode == 401 && !isRefreshReq) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            try {
              final opts = error.requestOptions
                ..headers['Authorization'] =
                    'Bearer ${_prefs.getString('access_token')}';
              final clone = await _dio.fetch(opts);
              return handler.resolve(clone);
            } catch (_) {
              // 重试失败,按原错误抛出
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<String> _loadOrCreateDeviceFp() async {
    final saved = _prefs.getString('device_fp');
    if (saved != null && saved.isNotEmpty) return saved;
    // 注意:Web 上 JS 位运算按 32 位截断,`1 << 32` 会得到 0,
    // 因此随机数上限使用 1 << 30,三段拼接保证熵足够。
    final rand = Random.secure();
    final seed = '${DateTime.now().microsecondsSinceEpoch}-'
        '${rand.nextInt(1 << 30)}-${rand.nextInt(1 << 30)}-${rand.nextInt(1 << 30)}';
    final fp = sha256.convert(utf8.encode(seed)).toString();
    await _prefs.setString('device_fp', fp);
    return fp;
  }

  Future<bool> _refreshToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearTokens();
      return false;
    }
    try {
      final res = await _dio
          .post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = res.data['data'];
      await saveTokens(data['access_token'] as String,
          (data['refresh_token'] ?? '') as String);
      return true;
    } catch (_) {
      // RefreshToken 失效:清除登录态,跳转登录页由各页面守卫处理
      await clearTokens();
      return false;
    }
  }

  /// 保存 JWT + RefreshToken
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _prefs.setString('access_token', accessToken);
    if (refreshToken.isNotEmpty) {
      await _prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> clearTokens() async {
    await _prefs.remove('access_token');
    await _prefs.remove('refresh_token');
  }
}
