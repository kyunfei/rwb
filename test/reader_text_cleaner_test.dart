import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/reader_text_cleaner.dart';

void main() {
  group('ReaderTextCleaner', () {
    test('strips html tags and scripts', () {
      const raw = '''
<script>alert(1)</script>
<p>正文<strong>加粗</strong>一段</p>
''';
      final out = ReaderTextCleaner.cleanForTts(raw);
      expect(out.contains('<'), isFalse);
      expect(out.contains('alert'), isFalse);
      expect(out.contains('正文'), isTrue);
    });

    test('drops ad-like short lines', () {
      const raw = '''
请记住本站地址
这是正常叙事内容，角色正在对话。
www.example.com
''';
      final out = ReaderTextCleaner.cleanForTts(raw);
      expect(out.contains('请记住本站'), isFalse);
      expect(out.contains('www.example.com'), isFalse);
      expect(out.contains('正常叙事'), isTrue);
    });

    test('collapses excessive whitespace', () {
      const raw = '行一   多空格\n\n\n\n行二';
      final out = ReaderTextCleaner.cleanForTts(raw);
      expect(out.contains('   '), isFalse);
      expect(out.split('\n').length, lessThanOrEqualTo(2));
    });

    test('keeps English narrative that merely mentions a URL', () {
      const raw = '''
She told him to visit www.example.com for the maps of London.
"Wait—" he said, glancing at the dash — "are you sure?"
[quietly] He closed the door.
''';
      final out = ReaderTextCleaner.cleanForTts(raw);
      expect(out, contains('www.example.com'));
      expect(out, contains('maps of London'));
      expect(out, contains('[quietly]'));
      expect(out, contains('—'));
    });

    test('drops URL-only short lines but keeps footnote digits stripped', () {
      const raw = '''
www.spam-ads.example
Chapter text continues here with a note.[1]
More prose after the marker.
''';
      final out = ReaderTextCleaner.cleanForTts(raw);
      expect(out.contains('www.spam-ads.example'), isFalse);
      expect(out, contains('Chapter text continues'));
      expect(out.contains('[1]'), isFalse);
      expect(out, contains('More prose'));
    });

    test('cleanForDisplay hides raw img markup from Standard Ebooks style content', () {
      const raw =
          'Imprint  <img alt="The Standard Ebooks logo." '
          'src="https://standardebooks.org/ebooks/charles-kingsley/hypatia/text/../images/logo.svg" '
          'epub:type="se:image.color-depth.black-on-transparent z3998:publisher-logo">  '
          'This ebook is the product of many hours of hard work by volunteers.';
      final out = ReaderTextCleaner.cleanForDisplay(raw);
      expect(out.toLowerCase().contains('<img'), isFalse);
      expect(out.contains('src='), isFalse);
      expect(out.contains('epub:type='), isFalse);
      expect(out, contains(ReaderTextCleaner.imagePlaceholder));
      expect(out, contains('Imprint'));
      expect(out, contains('volunteers'));
    });

    test('cleanForDisplay leaves Chinese line-per-paragraph prose untouched', () {
      const raw = '''
他推开门，走廊里只有风声。
「你来了。」她没有回头。
夜色沉得像一块湿布。
''';
      final out = ReaderTextCleaner.cleanForDisplay(raw);
      expect(out, equals(raw));
      expect(out.split('\n').where((l) => l.trim().isNotEmpty).length, 3);
    });

    test('cleanForDisplay leaves English prose without images untouched', () {
      const raw =
          'She told him to visit the old library before dusk.\n'
          '"Wait—" he said, glancing at the dash — "are you sure?"\n';
      final out = ReaderTextCleaner.cleanForDisplay(raw);
      expect(out, equals(raw));
      expect(out, contains('old library'));
      expect(out, contains('—'));
    });

    group('cleanForDisplay duplicate chapter title', () {
      const title = '第1章 雪地遇袭';

      test('removes identical duplicate on first line', () {
        const raw = '第1章 雪地遇袭\n午后，大周皇朝北部天空……';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '午后，大周皇朝北部天空……');
      });

      test('tolerates whitespace differences on first line', () {
        const raw = '第1章  雪地遇袭\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '正文');
      });

      test('tolerates full-width digits and punctuation', () {
        const raw = '第１章：雪地遇袭\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '正文');
      });

      test('tolerates chinese chapter numeral in title vs arabic in body line', () {
        const raw = '第1章 雪地遇袭\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: '第一章 雪地遇袭',
        );
        expect(out, '正文');
      });

      test('strips title prefix when body continues on same line', () {
        const raw = '第1章 雪地遇袭午后，大周皇朝北部天空……';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '午后，大周皇朝北部天空……');
      });

      test('does not strip when first line merely shares opening words', () {
        const raw = '第1章 雪地遇袭后的局势急转直下。\n第二段';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, raw);
      });

      test('does not strip duplicate title text in middle of chapter', () {
        const raw = '午后，大周皇朝北部天空……\n第1章 雪地遇袭\n后文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, raw);
      });

      test('catalog title with 正文 prefix still matches body line', () {
        const raw = '第1章 雪地遇袭\n正文段';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: '正文 第1章 雪地遇袭',
        );
        expect(out, '正文段');
      });
    });
  });
}
