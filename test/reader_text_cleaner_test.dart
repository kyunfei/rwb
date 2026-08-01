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
  });
}
