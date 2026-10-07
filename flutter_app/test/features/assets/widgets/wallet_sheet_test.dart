import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_quant_app/core/network/api_client.dart';
import 'package:ai_quant_app/core/theme/app_theme.dart';
import 'package:ai_quant_app/features/assets/widgets/wallet_sheet.dart';

/// WalletSheet Widget 测试:UI 渲染 / 金额校验 / 充值成功 / 提现失败。
/// 通过替换 ApiClient.dio 的 httpClientAdapter 模拟后端响应,不发起真实网络请求。
void main() {
  setUp(() async {
    // 隔离 SharedPreferences 原生通道
    SharedPreferences.setMockInitialValues({});
    await ApiClient().init();
    // 替换为模拟适配器
    ApiClient().dio.httpClientAdapter = _MockAdapter();
  });

  tearDown(() {
    // 恢复默认 IO 适配器,避免影响其他测试
    ApiClient().dio.httpClientAdapter = IOHttpClientAdapter();
  });

  Widget buildSheet({required String type}) {
    return MaterialApp(
      theme: AppTheme.darkFinanceTheme,
      home: Scaffold(
        body: WalletSheet(
          type: type,
          currency: 'USDT',
          coin: 'USDT',
        ),
      ),
    );
  }

  group('UI 渲染', () {
    testWidgets('充值表单显示标题/金额输入/渠道 chip/确认按钮', (tester) async {
      await tester.pumpWidget(buildSheet(type: 'deposit'));
      await tester.pump();

      expect(find.text('充值 USDT'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('充值渠道'), findsOneWidget);
      expect(find.text('银行卡'), findsOneWidget);
      expect(find.text('USDT-TRC20'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '确认充值'), findsOneWidget);
      // 提现专属元素不应出现
      expect(find.text('提现网络'), findsNothing);
      expect(find.text('提现地址(选填,模拟环境)'), findsNothing);
    });

    testWidgets('提现表单显示网络 chip 与地址输入', (tester) async {
      await tester.pumpWidget(buildSheet(type: 'withdraw'));
      await tester.pump();

      expect(find.text('提现 USDT'), findsOneWidget);
      expect(find.text('提现网络'), findsOneWidget);
      expect(find.text('TRC20'), findsOneWidget);
      expect(find.text('ERC20'), findsOneWidget);
      expect(find.text('提现地址(选填,模拟环境)'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '确认提现'), findsOneWidget);
    });
  });

  group('金额校验', () {
    testWidgets('空金额点击提交 → 显示「请输入有效金额」', (tester) async {
      await tester.pumpWidget(buildSheet(type: 'deposit'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, '确认充值'));
      await tester.pump();

      expect(find.text('请输入有效金额'), findsOneWidget);
    });

    testWidgets('负数金额 → 显示校验错误', (tester) async {
      await tester.pumpWidget(buildSheet(type: 'withdraw'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '-10');
      await tester.tap(find.widgetWithText(ElevatedButton, '确认提现'));
      await tester.pump();

      expect(find.text('请输入有效金额'), findsOneWidget);
    });
  });

  group('网络交互', () {
    testWidgets('充值成功 → 显示成功提示并触发 onDone', (tester) async {
      // 配置成功响应
      (_MockAdapter.responses as List).clear();
      _MockAdapter.responses.add(_jsonResp(200, {
        'code': 200,
        'message': 'success',
        'data': {
          'transaction_id': 1,
          'type': 'deposit',
          'currency': 'USDT',
          'amount': 500.0,
          'balance_after': 10500.0,
          'status': 'completed',
        }
      }));

      var doneCalled = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkFinanceTheme,
        home: Scaffold(
          body: WalletSheet(
            type: 'deposit',
            currency: 'USDT',
            coin: 'USDT',
            onDone: () => doneCalled = true,
          ),
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '500');
      await tester.tap(find.widgetWithText(ElevatedButton, '确认充值'));
      await tester.pump(); // 触发 loading
      await tester.pump(const Duration(milliseconds: 500)); // 等待异步

      // 成功提示(SnackBar)
      expect(find.textContaining('充值成功'), findsOneWidget);
      expect(doneCalled, isTrue);
    });

    testWidgets('提现失败(余额不足) → 显示后端错误消息', (tester) async {
      (_MockAdapter.responses as List).clear();
      _MockAdapter.responses.add(_jsonResp(400, {
        'code': 400,
        'message': 'USDT 可用余额不足',
      }));

      await tester.pumpWidget(buildSheet(type: 'withdraw'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '999999');
      await tester.tap(find.widgetWithText(ElevatedButton, '确认提现'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('USDT 可用余额不足'), findsOneWidget);
    });
  });
}

/// 模拟 Dio HttpClientAdapter,返回预设响应队列
class _MockAdapter implements HttpClientAdapter {
  static final List<_MockResp> responses = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (responses.isEmpty) {
      return ResponseBody.fromString(
        jsonEncode({'code': 500, 'message': 'no mock response'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }
    final r = responses.removeAt(0);
    return ResponseBody.fromString(
      r.body,
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockResp {
  final int status;
  final String body;
  _MockResp(this.status, this.body);
}

_MockResp _jsonResp(int status, Object data) =>
    _MockResp(status, jsonEncode(data));
