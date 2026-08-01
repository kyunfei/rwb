import 'search_text_normalizer.dart';

/// 搜索结果排序打分（纯函数，便于单测）。
///
/// 优先级：关键词匹配度（完全相等 > 开头匹配 > 包含）>
/// 多源命中数 > 源权重。
class SearchRanker {
  SearchRanker._();

  /// 匹配档位：越大越好。0=无匹配（精准搜索外也保留，但排后）。
  static const int matchExact = 300;
  static const int matchPrefix = 200;
  static const int matchContains = 100;
  static const int matchNone = 0;

  static int matchTier(String keyword, String? name) {
    final k = SearchTextNormalizer.normalize(keyword);
    final n = SearchTextNormalizer.normalize(name);
    if (k.isEmpty || n.isEmpty) return matchNone;
    if (n == k) return matchExact;
    if (n.startsWith(k)) return matchPrefix;
    if (n.contains(k)) return matchContains;
    return matchNone;
  }

  /// 综合分，越大越靠前。
  static int score({
    required String keyword,
    required String? name,
    required int originCount,
    required int sourceWeight,
  }) {
    final tier = matchTier(keyword, name);
    // originCount 放大，使「同等匹配下多源靠前」明显；权重作微调
    return tier * 1000000 + originCount * 1000 + sourceWeight;
  }

  /// 就地排序（高分在前）。
  static void sortResults(
    List<Map<String, dynamic>> results, {
    required String keyword,
  }) {
    results.sort((a, b) {
      final sa = score(
        keyword: keyword,
        name: a['name']?.toString(),
        originCount: _originCount(a),
        sourceWeight: _asInt(a['sourceWeight']),
      );
      final sb = score(
        keyword: keyword,
        name: b['name']?.toString(),
        originCount: _originCount(b),
        sourceWeight: _asInt(b['sourceWeight']),
      );
      return sb.compareTo(sa);
    });
  }

  static int _originCount(Map<String, dynamic> item) {
    final origins = item['origins'];
    if (origins is List && origins.isNotEmpty) return origins.length;
    return _asInt(item['originCount'], fallback: 1);
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
