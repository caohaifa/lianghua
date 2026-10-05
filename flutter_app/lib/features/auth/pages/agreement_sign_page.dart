import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../providers/auth_provider.dart';
import '../widgets/agreement_texts.dart';

class AgreementSignPage extends StatefulWidget {
  const AgreementSignPage({super.key});

  @override
  State<AgreementSignPage> createState() => _AgreementSignPageState();
}

class _AgreementSignPageState extends State<AgreementSignPage> {
  final Set<int> _checked = {};
  final Set<int> _read = {}; // 已滚动到底读完的协议
  final List<Offset> _signaturePoints = [];
  final _signAreaKey = GlobalKey();
  bool _loading = false;
  int _readCountdown = 30; // 🔴 强制阅读满 30s

  @override
  void initState() {
    super.initState();
    _startReadTimer();
  }

  void _startReadTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _readCountdown--);
      return _readCountdown > 0;
    });
  }

  bool get _allRequiredChecked {
    for (var i = 0; i < kSignAgreements.length; i++) {
      if (kSignAgreements[i].required && !_checked.contains(i)) return false;
    }
    return true;
  }

  bool get _canSign =>
      _allRequiredChecked && _readCountdown <= 0 && _signaturePoints.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('协议签署'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _checked.length / kSignAgreements.length,
            backgroundColor: AppTheme.divider,
            valueColor: const AlwaysStoppedAnimation(AppTheme.brandPrimary),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('2/2 协议签署', style: AppTheme.caption),
              const SizedBox(height: 12),
              if (_readCountdown > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFB300),
                    borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: AppTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('请仔细阅读协议,$_readCountdown s 后可签署',
                        style: TextStyle(color: AppTheme.warning, fontSize: 13)),
                    ],
                  ),
                ),
              // 协议列表
              ...List.generate(kSignAgreements.length, (i) {
                final doc = kSignAgreements[i];
                final checked = _checked.contains(i);
                final read = _read.contains(i);
                // 🔴 协议必须先滚动到底阅读全文,才能勾选
                final checkable = !doc.required || read;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FinanceCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: InkWell(
                      onTap: () => _openDoc(i, doc),
                      child: Row(
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: checkable
                                ? (v) => setState(() {
                                      if (v == true) {
                                        _checked.add(i);
                                      } else {
                                        _checked.remove(i);
                                      }
                                    })
                                : null,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: TextStyle(
                                    color: doc.required ? AppTheme.warning : AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (doc.required && !read)
                                  Text('点击阅读全文,读完后方可勾选',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (doc.required)
                            const Text('🔴 必读', style: TextStyle(color: AppTheme.bear, fontSize: 12)),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // 电子签名区
              const SizedBox(height: 8),
              FinanceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.draw, color: AppTheme.brandPrimary, size: 20),
                        const SizedBox(width: 8),
                        Text('电子签名', style: AppTheme.title),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('请在下方区域手写签名', style: AppTheme.caption),
                    const SizedBox(height: 12),
                    Container(
                      key: _signAreaKey,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundTertiary,
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() => _signaturePoints.add(details.localPosition));
                        },
                        onPanEnd: (_) {
                          setState(() => _signaturePoints.add(Offset.infinite));
                        },
                        child: CustomPaint(
                          painter: _SignaturePainter(_signaturePoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    if (_signaturePoints.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _signaturePoints.clear()),
                          child: const Text('清除重签'),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_canSign && !_loading) ? _sign : null,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('同意并签署'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDoc(int index, AgreementDoc doc) async {
    final done = await AgreementViewerPage.open(context, doc);
    if (done && mounted) setState(() => _read.add(index));
  }

  /// 手写签名 → PNG → Base64(服务端加 CA 时间戳存证 OSS)
  Future<String?> _exportSignatureBase64() async {
    if (_signaturePoints.isEmpty) return null;
    final box = _signAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(600, 150);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    _SignaturePainter(_signaturePoints).paint(canvas, size);
    final image = await recorder
        .endRecording()
        .toImage(size.width.round(), size.height.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return base64Encode(bytes.buffer.asUint8List());
  }

  Future<void> _sign() async {
    setState(() => _loading = true);
    final signature = await _exportSignatureBase64();
    if (!mounted) return;
    if (signature == null) {
      setState(() => _loading = false);
      return;
    }
    final auth = context.read<AuthProvider>();
    final agreementIds = [
      for (final i in _checked) kSignAgreements[i].id,
    ];
    final ok = await auth.signAgreement(signature, agreementIds);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/market');
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < points.length - 1; i++) {
      if (points[i + 1] != Offset.infinite && points[i] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
