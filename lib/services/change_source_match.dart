import 'search/search_text_normalizer.dart';

/// 换源列表的匹配与去重（纯函数，便于单测）。
///
/// 目标：列表里每一项都是「同一本书」在某个书源上的条目，
/// 不混入书名相似的其它小说，也不让同一源占多行。
class ChangeSourceMatch {
  ChangeSourceMatch._();

  /// 搜索关键词：只用书名。作者拼进 keyword 容易让站点返回杂书。
  static String searchKeyword(String bookName) => bookName.trim();

  /// 结果是否算「同一本书」。
  ///
  /// - 归一化书名必须全等
  /// - 目标有作者时：结果作者须全等，或结果作者为空（站点常漏作者，降权而非否决）
  /// - 目标无作者时：只按书名
  static bool isSameBook({
    required String targetName,
    required String targetAuthor,
    required String candidateName,
    required String candidateAuthor,
  }) {
    final tn = SearchTextNormalizer.normalize(targetName);
    final cn = SearchTextNormalizer.normalize(candidateName);
    if (tn.isEmpty || cn.isEmpty || tn != cn) return false;

    final ta = SearchTextNormalizer.normalize(targetAuthor);
    if (ta.isEmpty) return true;

    final ca = SearchTextNormalizer.normalize(candidateAuthor);
    return ca.isEmpty || ca == ta;
  }

  /// 从各源原始命中里筛出换源列表：每源最多一条。
  ///
  /// [hits] 元素需含 `sourceUrl`；通常还有 `name` / `author` / `lastChapter` /
  /// `sourceName`。当前源排第一，其余按书源名排序。
  static List<Map<String, dynamic>> selectSourceEntries({
    required String targetName,
    required String targetAuthor,
    required List<Map<String, dynamic>> hits,
    String? currentSourceUrl,
  }) {
    final bestBySource = <String, Map<String, dynamic>>{};

    for (final hit in hits) {
      final sourceUrl = hit['sourceUrl']?.toString() ?? '';
      if (sourceUrl.isEmpty) continue;

      final name = hit['name']?.toString() ?? '';
      final author = hit['author']?.toString() ?? '';
      if (!isSameBook(
        targetName: targetName,
        targetAuthor: targetAuthor,
        candidateName: name,
        candidateAuthor: author,
      )) {
        continue;
      }

      final existing = bestBySource[sourceUrl];
      if (existing == null ||
          _prefer(hit, existing, targetAuthor: targetAuthor)) {
        bestBySource[sourceUrl] = hit;
      }
    }

    final results = bestBySource.values.toList();
    results.sort((a, b) {
      final aUrl = a['sourceUrl']?.toString();
      final bUrl = b['sourceUrl']?.toString();
      if (aUrl == currentSourceUrl) return -1;
      if (bUrl == currentSourceUrl) return 1;
      return (a['sourceName']?.toString() ?? '')
          .compareTo(b['sourceName']?.toString() ?? '');
    });
    return results;
  }

  /// [a] 是否优于 [b]（同书同源时留哪一条）。
  static bool _prefer(
    Map<String, dynamic> a,
    Map<String, dynamic> b, {
    required String targetAuthor,
  }) {
    final ta = SearchTextNormalizer.normalize(targetAuthor);
    if (ta.isNotEmpty) {
      final aAuthor = SearchTextNormalizer.normalize(a['author']?.toString());
      final bAuthor = SearchTextNormalizer.normalize(b['author']?.toString());
      final aExact = aAuthor == ta;
      final bExact = bAuthor == ta;
      if (aExact != bExact) return aExact;
    }

    final aChapter = (a['lastChapter']?.toString() ?? '').trim();
    final bChapter = (b['lastChapter']?.toString() ?? '').trim();
    if (aChapter.isNotEmpty != bChapter.isNotEmpty) {
      return aChapter.isNotEmpty;
    }
    return false; // 同分保留先到的
  }
}
