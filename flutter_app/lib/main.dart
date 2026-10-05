import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 开启语义树:Web 端把输入框/按钮等暴露为可识别节点,
  // 便于无障碍与自动化测试操作(CanvasKit 默认只渲染单个 canvas)。
  SemanticsBinding.instance.ensureSemantics();
  await ApiClient().init();
  // 启动页分流前置:恢复本地登录态(JWT 有效 → 主页)
  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();
  runApp(AiQuantApp(authProvider: authProvider));
}
