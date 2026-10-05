import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// 开发环境模拟短信:发送验证码后直接弹窗展示(无真实短信网关)。
/// 用户可点"复制"后粘贴到验证码输入框,5 分钟内有效。
class MockCodeDialog extends StatelessWidget {
  final String code;

  const MockCodeDialog({super.key, required this.code});

  static Future<void> show(BuildContext context, String code) {
    return showDialog<void>(
      context: context,
      builder: (_) => MockCodeDialog(code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('验证码(开发环境模拟)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppTheme.brandPrimary,
              )),
          const SizedBox(height: 8),
          const Text('5 分钟内有效,请尽快使用', style: AppTheme.caption),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.of(context).pop();
          },
          child: const Text('复制并关闭'),
        ),
      ],
    );
  }
}
