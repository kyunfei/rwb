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
/// 每次「解析」都是对书源站点的真实搜索（HTTP + 同步 HTML 解析），成本与「打开
/// 一本书」同一量级，换来的却只是一张缩略图。真机实测（294 个书源、策展资产里
/// 497/551 本缺封面）证明它会长期占满网络与 UI isolate，把用户点书触发的
/// CuratedBookOpener 搜索从数秒拖到 31 秒——预算定时器和帧都被封面请求饿死。
///
/// 所以这里所有上限都按「宁可少几张封面，也不能拖慢交互」取值：单源超时短、
/// 每本试的源少、队列与会话总量都有硬顶、连续失败即熔断、且能被点书路径抢占。
class CuratedCoverResolver {
  CuratedCoverResolver({
    this.maxConcurrentBooks = 2,
    this.maxSourcesPerBook = 2,
    this.perSourceTimeout = const Duration(seconds: 4),
    this.maxQueueLength = 24,
    this.maxBooksPerSession = 60,
    this.failureCircuitThreshold = 6,
    BookSourceSearcher? searcher,
    CoverCacheStore? cacheStore,
  })  : _searcher = searcher ?? _defaultSearcher,
        _cache = cacheStore ?? StorageCoverCacheStore();

  /// 同时进行封面搜索的书籍数。2：兼顾首屏体感与源站压力。
  final int maxConcurrentBooks;

  /// 单本书最多尝试的书源数；找到封面即停。
  ///
  /// 2 而不是 4：串行重试的最坏耗时是 [maxSourcesPerBook] × [perSourceTimeout]，
  /// 4×12s=48s 一本书是荒谬的。权重排序后头两个源都没有封面时，第 3、4 个源
  /// 补上封面的边际概率远低于它们占用的网络成本。
  final int maxSourcesPerBook;

  /// 单源搜索超时。4s 而不是 12s：这是装饰用的缩略图，等不到就算了。
  /// 交互路径 CuratedBookOpener 给 12 个源的总墙钟预算才 8s，装饰性封面的
  /// 单源预算没有理由超过它。
  final Duration perSourceTimeout;

  /// 等待队列长度硬上限，超出直接丢弃。
  ///
  /// 页面每次 rebuild / 切 Tab 都会重新请求当前可见的书，原来的无界队列切几次
  /// Tab 就能堆几百个 job。24 约等于两屏的待办量；被丢掉的书下次真正滚进视口
  /// 时还会再来一次，不会永久丢失。
  final int maxQueueLength;

  /// 单次会话最多真正发起搜索的书籍数。
  ///
  /// 60 约等于一个分类 Tab 的全量。烧到这个数还在缺封面，说明是资产缺 coverUrl
  /// 的系统性问题，不是偶发未命中，继续搜只是白费网络。
  final int maxBooksPerSession;

  /// 连续多少个 job 拿不到封面就熔断整个会话。
  ///
  /// 6 个连续失败意味着已经白试了 6×[maxSourcesPerBook]=12 次源请求，足以说明
  /// 要么网络不通、要么这批书源整体不返回封面。此时继续排队只会持续饿死交互。
  /// 导入/启用新书源后可用 [resetCircuit] 重新开闸。
  final int failureCircuitThreshold;

  final BookSourceSearcher _searcher;
  final CoverCacheStore _cache;

  final Map<String, String> _memory = {};
  final Set<String> _inflight = {};
  final Set<String> _failed = {};
  final Queue<_CoverJob> _queue = Queue();

  /// 已在 [_queue] 里排队的 key。页面每帧都会重新 requestCovers，没有这层去重
  /// 同一本书会在队列里堆好几份（[_pump] 只在出队时才发现重复）。
  final Set<String> _queued = {};

  int _active = 0;
  int _startedJobs = 0;
  int _consecutiveFailures = 0;
  bool _circuitOpen = false;
  int _pauseDepth = 0;
  int? _lastSourceSignature;

  /// 暂停期间不启动新 job。
  bool get isPaused => _pauseDepth > 0;

  /// 熔断后本次会话彻底不再解析封面，直到 [resetCircuit]。
  bool get isCircuitOpen => _circuitOpen;

  int get queueLength => _queue.length;

  /// 本次会话已真正发起过搜索的书籍数（受 [maxBooksPerSession] 约束）。
  int get startedJobCount => _startedJobs;

  int get activeJobCount => _active;

  int get consecutiveFailureCount => _consecutiveFailures;

  /// 暂停启动新的封面搜索；点书这类交互路径进入时调用，独占网络。
  ///
  /// 用引用计数而不是 bool：重叠的 pause/resume（例如连点两本书）不会被先返回
  /// 的那一个提前放回运行态。
  void pause() {
    _pauseDepth++;
  }

  /// 与 [pause] 配对；计数归零时继续消费队列。
  void resume() {
    if (_pauseDepth == 0) return;
    _pauseDepth--;
    if (_pauseDepth == 0) _pump();
  }

  /// 重置熔断、会话配额与「这本书试过了」的记忆。
  ///
  /// 供「导入/启用了一批新书源」这类显式动作调用：上一批源不给封面的结论不该
  /// 锁死整个进程生命周期。
  void resetCircuit() {
    _circuitOpen = false;
    _consecutiveFailures = 0;
    _startedJobs = 0;
    _failed.clear();
  }

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

  /// 入队解析；已有封面 / 已失败 / 已在飞 / 已排队 / 已熔断 / 已到量则跳过。
  void enqueue({
    required CuratedBook book,
    required List<BookSource> sources,
    void Function(String coverUrl)? onResolved,
  }) {
    if (book.hasCover) return;
    if (_circuitOpen) return;
    final key = cacheKey(book.name, book.author);
    if (_memory.containsKey(key) ||
        _failed.contains(key) ||
        _inflight.contains(key) ||
        _queued.contains(key)) {
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

    final picked = _pickSources(sources);
    // 书源还没异步加载完（或全被禁用）时，既不要消耗会话配额也不要把书记成
    // 失败——否则源就绪前的几帧就能把整个会话额度烧光、还把书永久拉黑。
    if (picked.isEmpty) return;
    if (_startedJobs >= maxBooksPerSession) return;
    if (_queue.length >= maxQueueLength) return;

    _queue.add(
      _CoverJob(
        key: key,
        book: book,
        sources: picked,
        onResolved: onResolved,
      ),
    );
    _queued.add(key);
    _pump();
  }

  void prefetchVisible(
    Iterable<CuratedBook> books, {
    required List<BookSource> sources,
    void Function(String bookId, String coverUrl)? onResolved,
  }) {
    // 书源池一变（导入了一批、或启用/停用了几个）就自动开闸：熔断的结论是「这批
    // 源不给封面」，换了一批源它就不再成立，否则用户导入新源后本次会话里封面永远
    // 不会再出现。放在这里而不是让导入页去调，是因为入口有好几个（网络导入、文件
    // 导入、订阅刷新、逐个启用），每个都记得调一次不现实。
    final signature = _sourcePoolSignature(sources);
    if (signature != _lastSourceSignature) {
      _lastSourceSignature = signature;
      if (_circuitOpen || _startedJobs >= maxBooksPerSession) {
        resetCircuit();
      }
    }
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

  /// 只认「可搜索的源有没有变」，不逐个比 URL：书源列表有几百条，这个方法每批
  /// 可见书都会走一次。计数变化足以覆盖导入与启用/停用，等量替换会漏判但无害。
  static int _sourcePoolSignature(List<BookSource> sources) {
    var usable = 0;
    for (final s in sources) {
      if (s.enabled && (s.searchUrl?.trim().isNotEmpty ?? false)) usable++;
    }
    return Object.hash(sources.length, usable);
  }

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
    if (_circuitOpen || isPaused) return;
    while (_active < maxConcurrentBooks && _queue.isNotEmpty) {
      if (_startedJobs >= maxBooksPerSession) {
        // 配额用尽，队列里剩下的永远不会被执行，早点释放掉。
        _clearQueue();
        return;
      }
      final job = _queue.removeFirst();
      _queued.remove(job.key);
      if (_inflight.contains(job.key) || _memory.containsKey(job.key)) {
        continue;
      }
      _inflight.add(job.key);
      _active++;
      _startedJobs++;
      unawaited(_runJob(job).whenComplete(() {
        _inflight.remove(job.key);
        _active--;
        _pump();
      }));
    }
  }

  void _clearQueue() {
    _queue.clear();
    _queued.clear();
  }

  Future<void> _runJob(_CoverJob job) async {
    final keyword =
        buildCuratedSearchKeyword(job.book.name, job.book.author);
    for (final source in job.sources) {
      // 被点书路径抢占、或已熔断时不再开下一个请求。已经发出的那一个没法真取消
      // （WebBook 的 Future 不可中断，timeout 只是不再等它的结果），所以抢占粒度
      // 是「最多再欠一个已发出的请求」，而不是立即静默。
      // 这种中途放弃不算失败、也不写 _failed：下次这本书真正可见时可以重来。
      if (isPaused || _circuitOpen) return;
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
          _consecutiveFailures = 0;
          job.onResolved?.call(cover);
          return;
        }
      } catch (e) {
        debugPrint('策展封面搜索失败 ${source.bookSourceName}: $e');
      }
    }
    _failed.add(job.key);
    _noteJobFailure();
  }

  /// 一个 job 试完所有源都没拿到封面。连续失败到阈值就整会话停手：网络不通或
  /// 这批源不返回封面时，继续排队只是持续白烧网络和 UI isolate。
  void _noteJobFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures < failureCircuitThreshold) return;
    _circuitOpen = true;
    _clearQueue();
    debugPrint(
      '策展封面解析熔断：连续 $_consecutiveFailures 本没拿到封面，'
      '本次会话停止封面搜索（导入新书源后可 resetCircuit 重开）',
    );
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
