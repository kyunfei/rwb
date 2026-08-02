import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/book.dart';
import '../../models/book_source.dart';
import '../../models/curated_bookstore.dart';
import '../../providers/search_provider.dart';
import '../source_request_failure.dart';
import 'curated_match.dart';

/// 点策展书 → 多源搜索 → 决策结果。
class CuratedBookOpenResult {
  final CuratedOpenDecision decision;
  final String? errorMessage;

  const CuratedBookOpenResult({
    required this.decision,
    this.errorMessage,
  });

  bool get isError => errorMessage != null && errorMessage!.isNotEmpty;
}

/// 复用 [SearchProvider] 的多源聚合搜索，再按 [decideCuratedOpen] 决策。
///
/// 使用独立 [SearchProvider] 实例，避免污染全局搜索页状态。
class CuratedBookOpener {
  CuratedBookOpener({
    this.searcher,
    this.maxConcurrentSearches = 8,
    this.sourceLimit = sourceLimitDefault,
    this.timeBudget = timeBudgetDefault,
  });

  /// 点书只要一个可信命中，不必像全局搜索默认 50 那样铺开候选。
  ///
  /// 取 12：约 1.5 个默认并发窗口（8 路）。质量排序后头部源通常够用；
  /// 再多只会拉长「全灭」时的排队，帮不上「打开这一本」。
  static const int sourceLimitDefault = 12;

  /// 点书交互的墙钟预算。超过后用已收到的结果决策，而不是干等到源超时。
  ///
  /// 8 秒对人仍算「稍等」；再长就接近用户体感上的「点了没反应」。
  static const Duration timeBudgetDefault = Duration(seconds: 8);

  final BookSourceSearcher? searcher;
  final int maxConcurrentSearches;
  final int sourceLimit;
  final Duration timeBudget;

  Future<CuratedBookOpenResult> open(
    CuratedBook book, {
    required List<BookSource> sources,
  }) async {
    final keyword = buildCuratedSearchKeyword(book.name, book.author);
    final searchable = sources
        .where(
          (s) =>
              s.enabled &&
              s.searchUrl != null &&
              s.searchUrl!.trim().isNotEmpty,
        )
        .toList();

    if (searchable.isEmpty) {
      return CuratedBookOpenResult(
        decision: CuratedOpenDecision.notFound(searchKeyword: keyword),
        errorMessage: '还没有可用的搜索书源。请先到「我的 → 书源管理」导入并启用书源后重试。',
      );
    }

    // 与全局搜索同一套质量排序（weight > respondTime > customOrder），只取头部若干。
    // 不调用 selectAllSources：构造时已选中 initialSources，且 selectAllSources 会写 prefs。
    final rankedUrls = SearchProvider.pickDefaultSourceUrls(
      searchable,
      limit: sourceLimit,
    );
    final byUrl = {
      for (final source in searchable) source.bookSourceUrl: source,
    };
    final scoped = <BookSource>[
      for (final url in rankedUrls)
        if (byUrl[url] != null) byUrl[url]!,
    ];

    final provider = SearchProvider(
      maxConcurrentSearches: maxConcurrentSearches,
      searcher: searcher,
      initialSources: scoped,
    );

    // 点书是最容易「点了没反应」的交互，出问题时必须能从日志看出时间花在哪一段，
    // 否则只能靠截图猜。三条日志分别对应：提前收敛 / 预算到期 / 全部源跑完。
    final clock = Stopwatch()..start();
    void mark(String what) => debugPrint(
          '⏱️ 点书[${book.name}] $what @${clock.elapsedMilliseconds}ms '
          '结果=${provider.searchResults.length}',
        );

    final gate = Completer<void>();
    // stopSearch() 内部会 notifyListeners()，而 notifyListeners 是同步派发的：
    // 它会立刻重入下面的 onChanged。若此时 gate 还没落定，onChanged 又会去调
    // stopSearch —— 真机实测这样递归了两千多层、白烧掉 21 秒，8 秒预算触发后
    // 整个回调都陷在递归里，点书要等 29 秒才出详情页。
    // 所以任何 stopSearch 之前必须先把 gate 落定，让重入在第一行就返回。
    var concluded = false;
    void conclude() {
      concluded = true;
      if (!gate.isCompleted) {
        gate.complete();
      }
    }

    void onChanged() {
      if (concluded) return;
      if (canStopCuratedOpenSearch(
        curatedName: book.name,
        curatedAuthor: book.author,
        results: provider.searchResults,
      )) {
        mark('提前收敛');
        conclude();
        // stopSearch 递增 generation：进行中的 worker 返回后丢弃写入，未启动的源不再开跑。
        provider.stopSearch();
      }
    }

    provider.addListener(onChanged);
    // search() 单源失败已隔离，几乎不整体抛错；仍吞掉异常，防止提前收敛后
    // Future.any 已结束时，未完成的 search 把错误变成未处理异常。
    Object? searchError;
    final searchSettled = provider
        .search(keyword, precisionSearch: false)
        .then<void>((_) {}, onError: (Object e, _) {
      searchError = e;
    });
    final budgetTimer = Timer(timeBudget, () {
      mark('预算到期');
      conclude();
      provider.stopSearch();
    });

    try {
      await Future.any<void>([
        searchSettled.whenComplete(() {
          mark('全部源跑完');
          conclude();
        }),
        gate.future,
      ]);
    } finally {
      mark('open 返回');
      budgetTimer.cancel();
      provider.removeListener(onChanged);
      if (provider.isLoading) {
        provider.stopSearch();
      }
    }

    if (searchError != null && provider.searchResults.isEmpty) {
      final classified = classifySourceRequestError(searchError!);
      return CuratedBookOpenResult(
        decision: CuratedOpenDecision.notFound(searchKeyword: keyword),
        errorMessage: classified.userMessage,
      );
    }

    final results = provider.searchResults;
    if (results.isEmpty) {
      final hint = provider.error;
      final message = (hint != null && hint.isNotEmpty)
          ? hint
          : '所有书源都没有找到「${book.name}」。'
              '可能是书名与站点不一致，或当前书源暂时不可用，请稍后重试或手动搜索。';
      return CuratedBookOpenResult(
        decision: CuratedOpenDecision.notFound(searchKeyword: keyword),
        errorMessage: message,
      );
    }

    final decision = decideCuratedOpen(
      curatedName: book.name,
      curatedAuthor: book.author,
      results: results,
      searchKeyword: keyword,
    );
    return CuratedBookOpenResult(decision: decision);
  }

  /// 把搜索结果 map 转成详情页需要的 bookData（与 SearchPage 对齐）。
  static Map<String, dynamic> toDetailBookData(
    Map<String, dynamic> result, {
    MediaType mediaType = MediaType.novel,
  }) {
    return <String, dynamic>{
      ...result,
      'mediaType': result['mediaType'] ?? mediaType.index,
      'originType': result['originType'] ?? BookOriginType.online.index,
      'addedTime':
          result['addedTime'] ?? DateTime.now().toIso8601String(),
    };
  }
}
