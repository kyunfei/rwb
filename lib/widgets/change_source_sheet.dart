import 'package:flutter/material.dart';

import '../../models/book_source.dart';
import '../../services/change_source_match.dart';
import '../../services/source_engine/web_book.dart';
import '../../services/storage_service.dart';

/// 换源弹窗组件
/// 可在详情页和阅读器中使用
class ChangeSourceSheet extends StatefulWidget {
  final String bookName;
  final String bookAuthor;
  final String? currentSourceUrl;
  final String? currentSourceName;
  final Function(String sourceUrl, String sourceName, Map<String, dynamic> bookData) onSourceSelected;

  const ChangeSourceSheet({
    super.key,
    required this.bookName,
    required this.bookAuthor,
    this.currentSourceUrl,
    this.currentSourceName,
    required this.onSourceSelected,
  });

  /// 显示换源弹窗
  static void show({
    required BuildContext context,
    required String bookName,
    required String bookAuthor,
    String? currentSourceUrl,
    String? currentSourceName,
    required Function(String sourceUrl, String sourceName, Map<String, dynamic> bookData) onSourceSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChangeSourceSheet(
        bookName: bookName,
        bookAuthor: bookAuthor,
        currentSourceUrl: currentSourceUrl,
        currentSourceName: currentSourceName,
        onSourceSelected: onSourceSelected,
      ),
    );
  }

  @override
  State<ChangeSourceSheet> createState() => _ChangeSourceSheetState();
}

class _ChangeSourceSheetState extends State<ChangeSourceSheet> {
  final List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchSources();
  }

  Future<void> _searchSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sourcesData = StorageService.instance.getAllBookSources();
      final sources = <BookSource>[];

      for (final data in sourcesData) {
        try {
          final source = BookSource.fromJson(data);
          if (source.enabled &&
              source.searchUrl != null &&
              source.searchUrl!.isNotEmpty) {
            sources.add(source);
          }
        } catch (e) {
          debugPrint('跳过无效书源: $e');
        }
      }

      if (sources.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '没有可用的书源';
        });
        return;
      }

      // 只用书名搜；作者留给本地过滤，避免站点把「书名 作者」当成杂搜
      final keyword = ChangeSourceMatch.searchKeyword(widget.bookName);
      final futures = <Future<void>>[];
      final hits = <Map<String, dynamic>>[];

      for (final source in sources) {
        futures.add(() async {
          try {
            final searchResult = await WebBook(source)
                .searchBook(keyword)
                .timeout(const Duration(seconds: 15));

            for (final book in searchResult) {
              // 拷一份再写元数据，避免改到引擎内部缓存对象
              final row = Map<String, dynamic>.from(book);
              row['sourceUrl'] = source.bookSourceUrl;
              row['sourceName'] = source.bookSourceName;
              row['searchTime'] = DateTime.now().millisecondsSinceEpoch;
              hits.add(row);
            }
          } catch (e) {
            debugPrint('搜索书源 ${source.bookSourceName} 失败: $e');
          }
        }());
      }

      await Future.wait(futures);

      final results = ChangeSourceMatch.selectSourceEntries(
        targetName: widget.bookName,
        targetAuthor: widget.bookAuthor,
        hits: hits,
        currentSourceUrl: widget.currentSourceUrl,
      );

      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '搜索失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('换源', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${widget.bookName} - ${widget.bookAuthor}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                  onPressed: _searchSources,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildContent(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在搜索书源...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchSources,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48),
            SizedBox(height: 16),
            Text('未找到匹配的书源'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final sourceUrl = result['sourceUrl'] as String?;
        final sourceName = result['sourceName'] as String? ?? '未知';
        final lastChapter = result['lastChapter'] as String? ?? '';
        final isCurrentSource = sourceUrl == widget.currentSourceUrl;

        return ListTile(
          leading: Icon(
            Icons.source,
            color: isCurrentSource ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  sourceName,
                  style: TextStyle(
                    fontWeight:
                        isCurrentSource ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrentSource)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: lastChapter.isEmpty
              ? null
              : Text('最新: $lastChapter', style: const TextStyle(fontSize: 12)),
          trailing: isCurrentSource
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: isCurrentSource
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onSourceSelected(sourceUrl!, sourceName, result);
                },
        );
      },
    );
  }
}
