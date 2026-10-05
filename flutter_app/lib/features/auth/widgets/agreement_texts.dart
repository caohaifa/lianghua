import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 协议文档模型
class AgreementDoc {
  final String id;
  final String title;
  final bool required; // 🔴 强制阅读满 30s + 手写签名
  final String content;

  const AgreementDoc({
    required this.id,
    required this.title,
    required this.required,
    required this.content,
  });
}

/// 《AI 量化平台用户协议》
const kUserAgreement = AgreementDoc(
  id: 'user_agreement',
  title: '《AI 量化平台用户协议》',
  required: false,
  content: '''
第一条 总则
1.1 本协议由您与 AI 量化平台(以下简称"本平台")共同缔结,具有合同效力。
1.2 您确认已年满 18 周岁,具备完全民事行为能力。

第二条 服务内容
2.1 本平台提供基于多智能体协同的量化交易辅助决策服务,包括行情数据、AI 决策信号、策略回测、自动化交易执行等。
2.2 本平台为技术工具提供方,不构成任何投资建议。

第三条 账号与安全
3.1 您应妥善保管账号、验证码及 API Key,因您主动泄露造成的损失由您自行承担。
3.2 单账号绑定设备数量受平台风控规则限制,异地/新设备登录需完成二次验证。

第四条 费用与权限
4.1 平台权限分为不同档位,按年付费,具体权益以订阅页公示为准。
4.2 权限到期后自动降级为游客权限,历史数据保留。

第五条 行为规范
5.1 您不得利用本平台从事洗钱、操纵市场等违法违规活动。
5.2 您不得对平台进行逆向工程、爬虫抓取或攻击性访问。

第六条 协议变更与终止
6.1 本平台有权根据监管要求修订本协议,修订后将通过站内信公示。
6.2 您可随时申请注销账号,注销后数据按《隐私政策》处理。
''',
);

/// 《风险告知书》(🔴 强制阅读)
const kRiskDisclosure = AgreementDoc(
  id: 'risk_disclosure',
  title: '《风险告知书》',
  required: true,
  content: '''
第一条 市场风险
1.1 证券、期货及数字资产价格波动剧烈,您可能面临本金部分或全部损失。
1.2 历史回测收益不代表未来表现,回测区间、滑点与手续费假设均可能影响结果。

第二条 模型风险
2.1 AI 模型基于历史数据训练,极端行情、结构性变化下可能失效。
2.2 多智能体协同决策存在信号冲突、延迟或中断的可能。

第三条 技术风险
3.1 网络延迟、交易所接口故障、券商系统维护可能导致委托失败或延迟成交。
3.2 自动化交易在熔断机制触发前可能持续执行亏损策略。

第四条 杠杆与衍生品风险
4.1 高杠杆策略将同步放大收益与亏损,可能触发强制平仓。
4.2 您可购买的策略风险等级以风险测评结果为准(R1~R5)。

第五条 特别提示
5.1 AI 辅助决策,您应自主判断、自主决策、自主承担风险。
5.2 请勿投入超出您风险承受能力的资金。
''',
);

/// 《自主交易决策声明》(🔴 强制阅读)
const kSelfDecisionDeclaration = AgreementDoc(
  id: 'self_decision',
  title: '《自主交易决策声明》',
  required: true,
  content: '''
本人郑重声明:

一、本人已充分理解 AI 量化平台提供的内容为技术工具与信息参考,不构成投资建议或收益承诺。

二、本人在平台上进行的一切交易决策(包括启用、暂停、停止自动化策略)均为本人独立判断后自主作出。

三、本人知悉并自愿承担交易可能产生的全部风险与损失,不因使用平台工具而向平台主张投资损失赔偿。

四、本人承诺交易资金来源合法,交易行为符合所在司法辖区的法律法规。

五、本人理解平台风控熔断机制仅为辅助手段,不能免除本人的最终决策责任。
''',
);

/// 《电子签署授权书》
const kEsignAuthorization = AgreementDoc(
  id: 'esign_auth',
  title: '《电子签署授权书》',
  required: false,
  content: '''
第一条 本人授权平台使用本人手写签名的电子图像,作为本人签署平台相关协议的意思表示。

第二条 本人同意平台采用 CA 证书时间戳对签署行为进行存证,并将存证文件保存于第三方对象存储(OSS)。

第三条 依据《中华人民共和国电子签名法》,可靠的电子签名与手写签名或者盖章具有同等的法律效力。

第四条 本人可在"我的-合规档案"中随时查阅已签署协议全文及电子签章时间戳。
''',
);

/// 《隐私政策》(登录/注册页强制勾选)
const kPrivacyPolicy = AgreementDoc(
  id: 'privacy',
  title: '《隐私政策》',
  required: false,
  content: '''
第一条 信息收集
1.1 我们收集您的手机号、设备指纹、登录 IP 及城市,用于账号安全与异地登录风控。
1.2 风险测评答题数据用于适配性评估与策略权限控制。

第二条 信息使用
2.1 您的券商/交易所 API Key 经加密后存储,仅用于您授权的交易执行。
2.2 我们不向任何第三方出售您的个人信息。

第三条 信息存储与保护
3.1 敏感数据采用行业标准的加密算法存储与传输。
3.2 协议签署存证文件保存于 OSS,保留期限符合监管要求。

第四条 您的权利
4.1 您可查阅、更正您的个人信息,可申请注销账号。
4.2 注销后,法律法规要求留存的信息除外,其余数据将被删除或匿名化。
''',
);

/// 协议签署页的 4 份协议(②③ 🔴 强制阅读)
const kSignAgreements = <AgreementDoc>[
  kUserAgreement,
  kRiskDisclosure,
  kSelfDecisionDeclaration,
  kEsignAuthorization,
];

/// 协议全文阅读页:必须滚动到底部才能完成阅读
class AgreementViewerPage extends StatefulWidget {
  final AgreementDoc doc;

  const AgreementViewerPage({super.key, required this.doc});

  /// 打开阅读页,返回 true 表示已滚动到底并完成阅读
  static Future<bool> open(BuildContext context, AgreementDoc doc) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AgreementViewerPage(doc: doc)),
    );
    return result == true;
  }

  @override
  State<AgreementViewerPage> createState() => _AgreementViewerPageState();
}

class _AgreementViewerPageState extends State<AgreementViewerPage> {
  final _scrollCtrl = ScrollController();
  bool _reachedBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // 内容不足一屏时直接视为已读完
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _reachedBottom) return;
    final pos = _scrollCtrl.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 24) {
      setState(() => _reachedBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.doc.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                child: Text(widget.doc.content, style: AppTheme.body.copyWith(height: 1.8)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              child: ElevatedButton(
                onPressed: _reachedBottom ? () => Navigator.of(context).pop(true) : null,
                child: Text(_reachedBottom ? '我已阅读并理解' : '请滑动阅读全文'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
