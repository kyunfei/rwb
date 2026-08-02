/// 正文分页兜底：书源规则没写 nextContentUrl 时，从正文页 HTML 里推导下一分页 URL。
///
/// 背景：笔趣阁类站点普遍把一章正文切成 2~4 个分页，页脚放一个「下一页」链接。
/// 真机上用户导入的 294 个书源里只有 81 个写了 ruleContentUrlNext，其余 213 个
/// （72%）没写，这些源在分页站点上每章只能读到第一页，剩下的正文静默丢失。
///
/// 这里的全部风险在于「不能把下一章误判成下一页」——把两章正文粘在一起比少一段
/// 正文更糟。所以推导要过两道闸门，缺一不可：
///   1. 锚文本闸门 [isNextPageAnchorText]：命中「下一页」且不命中「下一章」；
///   2. URL 形状闸门 [deriveNextPageUrl]：候选必须是当前 URL 的分页变体。
/// 任何一道拿不准就返回 null，调用方退回「只读一页」的旧行为。
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 兜底翻页允许的最大页码。分页站点极少超过十几页，超出一律当作误判。
const int kMaxDerivedContentPages = 20;

/// 锚文本命中即认定为「下一页」。已去掉空白并转小写后匹配。
const List<String> _nextPageKeywords = <String>[
  '下一页',
  '下一頁',
  '下页',
  '下頁',
  'nextpage',
];

/// 锚文本命中即否决，优先级高于 [_nextPageKeywords]。
const List<String> _nextChapterKeywords = <String>[
  '下一章',
  '下章',
  '下一節',
  '下一节',
  '下節',
  '下节',
  'nextchapter',
];

/// 整页粗筛：HTML 里连「下一页」字样都没有就不必解析 DOM。
///
/// [findNextPageUrlInHtml] 会被 72% 的书源在每一章上调用，而绝大多数章节并没有
/// 分页，粗筛能避免一次同步的整页 DOM 解析（这段解析跑在主 isolate 上）。
/// 代价：页脚文案被写成 HTML 实体（`&#19979;&#19968;&#39029;`）的站点会漏筛，
/// 这类站点极少，漏筛的后果也只是退回「只读一页」的旧行为。
final RegExp _nextPageHintPattern =
    RegExp('下一页|下一頁|下页|下頁|next', caseSensitive: false);

/// 锚文本闸门：是否是「下一页」链接。
///
/// 先判否决词再判命中词，所以「下一章」「下一页(下一章)」这类文本一律返回 false。
bool isNextPageAnchorText(String? text) {
  if (text == null) return false;
  final normalized = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  if (normalized.isEmpty) return false;
  for (final keyword in _nextChapterKeywords) {
    if (normalized.contains(keyword)) return false;
  }
  for (final keyword in _nextPageKeywords) {
    if (normalized.contains(keyword)) return true;
  }
  return false;
}

/// URL 形状闸门：把 [candidateHref] 解析成绝对 URL，只有当它是 [currentUrl] 的
/// 「分页变体」时才返回该绝对 URL，否则返回 null。
///
/// 接受的条件（全部满足才接受）：
///   * scheme、host、port 完全相同；
///   * 目录路径完全相同；
///   * 文件名去掉 `_\d+` / `-\d+` 尾巴、query 去掉 `page=\d+` / `p=\d+` 之后完全相同；
///   * 页码恰好比当前页大 1，且不超过 [kMaxDerivedContentPages]。
///
/// 页码要求「恰好 +1」而不是「递增即可」：跳号的翻页写法现实中不存在，
/// 而 `chapter-12.html → chapter-14.html` 这种跳号更像换章节。
String? deriveNextPageUrl({
  required String currentUrl,
  required String candidateHref,
}) {
  final current = Uri.tryParse(currentUrl.trim());
  if (current == null || !current.hasScheme || current.host.isEmpty) {
    return null;
  }

  final absolute = _resolveHref(current, candidateHref);
  if (absolute == null) return null;
  final candidate = Uri.tryParse(absolute);
  if (candidate == null || candidate.host.isEmpty) return null;

  // 闸门 1：换站点（scheme / host / port 任一不同）一律拒绝
  if (candidate.scheme.toLowerCase() != current.scheme.toLowerCase()) {
    return null;
  }
  if (candidate.host.toLowerCase() != current.host.toLowerCase()) return null;
  if (candidate.port != current.port) return null;

  final currentPart = _splitPagedUrl(current);
  final candidatePart = _splitPagedUrl(candidate);

  // 闸门 2 + 3：目录路径、文件名主体、去掉页码后的 query 必须完全一致。
  // 换目录（回目录页）、换文件名主体（下一章）都在这里被拦掉。
  if (currentPart.identity != candidatePart.identity) return null;

  // 闸门 4：页码必须恰好递增 1，且不超过上限
  if (candidatePart.page != currentPart.page + 1) return null;
  if (candidatePart.page > kMaxDerivedContentPages) return null;

  return absolute;
}

/// 从正文页 HTML 里推导下一分页的绝对 URL，推导不出返回 null。
///
/// [currentUrl] 必须是这段 HTML 实际所在的 URL（重定向后的），
/// 相对链接按它拼接。
String? findNextPageUrlInHtml({
  required String html,
  required String currentUrl,
}) {
  if (html.isEmpty) return null;
  if (!_nextPageHintPattern.hasMatch(html)) return null;
  final dom.Document document;
  try {
    document = html_parser.parse(html);
  } catch (_) {
    return null;
  }
  for (final anchor in document.querySelectorAll('a[href]')) {
    if (!isNextPageAnchorText(anchor.text)) continue;
    final href = anchor.attributes['href'];
    if (href == null || href.trim().isEmpty) continue;
    final derived =
        deriveNextPageUrl(currentUrl: currentUrl, candidateHref: href);
    if (derived != null) return derived;
  }
  return null;
}

/// 把 href 拼成绝对 URL。
///
/// 不用 `Uri.resolve`：它会对 `%` 二次编码，破坏已编码的 URL 参数
/// （与 AnalyzeUrl.resolve 保持一致的手工拼接）。
String? _resolveHref(Uri base, String rawHref) {
  final href = rawHref.trim();
  if (href.isEmpty || href.startsWith('#')) return null;
  final lower = href.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return _stripFragment(href);
  }
  // 协议相对
  if (href.startsWith('//')) {
    return _stripFragment('${base.scheme}:$href');
  }
  // javascript: / data: / mailto: 等其它 scheme 一律拒绝
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(href)) return null;

  final authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
  if (href.startsWith('/')) {
    return _stripFragment('${base.scheme}://$authority$href');
  }
  // 只有 query 的相对引用（?page=2）保留当前路径
  if (href.startsWith('?')) {
    return _stripFragment('${base.scheme}://$authority${base.path}$href');
  }
  final basePath = base.path;
  final lastSlash = basePath.lastIndexOf('/');
  final dir = lastSlash >= 0 ? basePath.substring(0, lastSlash + 1) : '/';
  return _stripFragment('${base.scheme}://$authority$dir$href');
}

String _stripFragment(String url) {
  final hash = url.indexOf('#');
  return hash >= 0 ? url.substring(0, hash) : url;
}

/// URL 拆成「去掉页码后的身份」+「页码」。
class _PagedUrl {
  const _PagedUrl(this.identity, this.page);

  /// 目录 + 文件名主体 + 扩展名 + 去掉分页参数后的 query。
  /// 两个 URL 只有这一部分完全相同才可能是同一章的不同分页。
  final String identity;

  /// 页码，取不到时按第 1 页算。
  final int page;
}

_PagedUrl _splitPagedUrl(Uri uri) {
  final path = uri.path;
  final lastSlash = path.lastIndexOf('/');
  final dir = lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '/';
  final fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;

  final lastDot = fileName.lastIndexOf('.');
  final namePart = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  final extension = lastDot > 0 ? fileName.substring(lastDot) : '';

  // 文件名尾巴：xxx_2 / xxx-2。要求分隔符前至少有一个字符，
  // 所以纯数字文件名（/2.html）不会被当成分页。
  var stem = namePart;
  int? namePage;
  final match = RegExp(r'^(.+)[_-](\d{1,4})$').firstMatch(namePart);
  if (match != null) {
    stem = match.group(1)!;
    namePage = int.tryParse(match.group(2)!);
  }

  int? queryPage;
  final keptParams = <String>[];
  final rawQuery = uri.query;
  if (rawQuery.isNotEmpty) {
    for (final pair in rawQuery.split('&')) {
      final eq = pair.indexOf('=');
      final key = (eq >= 0 ? pair.substring(0, eq) : pair).toLowerCase();
      final value = eq >= 0 ? pair.substring(eq + 1) : '';
      if ((key == 'page' || key == 'p') &&
          RegExp(r'^\d{1,4}$').hasMatch(value)) {
        queryPage ??= int.parse(value);
        continue;
      }
      keptParams.add(pair);
    }
  }

  return _PagedUrl(
    '$dir$stem$extension?${keptParams.join('&')}',
    namePage ?? queryPage ?? 1,
  );
}
