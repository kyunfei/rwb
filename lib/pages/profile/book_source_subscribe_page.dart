import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/source_subscription.dart';
import '../../services/source_import_logic.dart';
import '../../services/source_subscribe_service.dart';
import '../../utils/design_tokens.dart';

/// 书源订阅管理：记住远程地址，支持单条更新与一键更新全部
class BookSourceSubscribePage extends StatefulWidget {
  const BookSourceSubscribePage({super.key});

  @override
  State<BookSourceSubscribePage> createState() =>
      _BookSourceSubscribePageState();
}

class _BookSourceSubscribePageState extends State<BookSourceSubscribePage> {
  final _service = SourceSubscribeService();
  final _urlController = TextEditingController();
  List<SourceSubscription> _subs = [];
  bool _busy = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _subs = _service.list());
  }

  Future<void> _addUrl({bool fromClipboard = false}) async {
    var url = _urlController.text.trim();
    if (fromClipboard) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      url = data?.text?.trim() ?? '';
      if (url.isNotEmpty) _urlController.text = url;
    }
    if (!looksLikeSubscribeUrl(url)) {
      _toast('请输入有效的 http(s) 订阅地址');
      return;
    }
    setState(() {
      _busy = true;
      _progress = '正在订阅并导入…';
    });
    try {
      final result = await _service.add(url);
      _reload();
      if (result != null) {
        _toast(
          '订阅成功：新增 ${result.added}，更新 ${result.updated}，未变 ${result.unchanged}',
        );
      } else {
        _toast('已添加订阅');
      }
      _urlController.clear();
    } catch (e) {
      _reload();
      _toast('订阅失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _updateOne(SourceSubscription sub) async {
    setState(() {
      _busy = true;
      _progress = '更新 ${sub.url}…';
    });
    try {
      final result = await _service.updateOne(sub.url);
      _reload();
      _toast(
        '更新完成：新增 ${result.added}，更新 ${result.updated}，未变 ${result.unchanged}',
      );
    } catch (e) {
      _reload();
      _toast('更新失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _updateAll() async {
    if (_subs.isEmpty) {
      _toast('暂无订阅');
      return;
    }
    setState(() {
      _busy = true;
      _progress = '准备更新…';
    });
    try {
      final outcomes = await _service.updateAll(
        onProgress: (done, total, url) {
          if (!mounted) return;
          setState(() {
            _progress = total == 0
                ? null
                : '更新中 $done/$total${url.isEmpty ? '' : '\n$url'}';
          });
        },
      );
      _reload();
      final ok = outcomes.where((o) => o.error == null).length;
      final fail = outcomes.length - ok;
      var added = 0;
      var updated = 0;
      for (final o in outcomes) {
        added += o.result?.added ?? 0;
        updated += o.result?.updated ?? 0;
      }
      _toast('全部更新完成：成功 $ok，失败 $fail；书源新增 $added / 更新 $updated');
    } catch (e) {
      _reload();
      _toast('批量更新异常: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _remove(SourceSubscription sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('仅删除订阅地址，不会删除已导入的书源。\n\n${sub.url}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.remove(sub.url);
    _reload();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源订阅'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _updateAll,
            child: const Text('一键更新全部'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: '订阅地址',
                        hintText: 'https://example.com/sources.json',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _addUrl(),
                    ),
                    const SizedBox(height: DesignTokens.spacingMd),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _addUrl(fromClipboard: true),
                          icon: const Icon(Icons.content_paste),
                          label: const Text('剪贴板'),
                        ),
                        const SizedBox(width: DesignTokens.spacingMd),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _addUrl,
                            icon: const Icon(Icons.add_link),
                            label: const Text('订阅并导入'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spacingSm),
                    Text(
                      '支持单个源、源数组，以及 {"sourceUrls":[...]} 订阅列表。'
                      '重复订阅按 bookSourceUrl 去重更新。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _subs.isEmpty
                    ? Center(
                        child: Text(
                          '暂无订阅地址',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _subs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final sub = _subs[index];
                          return ListTile(
                            title: Text(
                              sub.name?.isNotEmpty == true
                                  ? sub.name!
                                  : sub.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub.url,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _subtitleMeta(sub),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: sub.lastError != null
                                        ? Colors.red
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: '更新',
                                  onPressed:
                                      _busy ? null : () => _updateOne(sub),
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed:
                                      _busy ? null : () => _remove(sub),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black38,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (_progress != null) ...[
                          const SizedBox(height: 16),
                          Text(_progress!, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleMeta(SourceSubscription sub) {
    if (sub.lastError != null) {
      return '上次失败: ${sub.lastError}';
    }
    if (sub.lastUpdateTime <= 0) {
      return '尚未更新';
    }
    final t = DateTime.fromMillisecondsSinceEpoch(sub.lastUpdateTime);
    final ts =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '上次更新 $ts · +${sub.lastAdded} / ~${sub.lastUpdated} / =${sub.lastUnchanged}';
  }
}
