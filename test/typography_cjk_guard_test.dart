import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/reader_typography.dart';

/// 守住「西文排版不得误伤中文正文」这条线。
///
/// 西文走的是空行分段，中文网文每行即一段且通常没有空行，一旦
/// isPredominantlyLatin 的阈值被调松，整章会塌成一段。这里用真实
/// 形态的中文正文钉住行为。
void main() {
  group('中文正文不得走西文分段', () {
    test('纯中文网文：每个非空行仍是独立一段', () {
      const content = '''
林昭抬头看了一眼天色，云层压得很低。

“你确定要走这条路？”她问。
沈行没有回答，只是把刀往腰间又紧了紧。
风从山口灌进来，带着湿冷的土腥味。''';

      final ps = ReaderTypography.splitToParagraphs(content);
      expect(ReaderTypography.isPredominantlyLatin(content), isFalse);
      // 四个非空行 → 四段；中间那个空行本身被丢弃，不参与分段，
      // 也不得像西文那样把它前后的行合并成一段。
      expect(ps.length, 4, reason: '四个非空行应得四段，不得被空行合并');
      expect(ps.first, contains('林昭抬头'));
      expect(ps.last, contains('风从山口'));
    });

    test('中文夹少量英文（书名/术语）仍判为非拉丁', () {
      const content = '''
他把那本 The Old Man and the Sea 放回书架。
旁边是一台老式 ThinkPad，屏幕还亮着。
“CPU 都快烧了。”他嘟囔了一句。''';

      expect(ReaderTypography.isPredominantlyLatin(content), isFalse);
      expect(ReaderTypography.splitToParagraphs(content).length, 3);
    });

    test('短文本不足以判定时不走西文路径', () {
      expect(ReaderTypography.isPredominantlyLatin('Yes.'), isFalse);
      expect(ReaderTypography.isPredominantlyLatin('第一章'), isFalse);
    });

    test('英文正文才按空行分段，段内软换行拼成一段', () {
      const content = '''
He had been an old man who fished alone in a skiff
in the Gulf Stream and he had gone eighty-four days
now without taking a fish.

In the first forty days a boy had been with him.''';

      expect(ReaderTypography.isPredominantlyLatin(content), isTrue);
      final ps = ReaderTypography.splitToParagraphs(content);
      expect(ps.length, 2, reason: '两个空行分隔的块应得两段');
      expect(ps.first, contains('skiff in the Gulf Stream'),
          reason: '段内软换行须拼成空格而非留下断行');
    });
  });
}
