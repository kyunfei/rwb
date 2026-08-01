/// 朗读前正文清洗：去掉 HTML/网页残留、书源广告段与无意义空白。
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
    // 英文站点常见引流（仍受短行阈值约束）
    'please remember this site',
    'click next page',
    'continue reading',
  ];

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
