import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

/// 认证状态
enum AuthStatus { initial, authenticated, unauthenticated }

/// 登录结果
enum LoginResult { success, needSecondVerify, failed }

/// 用户信息
class UserInfo {
  final String userId;
  final String phone;
  final String? nickname;
  final String? avatar;
  final String? riskLevel; // R1~R5
  final bool agreementSigned;

  UserInfo({
    required this.userId,
    required this.phone,
    this.nickname,
    this.avatar,
    this.riskLevel,
    this.agreementSigned = false,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        userId: json['user_id'] ?? '',
        phone: json['phone'] ?? '',
        nickname: json['nickname'],
        avatar: json['avatar'],
        riskLevel: json['risk_level'],
        agreementSigned: json['agreement_signed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'phone': phone,
        'nickname': nickname,
        'avatar': avatar,
        'risk_level': riskLevel,
        'agreement_signed': agreementSigned,
      };

  UserInfo copyWith({String? riskLevel, bool? agreementSigned}) => UserInfo(
        userId: userId,
        phone: phone,
        nickname: nickname,
        avatar: avatar,
        riskLevel: riskLevel ?? this.riskLevel,
        agreementSigned: agreementSigned ?? this.agreementSigned,
      );

  bool get isRiskAssessed => riskLevel != null;
}

class AuthProvider extends ChangeNotifier {
  static const String _userCacheKey = 'cached_user';

  AuthStatus _status = AuthStatus.initial;
  UserInfo? _user;
  String? _errorMessage;

  // 风控二次验证暂存(异地/新设备登录)
  String? _pendingPhone;
  Map<String, String>? _riskDeviceInfo;

  AuthStatus get status => _status;
  UserInfo? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get pendingPhone => _pendingPhone;
  Map<String, String>? get riskDeviceInfo => _riskDeviceInfo;

  /// 登录态落地路由(启动页分流:已登录→主页;未完成测评/协议→对应页)
  String get landingRoute {
    if (_user == null) return '/login';
    if (!_user!.isRiskAssessed) return '/risk-assessment';
    if (!_user!.agreementSigned) return '/agreement-sign';
    return '/market';
  }

  /// 冷启动恢复登录态(JWT 有效 → 直接进入主页)
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final userJson = prefs.getString(_userCacheKey);
    if (token != null && token.isNotEmpty && userJson != null) {
      try {
        _user = UserInfo.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _status = (_user!.isRiskAssessed && _user!.agreementSigned)
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      } catch (_) {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// 获取图形验证码(发送短信前置校验)
  Future<Map<String, String>?> fetchCaptcha() async {
    try {
      final res = await ApiClient().dio.get('/auth/captcha');
      final data = res.data['data'];
      return {
        'id': data['captcha_id'].toString(),
        'image': data['image'].toString(), // Base64 PNG(可含 data-uri 前缀)
      };
    } catch (e) {
      _errorMessage = '图形验证码加载失败,请重试';
      notifyListeners();
      return null;
    }
  }

  /// 发送短信验证码(60s 限频,可选携带图形校验结果)
  /// 返回验证码(无真实短信网关,后端通过 mock_code 回传);失败返回 null。
  Future<String?> sendVerifyCode(String phone,
      {String? captchaId, String? captchaCode}) async {
    try {
      final res = await ApiClient().dio.post('/auth/sms/send', data: {
        'phone': phone,
        if (captchaId != null) 'captcha_id': captchaId,
        if (captchaCode != null) 'captcha_code': captchaCode,
      });
      return (res.data['data'] as Map?)?['mock_code']?.toString();
    } catch (e) {
      _errorMessage = '验证码发送失败';
      notifyListeners();
      return null;
    }
  }

  /// 注册(手机号+验证码,密码可留空由服务端生成随机密码)
  /// 成功后落地登录态(后端返回 Token),页面可按需跳转
  Future<bool> register(String phone, String code, {String? inviteCode}) async {
    try {
      final res = await ApiClient().dio.post('/auth/register', data: {
        'phone': phone,
        'code': code,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
      });
      final data = res.data['data'];
      if (data is Map<String, dynamic> && data['access_token'] != null) {
        await _onLoginSuccess(data);
      }
      return true;
    } catch (e) {
      _errorMessage = '注册失败';
      notifyListeners();
      return false;
    }
  }

  /// 登录(手机号+密码)
  Future<LoginResult> login(String phone, String password) {
    return _doLogin(
      {'phone': phone, 'password': password},
      errorMessage: '手机号或密码错误',
    );
  }

  /// 登录(手机号+短信验证码)
  Future<LoginResult> loginWithCode(String phone, String code,
      {bool trustDevice = false}) {
    return _doLogin(
      {'phone': phone, 'code': code, if (trustDevice) 'trust_device': true},
      errorMessage: '验证码错误或已过期',
    );
  }

  /// 风控二次验证(异地/新设备 → 短信验证码)
  Future<LoginResult> verifySecondLogin(String code,
      {bool trustDevice = false}) {
    final phone = _pendingPhone;
    if (phone == null) return Future.value(LoginResult.failed);
    return loginWithCode(phone, code, trustDevice: trustDevice);
  }

  Future<LoginResult> _doLogin(Map<String, dynamic> body,
      {required String errorMessage}) async {
    try {
      final res = await ApiClient().dio.post('/auth/login', data: {
        ...body,
        'device_fp': ApiClient().deviceFp, // 异地登录风控:携带设备指纹
      });
      final data = res.data['data'] as Map<String, dynamic>;
      // 新城市且新设备 → risk_level=2 → 触发二次验证
      if (data['need_second_verify'] == true || data['risk_level'] == 2) {
        _pendingPhone = body['phone'] as String;
        _riskDeviceInfo = {
          if (data['device_model'] != null)
            'model': data['device_model'].toString(),
          if (data['ip'] != null) 'ip': data['ip'].toString(),
          if (data['city'] != null) 'city': data['city'].toString(),
        };
        return LoginResult.needSecondVerify;
      }
      await _onLoginSuccess(data);
      return LoginResult.success;
    } catch (e) {
      _errorMessage = errorMessage;
      notifyListeners();
      return LoginResult.failed;
    }
  }

  Future<void> _onLoginSuccess(Map<String, dynamic> data) async {
    // 颁发 JWT(2h) + RefreshToken(7d)
    await ApiClient().saveTokens(
      data['access_token'] as String,
      (data['refresh_token'] ?? '') as String,
    );
    _user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
    _status = (_user!.isRiskAssessed && _user!.agreementSigned)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    _pendingPhone = null;
    _riskDeviceInfo = null;
    await _cacheUser();
    notifyListeners();
  }

  /// 提交风险测评(答题 → 输出 R1~R5 等级)
  Future<bool> submitRiskAssessment(List<int> answers) async {
    try {
      final res = await ApiClient()
          .dio
          .post('/auth/risk/assessment', data: {'answers': answers});
      final level = res.data['data']['risk_level'] as String;
      _user = _user!.copyWith(riskLevel: level);
      await _cacheUser();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '风险测评提交失败';
      notifyListeners();
      return false;
    }
  }

  /// 签署协议(手写签名 Base64,服务端加 CA 时间戳存证 OSS)
  Future<bool> signAgreement(
      String signatureBase64, List<String> agreementIds) async {
    try {
      await ApiClient().dio.post('/auth/agreement/sign', data: {
        'signature': signatureBase64,
        'agreements': agreementIds,
      });
      _user = _user!.copyWith(agreementSigned: true);
      _status = AuthStatus.authenticated;
      await _cacheUser();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '协议签署失败';
      notifyListeners();
      return false;
    }
  }

  /// 重置密码(短信验证码 + 新密码)
  Future<bool> resetPassword(
      String phone, String code, String newPassword) async {
    try {
      await ApiClient().dio.post('/auth/password/reset', data: {
        'phone': phone,
        'code': code,
        'new_password': newPassword,
      });
      return true;
    } catch (e) {
      _errorMessage = '密码重置失败';
      notifyListeners();
      return false;
    }
  }

  /// 退出登录(清除 JWT → 回登录页)
  Future<void> logout() async {
    await ApiClient().clearTokens();
    _user = null;
    _pendingPhone = null;
    _riskDeviceInfo = null;
    await _cacheUser();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _cacheUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString(_userCacheKey, jsonEncode(_user!.toJson()));
    } else {
      await prefs.remove(_userCacheKey);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
