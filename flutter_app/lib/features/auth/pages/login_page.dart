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

enum _LoginMode { password, smsCode }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _LoginMode _mode = _LoginMode.password;
  bool _agreed = false;
  bool _loading = false;
  bool _pwdVisible = false; // 密码明文/密文切换
  int _countdown = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                const Icon(Icons.trending_up,
                    size: 56, color: AppTheme.brandPrimary),
                const SizedBox(height: 8),
                Text('AI 量化',
                    style: AppTheme.display, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('多智能体协同 · 五因子门控决策',
                    style: AppTheme.caption, textAlign: TextAlign.center),
                const SizedBox(height: 32),

                FinanceCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 登录模式切换(手机号+密码 / 手机号+验证码)
                      SegmentedButton<_LoginMode>(
                        segments: const [
                          ButtonSegment(
                              value: _LoginMode.password, label: Text('密码登录')),
                          ButtonSegment(
                              value: _LoginMode.smsCode, label: Text('验证码登录')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                      const SizedBox(height: 20),
                      // 手机号(带国家码前缀 +86)
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          prefixText: '+86 ',
                          prefixIcon: Icon(Icons.phone_iphone,
                              color: AppTheme.textSecondary),
                        ),
                        validator: (v) => (v == null || v.length != 11)
                            ? '请输入 11 位手机号'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (_mode == _LoginMode.password)
                        // 密码(可明文/密文切换)
                        TextFormField(
                          controller: _pwdCtrl,
                          obscureText: !_pwdVisible,
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _pwdVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _pwdVisible = !_pwdVisible),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.length < 6) ? '密码至少 6 位' : null,
                        )
                      else
                        // 短信验证码 + 发送按钮(先弹图形校验 → 60s 倒计时)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codeCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: '验证码',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.sms,
                                      color: AppTheme.textSecondary),
                                ),
                                validator: (v) => (v == null || v.length != 6)
                                    ? '请输入 6 位验证码'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: OutlinedButton(
                                onPressed: (_countdown == 0 &&
                                        _phoneCtrl.text.length == 11)
                                    ? _sendCodeWithCaptcha
                                    : null,
                                child: Text(_countdown > 0
                                    ? '${_countdown}s'
                                    : '发送验证码'),
                              ),
                            ),
                          ],
                        ),
                      // 忘记密码 → 切换验证码登录
                      if (_mode == _LoginMode.password)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _mode = _LoginMode.smsCode),
                            child: Text('忘记密码?',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ),
                        ),
                      // 《用户协议》《隐私政策》勾选框
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
                                    style: const TextStyle(
                                        color: AppTheme.brandPrimary),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => AgreementViewerPage.open(
                                          context, kUserAgreement),
                                  ),
                                  const TextSpan(text: ' 和 '),
                                  TextSpan(
                                    text: '《隐私政策》',
                                    style: const TextStyle(
                                        color: AppTheme.brandPrimary),
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
                              style: TextStyle(
                                  color: AppTheme.bear, fontSize: 13)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // 登录按钮
                ElevatedButton(
                  onPressed: (_agreed && !_loading) ? _handleLogin : null,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('登录'),
                ),
                const SizedBox(height: 12),
                // 注册入口(注册成功后自动填充手机号)
                TextButton(
                  onPressed: _goRegister,
                  child: Text('没有账号?立即注册',
                      style: TextStyle(color: AppTheme.brandPrimary)),
                ),
                const SizedBox(height: 8),
                // 第三方登录(微信 / Apple ID)
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppTheme.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('第三方登录', style: AppTheme.caption),
                    ),
                    const Expanded(child: Divider(color: AppTheme.divider)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _thirdPartyButton(Icons.wechat, '微信'),
                    const SizedBox(width: 24),
                    _thirdPartyButton(Icons.apple, 'Apple ID'),
                  ],
                ),
                const SizedBox(height: 24),
                // 风险告知
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFB300),
                    borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('AI 辅助决策,自主承担风险。历史回测不代表未来收益。',
                            style: TextStyle(
                                color: AppTheme.warning, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TODO: 接入微信/Apple 登录 SDK
  Widget _thirdPartyButton(IconData icon, String label) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label 登录即将上线')),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 26),
      ),
    );
  }

  Future<void> _goRegister() async {
    final phone = await context.push<String>('/register');
    if (phone != null && mounted) {
      setState(() => _phoneCtrl.text = phone);
    }
  }

  /// 发送验证码:先弹图形校验,通过后发送并倒计时
  Future<void> _sendCodeWithCaptcha() async {
    final captcha = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CaptchaDialog(),
    );
    if (captcha == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final mockCode = await auth.sendVerifyCode(
      _phoneCtrl.text,
      captchaId: captcha['id'],
      captchaCode: captcha['code'],
    );
    if (!mounted) return;
    if (mockCode != null) {
      _startTimer();
      await MockCodeDialog.show(context, mockCode);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final result = _mode == _LoginMode.password
        ? await auth.login(_phoneCtrl.text, _pwdCtrl.text)
        : await auth.loginWithCode(_phoneCtrl.text, _codeCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case LoginResult.success:
        context.go(auth.landingRoute);
      case LoginResult.needSecondVerify:
        // 风控校验:新设备/异地 → 二次验证页
        context.push('/verify-code');
      case LoginResult.failed:
        break; // 错误信息由 provider.errorMessage 展示
    }
  }
}

/// 图形校验对话框(发送短信前置)
class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog();

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final _inputCtrl = TextEditingController();
  String? _captchaId;
  String? _captchaImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final captcha = await context.read<AuthProvider>().fetchCaptcha();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _captchaId = captcha?['id'];
      _captchaImage = captcha?['image'];
      _inputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('图形校验'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _refresh,
            child: Container(
              height: 56,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.backgroundTertiary,
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                border: Border.all(color: AppTheme.divider),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : _captchaImage != null
                      ? Image.memory(
                          base64Decode(_stripDataUri(_captchaImage!)),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : Text('加载失败,点击重试',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputCtrl,
            autofocus: true,
            // 输入时触发重建,否则下方"确定"按钮的可用状态不会更新
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '请输入图中字符'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: (_captchaId != null && _inputCtrl.text.isNotEmpty)
              ? () => Navigator.of(context)
                  .pop({'id': _captchaId!, 'code': _inputCtrl.text})
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }

  String _stripDataUri(String image) =>
      image.contains(',') ? image.split(',').last : image;
}
