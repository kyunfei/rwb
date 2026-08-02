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

    // 真机上 m.bingfengzw.net 的《夜无疆》第 1 章正文首行就是
    // 「第1章 永夜 (第1/3页)」，剥标题前缀只会剩下「(第1/3页)」，所以整行去掉。
    group('cleanForDisplay 站点分页角标', () {
      const title = '第1章 永夜';

      test('真机原文：标题 + 括号页码角标整行去掉', () {
        const raw = '第1章 永夜 (第1/3页)\n那一天太阳落下再也没有升起……';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '那一天太阳落下再也没有升起……');
      });

      test('标题与角标之间没有空格也去掉', () {
        const raw = '第1章 永夜(第1/3页)\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '正文');
      });

      test('全角括号与全角斜杠也去掉', () {
        const raw = '第1章 永夜（第１／３页）\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '正文');
      });

      test('裸角标行去掉：合并多页后会落在正文中间', () {
        const raw = '上页末句。\n(第2/3页)\n下页首句。';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '上页末句。\n下页首句。');
      });

      test('多页合并后每页页头都去掉', () {
        const raw = '第1章 永夜 (第1/3页)\n甲\n第1章 永夜 (第2/3页)\n乙\n'
            '第1章 永夜 (第3/3页)\n丙';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '甲\n乙\n丙');
      });

      test('本章共N页 / 第N页 也算角标', () {
        const raw = '本章共3页\n第2页\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, '正文');
      });

      test('没有标题参数时裸角标行也能去掉', () {
        const raw = '(第1/3页)\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(raw);
        expect(out, '正文');
      });

      test('不误删：正文里正常出现的页数说法', () {
        const raw = '他翻到第3页，看见一行小字。\n那本书共300页，厚得像砖。';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, raw);
      });

      test('不误删：括号里不是页码的角标', () {
        const raw = '第1章 永夜 (上)\n正文';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, raw);
      });

      test('不误删：分数式比分不带页字也不算角标', () {
        const raw = '比分是 2/3，他并不甘心。\n下一段';
        final out = ReaderTextCleaner.cleanForDisplay(
          raw,
          chapterTitle: title,
        );
        expect(out, raw);
      });
    });
  });
}
