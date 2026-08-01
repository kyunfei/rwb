/// 书名/作者归一化，供多源去重比对使用。
///
/// 处理：全半角、空白、常见书名包裹符（《》〈〉【】[]「」『』""''）、
/// 末尾卷/册等噪声前的主体保留（不做过度清洗以免误并）。
class SearchTextNormalizer {
  SearchTextNormalizer._();

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _wrapChars = RegExp(
    r'''[《》〈〉「」『』【】\[\]（）()""''„‟‹›]+''',
  );

  /// 归一化后的可比对键（小写）。
  static String normalize(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';

    s = _toHalfWidth(s);
    s = s.replaceAll(_wrapChars, '');
    s = s.replaceAll(_whitespace, '');
    return s.toLowerCase();
  }

  /// 书名+作者联合去重键。
  static String dedupeKey(String? name, String? author) {
    return '${normalize(name)}\u0000${normalize(author)}';
  }

  static String _toHalfWidth(String input) {
    final buf = StringBuffer();
    for (final unit in input.runes) {
      // 全角空格
      if (unit == 0x3000) {
        buf.writeCharCode(0x20);
        continue;
      }
      // 全角 ASCII 区 FF01-FF5E → 0021-007E
      if (unit >= 0xFF01 && unit <= 0xFF5E) {
        buf.writeCharCode(unit - 0xFEE0);
        continue;
      }
      buf.writeCharCode(unit);
    }
    return buf.toString();
  }
}
