/// 朗读 / 显示前的正文清洗：去掉 HTML/网页残留、书源广告段与无意义空白。
///
/// 对西文友好：不整段误杀含 URL 的叙述句，不剥掉英文方括号旁白/脚注散文。
class ReaderTextCleaner {
  /// 常见书源广告/引流关键词（整段命中且行较短则丢弃）。
  static const List<String> defaultAdKeywords = [
    '请记住本站',
    '本章未完',
    '点击下一页',
    '继续阅读',
    '手机用户请',
    '最新章节',
    '天才一秒',
    '最快更新',
    '无弹窗',
    '无广告',
    '笔趣阁',
    '顶点小说',
    '飘天文学',
    // 英文站点常见引流（仍受短行规则约束）
    'please remember this site',
    'click next page',
    'continue reading',
  ];

  /// 显示用占位：正文里残留的 `<img>` 替换为此标记（不改缓存原文）。
  static const String imagePlaceholder = '【图片】';

  /// 将章节正文转为适合阅读器显示的纯文本。
  ///
  /// 书源侧 formatKeepImg 会刻意保留 `<img>`；纯文本分页路径会对全文 HTML
  /// 转义，行内真图又会牵动分栏测量，故显示时先换成短占位，缓存原文不动。
  ///
  /// [chapterTitle] 非空时，若正文开头重复了章节标题（书源正文容器常自带标题），
  /// 仅在显示层去掉首段重复，不改缓存。
  static String cleanForDisplay(
    String raw, {
    String chapterTitle = '',
  }) {
    if (raw.isEmpty) return '';
    var text = raw.replaceAll(
      RegExp(r'<img\b[^>]*/?>', caseSensitive: false),
      imagePlaceholder,
    );
    text = stripSitePageMarkerLines(text, chapterTitle: chapterTitle);
    if (chapterTitle.trim().isNotEmpty) {
      text = stripLeadingDuplicateChapterTitle(text, chapterTitle);
    }
    return text;
  }

  /// 去掉站点分页角标行，如「第1章 永夜 (第1/3页)」「(第2/3页)」「本章共3页」。
  ///
  /// 笔趣阁类站点把一章切成多页，每页页首都带这么一行。剥掉标题前缀只会剩下
  /// 「(第1/3页)」这种垃圾，所以整行去掉。合并多页正文后这些行会落在正文中间，
  /// 故不限首行——叙事句不可能整行只是一个页码角标，误伤风险极低。
  static String stripSitePageMarkerLines(
    String content, {
    String chapterTitle = '',
  }) {
    if (content.isEmpty || !content.contains(RegExp(r'[/／页]'))) {
      return content;
    }
    final lines = content.split('\n');
    final kept = <String>[];
    var removed = 0;
    for (final line in lines) {
      if (_isSitePageMarkerLine(line, chapterTitle)) {
        removed++;
        continue;
      }
      kept.add(line);
    }
    if (removed == 0) return content;
    return kept.join('\n');
  }

  static bool _isSitePageMarkerLine(String line, String chapterTitle) {
    final plain = line.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (plain.isEmpty || plain.length > 40) return false;
    if (_looksLikePageMarker(plain)) return true;
    // 「标题 + 角标」：只有角标部分是纯页码时才算页头，避免误删正文
    if (chapterTitle.trim().isEmpty) return false;
    final titleEnd = _titleAlignEnd(plain, chapterTitle);
    if (titleEnd == null) return false;
    return _looksLikePageMarker(plain.substring(titleEnd));
  }

  /// 判断一段文本是否只是页码角标（去掉外层括号后比对）。
  static bool _looksLikePageMarker(String input) {
    var s = _fullWidthAsciiToHalf(input).trim();
    for (var i = 0; i < 3 && s.length >= 2; i++) {
      final open = s[0];
      final close = s[s.length - 1];
      const pairs = {'(': ')', '[': ']', '【': '】', '（': '）'};
      if (pairs[open] == close) {
        s = s.substring(1, s.length - 1).trim();
      } else {
        break;
      }
    }
    if (s.isEmpty) return false;
    // 必须带「页」或斜杠，否则「(1)」这类分部标记也会被吃掉
    if (!s.contains('页') && !s.contains('/')) return false;
    return _pageMarkerPatterns.any((re) => re.hasMatch(s));
  }

  static final List<RegExp> _pageMarkerPatterns = [
    RegExp(r'^第?\s*\d{1,3}\s*/\s*\d{1,3}\s*页?$'),
    RegExp(r'^第\s*\d{1,3}\s*页$'),
    RegExp(r'^(本章)?共\s*\d{1,3}\s*页$'),
    RegExp(r'^page\s*\d{1,3}\s*(/\s*\d{1,3})?$', caseSensitive: false),
  ];

  /// 若正文开头首行重复了 [chapterTitle]，去掉该重复部分（仅显示用）。
  ///
  /// 只处理开头首行；章节中间同名文字不动。
  static String stripLeadingDuplicateChapterTitle(
    String content,
    String chapterTitle,
  ) {
    if (content.isEmpty || chapterTitle.trim().isEmpty) return content;

    final start = _indexAfterLeadingBlankLines(content);
    if (start >= content.length) return content;

    final firstBreak = _indexOfLineBreak(content, start);
    final firstLine = content.substring(start, firstBreak);
    final afterFirstLine = firstBreak < content.length
        ? content.substring(_indexAfterLineBreak(content, firstBreak))
        : '';

    // 整行与标题等价 → 去掉整行（最常见：标题独占首行）
    if (_linesMatchAsDuplicateTitle(firstLine, chapterTitle)) {
      return afterFirstLine;
    }

    // 首行「标题 + 正文连写」：仅当标题形如章节名时才剥前缀，避免短标题误伤叙事句
    if (_looksLikeChapterHeading(chapterTitle)) {
      final cut = _flexibleTitlePrefixEnd(firstLine, chapterTitle);
      if (cut != null && cut < firstLine.length) {
        final remainder = firstLine.substring(cut);
        if (remainder.trim().isNotEmpty) {
          // 保留首行后的换行符，避免与下一行粘连
          final lineSuffix = firstBreak < content.length
              ? content.substring(firstBreak)
              : '';
          return remainder + lineSuffix;
        }
      }
    }

    return content;
  }

  /// 将章节正文转为适合 TTS 的纯文本。
  static String cleanForTts(
    String raw, {
    List<String> adKeywords = defaultAdKeywords,
  }) {
    if (raw.isEmpty) return '';

    var text = raw;
    text = _stripHtml(text);
    text = text.replaceAll('\u00a0', ' ');
    text = text.replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // 仅去掉空占位或纯数字脚注标记，保留 [aside] / {emotion} 等英文旁白
    text = text.replaceAll(RegExp(r'\{\s*\}'), ' ');
    text = text.replaceAll(RegExp(r'\[\s*\]'), ' ');
    text = text.replaceAll(RegExp(r'\[\d{1,3}\]'), ' ');

    final lines = text.split(RegExp(r'\r?\n'));
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isAdLine(trimmed, adKeywords)) continue;
      if (trimmed.length <= 2 && RegExp(r'^[\W\d]+$').hasMatch(trimmed)) {
        continue;
      }
      kept.add(trimmed);
    }

    text = kept.join('\n');
    text = text.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static bool _linesMatchAsDuplicateTitle(String line, String chapterTitle) {
    final lineKey = _normalizeTitleKey(line);
    if (lineKey.isEmpty) return false;
    for (final titleKey in _titleCompareKeys(chapterTitle)) {
      if (lineKey == titleKey) return true;
    }
    return false;
  }

  /// 标题比较用归一化：空白、常见标点、全角 ASCII、章号中文数字等差异忽略。
  static String _normalizeTitleKey(String input) {
    var s = input.replaceAll(RegExp(r'<[^>]+>'), '');
    s = _fullWidthAsciiToHalf(s);
    s = _normalizeDiChapterNumerals(s);
    s = s.replaceAll(RegExp(r'[\s\u00a0\u3000\u200b-\u200d\ufeff]+'), '');
    s = s.replaceAll(
      RegExp(
        r'[：:·\-—_，,。.、!！?？;；:()\（\）\[\]【】《》「」『』""'
        r"''`~@#\$%^&*+=|\\/<>]",
      ),
      '',
    );
    return s.toLowerCase();
  }

  static Iterable<String> _titleCompareKeys(String chapterTitle) sync* {
    final primary = _normalizeTitleKey(chapterTitle);
    if (primary.isEmpty) return;
    yield primary;
    final withoutPrefix = primary.replaceFirst(
      RegExp(r'^(正文|默认|番外|外传|最新章节)+'),
      '',
    );
    if (withoutPrefix.isNotEmpty && withoutPrefix != primary) {
      yield withoutPrefix;
    }
  }

  static bool _looksLikeChapterHeading(String title) {
    final t = title.trim();
    if (RegExp(r'第.{1,20}章', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'chapter\s*\d+', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^\s*第?\s*\d+\s*[、.．]', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    return _normalizeTitleKey(t).length >= 12;
  }

  /// 在 [line] 开头柔性对齐 [chapterTitle]，返回应保留的正文起始下标；无法对齐则 null。
  static int? _flexibleTitlePrefixEnd(String line, String chapterTitle) {
    final aligned = _titleAlignEnd(line, chapterTitle);
    if (aligned == null) return null;
    var i = aligned;
    while (i < line.length && _isIgnorableSeparator(line[i])) {
      i++;
    }
    if (i >= line.length) return null;
    // 同行去标题：要求标题与正文之间有分隔，或正文首字像新段落起笔（避免「雪地遇袭后的…」误删）
    if (!_sameLineTitleBodyBoundaryOk(line, i)) return null;
    return i;
  }

  /// 在 [line] 开头对齐 [chapterTitle]，返回标题末字之后的下标；对不上则 null。
  ///
  /// 与 [_flexibleTitlePrefixEnd] 的区别：不跳过标题后的分隔符、不判定正文边界，
  /// 供「标题 + 页码角标」这类整行判定复用。
  static int? _titleAlignEnd(String line, String chapterTitle) {
    for (final titleKey in _titleCompareKeys(chapterTitle)) {
      if (titleKey.isEmpty) continue;
      final lineKey = _normalizeTitleKey(line);
      if (!lineKey.startsWith(titleKey) || lineKey.length <= titleKey.length) {
        continue;
      }
      final normBuf = StringBuffer();
      var i = 0;
      while (i < line.length && normBuf.length < titleKey.length) {
        final ch = line[i];
        if (_isIgnorableSeparator(ch)) {
          i++;
          continue;
        }
        normBuf.write(_normalizeTitleKey(ch));
        i++;
      }
      if (normBuf.toString() != titleKey) continue;
      return i;
    }
    return null;
  }

  static bool _sameLineTitleBodyBoundaryOk(String line, int bodyStart) {
    if (bodyStart <= 0 || bodyStart >= line.length) return false;
    final beforeBody = line.substring(0, bodyStart);
    if (RegExp(r'[\s\u3000，,。.、:：!！?？;；]$').hasMatch(beforeBody)) {
      return true;
    }
    final firstBody = line.substring(bodyStart).trimLeft();
    if (firstBody.isEmpty) return false;
    final starter = String.fromCharCode(firstBody.runes.first);
    if (RegExp(r'[a-zA-Z]').hasMatch(starter)) return true;
    return _sameLineBodyStarters.contains(starter);
  }

  /// 书源正文紧接标题后常见起笔（偏保守，不在此集合则不剥同行前缀）。
  static const Set<String> _sameLineBodyStarters = {
    '午',
    '夜',
    '天',
    '他',
    '她',
    '我',
    '你',
    '这',
    '那',
    '当',
    '此',
    '正',
    '忽',
    '却',
    '说',
    '话',
    '在',
    '从',
    '到',
    '向',
    '与',
    '和',
    '而',
    '但',
    '已',
    '又',
    '再',
    '只',
    '便',
    '于',
    '由',
    '被',
    '让',
    '把',
    '虽',
    '若',
    '如',
    '似',
    '仿',
    '两',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '百',
    '千',
    '万',
    '一',
    '二',
    '“',
    '「',
    '『',
    '【',
    '—',
    '…',
  };

  static bool _isIgnorableSeparator(String ch) {
    if (ch.trim().isEmpty) return true;
    return RegExp(r'[：:·\-—_，,。.、!！?？;；:()\（\）\[\]【】《》「」『』""'
            r"''`~@#\$%^&*+=|\\/<>]")
        .hasMatch(ch);
  }

  static String _fullWidthAsciiToHalf(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buf.writeCharCode(rune - 0xFEE0);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  static String _normalizeDiChapterNumerals(String input) {
    return input.replaceAllMapped(
      RegExp(r'第([一二三四五六七八九十百千万零〇两]+)章'),
      (match) {
        final digits = _chineseNumeralToInt(match.group(1)!);
        return digits == null ? match.group(0)! : '第$digits章';
      },
    );
  }

  static int? _chineseNumeralToInt(String chinese) {
    if (chinese.isEmpty) return null;
    const digit = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (chinese.length == 1 && digit.containsKey(chinese)) {
      return digit[chinese];
    }
    if (chinese == '十') return 10;
    if (chinese.startsWith('十') && chinese.length == 2) {
      return 10 + (digit[chinese[1]] ?? 0);
    }
    if (chinese.endsWith('十') && chinese.length == 2) {
      return (digit[chinese[0]] ?? 0) * 10;
    }
    if (chinese.length == 3 &&
        chinese[1] == '十' &&
        digit.containsKey(chinese[0]) &&
        digit.containsKey(chinese[2])) {
      return digit[chinese[0]]! * 10 + digit[chinese[2]]!;
    }
    if (chinese.endsWith('百') && chinese.length == 2) {
      return (digit[chinese[0]] ?? 0) * 100;
    }
    return null;
  }

  static int _indexAfterLeadingBlankLines(String content) {
    var i = 0;
    while (i < content.length) {
      final breakAt = _indexOfLineBreak(content, i);
      final line = content.substring(i, breakAt);
      if (line.trim().isNotEmpty) return i;
      if (breakAt >= content.length) return content.length;
      i = _indexAfterLineBreak(content, breakAt);
    }
    return content.length;
  }

  static int _indexOfLineBreak(String content, int from) {
    for (var i = from; i < content.length; i++) {
      if (content[i] == '\n' || content[i] == '\r') return i;
    }
    return content.length;
  }

  static int _indexAfterLineBreak(String content, int breakAt) {
    var i = breakAt;
    if (i < content.length && content[i] == '\r') i++;
    if (i < content.length && content[i] == '\n') i++;
    return i;
  }

  static String _stripHtml(String input) {
    var s = input;
    s = s.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return s;
  }

  static bool _isAdLine(String line, List<String> keywords) {
    final lower = line.toLowerCase();
    for (final kw in keywords) {
      if (kw.isEmpty) continue;
      if (line.contains(kw) || lower.contains(kw.toLowerCase())) {
        if (line.length < 120) return true;
      }
    }
    // 整行几乎就是链接才丢弃（避免误杀 "Visit www.example.com for maps."）
    if (RegExp(
      r'^(?:https?://|www\.)\S+$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    return false;
  }
}
