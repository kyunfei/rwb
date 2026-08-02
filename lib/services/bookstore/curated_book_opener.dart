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
  });

  final BookSourceSearcher? searcher;
  final int maxConcurrentSearches;

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

    final provider = SearchProvider(
      maxConcurrentSearches: maxConcurrentSearches,
      searcher: searcher,
      initialSources: searchable,
    );
    provider.selectAllSources();

    try {
      await provider.search(keyword, precisionSearch: false);
    } catch (e) {
      final classified = classifySourceRequestError(e);
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
