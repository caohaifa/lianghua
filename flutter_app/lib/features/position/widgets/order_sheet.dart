import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../market/providers/market_provider.dart';
import '../providers/position_provider.dart';

/// 公共下单面板:标的(行情列表) + 买卖 + 市价/限价 + 数量/价格。
/// 持仓页"+"与行情详情页"买入/卖出"共用;可传入预选标的与方向。
void showOrderSheet(BuildContext context,
    {String? initialSymbol, String? initialSide}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        OrderSheet(initialSymbol: initialSymbol, initialSide: initialSide),
  );
}

class OrderSheet extends StatefulWidget {
  final String? initialSymbol;
  final String? initialSide;
  const OrderSheet({super.key, this.initialSymbol, this.initialSide});

  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  String? _symbol;
  String _side = 'buy';
  String _orderType = 'market';
  final _amountCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _symbol = widget.initialSymbol;
    if (widget.initialSide == 'sell') _side = 'sell';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    final price =
        _orderType == 'limit' ? double.tryParse(_priceCtrl.text) : null;
    if (_symbol == null) return _toast('请选择标的');
    if (amount == null || amount <= 0) return _toast('请输入有效数量');
    if (_orderType == 'limit' && (price == null || price <= 0)) {
      return _toast('请输入有效限价');
    }
    setState(() => _submitting = true);
    final err = await context.read<PositionProvider>().placeOrder(
        symbol: _symbol!,
        side: _side,
        orderType: _orderType,
        price: price,
        amount: amount);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err == null) {
      Navigator.of(context).pop();
      _toast('下单成功');
    } else {
      _toast(err);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<MarketProvider>().quotes;
    _symbol ??= quotes.isNotEmpty ? quotes.first.symbol : null;
    Quote? selectedQuote;
    for (final q in quotes) {
      if (q.symbol == _symbol) {
        selectedQuote = q;
        break;
      }
    }
    final isAShare = selectedQuote?.market == 'a-share';

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('新建委托', style: AppTheme.headline),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _symbol,
            decoration: const InputDecoration(labelText: '标的'),
            items: quotes
                .map((q) => DropdownMenuItem(
                    value: q.symbol, child: Text('${q.symbol}  ${q.name}')))
                .toList(),
            onChanged: (v) => setState(() => _symbol = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'buy', label: Text('买入')),
                    ButtonSegment(value: 'sell', label: Text('卖出')),
                  ],
                  selected: {_side},
                  onSelectionChanged: (s) => setState(() => _side = s.first),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'market', label: Text('市价')),
                    ButtonSegment(value: 'limit', label: Text('限价')),
                  ],
                  selected: {_orderType},
                  onSelectionChanged: (s) =>
                      setState(() => _orderType = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_orderType == 'limit')
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '限价'),
            ),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.numberWithOptions(decimal: !isAShare),
            decoration: InputDecoration(
              labelText: '数量',
              hintText: isAShare ? '按手填写,1手=100股' : null,
              helperText: isAShare ? 'A股T+1,当日买入次日才可卖' : null,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('确认下单'),
          ),
        ],
      ),
    );
  }
}
