/// 章节正文质量启发式检测（仅识别与提示，不涉及任何防盗破解）。
enum ChapterContentQualityKind {
  ok,
  tooShort,
  paywallHint,
  garbled,
  truncatedLikely,
}

class ChapterContentQualityResult {
  const ChapterContentQualityResult({
    required this.kind,
    required this.userMessage,
  });

  final ChapterContentQualityKind kind;
  final String userMessage;

  bool get isOk => kind == ChapterContentQualityKind.ok;

  static const okResult = ChapterContentQualityResult(
    kind: ChapterContentQualityKind.ok,
    userMessage: '',
  );
}

/// 对 [cleanedText]（已走 [ReaderTextCleaner.cleanForDisplay]）做质量分析。
ChapterContentQualityResult analyzeChapterContentQuality(
  String cleanedText, {
  String chapterTitle = '',
}) {
  final text = cleanedText.trim();
  if (text.isEmpty) {
    return const ChapterContentQualityResult(
      kind: ChapterContentQualityKind.tooShort,
      userMessage: '本章正文过短或为空，可能未完整加载',
    );
  }

  final compact = text.replaceAll(RegExp(r'\s+'), '');
  final meaningfulCount = _countMeaningfulChars(compact);
  final paywall = _containsPaywallHint(text);
  final shortChapterOk = _isLikelyIntentionallyShortChapter(chapterTitle);

  if (paywall && meaningfulCount < 400) {
    return const ChapterContentQualityResult(
      kind: ChapterContentQualityKind.paywallHint,
      userMessage: '正文疑似付费/VIP 占位，建议换源获取完整章节',
    );
  }

  if (_looksGarbled(text, compact, meaningfulCount) ||
      _looksLikeAntiTheftGarbage(compact, meaningfulCount)) {
    return const ChapterContentQualityResult(
      kind: ChapterContentQualityKind.garbled,
      userMessage: '正文疑似乱码或防盗混淆，建议换源或重新加载',
    );
  }

  if (_looksTruncated(text, compact, meaningfulCount, chapterTitle)) {
    return const ChapterContentQualityResult(
      kind: ChapterContentQualityKind.truncatedLikely,
      userMessage: '正文疑似被截断或未合并分页，建议换源获取完整正文',
    );
  }

  if (meaningfulCount < 120 && !shortChapterOk) {
    if (paywall) {
      return const ChapterContentQualityResult(
        kind: ChapterContentQualityKind.paywallHint,
        userMessage: '正文疑似付费/VIP 占位，建议换源获取完整章节',
      );
    }
    return const ChapterContentQualityResult(
      kind: ChapterContentQualityKind.tooShort,
      userMessage: '本章正文过短，可能残缺或未加载完整',
    );
  }

  return ChapterContentQualityResult.okResult;
}

int _countMeaningfulChars(String compact) {
  if (compact.isEmpty) return 0;
  final matches = RegExp(r'[\u4e00-\u9fffA-Za-z0-9]').allMatches(compact);
  return matches.length;
}

bool _containsPaywallHint(String text) {
  const hints = [
    'VIP',
    'vip',
    '付费',
    '订阅',
    '购买本章',
    '防盗',
    '本章完结后请',
    '登录后',
    '开通会员',
    '订阅本章',
    '付费章节',
    '请登录',
    '本章内容需要',
    '订阅后',
    '付费后',
    '会员专享',
    '解锁本章',
  ];
  for (final hint in hints) {
    if (text.contains(hint)) return true;
  }
  return false;
}

bool _isLikelyIntentionallyShortChapter(String chapterTitle) {
  final t = chapterTitle.trim();
  if (t.isEmpty) return false;
  const patterns = [
    '番外',
    '感言',
    '作者的话',
    '作者说',
    '后记',
    '楔子',
    '序章',
    '序言',
    '前言',
    '引言',
    '完本感言',
    '请假条',
    '停更',
  ];
  for (final p in patterns) {
    if (t.contains(p)) return true;
  }
  return false;
}

bool _looksGarbled(String text, String compact, int meaningfulCount) {
  if (compact.isEmpty) return false;

  final replacementCount = '�'.allMatches(text).length;
  if (replacementCount >= 3 &&
      replacementCount / compact.length > 0.02) {
    return true;
  }

  if (meaningfulCount >= 80) {
    final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(compact).length;
    final ratio = cjk / meaningfulCount;
    if (meaningfulCount > 200 && ratio < 0.25) {
      return true;
    }
  }

  final privateUse =
      RegExp(r'[\uE000-\uF8FF\uFFF0-\uFFFF]').allMatches(text).length;
  if (privateUse >= 5 && privateUse / compact.length > 0.01) {
    return true;
  }

  if (meaningfulCount >= 60 && _hasHeavyMeaninglessRepeat(compact)) {
    return true;
  }

  return false;
}

bool _hasHeavyMeaninglessRepeat(String compact) {
  if (compact.length < 24) return false;
  for (var len = 3; len <= 5; len++) {
    if (compact.length < len * 10) continue;
    final seen = <String, int>{};
    for (var i = 0; i <= compact.length - len; i++) {
      final slice = compact.substring(i, i + len);
      if (!RegExp(r'[\u4e00-\u9fffA-Za-z]').hasMatch(slice)) continue;
      final count = (seen[slice] ?? 0) + 1;
      seen[slice] = count;
      if (count >= 10 && (count * len) / compact.length > 0.35) {
        return true;
      }
    }
  }
  return false;
}

/// 常见「首段尚可、后面整章乱套」的防盗占位：后半段虚词极少或汉字过散。
bool _looksLikeAntiTheftGarbage(String compact, int meaningfulCount) {
  if (meaningfulCount < 180) return false;
  final cjkOnly = compact.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
  if (cjkOnly.length < 160) return false;

  // 跳过开头约 1/3（常保留可读诱饵），检查后段。
  final start = cjkOnly.length ~/ 3;
  final tail = cjkOnly.substring(start);
  if (tail.length < 120) return false;

  const particles = [
    '的', '了', '是', '在', '有', '和', '我', '他', '她', '这',
    '那', '就', '不', '人', '说', '着', '也', '都', '而', '与',
    '把', '被', '让', '给', '到', '从', '对', '为', '会', '能',
  ];
  var particleHits = 0;
  for (final p in particles) {
    particleHits += p.allMatches(tail).length;
  }
  final particleRatio = particleHits / tail.length;
  if (particleRatio < 0.018) {
    return true;
  }

  final unique = tail.split('').toSet().length;
  if (tail.length >= 220 && unique / tail.length > 0.82) {
    return true;
  }

  return false;
}

bool _looksTruncated(
  String text,
  String compact,
  int meaningfulCount,
  String chapterTitle,
) {
  const truncatePhrases = [
    '本章未完',
    '请点击下一页继续',
    '点击下一页继续',
    '请订阅',
    '订阅后继续',
    '未完待续',
  ];
  final hasPhrase = truncatePhrases.any(text.contains);
  if (hasPhrase && meaningfulCount < 250) {
    return true;
  }

  final title = chapterTitle.trim();
  final normalChapterTitle =
      RegExp(r'第[\d一二三四五六七八九十百千零两]+[章节回幕]').hasMatch(title) ||
          RegExp(r'Chapter\s+\d+', caseSensitive: false).hasMatch(title);

  if (normalChapterTitle &&
      meaningfulCount < 180 &&
      !_isLikelyIntentionallyShortChapter(title)) {
    return true;
  }

  return false;
}
