/// WebView 分页模式下与滚动模式共用的阅读位置比例换算（纯 Dart，便于单测）。
class ReaderPaginationUtils {
  ReaderPaginationUtils._();

  /// 当前页在 [0, pageCount-1] 内时，返回 0~1 的阅读进度比例。
  static double pageIndexToFraction(int pageIndex, int pageCount) {
    if (pageCount <= 1) return 0.0;
    final clamped = pageIndex.clamp(0, pageCount - 1);
    return clamped / (pageCount - 1);
  }

  /// 将 0~1 比例映射回页码（四舍五入，边界 clamp）。
  static int fractionToPageIndex(double fraction, int pageCount) {
    if (pageCount <= 1) return 0;
    final f = fraction.clamp(0.0, 1.0);
    return (f * (pageCount - 1)).round().clamp(0, pageCount - 1);
  }

  /// 按阅读比例估算正文字符偏移（用于从当前屏开始朗读）。
  static int estimateCharOffsetFromFraction(double fraction, int textLength) {
    if (textLength <= 0) return 0;
    final f = fraction.clamp(0.0, 1.0);
    return (f * textLength).floor().clamp(0, textLength - 1);
  }

  /// 从近似位置向前找到句首（中文/英文标点分句）。
  static int findSentenceStartIndex(String text, int approximateIndex) {
    if (text.isEmpty) return 0;
    var i = approximateIndex.clamp(0, text.length - 1);
    const boundaries = '。！？；!?;…\n';
    while (i > 0) {
      final ch = text[i - 1];
      if (boundaries.contains(ch)) {
        break;
      }
      i--;
    }
    while (i < text.length && (text[i] == ' ' || text[i] == '\n')) {
      i++;
    }
    return i.clamp(0, text.length);
  }
}
