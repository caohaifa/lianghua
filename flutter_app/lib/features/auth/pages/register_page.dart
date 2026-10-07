import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../providers/auth_provider.dart';
import '../widgets/agreement_texts.dart';
import '../widgets/mock_code_dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController(); // 图形验证码
  final _codeCtrl = TextEditingController(); // 短信验证码
  final _inviteCtrl = TextEditingController(); // 邀请码(选填)
  bool _agreed = false;
  bool _loading = false;
  int _countdown = 0;

  String? _captchaId;
  String? _captchaImage; // Base64

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _captchaCtrl.dispose();
    _codeCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCaptcha() async {
    final auth = context.read<AuthProvider>();
    final captcha = await auth.fetchCaptcha();
    if (captcha != null && mounted) {
      setState(() {
        _captchaId = captcha['id'];
        _captchaImage = captcha['image'];
        _captchaCtrl.clear();
      });
    }
  }

  void _startTimer() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  bool get _canSendCode =>
      _countdown == 0 &&
      _phoneCtrl.text.length == 11 &&
      _captchaCtrl.text.isNotEmpty &&
      _captchaId != null;

  bool get _canSubmit =>
      _agreed &&
      !_loading &&
      _phoneCtrl.text.length == 11 &&
      _codeCtrl.text.length == 6;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('注册新账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: FinanceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 手机号
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixText: '+86 ',
                    prefixIcon:
                        Icon(Icons.phone_iphone, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                // 图形验证码(短信前置校验,点击图片刷新)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captchaCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '图形验证码',
                          prefixIcon: Icon(Icons.verified_user_outlined,
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _refreshCaptcha,
                      child: Container(
                        width: 120,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundTertiary,
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadius),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: _captchaImage != null
                            ? Image.memory(
                                base64Decode(_stripDataUri(_captchaImage!)),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              )
                            : const Text('点击刷新',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 短信验证码
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '短信验证码',
                          counterText: '',
                          prefixIcon:
                              Icon(Icons.sms, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: _canSendCode ? _sendCode : null,
                        child:
                            Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 邀请码(内测必填)
                TextField(
                  controller: _inviteCtrl,
                  decoration: const InputDecoration(
                    labelText: '邀请码(内测必填)',
                    prefixIcon: Icon(Icons.card_giftcard,
                        color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                // 协议勾选(强制,不勾选无法注册)
                Row(
                  children: [
                    Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v!)),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: AppTheme.caption,
                          children: [
                            const TextSpan(text: '我已阅读并同意 '),
                            TextSpan(
                              text: '《用户协议》',
                              style:
                                  const TextStyle(color: AppTheme.brandPrimary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => AgreementViewerPage.open(
                                    context, kUserAgreement),
                            ),
                            const TextSpan(text: ' 和 '),
                            TextSpan(
                              text: '《隐私政策》',
                              style:
                                  const TextStyle(color: AppTheme.brandPrimary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => AgreementViewerPage.open(
                                    context, kPrivacyPolicy),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(auth.errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.bear, fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                // 注册按钮(未勾选协议灰色不可点)
                ElevatedButton(
                  onPressed: _canSubmit ? _handleRegister : null,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stripDataUri(String image) =>
      image.contains(',') ? image.split(',').last : image;

  Future<void> _sendCode() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final mockCode = await auth.sendVerifyCode(
      _phoneCtrl.text,
      captchaId: _captchaId,
      captchaCode: _captchaCtrl.text,
    );
    if (!mounted) return;
    if (mockCode != null) {
      _startTimer();
      await MockCodeDialog.show(context, mockCode);
    } else {
      // 发送失败:图形验证码可能已失效,刷新
      _refreshCaptcha();
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _phoneCtrl.text,
      _codeCtrl.text,
      inviteCode: _inviteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // 注册成功 → 自动填充手机号跳回登录页
      context.pop(_phoneCtrl.text);
    }
  }
}
