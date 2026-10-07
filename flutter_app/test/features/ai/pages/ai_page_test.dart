import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_quant_app/core/network/api_client.dart';
import 'package:ai_quant_app/core/theme/app_theme.dart';
import 'package:ai_quant_app/features/ai/pages/ai_page.dart';
import 'package:ai_quant_app/features/market/providers/market_provider.dart';
import 'package:ai_quant_app/features/monitor/providers/copy_provider.dart';
import 'package:ai_quant_app/features/monitor/providers/monitor_provider.dart';
import 'package:provider/provider.dart';

/// AI 量化主页 Widget 测试:收益卡 / 策略广场(真实发布) / 我的策略 / 发布与跟单弹层。
/// 通过替换 ApiClient.dio 的 httpClientAdapter,为 /ai/summary、/monitors、/copy/*、/market/* 返回假数据。
void main() {
  late Map<String, String> responses;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient().init();
    responses = _baseResponses();
    ApiClient().dio.httpClientAdapter = _MockAdapter(() => responses);
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = IOHttpClientAdapter();
  });

  Widget buildAiPage() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MonitorProvider()),
        ChangeNotifierProvider(create: (_) => CopyProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider(wsEnabled: false)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkFinanceTheme,
        home: const Scaffold(body: AiPage()),
      ),
    );
  }

  /// initState 中发起的 Dio 请求在 fake-async 区需用 runAsync 推进真实定时器,
  /// 再 pump 触发 setState 重建。MarketProvider 的 WS 重连定时器阻止 pumpAndSettle。
  Future<void> settle(WidgetTester tester, {bool pullRefresh = false}) async {
    if (pullRefresh) {
      await tester.drag(find.text('AI 量化'), const Offset(0, 120));
    }
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('收益卡', () {
    testWidgets('显示累计收益、今日收益与三项统计', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/ai/summary'] = _ok({
        'total_pnl': 8420.50,
        'today_pnl': 120.30,
        'running_strategies': 3,
        'win_rate': 68,
        'closed_trades': 11,
      });

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('累计收益(USDT)'), findsOneWidget);
      expect(find.textContaining('+\$8420.50'), findsOneWidget);
      expect(find.textContaining('今日 +\$120.30'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 运行中
      expect(find.text('68%'), findsOneWidget); // 胜率
      expect(find.text('11笔'), findsOneWidget); // 已了结
    });
  });

  group('策略广场', () {
    testWidgets('空态引导(暂无发布的策略)', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.textContaining('暂无发布的策略'), findsOneWidget);
    });

    testWidgets('渲染发布卡(标题/策略/发起人/标的/跟单人数)', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/copy/published'] = _ok(_published);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      // 标题与说明
      expect(find.text('BTC 网格收租'), findsOneWidget);
      expect(find.text('区间高抛低吸,稳健为主'), findsOneWidget);
      expect(find.text('ETH 趋势突破'), findsOneWidget);
      // 策略 chip 与发起人/标的
      expect(find.text('网格区间'), findsOneWidget);
      expect(find.text('趋势追踪'), findsOneWidget);
      expect(find.text('量哥 · BTC/USDT'), findsOneWidget);
      expect(find.text('138****8000 · ETH/USDT'), findsOneWidget);
      // 跟单人数
      expect(find.text('1284 人跟单'), findsOneWidget);
      expect(find.text('862 人跟单'), findsOneWidget);
    });

    testWidgets('点击「跟单」打开跟单弹层,选比例后提交成功关闭', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/copy/published'] = _ok([_published.first]);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      // 打开跟单弹层
      await tester.tap(find.text('跟单'));
      await settle(tester);

      expect(find.text('确认跟单'), findsWidgets); // 弹层标题 + 确认按钮
      expect(find.text('跟单比例'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      // 策略信息卡(与广场卡同文本,可能出现两次)
      expect(find.text('量哥 · BTC/USDT'), findsWidgets);

      // 选择 50% 后提交
      await tester.tap(find.text('50%'));
      await tester.pump();
      responses['PUT_/copy/follow'] = _ok({});

      await tester.tap(find.widgetWithText(ElevatedButton, '确认跟单'));
      await settle(tester);

      // 弹层关闭
      expect(find.widgetWithText(ElevatedButton, '确认跟单'), findsNothing);
    });
    testWidgets('机器人发布卡显示「机器人」标识', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/copy/published'] = _ok([
        {
          'id': 103,
          'monitorId': 3,
          'title': 'EMA 交叉机器人 · BTC 自动带单',
          'description': 'EMA12/26 金叉策略',
          'strategy': 'EMA均线交叉',
          'symbol': 'BTC/USDT',
          'status': 'published',
          'leaderName': 'EMA 交叉机器人',
          'followers': 56,
          'isBot': 1,
        },
      ]);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('机器人'), findsOneWidget);
      expect(find.text('56 人跟单'), findsOneWidget);
    });
  });

  group('我的策略', () {
    testWidgets('无监控时显示空态引导', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('还没有运行中的策略'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '立即新建'), findsOneWidget);
    });

    testWidgets('有监控时渲染监控条目与「发布」入口', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/monitors'] = _ok([
        {
          'id': 1,
          'symbol': 'BTC/USDT',
          'strategy': '网格区间',
          'status': 'running',
          'signal': '等待信号'
        },
      ]);
      responses['/market/quotes'] = _ok([
        {
          'symbol': 'BTC/USDT',
          'name': 'Bitcoin',
          'price': 85000,
          'change': 2.5,
          'volume': 1000,
          'currency': 'USDT',
          'market': 'crypto'
        },
      ]);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('BTC/USDT'), findsWidgets);
      expect(find.text('网格区间 · 等待信号'), findsOneWidget);
      expect(find.text('运行中'), findsWidgets);
      // 未发布:发布 chip + 引导说明
      expect(find.text('发布'), findsOneWidget);
      expect(find.text('发布到策略广场,他人可跟单'), findsOneWidget);
    });

    testWidgets('已提交审核的监控显示「审核中」', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/monitors'] = _ok([
        {
          'id': 1,
          'symbol': 'BTC/USDT',
          'strategy': '网格区间',
          'status': 'running',
          'signal': '等待信号'
        },
      ]);
      responses['/copy/my-publish'] = _ok([
        {
          'id': 9,
          'monitorId': 1,
          'title': 'BTC 网格收租',
          'strategy': '网格区间',
          'symbol': 'BTC/USDT',
          'status': 'pending'
        },
      ]);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('审核中'), findsOneWidget);
      expect(find.text('发布'), findsNothing);
    });
  });

  group('发布弹层', () {
    Future<void> open(WidgetTester tester) async {
      responses['/monitors'] = _ok([
        {
          'id': 1,
          'symbol': 'BTC/USDT',
          'strategy': '网格区间',
          'status': 'running',
          'signal': '等待信号'
        },
      ]);
      await tester.pumpWidget(buildAiPage());
      await settle(tester);
      await tester.tap(find.text('发布'));
      await settle(tester);
    }

    testWidgets('打开时预填默认标题', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      await open(tester);

      expect(find.text('发布策略到广场'), findsOneWidget);
      expect(find.text('网格区间·BTC/USDT'), findsOneWidget); // 预填标题
      expect(find.textContaining('运营审核'), findsOneWidget); // 审核提示
      expect(find.widgetWithText(ElevatedButton, '提交审核'), findsOneWidget);
    });

    testWidgets('标题为空提交 → 提示「请填写策略标题」', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      await open(tester);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '提交审核'));
      await tester.pump();

      expect(find.text('请填写策略标题'), findsOneWidget);
    });

    testWidgets('提交成功 → 弹层关闭', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      await open(tester);

      responses['POST_/copy/publish'] = _ok({});
      await tester.tap(find.widgetWithText(ElevatedButton, '提交审核'));
      await settle(tester);

      expect(find.text('发布策略到广场'), findsNothing);
    });
  });

  group('我的跟单', () {
    testWidgets('渲染跟单条目与取消跟单入口', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      responses['/copy/published'] = _ok([_published.first]);
      responses['/copy/follows'] = _ok([
        {
          'id': 7,
          'publishId': 101,
          'ratio': 25,
          'status': 'active',
          'title': 'BTC 网格收租',
          'strategy': '网格区间',
          'symbol': 'BTC/USDT',
          'leaderName': '量哥',
          'publishStatus': 'published',
          'tradeCount': 6,
          'totalPnl': 128.5
        },
      ]);

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('我的跟单'), findsOneWidget);
      expect(find.text('(1个跟单中)'), findsOneWidget);
      expect(find.text('BTC 网格收租'), findsWidgets); // 广场卡 + 跟单条
      expect(find.text('量哥 · 网格区间 · 固定比例 25%'), findsOneWidget);
      // 盈亏跟踪:复制笔数 + 已实现盈亏
      expect(find.text('复制 6 笔'), findsOneWidget);
      expect(find.text('盈亏 +128.50'), findsOneWidget);
      expect(find.text('取消跟单'), findsOneWidget);
      // 已跟单的广场卡:显示「跟单中」tag 与「调比例」按钮
      expect(find.text('跟单中'), findsOneWidget);
      expect(find.text('调比例'), findsOneWidget);
    });
  });

  group('新建策略弹层', () {
    Future<void> open(WidgetTester tester) async {
      responses['/market/quotes'] = _ok([
        {
          'symbol': 'BTC/USDT',
          'name': 'Bitcoin',
          'price': 85000,
          'change': 2.5,
          'volume': 1000,
          'currency': 'USDT',
          'market': 'crypto'
        },
      ]);
      await tester.pumpWidget(buildAiPage());
      await settle(tester);
      await tester.tap(find.text('新建策略'));
      await settle(tester);
    }

    testWidgets('未选标的点击确认 → 提示「请选择标的」', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      await open(tester);

      expect(find.text('新建策略监控'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, '确认创建'));
      await tester.pump();

      expect(find.text('请选择标的'), findsOneWidget);
    });

    testWidgets('选择标的后确认创建 → 调用 create 并关闭', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      await open(tester);

      // 选择 BTC 标的
      await tester.tap(find.text('BTC'));
      await tester.pump();

      // mock 创建成功响应
      responses['POST_/monitors'] = _ok({});

      await tester.tap(find.widgetWithText(ElevatedButton, '确认创建'));
      await settle(tester);

      // 弹层关闭
      expect(find.text('新建策略监控'), findsNothing);
    });
  });

  group('整体布局', () {
    testWidgets('显示标题 PRO 徽章与新建策略按钮', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildAiPage());
      await settle(tester);

      expect(find.text('AI 量化'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('新建策略'), findsOneWidget);
      expect(find.text('策略广场'), findsOneWidget);
      expect(find.text('我的策略'), findsOneWidget);
      // 底部免责声明
      expect(find.text('量化交易存在风险,历史收益不代表未来表现'), findsOneWidget);
    });
  });
}

Map<String, String> _baseResponses() => {
      '/ai/summary': _ok({
        'total_pnl': 0,
        'today_pnl': 0,
        'running_strategies': 0,
        'win_rate': 0,
        'closed_trades': 0,
      }),
      '/monitors': _ok([]),
      '/copy/published': _ok([]),
      '/copy/my-publish': _ok([]),
      '/copy/follows': _ok([]),
      '/market/quotes': _ok([]),
      '/market/overview': _ok({}),
      '/market/meta': _ok({}),
    };

List<Object> get _published => [
      {
        'id': 101,
        'monitorId': 1,
        'title': 'BTC 网格收租',
        'description': '区间高抛低吸,稳健为主',
        'strategy': '网格区间',
        'symbol': 'BTC/USDT',
        'status': 'published',
        'leaderName': '量哥',
        'followers': 1284,
      },
      {
        'id': 102,
        'monitorId': 2,
        'title': 'ETH 趋势突破',
        'description': '',
        'strategy': '趋势追踪',
        'symbol': 'ETH/USDT',
        'status': 'published',
        'leaderName': '138****8000',
        'followers': 862,
      },
    ];

String _ok(Object data) =>
    jsonEncode({'code': 200, 'message': 'success', 'data': data});

// ── Mock HTTP 适配器 ──────────────────────────────────────

class _MockAdapter implements HttpClientAdapter {
  final Map<String, String> Function() _responses;
  _MockAdapter(this._responses);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final uriPath = options.uri.path;
    final method = options.method;
    final map = _responses();
    String? body;
    // 优先 "METHOD_路径"(按后缀匹配)
    for (final k in map.keys) {
      if (k.startsWith('${method}_')) {
        final pathPart = k.substring(method.length + 1);
        if (uriPath.endsWith(pathPart)) {
          body = map[k];
          break;
        }
      }
    }
    // 再按纯路径后缀匹配
    body ??= map.entries
        .where((e) => !e.key.contains('_') && uriPath.endsWith(e.key))
        .map((e) => e.value)
        .firstOrNull;
    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode({'code': 404, 'message': 'no mock for $uriPath'}),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
