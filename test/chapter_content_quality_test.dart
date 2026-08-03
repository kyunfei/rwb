import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/chapter_content_quality.dart';

void main() {
  group('analyzeChapterContentQuality', () {
    test('正常长篇正文为 ok', () {
      final parts = List.generate(
        45,
        (i) => '第${i + 1}段：他走在长街上，风从巷口吹来，远处钟声响了几声。',
      );
      final body = parts.join('\n');
      final result = analyzeChapterContentQuality(body, chapterTitle: '第十章 风起');
      expect(result.kind, ChapterContentQualityKind.ok);
    });

    test('过短且无付费提示为 tooShort', () {
      const body = '很短的一小段正文。';
      final result = analyzeChapterContentQuality(body, chapterTitle: '随笔');
      expect(result.kind, ChapterContentQualityKind.tooShort);
      expect(result.userMessage, isNotEmpty);
    });

    test('短正文含 VIP/付费关键词为 paywallHint', () {
      const body = '本章为VIP章节，请登录后订阅购买本章继续阅读。';
      final result = analyzeChapterContentQuality(body, chapterTitle: '第100章');
      expect(result.kind, ChapterContentQualityKind.paywallHint);
    });

    test('替换字符过多为 garbled', () {
      final body = '�' * 50 + 'abc' * 10;
      final result = analyzeChapterContentQuality(body, chapterTitle: '第5章');
      expect(result.kind, ChapterContentQualityKind.garbled);
    });

    test('本章未完且正文极短为 truncatedLikely', () {
      const body = '开头几句。\n本章未完，请点击下一页继续阅读。';
      final result = analyzeChapterContentQuality(body, chapterTitle: '第20章 决战');
      expect(result.kind, ChapterContentQualityKind.truncatedLikely);
    });

    test('番外短章不因过短误报', () {
      const body = '作者有话说：感谢各位一路支持，下本见。';
      final result = analyzeChapterContentQuality(body, chapterTitle: '番外 感言');
      expect(result.kind, ChapterContentQualityKind.ok);
    });

    test('正常章节标题但正文过短为 truncatedLikely', () {
      const body = '只有寥寥数语，远不够一章。';
      final result = analyzeChapterContentQuality(body, chapterTitle: '第33章 夜雨');
      expect(
        result.kind,
        anyOf(
          ChapterContentQualityKind.tooShort,
          ChapterContentQualityKind.truncatedLikely,
        ),
      );
    });

    test('首段可读后半段无虚词乱字为 garbled', () {
      const head = '他推开门走进屋子，窗外的雨还没有停。';
      // 人为构造低虚词、高离散汉字串，模拟防盗混淆尾段
      const tailChars =
          '夔嬴饕餮貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏'
          '饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏'
          '饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏'
          '饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏饕餮夔嬴貔貅鲲鹏';
      final result = analyzeChapterContentQuality(
        '$head$tailChars',
        chapterTitle: '第88章 迷障',
      );
      expect(result.kind, ChapterContentQualityKind.garbled);
    });
  });
}
