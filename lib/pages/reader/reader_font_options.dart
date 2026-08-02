/// 阅读器可选字体（存 CSS `font-family` 值，空串=系统默认）。
class ReaderFontOption {
  final String label;
  final String cssFamily;

  const ReaderFontOption(this.label, this.cssFamily);
}

/// 手机端可用的常见中英文字体栈。不依赖随包字体文件，走系统已装字体。
const List<ReaderFontOption> kReaderFontOptions = [
  ReaderFontOption('系统默认', ''),
  ReaderFontOption(
    '黑体',
    '"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC", '
        '"Hiragino Sans GB", "Microsoft YaHei", "微软雅黑", sans-serif',
  ),
  ReaderFontOption(
    '宋体',
    '"Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", '
        '"SimSun", "宋体", serif',
  ),
  ReaderFontOption(
    '楷体',
    '"Kaiti SC", "STKaiti", "KaiTi", "楷体", "TW-Kai", serif',
  ),
  ReaderFontOption(
    '仿宋',
    '"STFangsong", "FangSong", "仿宋", "FangSong_GB2312", serif',
  ),
  ReaderFontOption(
    '圆体',
    '"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", '
        '"Noto Sans CJK SC", sans-serif',
  ),
  ReaderFontOption(
    '雅黑',
    '"Microsoft YaHei", "微软雅黑", "PingFang SC", "Noto Sans CJK SC", sans-serif',
  ),
  ReaderFontOption('衬线英文', 'Georgia, "Times New Roman", Times, serif'),
  ReaderFontOption('无衬线英文', 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'),
  ReaderFontOption('等宽', 'ui-monospace, "Cascadia Mono", Consolas, monospace'),
];
