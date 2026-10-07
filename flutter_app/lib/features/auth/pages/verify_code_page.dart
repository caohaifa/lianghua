import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/mock_code_dialog.dart';

/// 验证码输入页(短信二次验证 - 异地登录风控)
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _trustDevice = false; // 信任此设备(7 天内免验证)
  bool _loading = false;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  String get _maskedPhone {
    final phone = context.read<AuthProvider>().pendingPhone ?? '';
    if (phone.length == 11) {
      return '+86 ${phone.substring(0, 3)}****${phone.substring(7)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final risk = auth.riskDeviceInfo;

    return Scaffold(
      appBar: AppBar(title: const Text('短信验证')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // 黄色警示条
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x26F0B90B),
                  borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('检测到您正在新设备/异地登录',
                          style:
                              TextStyle(color: AppTheme.warning, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 当前设备信息
              if (risk != null && risk.isNotEmpty) ...[
                _infoRow(Icons.phone_iphone, '设备型号', risk['model'] ?? '未知设备'),
                _infoRow(Icons.language, 'IP 地址', risk['ip'] ?? '-'),
                _infoRow(
                    Icons.location_on_outlined, '登录城市', risk['city'] ?? '-'),
                const SizedBox(height: 20),
              ],
              Text('我们已发送 6 位验证码至 $_maskedPhone', style: AppTheme.caption),
              const SizedBox(height: 24),
              // 6 位验证码输入
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: AppTheme.headline,
                      decoration: InputDecoration(
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadius),
                          borderSide: const BorderSide(color: AppTheme.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadius),
                          borderSide: const BorderSide(
                              color: AppTheme.brandPrimary, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.length == 1 && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (v.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        // 6 位输入完毕 → 自动提交
                        if (v.length == 1 && i == 5) _verify();
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // 信任此设备(7 天内免验证)
              Row(
                children: [
                  Checkbox(
                    value: _trustDevice,
                    onChanged: (v) => setState(() => _trustDevice = v!),
                  ),
                  const Expanded(
                      child: Text('我本人操作,信任此设备(7 天内免验证)',
                          style: AppTheme.caption)),
                ],
              ),
              if (auth.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(auth.errorMessage!,
                      style:
                          const TextStyle(color: AppTheme.bear, fontSize: 13)),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('确认'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _countdown == 0 ? _resend : null,
                  child: Text(
                    _countdown > 0 ? '重新发送(${_countdown}s)' : '重新发送',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text('$label:', style: AppTheme.caption),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: AppTheme.body)),
        ],
      ),
    );
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final phone = auth.pendingPhone;
    if (phone == null) return;
    auth.clearError();
    final mockCode = await auth.sendVerifyCode(phone);
    if (!mounted) return;
    if (mockCode != null) {
      _startCountdown();
      await MockCodeDialog.show(context, mockCode);
    }
  }

  Future<void> _verify() async {
    final code = _ctrls.map((c) => c.text).join();
    if (code.length != 6 || _loading) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final result =
        await auth.verifySecondLogin(code, trustDevice: _trustDevice);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == LoginResult.success) {
      context.go(auth.landingRoute);
    } else if (result == LoginResult.failed) {
      // 失败震动提示
      HapticFeedback.vibrate();
      for (final c in _ctrls) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }
}
