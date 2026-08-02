import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../models/book_source.dart';
import '../../models/curated_bookstore.dart';
import '../search/search_text_normalizer.dart';
import '../source_engine/web_book.dart';
import '../storage_service.dart';
import 'curated_match.dart';

/// 策展封面惰性解析：占位 → 后台搜索真封面 → 本地缓存。
///
/// 并发上限刻意压低：一屏可能挂 20+ 本书，每本若再打几十个源会把网络打爆。
/// 默认最多同时解析 [maxConcurrentBooks] 本书，每本最多探 [maxSourcesPerBook] 个源。
class CuratedCoverResolver {
  CuratedCoverResolver({
    this.maxConcurrentBooks = 2,
    this.maxSourcesPerBook = 4,
    this.perSourceTimeout = const Duration(seconds: 12),
    BookSourceSearcher? searcher,
    CoverCacheStore? cacheStore,
  })  : _searcher = searcher ?? _defaultSearcher,
        _cache = cacheStore ?? StorageCoverCacheStore();

  /// 同时进行封面搜索的书籍数。2：兼顾首屏体感与源站压力。
  final int maxConcurrentBooks;

  /// 单本书最多尝试的书源数；找到封面即停。
  final int maxSourcesPerBook;

  final Duration perSourceTimeout;
  final BookSourceSearcher _searcher;
  final CoverCacheStore _cache;

  final Map<String, String> _memory = {};
  final Set<String> _inflight = {};
  final Set<String> _failed = {};
  final Queue<_CoverJob> _queue = Queue();
  int _active = 0;

  /// 内存 + 持久化缓存中的封面 URL；无则 null。
  String? cachedCoverUrl(CuratedBook book) {
    final key = cacheKey(book.name, book.author);
    final mem = _memory[key];
    if (mem != null && mem.isNotEmpty) return mem;
    if (book.hasCover) return book.coverUrl;
    final stored = _cache.read(key);
    if (stored != null && stored.isNotEmpty) {
      _memory[key] = stored;
      return stored;
    }
    return null;
  }

  /// 入队解析；已有封面 / 已失败 / 已在飞则跳过。
  void enqueue({
    required CuratedBook book,
    required List<BookSource> sources,
    void Function(String coverUrl)? onResolved,
  }) {
    if (book.hasCover) return;
    final key = cacheKey(book.name, book.author);
    if (_memory.containsKey(key) || _failed.contains(key) || _inflight.contains(key)) {
      final cached = _memory[key];
      if (cached != null && cached.isNotEmpty) {
        onResolved?.call(cached);
      }
      return;
    }
    final stored = _cache.read(key);
    if (stored != null && stored.isNotEmpty) {
      _memory[key] = stored;
      onResolved?.call(stored);
      return;
    }

    _queue.add(
      _CoverJob(
        key: key,
        book: book,
        sources: _pickSources(sources),
        onResolved: onResolved,
      ),
    );
    _pump();
  }

  void prefetchVisible(
    Iterable<CuratedBook> books, {
    required List<BookSource> sources,
    void Function(String bookId, String coverUrl)? onResolved,
  }) {
    for (final book in books) {
      enqueue(
        book: book,
        sources: sources,
        onResolved: onResolved == null
            ? null
            : (url) => onResolved(book.id, url),
      );
    }
  }

  static String cacheKey(String name, String author) =>
      SearchTextNormalizer.dedupeKey(name, author);

  List<BookSource> _pickSources(List<BookSource> sources) {
    final enabled = sources
        .where(
          (s) =>
              s.enabled &&
              s.searchUrl != null &&
              s.searchUrl!.trim().isNotEmpty,
        )
        .toList();
    enabled.sort((a, b) => b.weight.compareTo(a.weight));
    if (enabled.length <= maxSourcesPerBook) return enabled;
    return enabled.take(maxSourcesPerBook).toList();
  }

  void _pump() {
    while (_active < maxConcurrentBooks && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (_inflight.contains(job.key) || _memory.containsKey(job.key)) {
        continue;
      }
      _inflight.add(job.key);
      _active++;
      unawaited(_runJob(job).whenComplete(() {
        _inflight.remove(job.key);
        _active--;
        _pump();
      }));
    }
  }

  Future<void> _runJob(_CoverJob job) async {
    if (job.sources.isEmpty) {
      _failed.add(job.key);
      return;
    }
    final keyword =
        buildCuratedSearchKeyword(job.book.name, job.book.author);
    for (final source in job.sources) {
      try {
        final results = await _searcher(source, keyword)
            .timeout(perSourceTimeout);
        final cover = _pickCoverFromResults(
          curatedName: job.book.name,
          curatedAuthor: job.book.author,
          results: results,
          sourceUrl: source.bookSourceUrl,
        );
        if (cover != null && cover.isNotEmpty) {
          _memory[job.key] = cover;
          await _cache.write(job.key, cover);
          job.onResolved?.call(cover);
          return;
        }
      } catch (e) {
        debugPrint('策展封面搜索失败 ${source.bookSourceName}: $e');
      }
    }
    _failed.add(job.key);
  }

  /// 从单源结果里挑最匹配且带封面的 URL（纯逻辑，便于测）。
  static String? pickCoverFromResults({
    required String curatedName,
    required String curatedAuthor,
    required List<Map<String, dynamic>> results,
  }) {
    return _pickCoverFromResults(
      curatedName: curatedName,
      curatedAuthor: curatedAuthor,
      results: results,
      sourceUrl: null,
    );
  }

  static String? _pickCoverFromResults({
    required String curatedName,
    required String curatedAuthor,
    required List<Map<String, dynamic>> results,
    required String? sourceUrl,
  }) {
    CuratedMatchScore? best;
    String? bestCover;
    for (final result in results) {
      final cover = result['coverUrl']?.toString().trim() ?? '';
      if (cover.isEmpty) continue;
      final match = scoreCuratedMatch(
        curatedName: curatedName,
        curatedAuthor: curatedAuthor,
        resultName: result['name']?.toString(),
        resultAuthor: result['author']?.toString(),
      );
      if (match.kind == CuratedMatchKind.none) continue;
      if (best == null || match.score > best.score) {
        best = match;
        bestCover = cover;
      }
    }
    if (bestCover == null) return null;
    // 相对路径封面无法直接用；要求像 URL
    if (!bestCover.startsWith('http://') && !bestCover.startsWith('https://')) {
      if (sourceUrl != null &&
          sourceUrl.startsWith('http') &&
          bestCover.startsWith('/')) {
        try {
          final base = Uri.parse(sourceUrl);
          return base.resolve(bestCover).toString();
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return bestCover;
  }

  static Future<List<Map<String, dynamic>>> _defaultSearcher(
    BookSource source,
    String keyword,
  ) {
    return WebBook(source).searchBook(keyword);
  }
}

typedef BookSourceSearcher = Future<List<Map<String, dynamic>>> Function(
  BookSource source,
  String keyword,
);

class _CoverJob {
  final String key;
  final CuratedBook book;
  final List<BookSource> sources;
  final void Function(String coverUrl)? onResolved;

  _CoverJob({
    required this.key,
    required this.book,
    required this.sources,
    this.onResolved,
  });
}

abstract class CoverCacheStore {
  String? read(String key);
  Future<void> write(String key, String coverUrl);
}

/// 用 StorageService.settings 持久化封面缓存（键前缀隔离）。
class StorageCoverCacheStore implements CoverCacheStore {
  static const prefix = 'curatedCover:';

  @override
  String? read(String key) {
    try {
      final v = StorageService.instance.getSetting('$prefix$key');
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  @override
  Future<void> write(String key, String coverUrl) async {
    try {
      await StorageService.instance.setSetting('$prefix$key', coverUrl);
    } catch (e) {
      debugPrint('保存策展封面缓存失败: $e');
    }
  }
}

/// 内存缓存，供单测使用。
class MemoryCoverCacheStore implements CoverCacheStore {
  final Map<String, String> data = {};

  @override
  String? read(String key) => data[key];

  @override
  Future<void> write(String key, String coverUrl) async {
    data[key] = coverUrl;
  }
}
