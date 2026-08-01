import 'search_ranker.dart';
import 'search_text_normalizer.dart';

/// 多源搜索结果归并：按【归一化书名 + 作者】去重，保留各源出处。
class SearchAggregator {
  SearchAggregator({this.keyword = ''});

  String keyword;
  final Map<String, Map<String, dynamic>> _byKey = {};
  final List<Map<String, dynamic>> _order = [];

  List<Map<String, dynamic>> get results =>
      List<Map<String, dynamic>>.unmodifiable(_order);

  void clear() {
    _byKey.clear();
    _order.clear();
  }

  /// 合并一批单源结果。每条结果应已带 sourceUrl/sourceName。
  void addAll(
    List<Map<String, dynamic>> books, {
    required String sourceUrl,
    required String sourceName,
    int sourceWeight = 0,
  }) {
    for (final book in books) {
      add(
        book,
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        sourceWeight: sourceWeight,
      );
    }
  }

  void add(
    Map<String, dynamic> book, {
    required String sourceUrl,
    required String sourceName,
    int sourceWeight = 0,
  }) {
    final name = book['name']?.toString() ?? '';
    final author = book['author']?.toString() ?? '';
    final key = SearchTextNormalizer.dedupeKey(name, author);
    // 无名结果无法可靠去重，用书源+链接兜底避免互相覆盖
    final effectiveKey = key == '\u0000'
        ? '$sourceUrl\u0000${book['bookUrl'] ?? book.hashCode}'
        : key;

    final origin = <String, dynamic>{
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'bookUrl': book['bookUrl']?.toString() ?? '',
      'coverUrl': book['coverUrl']?.toString() ?? '',
      'sourceWeight': sourceWeight,
    };

    final existing = _byKey[effectiveKey];
    if (existing == null) {
      final merged = Map<String, dynamic>.from(book);
      merged['sourceUrl'] = sourceUrl;
      merged['sourceName'] = sourceName;
      merged['sourceWeight'] = sourceWeight;
      merged['origins'] = <Map<String, dynamic>>[origin];
      merged['originCount'] = 1;
      _byKey[effectiveKey] = merged;
      _order.add(merged);
      return;
    }

    final origins = existing['origins'];
    final list = origins is List
        ? List<Map<String, dynamic>>.from(
            origins.map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    final already = list.any((o) => o['sourceUrl'] == sourceUrl);
    if (!already) {
      list.add(origin);
      existing['origins'] = list;
      existing['originCount'] = list.length;
    }

    // 多源时提升展示权重：取最大源权重；补全空字段
    final prevWeight = existing['sourceWeight'];
    final prev = prevWeight is int
        ? prevWeight
        : int.tryParse(prevWeight?.toString() ?? '') ?? 0;
    if (sourceWeight > prev) {
      existing['sourceWeight'] = sourceWeight;
    }
    _fillIfEmpty(existing, book, 'coverUrl');
    _fillIfEmpty(existing, book, 'intro');
    _fillIfEmpty(existing, book, 'lastChapter');
    _fillIfEmpty(existing, book, 'kind');
    _fillIfEmpty(existing, book, 'wordCount');

    // 主展示书源：权重更高者优先
    if (sourceWeight > prev) {
      existing['sourceUrl'] = sourceUrl;
      existing['sourceName'] = sourceName;
      existing['bookUrl'] = book['bookUrl'] ?? existing['bookUrl'];
    }
  }

  /// 按关键词匹配度 + 多源命中 + 权重重排。
  void resort() {
    SearchRanker.sortResults(_order, keyword: keyword);
  }

  static void _fillIfEmpty(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
    String key,
  ) {
    final cur = target[key]?.toString().trim() ?? '';
    if (cur.isNotEmpty) return;
    final next = source[key]?.toString().trim() ?? '';
    if (next.isNotEmpty) target[key] = source[key];
  }
}
