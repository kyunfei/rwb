import '../search/search_text_normalizer.dart';

/// 策展条目与搜索结果的匹配档位（越大越好）。
enum CuratedMatchKind {
  /// 完全不相关
  none,

  /// 结果书名包含策展书名（弱）
  nameContains,

  /// 书名主体相同，但结果带常见噪声后缀（如「凡人修仙传_免费阅读」）
  nameWithNoiseSuffix,

  /// 书名完全一致（作者未对齐或不要求）
  exactName,

  /// 书名 + 作者均对齐
  exactNameAndAuthor,
}

/// 单条搜索结果相对策展条目的打分结果。
class CuratedMatchScore {
  final CuratedMatchKind kind;
  final int score;
  final String normalizedResultName;
  final String normalizedResultAuthor;

  const CuratedMatchScore({
    required this.kind,
    required this.score,
    this.normalizedResultName = '',
    this.normalizedResultAuthor = '',
  });

  static const none = CuratedMatchScore(kind: CuratedMatchKind.none, score: 0);

  bool get isHighConfidence =>
      kind == CuratedMatchKind.exactNameAndAuthor ||
      kind == CuratedMatchKind.exactName;
}

/// 打开策展书时的决策。
enum CuratedOpenAction {
  /// 高置信匹配 → 直接进详情
  openDetail,

  /// 多个候选或不确定 → 展示搜索结果让用户选
  showSearchResults,

  /// 全部源无结果
  notFound,
}

class CuratedOpenDecision {
  final CuratedOpenAction action;
  final Map<String, dynamic>? bestResult;
  final List<Map<String, dynamic>> candidates;
  final String searchKeyword;

  const CuratedOpenDecision({
    required this.action,
    this.bestResult,
    this.candidates = const [],
    this.searchKeyword = '',
  });

  factory CuratedOpenDecision.openDetail(
    Map<String, dynamic> result, {
    required String searchKeyword,
  }) {
    return CuratedOpenDecision(
      action: CuratedOpenAction.openDetail,
      bestResult: result,
      candidates: [result],
      searchKeyword: searchKeyword,
    );
  }

  factory CuratedOpenDecision.showSearchResults(
    List<Map<String, dynamic>> candidates, {
    required String searchKeyword,
  }) {
    return CuratedOpenDecision(
      action: CuratedOpenAction.showSearchResults,
      candidates: candidates,
      searchKeyword: searchKeyword,
    );
  }

  factory CuratedOpenDecision.notFound({required String searchKeyword}) {
    return CuratedOpenDecision(
      action: CuratedOpenAction.notFound,
      searchKeyword: searchKeyword,
    );
  }
}

/// 常见书名噪声后缀（归一化前匹配用的原始片段，也会在 normalize 后比对）。
const List<String> kCuratedNameNoiseSuffixes = [
  '_免费阅读',
  '-免费阅读',
  '免费阅读',
  '_全集',
  '全集',
  '_完结',
  '(完结)',
  '（完结）',
  '_全文',
  '最新章节',
  'txt下载',
  'txt',
];

/// 构建搜索关键词：优先书名；作者非空时用「书名 作者」提高命中率。
String buildCuratedSearchKeyword(String name, String author) {
  final n = name.trim();
  final a = author.trim();
  if (n.isEmpty) return a;
  if (a.isEmpty) return n;
  return '$n $a';
}

/// 对单条搜索结果相对策展书名/作者打分（纯函数）。
CuratedMatchScore scoreCuratedMatch({
  required String curatedName,
  required String curatedAuthor,
  required String? resultName,
  required String? resultAuthor,
}) {
  final wantName = SearchTextNormalizer.normalize(curatedName);
  final wantAuthor = SearchTextNormalizer.normalize(curatedAuthor);
  final gotName = SearchTextNormalizer.normalize(resultName);
  final gotAuthor = SearchTextNormalizer.normalize(resultAuthor);

  if (wantName.isEmpty || gotName.isEmpty) {
    return CuratedMatchScore(
      kind: CuratedMatchKind.none,
      score: 0,
      normalizedResultName: gotName,
      normalizedResultAuthor: gotAuthor,
    );
  }

  final authorAligned = wantAuthor.isEmpty ||
      gotAuthor.isEmpty ||
      wantAuthor == gotAuthor;

  if (gotName == wantName) {
    if (wantAuthor.isNotEmpty && gotAuthor == wantAuthor) {
      return CuratedMatchScore(
        kind: CuratedMatchKind.exactNameAndAuthor,
        score: 400,
        normalizedResultName: gotName,
        normalizedResultAuthor: gotAuthor,
      );
    }
    return CuratedMatchScore(
      kind: CuratedMatchKind.exactName,
      score: authorAligned ? 320 : 300,
      normalizedResultName: gotName,
      normalizedResultAuthor: gotAuthor,
    );
  }

  if (_isNameWithNoiseSuffix(wantName, gotName)) {
    return CuratedMatchScore(
      kind: CuratedMatchKind.nameWithNoiseSuffix,
      score: authorAligned ? 220 : 200,
      normalizedResultName: gotName,
      normalizedResultAuthor: gotAuthor,
    );
  }

  if (gotName.contains(wantName) || wantName.contains(gotName)) {
    return CuratedMatchScore(
      kind: CuratedMatchKind.nameContains,
      score: authorAligned ? 120 : 100,
      normalizedResultName: gotName,
      normalizedResultAuthor: gotAuthor,
    );
  }

  return CuratedMatchScore(
    kind: CuratedMatchKind.none,
    score: 0,
    normalizedResultName: gotName,
    normalizedResultAuthor: gotAuthor,
  );
}

/// 当前结果是否已足以提前结束点书搜索（无需再等其余源）。
///
/// 仅当 [decideCuratedOpen] 已能给出「直达详情」时返回 true。
/// [CuratedOpenAction.showSearchResults] / [CuratedOpenAction.notFound]
/// 仍可能被后续更好结果改写，故继续等。
bool canStopCuratedOpenSearch({
  required String curatedName,
  required String curatedAuthor,
  required List<Map<String, dynamic>> results,
}) {
  if (results.isEmpty) return false;
  final decision = decideCuratedOpen(
    curatedName: curatedName,
    curatedAuthor: curatedAuthor,
    results: results,
  );
  return decision.action == CuratedOpenAction.openDetail;
}

/// 根据多源搜索结果决定：直达详情 / 展示候选 / 未找到。
CuratedOpenDecision decideCuratedOpen({
  required String curatedName,
  required String curatedAuthor,
  required List<Map<String, dynamic>> results,
  String? searchKeyword,
}) {
  final keyword =
      searchKeyword ?? buildCuratedSearchKeyword(curatedName, curatedAuthor);

  if (results.isEmpty) {
    return CuratedOpenDecision.notFound(searchKeyword: keyword);
  }

  final scored = <({Map<String, dynamic> result, CuratedMatchScore match})>[];
  for (final result in results) {
    final match = scoreCuratedMatch(
      curatedName: curatedName,
      curatedAuthor: curatedAuthor,
      resultName: result['name']?.toString(),
      resultAuthor: result['author']?.toString(),
    );
    if (match.kind == CuratedMatchKind.none) continue;
    scored.add((result: result, match: match));
  }

  if (scored.isEmpty) {
    // 有结果但与策展书无关 → 仍展示搜索页，让用户自己看
    return CuratedOpenDecision.showSearchResults(
      results,
      searchKeyword: keyword,
    );
  }

  scored.sort((a, b) => b.match.score.compareTo(a.match.score));
  final best = scored.first;
  final second = scored.length > 1 ? scored[1] : null;

  // 书名+作者完全匹配 → 直达
  if (best.match.kind == CuratedMatchKind.exactNameAndAuthor) {
    return CuratedOpenDecision.openDetail(
      best.result,
      searchKeyword: keyword,
    );
  }

  // 仅书名完全匹配，且没有同等或更高分的竞争者 → 直达
  if (best.match.kind == CuratedMatchKind.exactName) {
    final contested = second != null &&
        second.match.score >= best.match.score &&
        !_sameBook(best.result, second.result);
    if (!contested) {
      return CuratedOpenDecision.openDetail(
        best.result,
        searchKeyword: keyword,
      );
    }
  }

  // 带噪声后缀：仅当唯一相关候选且作者对齐时直达，否则让用户选
  if (best.match.kind == CuratedMatchKind.nameWithNoiseSuffix) {
    final onlyOneStrong = scored.length == 1 ||
        (second != null &&
            second.match.kind.index < CuratedMatchKind.nameWithNoiseSuffix.index);
    final authorOk = SearchTextNormalizer.normalize(curatedAuthor).isEmpty ||
        best.match.normalizedResultAuthor ==
            SearchTextNormalizer.normalize(curatedAuthor);
    if (onlyOneStrong && authorOk) {
      return CuratedOpenDecision.openDetail(
        best.result,
        searchKeyword: keyword,
      );
    }
  }

  return CuratedOpenDecision.showSearchResults(
    scored.map((e) => e.result).toList(),
    searchKeyword: keyword,
  );
}

bool _sameBook(Map<String, dynamic> a, Map<String, dynamic> b) {
  final keyA = SearchTextNormalizer.dedupeKey(
    a['name']?.toString(),
    a['author']?.toString(),
  );
  final keyB = SearchTextNormalizer.dedupeKey(
    b['name']?.toString(),
    b['author']?.toString(),
  );
  return keyA == keyB && keyA != '\u0000';
}

bool _isNameWithNoiseSuffix(String wantName, String gotName) {
  if (!gotName.startsWith(wantName) || gotName.length <= wantName.length) {
    return false;
  }
  final rest = gotName.substring(wantName.length);
  // 常见分隔：_ - / | 空格（归一化后空格已去，剩符号字面）
  final stripped = rest
      .replaceFirst(RegExp(r'^[\-_/|·:：]+'), '')
      .trim();
  if (stripped.isEmpty) return true;

  final noiseNorm = kCuratedNameNoiseSuffixes
      .map(SearchTextNormalizer.normalize)
      .where((s) => s.isNotEmpty)
      .toList();
  for (final noise in noiseNorm) {
    if (stripped == noise || stripped.endsWith(noise) || noise.contains(stripped)) {
      return true;
    }
  }
  // 很短的尾巴（如「完」「新」）也视作噪声，避免过宽：仅 1~4 字且全是常见字
  if (stripped.length <= 4 &&
      RegExp(r'^(免费|阅读|完结|全集|全文|最新|章节|小说)+$').hasMatch(stripped)) {
    return true;
  }
  return false;
}
