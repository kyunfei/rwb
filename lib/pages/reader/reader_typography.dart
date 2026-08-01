/// 阅读器西文/中文混排辅助：脚本检测、段落切分、换行 CSS。
///
/// 中文网文常见「一行一段」；英文（及拉丁语系）纯文本常见「软换行 + 空行分段」。
/// 若一律按行切段，英文会在每个硬换行处变成独立短段，版式破碎。
class ReaderTypography {
  ReaderTypography._();

  /// 是否以拉丁字母为主（英文及其他拉丁语系正文）。
  ///
  /// 抽样前 [sampleLimit] 个 UTF-16 code unit；字母样本过少时返回 false，
  /// 保持中文默认切段，避免短标题/目录误判。
  static bool isPredominantlyLatin(String text, {int sampleLimit = 800}) {
    if (text.isEmpty) return false;
    final sample =
        text.length <= sampleLimit ? text : text.substring(0, sampleLimit);
    var latin = 0;
    var cjk = 0;
    for (final unit in sample.runes) {
      if (_isLatinLetter(unit)) {
        latin++;
      } else if (_isCjk(unit)) {
        cjk++;
      }
    }
    if (latin + cjk < 12) return false;
    return latin > cjk * 2;
  }

  static bool _isLatinLetter(int unit) {
    if (unit >= 0x41 && unit <= 0x5A) return true; // A-Z
    if (unit >= 0x61 && unit <= 0x7A) return true; // a-z
    if (unit >= 0x00C0 && unit <= 0x024F) return true; // Latin-1 / Extended
    if (unit >= 0x1E00 && unit <= 0x1EFF) return true; // Latin Extended Additional
    return false;
  }

  static bool _isCjk(int unit) {
    if (unit >= 0x3400 && unit <= 0x4DBF) return true; // Ext A
    if (unit >= 0x4E00 && unit <= 0x9FFF) return true; // CJK Unified
    if (unit >= 0xF900 && unit <= 0xFAFF) return true; // Compatibility
    if (unit >= 0x20000 && unit <= 0x2CEAF) return true; // Ext B–F（粗范围）
    return false;
  }

  /// 将正文切成段落。
  ///
  /// - 拉丁文主导：按空行分段，段内软换行拼成空格（Gutenberg TXT 等）。
  /// - 否则：沿用中文网文习惯，每个非空行一段。
  static List<String> splitToParagraphs(String content) {
    if (content.isEmpty) return const [];
    if (isPredominantlyLatin(content)) {
      return _splitLatinParagraphs(content);
    }
    return _splitLineParagraphs(content);
  }

  /// 中文习惯：非空行 → 段。
  static List<String> _splitLineParagraphs(String content) {
    return content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// 西文：空行分段；段内行用空格连接，并合并多余空白。
  static List<String> _splitLatinParagraphs(String content) {
    final blocks = content.split(RegExp(r'(?:\r?\n[ \t\u00a0]*){2,}'));
    final out = <String>[];
    for (final block in blocks) {
      final joined = block
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' ');
      final normalized = joined.replaceAll(RegExp(r'[ \t\f\v]+'), ' ').trim();
      if (normalized.isNotEmpty) out.add(normalized);
    }
    return out;
  }

  /// `.reader-p` / EPUB 段落换行策略：按词断行，仅在必要时拆超长 token。
  ///
  /// 避免 `word-break: break-word/break-all` 在单词中间切开英文。
  static const String paragraphWrapCss = '''
  word-break: normal;
  overflow-wrap: break-word;
  hyphens: auto;
  -webkit-hyphens: auto;''';

  /// 西文主导时的段首缩进（em）。用户配置为 0 时保持 0。
  ///
  /// 中文默认两全角字 ≈ 2em 对英文偏重；拉丁文封顶 1.5em。
  static double effectiveIndentEm({
    required double configuredEm,
    required bool latinDominant,
  }) {
    if (configuredEm <= 0) return 0;
    if (!latinDominant) return configuredEm;
    return configuredEm > 1.5 ? 1.5 : configuredEm;
  }

  /// 正文格式化阶段的段首缩进字符（对齐 legado 习惯，但西文不用全角空格）。
  static String contentFormatIndent({required bool latinDominant}) {
    return latinDominant ? '  ' : '\u3000\u3000';
  }
}
