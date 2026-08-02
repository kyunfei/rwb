import 'dart:convert';

/// MyBookshelf 2.x（阅读 2.0）扁平书源 → Legado 3.x 嵌套形状。
///
/// 纯函数模块：只做格式搬运，不改规则语义、不碰存储/UI。
/// 规则字符串原样保留（analyze_rule 已兼容 2.x 选择器写法）；
/// 真正需要改写的只有 URL 层面的裸占位符、|char=、@POST body。

const _searchMap = <String, String>{
  'ruleSearchList': 'bookList',
  'ruleSearchName': 'name',
  'ruleSearchAuthor': 'author',
  'ruleSearchKind': 'kind',
  'ruleSearchIntroduce': 'intro',
  'ruleSearchCoverUrl': 'coverUrl',
  'ruleSearchLastChapter': 'lastChapter',
  'ruleSearchNoteUrl': 'bookUrl',
};

const _exploreMap = <String, String>{
  'ruleFindList': 'bookList',
  'ruleFindName': 'name',
  'ruleFindAuthor': 'author',
  'ruleFindKind': 'kind',
  'ruleFindIntroduce': 'intro',
  'ruleFindCoverUrl': 'coverUrl',
  'ruleFindLastChapter': 'lastChapter',
  'ruleFindNoteUrl': 'bookUrl',
};

const _infoMap = <String, String>{
  'ruleBookName': 'name',
  'ruleBookAuthor': 'author',
  'ruleBookKind': 'kind',
  'ruleIntroduce': 'intro',
  'ruleCoverUrl': 'coverUrl',
  'ruleBookLastChapter': 'lastChapter',
  'ruleChapterUrl': 'tocUrl',
};

const _tocMap = <String, String>{
  'ruleChapterList': 'chapterList',
  'ruleChapterName': 'chapterName',
  'ruleContentUrl': 'chapterUrl',
  'ruleChapterUrlNext': 'nextTocUrl',
};

const _contentMap = <String, String>{
  'ruleBookContent': 'content',
  'ruleContentUrlNext': 'nextContentUrl',
  'ruleBookContentReplace': 'replaceRegex',
};

/// 2.x 扁平格式独有字段（任一侧命中即可作为正向信号）。
/// 不用 enable/serialNumber/httpUserAgent：单独出现时信号太弱，易误伤。
const _flatMarkers = <String>{
  'ruleSearchUrl',
  'ruleFindUrl',
  'ruleBookContent',
  'ruleSearchList',
  'ruleChapterList',
  'ruleContentUrl',
  'ruleBookName',
  'ruleSearchName',
  'ruleChapterName',
  'ruleBookContentReplace',
};

/// 3.x 嵌套/顶层字段（出现则不当作纯 2.x）
const _legado3Markers = <String>{
  'searchUrl',
  'exploreUrl',
  'ruleSearch',
  'ruleExplore',
  'ruleBookInfo',
  'ruleToc',
  'ruleContent',
};

/// 是否为 MyBookshelf 2.x 扁平书源。
///
/// 条件：有 2.x 独有扁平字段，且没有 3.x 的嵌套/顶层字段。
/// 混合或异常输入返回 false，由调用方按 3.x 原样处理。
bool isMyBookshelf2FlatSource(Map<String, dynamic> src) {
  final hasFlat = _flatMarkers.any(src.containsKey);
  if (!hasFlat) return false;
  final hasLegado3 = _legado3Markers.any(src.containsKey);
  return !hasLegado3;
}

/// 将单个 2.x 扁平书源转为 Legado 3.x 形状的 Map。
///
/// 输入不是 2.x 时原样返回（浅拷贝顶层键）。
Map<String, dynamic> convertMyBookshelf2Source(Map<String, dynamic> src) {
  if (!isMyBookshelf2FlatSource(src)) {
    return Map<String, dynamic>.from(src);
  }

  final out = <String, dynamic>{
    'bookSourceUrl': _asString(src['bookSourceUrl']),
    'bookSourceName': _asString(src['bookSourceName']),
    'bookSourceGroup': _asString(src['bookSourceGroup']),
    'bookSourceType': _asBookSourceType(src['bookSourceType']),
    'enabled': _asBool(src['enable'], defaultValue: true),
    'enabledExplore': _nonEmpty(src['ruleFindUrl']),
    'customOrder': _asInt(src['serialNumber']),
    'weight': _asInt(src['weight']),
    'lastUpdateTime': 0,
    'respondTime': 180000,
  };

  final pattern = _asString(src['ruleBookUrlPattern']);
  if (pattern.isNotEmpty) {
    out['bookUrlPattern'] = pattern;
  }

  final loginUrl = _normalizeLoginUrl(src['loginUrl']);
  if (loginUrl != null) {
    out['loginUrl'] = loginUrl;
  }

  final header = convertMyBookshelf2Header(src['httpUserAgent']);
  if (header != null) {
    out['header'] = header;
  }

  final searchUrl = _asString(src['ruleSearchUrl']);
  if (searchUrl.isNotEmpty) {
    out['searchUrl'] = convertMyBookshelf2Url(searchUrl);
  }

  final findUrl = _asString(src['ruleFindUrl']);
  if (findUrl.isNotEmpty) {
    out['exploreUrl'] = convertMyBookshelf2Url(findUrl);
  }

  final ruleSearch = _nest(src, _searchMap);
  if (ruleSearch != null) out['ruleSearch'] = ruleSearch;

  final ruleExplore = _nest(src, _exploreMap);
  if (ruleExplore != null) out['ruleExplore'] = ruleExplore;

  final ruleBookInfo = _nest(src, _infoMap);
  if (ruleBookInfo != null) out['ruleBookInfo'] = ruleBookInfo;

  final ruleToc = _nest(src, _tocMap);
  if (ruleToc != null) out['ruleToc'] = ruleToc;

  final ruleContent = _nest(src, _contentMap);
  if (ruleContent != null) out['ruleContent'] = ruleContent;

  return out;
}

/// 若 [decoded] 为书源 Map/List，就地识别并转换 2.x 条目。
/// 返回转换后的结构与转换条数；识别不出则原样返回。
({dynamic data, int convertedCount}) adaptMyBookshelfPayload(dynamic decoded) {
  if (decoded is List) {
    var converted = 0;
    final out = <dynamic>[];
    for (final item in decoded) {
      if (item is Map) {
        final map = _stringKeyMap(item);
        if (isMyBookshelf2FlatSource(map)) {
          out.add(convertMyBookshelf2Source(map));
          converted++;
        } else {
          out.add(map);
        }
      } else {
        out.add(item);
      }
    }
    return (data: out, convertedCount: converted);
  }

  if (decoded is Map) {
    final map = _stringKeyMap(decoded);
    // 订阅聚合格式不转换
    if (map['sourceUrls'] is List) {
      return (data: map, convertedCount: 0);
    }
    if (isMyBookshelf2FlatSource(map)) {
      return (data: convertMyBookshelf2Source(map), convertedCount: 1);
    }
    return (data: map, convertedCount: 0);
  }

  return (data: decoded, convertedCount: 0);
}

/// 2.x URL → 3.x：|char=、@POST body、裸 searchKey/searchPage。
String convertMyBookshelf2Url(String raw) {
  if (raw.isEmpty) return raw;

  var u = raw;
  final opts = <String, dynamic>{};

  // 1) |char=xxx / |charset=xxx（可能夹杂其它 | 参数，只挑编码）
  final charRe = RegExp(r'\|(char|charset)=([\w-]+)', caseSensitive: false);
  u = u.replaceAllMapped(charRe, (m) {
    opts['charset'] = m.group(2);
    return '';
  });

  // 2) @ 分隔的 POST body（避开 JS / userinfo）
  if (!u.contains('<js>') && !u.contains('@js:') && u.contains('@')) {
    final split = _splitPostAt(u);
    if (split != null) {
      u = split.url;
      opts['method'] = 'POST';
      opts['body'] = split.body;
    }
  }

  // 3) 裸占位符（URL 与 body 都替换）
  u = _replacePlaceholders(u);
  if (opts['body'] is String) {
    opts['body'] = _replacePlaceholders(opts['body'] as String);
  }

  if (opts.isEmpty) return u;
  return '$u,${jsonEncode(opts)}';
}

/// httpUserAgent → header。
///
/// - 已是 JSON 串（以 `{` 开头）或 `@js:`：原样
/// - Map：编码为 JSON 串
/// - 裸 UA：包成 `{"User-Agent":"..."}`
String? convertMyBookshelf2Header(dynamic ua) {
  if (ua == null) return null;
  if (ua is Map) {
    return jsonEncode(ua.map((k, v) => MapEntry('$k', v)));
  }
  final s = '$ua'.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('@js:') || s.startsWith('{')) return s;
  return jsonEncode({'User-Agent': s});
}

String _replacePlaceholders(String value) {
  return value
      .replaceAll('searchKey', '{{key}}')
      .replaceAll('searchPage', '{{page}}');
}

/// 在合适位置按 `@` 切开 POST body；切不了返回 null。
({String url, String body})? _splitPostAt(String u) {
  final schemeIdx = u.indexOf('://');
  final String prefix;
  final String probe;
  if (schemeIdx >= 0) {
    prefix = u.substring(0, schemeIdx + 3);
    probe = u.substring(schemeIdx + 3);
  } else {
    prefix = '';
    probe = u;
  }

  if (!probe.contains('@')) return null;

  // userinfo：authority 段（第一个 / 或 ? 之前）里的 @ 不能当 POST 分隔
  final pathStart = _authorityEnd(probe);
  final searchFrom = pathStart < 0 ? 0 : pathStart;
  // 相对路径 `/...@body` 或 `?...@body`：整段可切
  final relative = u.startsWith('/') || u.startsWith('?');

  int at;
  if (relative) {
    at = probe.indexOf('@');
  } else if (pathStart >= 0) {
    at = probe.indexOf('@', searchFrom);
  } else {
    // 无 path 的绝对 URL：只有当 @ 前已有 `/`（不应发生）才切；
    // 否则视为 userinfo，不切。与「@ 须在 host 之后」一致。
    final firstAt = probe.indexOf('@');
    final before = probe.substring(0, firstAt);
    if (!before.contains('/')) return null;
    at = firstAt;
  }

  if (at < 0) return null;

  final before = probe.substring(0, at);
  final after = probe.substring(at + 1);
  // 绝对 URL 还需保证 @ 出现在 host 之后（before 含 /，或原本就是相对）
  if (!relative && !before.contains('/') && !before.contains('?')) {
    return null;
  }

  return (url: '$prefix$before', body: after);
}

/// authority 结束位置：第一个 `/` 或 `?`；没有则 -1。
int _authorityEnd(String probe) {
  final slash = probe.indexOf('/');
  final q = probe.indexOf('?');
  if (slash < 0) return q;
  if (q < 0) return slash;
  return slash < q ? slash : q;
}

Map<String, dynamic>? _nest(Map<String, dynamic> src, Map<String, String> mapping) {
  final d = <String, dynamic>{};
  for (final entry in mapping.entries) {
    final v = src[entry.key];
    if (v == null) continue;
    if (v is String && v.isEmpty) continue;
    d[entry.value] = v;
  }
  return d.isEmpty ? null : d;
}

/// loginUrl 空壳丢掉，避免误触发登录。
String? _normalizeLoginUrl(dynamic raw) {
  final lu = _asString(raw).trim();
  if (lu.isEmpty) return null;
  // 2.x 常见空壳：{"url": ""}（含换行美化形态）
  if (lu.contains('"url": ""') || lu.contains('"url":""')) return null;
  return lu;
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, item) => MapEntry('$key', item));
}

String _asString(dynamic value) {
  if (value == null) return '';
  return '$value';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value == null) return 0;
  return int.tryParse('$value') ?? 0;
}

int _asBookSourceType(dynamic value) {
  if (value is int) return value;
  final s = '$value'.trim();
  if (s.isEmpty) return 0;
  return int.tryParse(s) ?? 0;
}

bool _asBool(dynamic value, {required bool defaultValue}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  final s = '$value'.toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return defaultValue;
}

bool _nonEmpty(dynamic value) {
  if (value == null) return false;
  return '$value'.trim().isNotEmpty;
}
