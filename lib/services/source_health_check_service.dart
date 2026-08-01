import 'dart:async';

import '../models/book.dart';
import '../models/book_source.dart';
import '../models/chapter.dart';
import '../models/source_health.dart';
import 'app_logger.dart';
import 'source_engine/web_book.dart';
import 'source_health_logic.dart';
import 'storage_service.dart';

typedef HealthProgressCallback = void Function(
  int done,
  int total,
  SourceHealthResult? latest,
);

/// 书源健康检查：真实走搜索→详情→目录→正文，带并发/超时/取消。
class SourceHealthCheckService {
  final StorageService storage;

  SourceHealthCheckService({StorageService? storage})
      : storage = storage ?? StorageService.instance;

  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  bool get isCancelled => _cancelled;

  Future<List<SourceHealthResult>> checkSources(
    List<BookSource> sources, {
    String keyword = '我的',
    int concurrency = 3,
    Duration stepTimeout = const Duration(seconds: 25),
    HealthProgressCallback? onProgress,
  }) async {
    _cancelled = false;
    final total = sources.length;
    final results = <SourceHealthResult>[];
    var done = 0;
    var index = 0;

    Future<void> worker() async {
      while (true) {
        if (_cancelled) return;
        final i = index;
        if (i >= sources.length) return;
        index = i + 1;
        final source = sources[i];
        SourceHealthResult result;
        try {
          result = await checkOne(
            source,
            keyword: keyword,
            stepTimeout: stepTimeout,
          );
        } catch (e, st) {
          AppLogger.instance.error(
            LogCategory.parse,
            '健康检查异常: ${source.bookSourceName}',
            detail: '$e\n$st',
          );
          result = SourceHealthResult(
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
            status: SourceHealthStatus.failed,
            steps: [
              SourceHealthStep(
                name: kHealthStepSearch,
                success: false,
                durationMs: 0,
                error: e.toString(),
              ),
            ],
            totalMs: 0,
            failReason: e.toString(),
          );
        }
        if (_cancelled) return;
        results.add(result);
        done++;
        onProgress?.call(done, total, result);
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, 8),
      (_) => worker(),
    );
    await Future.wait(workers);

    // 保持与输入大致同序
    final order = {
      for (var i = 0; i < sources.length; i++) sources[i].bookSourceUrl: i,
    };
    results.sort((a, b) =>
        (order[a.sourceUrl] ?? 0).compareTo(order[b.sourceUrl] ?? 0));
    return results;
  }

  Future<SourceHealthResult> checkOne(
    BookSource source, {
    String keyword = '我的',
    Duration stepTimeout = const Duration(seconds: 25),
  }) async {
    if (_cancelled) {
      return judgeSourceHealth(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        steps: const [],
      );
    }

    final steps = <SourceHealthStep>[];
    final webBook = WebBook(source);
    final kw = keyword.trim().isEmpty
        ? (source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
            ? source.ruleSearch!.checkKeyWord!.trim()
            : '我的')
        : keyword.trim();

    // 1. 搜索
    String? bookUrl;
    final searchStep = await _timedStep<String>(
      kHealthStepSearch,
      stepTimeout,
      () async {
        if (source.searchUrl == null || source.searchUrl!.trim().isEmpty) {
          throw Exception('搜索地址为空');
        }
        if (source.ruleSearch == null) {
          throw Exception('搜索规则为空');
        }
        final list = await webBook.searchBook(kw);
        if (list.isEmpty) {
          throw Exception('搜索无结果');
        }
        final first = list.first;
        final url = '${first['bookUrl'] ?? ''}'.trim();
        if (url.isEmpty) {
          throw Exception('搜索结果缺少 bookUrl');
        }
        bookUrl = url;
        return '命中 ${list.length} 本，取「${first['name'] ?? ''}」';
      },
    );
    steps.add(searchStep);
    if (!searchStep.success || bookUrl == null) {
      return judgeSourceHealth(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        steps: steps,
      );
    }

    // 2. 详情
    Book? book;
    String? tocUrl;
    final detailStep = await _timedStep<String>(
      kHealthStepDetail,
      stepTimeout,
      () async {
        final info = await webBook.getBookInfo(bookUrl!);
        if (info == null) throw Exception('详情解析返回 null');
        book = info;
        tocUrl = (info.tocUrl?.trim().isNotEmpty == true)
            ? info.tocUrl!.trim()
            : bookUrl!;
        return info.name;
      },
    );
    steps.add(detailStep);
    if (!detailStep.success || book == null || tocUrl == null) {
      return judgeSourceHealth(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        steps: steps,
      );
    }

    // 3. 目录
    Chapter? chapter;
    List<Chapter>? chapters;
    String? chapterUrl;
    final tocStep = await _timedStep<String>(
      kHealthStepToc,
      stepTimeout,
      () async {
        final list = await webBook.getChapterList(tocUrl!, book: book);
        if (list.isEmpty) throw Exception('目录为空');
        final contentChapters = list.where((c) => !c.isVolume).toList();
        final pick =
            contentChapters.isNotEmpty ? contentChapters.first : list.first;
        final url = pick.url?.trim() ?? '';
        if (url.isEmpty) throw Exception('首章链接为空');
        chapters = list;
        chapter = pick;
        chapterUrl = url;
        return '共 ${list.length} 章';
      },
    );
    steps.add(tocStep);
    if (!tocStep.success ||
        chapter == null ||
        chapters == null ||
        chapterUrl == null) {
      return judgeSourceHealth(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        steps: steps,
      );
    }

    // 4. 正文
    final contentStep = await _timedStep<String>(
      kHealthStepContent,
      stepTimeout,
      () async {
        String? nextChapterUrl;
        final list = chapters!;
        final current = chapter!;
        final idx = list.indexWhere((c) => c.url == current.url);
        if (idx >= 0 && idx + 1 < list.length) {
          nextChapterUrl = list[idx + 1].url;
        }
        final content = await webBook.getContent(
          chapterUrl!,
          book: book,
          chapter: current,
          nextChapterUrl: nextChapterUrl,
        );
        if (content == null || content.trim().isEmpty) {
          throw Exception('正文为空');
        }
        return '正文 ${content.trim().length} 字';
      },
    );
    steps.add(contentStep);

    return judgeSourceHealth(
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      steps: steps,
    );
  }

  /// 一键禁用全部失效源
  Future<int> disableFailedSources(List<SourceHealthResult> results) async {
    final urls = collectFailedSourceUrls(results);
    var count = 0;
    for (final url in urls) {
      final data = storage.getBookSource(url);
      if (data == null) continue;
      if (data['enabled'] == false) continue;
      data['enabled'] = false;
      await storage.saveBookSource(data);
      count++;
    }
    return count;
  }

  Future<SourceHealthStep> _timedStep<T>(
    String name,
    Duration timeout,
    Future<T> Function() action,
  ) async {
    final sw = Stopwatch()..start();
    try {
      if (_cancelled) {
        return SourceHealthStep(
          name: name,
          success: false,
          durationMs: 0,
          error: '已取消',
        );
      }
      final value = await action().timeout(timeout);
      sw.stop();
      return SourceHealthStep(
        name: name,
        success: true,
        durationMs: sw.elapsedMilliseconds,
        detail: value is String ? value : value?.toString(),
      );
    } on TimeoutException {
      sw.stop();
      AppLogger.instance.warn(
        LogCategory.network,
        '健康检查超时: $name',
        detail: 'timeout=${timeout.inSeconds}s',
      );
      return SourceHealthStep(
        name: name,
        success: false,
        durationMs: sw.elapsedMilliseconds,
        error: '超时(${timeout.inSeconds}s)',
      );
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        LogCategory.parse,
        '健康检查步骤失败: $name',
        detail: '$e\n$st',
      );
      return SourceHealthStep(
        name: name,
        success: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }
}
