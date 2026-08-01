import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/services/builtin_book_source_service.dart';
import 'package:mr/services/source_engine/analyze_rule.dart';

/// 本地 fixture 验证内置英文书源规则可被 AnalyzeRule 正确解析。
/// 不访问外网；真实站点结构变化需另行联网校验。
void main() {
  BookSource loadAssetSource(String fileName) {
    final file = File('assets/book_sources/$fileName');
    expect(file.existsSync(), isTrue, reason: 'missing $fileName');
    final sources =
        BuiltinBookSourceService.parseSourcesJson(file.readAsStringSync());
    expect(sources, hasLength(1));
    return sources.single;
  }

  group('BuiltinBookSourceService.parseSourcesJson', () {
    test('parses single object and array', () {
      final one = BuiltinBookSourceService.parseSourcesJson(
        '{"bookSourceUrl":"https://a.example","bookSourceName":"A"}',
      );
      expect(one.single.bookSourceName, 'A');

      final many = BuiltinBookSourceService.parseSourcesJson(
        jsonEncode([
          {'bookSourceUrl': 'https://a.example', 'bookSourceName': 'A'},
          {'bookSourceUrl': 'https://b.example', 'bookSourceName': 'B'},
        ]),
      );
      expect(many.map((e) => e.bookSourceName), ['A', 'B']);
    });
  });

  group('ppxsw.json 中文示例源', () {
    late BookSource source;

    setUp(() {
      source = loadAssetSource('ppxsw.json');
    });

    test('可被 BookSource.fromJson 完整解析，四组规则字段齐全', () {
      expect(source.bookSourceUrl, 'https://www.ppxsw.co');
      expect(source.bookSourceName, '皮皮小说网');
      expect(source.searchUrl, isNotEmpty);
      expect(source.ruleSearch, isNotNull);
      expect(source.ruleSearch!.bookList, isNotEmpty);
      expect(source.ruleSearch!.name, isNotEmpty);
      expect(source.ruleSearch!.bookUrl, isNotEmpty);
      expect(source.ruleBookInfo, isNotNull);
      expect(source.ruleBookInfo!.name, isNotEmpty);
      expect(source.ruleToc, isNotNull);
      expect(source.ruleToc!.chapterList, isNotEmpty);
      expect(source.ruleToc!.chapterName, isNotEmpty);
      expect(source.ruleContent, isNotNull);
      expect(source.ruleContent!.content, isNotEmpty);
    });

    test('搜索规则可在本地 fixture HTML 上抽出书名与链接', () {
      const html = '''
<html><body>
<ul class="txt-list">
  <li>
    <span class="s1">玄幻</span>
    <span class="s2"><a href="/book/1.html">测试小说</a></span>
    <span class="s3"><a href="/author/a">测试作者</a></span>
    <span class="s4"><a href="/book/1/100.html">第100章</a></span>
  </li>
</ul>
</body></html>
''';
      final analyzer = AnalyzeRule().setContent(
        html,
        baseUrl: 'https://www.ppxsw.co/search.html',
      );
      final books = analyzer.getElements(source.ruleSearch!.bookList!);
      expect(books, isNotEmpty);
      final first = AnalyzeRule().setContent(
        books.first,
        baseUrl: 'https://www.ppxsw.co/search.html',
      );
      expect(first.getString(source.ruleSearch!.name!), '测试小说');
      expect(
        first.getString(source.ruleSearch!.bookUrl!, isUrl: true),
        'https://www.ppxsw.co/book/1.html',
      );
    });

    test('正文规则可疑：content 与 title 使用同一选择器（章节标题）', () {
      // 钉住现状：该示例源的 ruleContent.content 指向 chapter-title，
      // 即使注入成功，真实阅读也很可能抽不到正文。勿在未校验站点前“修好”它。
      expect(source.ruleContent!.content, 'class.chapter-title@text');
      expect(source.ruleContent!.title, 'class.chapter-title@text');
      expect(source.ruleContent!.content, source.ruleContent!.title);
    });
  });

  group('Project Gutenberg fixtures', () {
    late BookSource source;

    setUp(() {
      source = loadAssetSource('project_gutenberg.json');
    });

    test('search rules extract title/author/url', () {
      const html = '''
<html><body>
<ul>
  <li class="booklink">
    <a class="link" href="/ebooks/1342">
      <span class="title">Pride and Prejudice</span>
      <span class="subtitle">Jane Austen</span>
      <span class="extra">English</span>
      <img class="cover-thumb" src="/cache/epub/1342/pg1342.cover.medium.jpg"/>
    </a>
  </li>
  <li class="booklink">
    <a class="link" href="/ebooks/11">
      <span class="title">Alice's Adventures in Wonderland</span>
      <span class="subtitle">Lewis Carroll</span>
    </a>
  </li>
</ul>
</body></html>
''';
      final analyzer = AnalyzeRule().setContent(
        html,
        baseUrl: 'https://www.gutenberg.org/ebooks/search/?query=pride',
      );
      final books = analyzer.getElements(source.ruleSearch!.bookList!);
      expect(books, hasLength(2));

      final first = AnalyzeRule().setContent(
        books.first,
        baseUrl: 'https://www.gutenberg.org/ebooks/search/?query=pride',
      );
      expect(first.getString(source.ruleSearch!.name!), 'Pride and Prejudice');
      expect(first.getString(source.ruleSearch!.author!), 'Jane Austen');
      expect(
        first.getString(source.ruleSearch!.bookUrl!, isUrl: true),
        'https://www.gutenberg.org/ebooks/1342',
      );
    });

    test('bookInfo prefers plain-text tocUrl', () {
      const html = '''
<html><body>
  <h1>Pride and Prejudice</h1>
  <a itemprop="creator" href="/ebooks/author/68">Jane Austen</a>
  <span itemprop="description">A novel of manners.</span>
  <img class="cover" src="/cache/epub/1342/pg1342.cover.medium.jpg"/>
  <a href="/files/1342/1342-0.txt" type="text/plain; charset=utf-8">Plain Text UTF-8</a>
  <a href="/files/1342/1342-h/1342-h.htm" type="text/html">Read online</a>
</body></html>
''';
      final analyzer = AnalyzeRule().setContent(
        html,
        baseUrl: 'https://www.gutenberg.org/ebooks/1342',
      );
      expect(analyzer.getString(source.ruleBookInfo!.name!), 'Pride and Prejudice');
      expect(analyzer.getString(source.ruleBookInfo!.author!), 'Jane Austen');
      expect(
        analyzer.getString(source.ruleBookInfo!.tocUrl!, isUrl: true),
        'https://www.gutenberg.org/files/1342/1342-0.txt',
      );
    });

    test('content rule reads plain text body', () {
      const text = '''
The Project Gutenberg eBook of Pride and Prejudice

*** START OF THE PROJECT GUTENBERG EBOOK PRIDE AND PREJUDICE ***

It is a truth universally acknowledged.

*** END OF THE PROJECT GUTENBERG EBOOK PRIDE AND PREJUDICE ***
''';
      final analyzer = AnalyzeRule().setContent(text);
      final content = analyzer.getString(source.ruleContent!.content!);
      expect(content, contains('truth universally acknowledged'));
    });
  });

  group('English Wikisource fixtures', () {
    late BookSource source;

    setUp(() {
      source = loadAssetSource('english_wikisource.json');
    });

    test('search rules extract heading links', () {
      const html = '''
<html><body>
<ul class="mw-search-results">
  <li class="mw-search-result">
    <div class="mw-search-result-heading">
      <a href="/wiki/Pride_and_Prejudice">Pride and Prejudice</a>
    </div>
    <div class="searchresult">A novel by Jane Austen...</div>
  </li>
</ul>
</body></html>
''';
      final analyzer = AnalyzeRule().setContent(
        html,
        baseUrl: 'https://en.wikisource.org/w/index.php?search=pride',
      );
      final books = analyzer.getElements(source.ruleSearch!.bookList!);
      expect(books, hasLength(1));
      final item = AnalyzeRule().setContent(
        books.first,
        baseUrl: 'https://en.wikisource.org/w/index.php?search=pride',
      );
      expect(
        item.getString(source.ruleSearch!.name!),
        'Pride and Prejudice',
      );
      expect(
        item.getString(source.ruleSearch!.bookUrl!, isUrl: true),
        'https://en.wikisource.org/wiki/Pride_and_Prejudice',
      );
    });

    test('toc and content rules on chapter page', () {
      const tocHtml = '''
<html><body>
  <h1 id="firstHeading">Pride and Prejudice</h1>
  <div id="mw-content-text">
    <p>A novel of manners.</p>
    <ul>
      <li><a href="/wiki/Pride_and_Prejudice/Chapter_1">Chapter 1</a></li>
      <li><a href="/wiki/Pride_and_Prejudice/Chapter_2">Chapter 2</a></li>
    </ul>
  </div>
</body></html>
''';
      final tocAnalyzer = AnalyzeRule().setContent(
        tocHtml,
        baseUrl: 'https://en.wikisource.org/wiki/Pride_and_Prejudice',
      );
      final chapters =
          tocAnalyzer.getElements(source.ruleToc!.chapterList!);
      expect(chapters.length, greaterThanOrEqualTo(2));
      final ch0 = AnalyzeRule().setContent(
        chapters.first,
        baseUrl: 'https://en.wikisource.org/wiki/Pride_and_Prejudice',
      );
      expect(ch0.getString(source.ruleToc!.chapterName!), 'Chapter 1');
      expect(
        ch0.getString(source.ruleToc!.chapterUrl!, isUrl: true),
        'https://en.wikisource.org/wiki/Pride_and_Prejudice/Chapter_1',
      );

      const chapterHtml = '''
<html><body>
  <div id="mw-content-text">
    <p>It is a truth universally acknowledged, that a single man...</p>
    <span class="mw-editsection">[edit]</span>
  </div>
</body></html>
''';
      final contentAnalyzer = AnalyzeRule().setContent(chapterHtml);
      final body = contentAnalyzer.getString(source.ruleContent!.content!);
      expect(body, contains('truth universally acknowledged'));
    });
  });

  group('Standard Ebooks fixtures', () {
    late BookSource source;

    setUp(() {
      source = loadAssetSource('standard_ebooks.json');
    });

    test('search rules extract catalog cards', () {
      const html = '''
<html><body>
<ol class="ebooks-list">
  <li>
    <p class="title"><a href="/ebooks/jane-austen/pride-and-prejudice">Pride and Prejudice</a></p>
    <p class="author"><a href="/ebooks?query=Jane+Austen">Jane Austen</a></p>
    <img src="/images/covers/pride-and-prejudice.jpg"/>
    <p class="description">A witty novel of manners.</p>
  </li>
</ol>
</body></html>
''';
      final analyzer = AnalyzeRule().setContent(
        html,
        baseUrl: 'https://standardebooks.org/ebooks?query=pride',
      );
      final books = analyzer.getElements(source.ruleSearch!.bookList!);
      expect(books, hasLength(1));
      final item = AnalyzeRule().setContent(
        books.first,
        baseUrl: 'https://standardebooks.org/ebooks?query=pride',
      );
      expect(item.getString(source.ruleSearch!.name!), 'Pride and Prejudice');
      expect(item.getString(source.ruleSearch!.author!), 'Jane Austen');
      expect(
        item.getString(source.ruleSearch!.bookUrl!, isUrl: true),
        'https://standardebooks.org/ebooks/jane-austen/pride-and-prejudice',
      );
    });

    test('toc links and article content', () {
      const tocHtml = '''
<html><body>
  <h1>Pride and Prejudice</h1>
  <nav id="toc">
    <ol>
      <li><a href="/ebooks/jane-austen/pride-and-prejudice/text/chapter-1">Chapter I</a></li>
      <li><a href="/ebooks/jane-austen/pride-and-prejudice/text/chapter-2">Chapter II</a></li>
    </ol>
  </nav>
  <a href="/ebooks/jane-austen/pride-and-prejudice/text">Read online</a>
</body></html>
''';
      final info = AnalyzeRule().setContent(
        tocHtml,
        baseUrl:
            'https://standardebooks.org/ebooks/jane-austen/pride-and-prejudice',
      );
      expect(
        info.getString(source.ruleBookInfo!.tocUrl!, isUrl: true),
        'https://standardebooks.org/ebooks/jane-austen/pride-and-prejudice/text',
      );
      final chapters = info.getElements(source.ruleToc!.chapterList!);
      expect(chapters, hasLength(2));

      const chapterHtml = '''
<html><body>
  <article>
    <h2>Chapter I</h2>
    <p>It is a truth universally acknowledged...</p>
  </article>
</body></html>
''';
      final content = AnalyzeRule()
          .setContent(chapterHtml)
          .getString(source.ruleContent!.content!);
      expect(content, contains('truth universally acknowledged'));
    });
  });
}
