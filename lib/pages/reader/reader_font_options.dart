/// 阅读器字体选项（对照 QQ 阅读「更多字体」交互：卡片网格 + 中文名）。
///
/// 不随包商业字体（汉仪/方正需授权）。内置项用系统字体栈模拟常见风格；
/// 用户可从本机导入 .ttf/.otf（例如从 QQ 阅读已下载目录拷出来的字体）。
class ReaderFontOption {
  /// 稳定 id，空串表示系统默认。
  final String id;

  /// 展示名（中文）。
  final String label;

  /// 副标题：系统 / 风格说明 / 本地 等。
  final String subtitle;

  /// 写入 CSS `font-family` 的值；本地字体为 `"rwb-local-xxx"`。
  final String cssFamily;

  /// 预览时尽量用的字体（与 cssFamily 相同或为其第一项）。
  final String previewFamily;

  const ReaderFontOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.cssFamily,
    String? previewFamily,
  }) : previewFamily = previewFamily ?? cssFamily;

  bool get isSystemDefault => id.isEmpty;
}

/// 本地导入字体的持久化条目。
class LocalReaderFont {
  final String id;
  final String name;
  final String path;

  const LocalReaderFont({
    required this.id,
    required this.name,
    required this.path,
  });

  String get cssFamily => '"rwb-local-$id"';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};

  factory LocalReaderFont.fromJson(Map<String, dynamic> json) {
    return LocalReaderFont(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '本地字体',
      path: json['path']?.toString() ?? '',
    );
  }

  ReaderFontOption toOption() => ReaderFontOption(
        id: id,
        label: name,
        subtitle: '本地',
        cssFamily: cssFamily,
        previewFamily: cssFamily,
      );
}

/// QQ 阅读常见风格的系统映射（名称贴近用户习惯，不冒充商业字库授权）。
const List<ReaderFontOption> kReaderFontOptions = [
  ReaderFontOption(
    id: '',
    label: '系统字体',
    subtitle: '默认',
    cssFamily: '',
    previewFamily: 'sans-serif',
  ),
  ReaderFontOption(
    id: 'hei',
    label: '黑体',
    subtitle: '旗黑风',
    cssFamily:
        '"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "微软雅黑", sans-serif',
    previewFamily: '"Microsoft YaHei", "PingFang SC", sans-serif',
  ),
  ReaderFontOption(
    id: 'hei-light',
    label: '细黑',
    subtitle: '轻字重',
    cssFamily:
        '"Noto Sans CJK SC", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", sans-serif',
    previewFamily: '"PingFang SC", "Microsoft YaHei UI", sans-serif',
  ),
  ReaderFontOption(
    id: 'kai',
    label: '楷体',
    subtitle: '手写感',
    cssFamily: '"Kaiti SC", "STKaiti", "KaiTi", "楷体", "TW-Kai", serif',
    previewFamily: '"KaiTi", "STKaiti", "Kaiti SC", serif',
  ),
  ReaderFontOption(
    id: 'song',
    label: '书宋',
    subtitle: '正文宋',
    cssFamily:
        '"Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "SimSun", "宋体", serif',
    previewFamily: '"SimSun", "Songti SC", serif',
  ),
  ReaderFontOption(
    id: 'yuan',
    label: '正圆',
    subtitle: '圆润',
    cssFamily:
        '"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", "Noto Sans CJK SC", sans-serif',
    previewFamily: '"PingFang SC", "Microsoft YaHei UI", sans-serif',
  ),
  ReaderFontOption(
    id: 'fangsong',
    label: '仿宋',
    subtitle: '古风',
    cssFamily: '"STFangsong", "FangSong", "仿宋", "FangSong_GB2312", serif',
    previewFamily: '"FangSong", "STFangsong", serif',
  ),
  ReaderFontOption(
    id: 'li',
    label: '隶书',
    subtitle: '系统',
    cssFamily: '"STLiti", "LiSu", "隶书", "Baoli SC", serif',
    previewFamily: '"STLiti", "LiSu", serif',
  ),
  ReaderFontOption(
    id: 'yahei',
    label: '雅黑',
    subtitle: '清晰',
    cssFamily:
        '"Microsoft YaHei", "微软雅黑", "PingFang SC", "Noto Sans CJK SC", sans-serif',
    previewFamily: '"Microsoft YaHei", "PingFang SC", sans-serif',
  ),
  ReaderFontOption(
    id: 'serif-en',
    label: '衬线英文',
    subtitle: 'Georgia',
    cssFamily: 'Georgia, "Times New Roman", Times, serif',
  ),
  ReaderFontOption(
    id: 'sans-en',
    label: '无衬线英文',
    subtitle: '系统 UI',
    cssFamily: 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
  ),
  ReaderFontOption(
    id: 'mono',
    label: '等宽',
    subtitle: '代码风',
    cssFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace',
  ),
];

ReaderFontOption? findBuiltinFontByCss(String cssFamily) {
  for (final opt in kReaderFontOptions) {
    if (opt.cssFamily == cssFamily) return opt;
  }
  return null;
}
