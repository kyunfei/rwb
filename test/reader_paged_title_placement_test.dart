import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/webview/reader_html_template.dart';
import 'package:mr/providers/reader_provider.dart';

/// 分页模式下章节标题必须在正文流内，不能挂在 #reader-stage 外常驻顶栏。
void main() {
  test('分页 HTML：.reader-title 在 content 内，stage 前无独立标题', () {
    final provider = ReaderProvider();
    expect(provider.showChapterTitle, isTrue);

    final html = ReaderHtmlTemplate.generate(
      content: '那一天太阳落下再也没有升起……',
      title: '第1章 永夜',
      chapterIndex: 0,
      provider: provider,
      viewWidth: 360,
      viewHeight: 640,
      isScrollMode: false,
      pageAnimDurationMs: 300,
      pageModeIndex: 0,
    );

    // stage 之前不应再有独立的 h1.reader-title（旧实现会顶栏常驻）
    final stageIdx = html.indexOf('id="reader-stage"');
    expect(stageIdx, greaterThan(0));
    final beforeStage = html.substring(0, stageIdx);
    expect(beforeStage.contains('class="reader-title"'), isFalse);

    // 标题应出现在 content-a 内部，这样才只占第 1 页
    final contentAStart = html.indexOf('id="reader-content-a"');
    final contentAEnd = html.indexOf('id="reader-content-b"');
    expect(contentAStart, greaterThan(stageIdx));
    expect(contentAEnd, greaterThan(contentAStart));
    final contentA = html.substring(contentAStart, contentAEnd);
    expect(contentA.contains('class="reader-title"'), isTrue);
    expect(contentA.contains('第1章 永夜'), isTrue);
  });
}
