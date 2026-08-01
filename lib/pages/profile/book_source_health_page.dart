import 'package:flutter/material.dart';

import '../../models/book_source.dart';
import '../../models/source_health.dart';
import '../../services/app_logger.dart';
import '../../services/source_health_check_service.dart';
import '../../services/source_health_logic.dart';
import '../../services/storage_service.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common_widgets.dart';

/// 书源健康检查页：批量真实探测搜索→详情→目录→正文
class BookSourceHealthPage extends StatefulWidget {
  const BookSourceHealthPage({super.key});

  @override
  State<BookSourceHealthPage> createState() => _BookSourceHealthPageState();
}

class _BookSourceHealthPageState extends State<BookSourceHealthPage> {
  final _keywordController = TextEditingController(text: '我的');
  final _searchController = TextEditingController();
  final _service = SourceHealthCheckService();

  List<SourceHealthResult> _results = [];
  bool _running = false;
  int _done = 0;
  int _total = 0;
  SourceHealthStatus? _filterStatus;
  SourceHealthSort _sort = SourceHealthSort.status;
  bool _sortAsc = true;
  bool _enabledOnly = true;
  int _concurrency = 3;

  @override
  void dispose() {
    _keywordController.dispose();
    _searchController.dispose();
    _service.cancel();
    super.dispose();
  }

  List<BookSource> _loadSources() {
    final raw = StorageService.instance.getAllBookSources();
    final list = <BookSource>[];
    for (final item in raw) {
      try {
        final source = BookSource.fromJson(Map<String, dynamic>.from(item));
        if (_enabledOnly && !source.enabled) continue;
        list.add(source);
      } catch (e, st) {
        AppLogger.instance.warn(
          LogCategory.storage,
          '健康检查跳过损坏书源',
          detail: '$e\n$st',
        );
      }
    }
    return list;
  }

  Future<void> _start() async {
    final sources = _loadSources();
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可检测的书源')),
      );
      return;
    }
    setState(() {
      _running = true;
      _results = [];
      _done = 0;
      _total = sources.length;
    });
    try {
      final results = await _service.checkSources(
        sources,
        keyword: _keywordController.text.trim(),
        concurrency: _concurrency,
        onProgress: (done, total, latest) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
            if (latest != null) {
              _results = [..._results, latest];
            }
          });
        },
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('健康检查异常: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _cancel() {
    _service.cancel();
    setState(() => _running = false);
  }

  Future<void> _disableFailed() async {
    final count = await _service.disableFailedSources(_results);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已禁用 $count 个失效书源')),
    );
  }

  List<SourceHealthResult> get _display {
    final filtered = filterHealthResults(
      _results,
      status: _filterStatus,
      keyword: _searchController.text,
    );
    return sortHealthResults(filtered, sort: _sort, ascending: _sortAsc);
  }

  @override
  Widget build(BuildContext context) {
    final display = _display;
    final available =
        _results.where((r) => r.status == SourceHealthStatus.available).length;
    final partial =
        _results.where((r) => r.status == SourceHealthStatus.partial).length;
    final failed =
        _results.where((r) => r.status == SourceHealthStatus.failed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源健康检查'),
        actions: [
          if (_running)
            AppBarTextButton(onPressed: _cancel, label: '取消')
          else
            AppBarTextButton(onPressed: _start, label: '开始检测'),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'disable_failed':
                  await _disableFailed();
                  break;
                case 'sort_name':
                  setState(() {
                    _sort = SourceHealthSort.name;
                    _sortAsc = true;
                  });
                  break;
                case 'sort_status':
                  setState(() {
                    _sort = SourceHealthSort.status;
                    _sortAsc = true;
                  });
                  break;
                case 'sort_duration':
                  setState(() {
                    _sort = SourceHealthSort.duration;
                    _sortAsc = true;
                  });
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'disable_failed', child: Text('一键禁用全部失效源')),
              PopupMenuItem(value: 'sort_status', child: Text('按状态排序')),
              PopupMenuItem(value: 'sort_name', child: Text('按名称排序')),
              PopupMenuItem(value: 'sort_duration', child: Text('按耗时排序')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keywordController,
                        enabled: !_running,
                        decoration: const InputDecoration(
                          labelText: '测试关键词',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '并发',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _concurrency,
                            items: const [1, 2, 3, 4, 5, 6]
                                .map((n) => DropdownMenuItem(
                                      value: n,
                                      child: Text('$n'),
                                    ))
                                .toList(),
                            onChanged: _running
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setState(() => _concurrency = v);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('仅启用'),
                      selected: _enabledOnly,
                      onSelected: _running
                          ? null
                          : (v) => setState(() => _enabledOnly = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '筛选结果…',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('全部(${_results.length})'),
                      selected: _filterStatus == null,
                      onSelected: (_) =>
                          setState(() => _filterStatus = null),
                    ),
                    ChoiceChip(
                      label: Text('可用($available)'),
                      selected: _filterStatus == SourceHealthStatus.available,
                      onSelected: (_) => setState(
                          () => _filterStatus = SourceHealthStatus.available),
                    ),
                    ChoiceChip(
                      label: Text('部分($partial)'),
                      selected: _filterStatus == SourceHealthStatus.partial,
                      onSelected: (_) => setState(
                          () => _filterStatus = SourceHealthStatus.partial),
                    ),
                    ChoiceChip(
                      label: Text('失效($failed)'),
                      selected: _filterStatus == SourceHealthStatus.failed,
                      onSelected: (_) => setState(
                          () => _filterStatus = SourceHealthStatus.failed),
                    ),
                  ],
                ),
                if (_running) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _total == 0 ? null : _done / _total,
                  ),
                  const SizedBox(height: 4),
                  Text('进度 $_done / $_total'),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: display.isEmpty
                ? Center(
                    child: Text(
                      _running ? '检测中…' : '点击右上角「开始检测」',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: display.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = display[index];
                      return ListTile(
                        leading: _statusIcon(r.status),
                        title: Text(r.sourceName),
                        subtitle: Text(
                          '${r.status.label} · ${r.totalMs}ms'
                          '${r.failReason != null ? '\n${r.failReason}' : ''}\n'
                          '${r.steps.map((s) => '${s.name}:${s.success ? "✓" : "✗"}(${s.durationMs}ms)').join(' · ')}',
                        ),
                        isThreeLine: true,
                        onTap: () => _showDetail(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(SourceHealthStatus status) {
    switch (status) {
      case SourceHealthStatus.available:
        return const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.check, color: Colors.green),
        );
      case SourceHealthStatus.partial:
        return const CircleAvatar(
          backgroundColor: Color(0xFFFFF8E1),
          child: Icon(Icons.warning_amber, color: Colors.orange),
        );
      case SourceHealthStatus.failed:
        return const CircleAvatar(
          backgroundColor: Color(0xFFFFEBEE),
          child: Icon(Icons.close, color: Colors.red),
        );
    }
  }

  void _showDetail(SourceHealthResult r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.sourceName, style: Theme.of(ctx).textTheme.titleMedium),
              Text(r.sourceUrl, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Text('状态: ${r.status.label} · 总耗时 ${r.totalMs}ms'),
              if (r.failReason != null) Text('原因: ${r.failReason}'),
              const Divider(),
              ...r.steps.map(
                (s) => ListTile(
                  dense: true,
                  leading: Icon(
                    s.success ? Icons.check_circle : Icons.error,
                    color: s.success ? Colors.green : Colors.red,
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    s.success
                        ? (s.detail ?? '成功')
                        : (s.error ?? '失败'),
                  ),
                  trailing: Text('${s.durationMs}ms'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
