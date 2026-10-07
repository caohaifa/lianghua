import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';

/// 系统公告(运营后台发布,用户端只读)
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get('/announcements');
      if (!mounted) return;
      setState(() =>
          _items = (res.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '加载失败,请检查网络');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('系统公告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: AppTheme.caption),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('暂无公告', style: AppTheme.caption))
                  : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) => _tile(_items[i]),
                  ),
                ),
    );
  }

  Widget _tile(Map<String, dynamic> a) {
    final time = (a['publishedAt'] ?? a['createdAt'] ?? '').toString();
    return FinanceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a['title'] ?? '', style: AppTheme.title),
          const SizedBox(height: 4),
          Text(time.length >= 16 ? time.substring(0, 16).replaceAll('T', ' ') : time,
              style: AppTheme.caption),
          const SizedBox(height: 8),
          Text(a['content'] ?? '', style: AppTheme.body),
        ],
      ),
    );
  }
}
