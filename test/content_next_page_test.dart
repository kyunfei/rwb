import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/models/rules/content_rule.dart';
import 'package:mr/services/source_engine/content_next_page.dart';
import 'package:mr/services/source_engine/web_book.dart';

/// 正文分页兜底的两道闸门。
///
/// 这些用例的重点不是「能翻页」，而是「不会把下一章当成下一页」——
/// 粘章比丢正文更糟，所以拒绝用例比接受用例更重要。
void main() {
  const chapterUrl = 'https://m.bingfengzw.net/book/217539/83685740.html';

  group('deriveNextPageUrl 接受：确实是同一章的分页变体', () {
    test('首页 → _2（真机上《夜无疆》的写法）', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: '/book/217539/83685740_2.html',
        ),
        'https://m.bingfengzw.net/book/217539/83685740_2.html',
      );
    });

    test('_2 → _3', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_2.html',
          candidateHref: '83685740_3.html',
        ),
        'https://m.bingfengzw.net/book/217539/83685740_3.html',
      );
    });

    test('?page=1 → ?page=2', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/read.php?id=99&page=1',
          candidateHref: '/read.php?id=99&page=2',
        ),
        'https://x.example/read.php?id=99&page=2',
      );
    });

    test('无 page 参数 → ?page=2（隐式第 1 页）', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/read.php?id=99',
          candidateHref: 'read.php?id=99&page=2',
        ),
        'https://x.example/read.php?id=99&page=2',
      );
    });

    test('?p=2 → ?p=3', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/c/1.html?p=2',
          candidateHref: '/c/1.html?p=3',
        ),
        'https://x.example/c/1.html?p=3',
      );
    });

    test('短横线分页 -2 → -3', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/book/1/ch-2.html',
          candidateHref: 'ch-3.html',
        ),
        'https://x.example/book/1/ch-3.html',
      );
    });

    test('绝对 URL 形式的候选也接受', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref:
              'https://m.bingfengzw.net/book/217539/83685740_2.html',
        ),
        'https://m.bingfengzw.net/book/217539/83685740_2.html',
      );
    });

    test('候选带 fragment 时截掉 fragment', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: '83685740_2.html#content',
        ),
        'https://m.bingfengzw.net/book/217539/83685740_2.html',
      );
    });
  });

  group('deriveNextPageUrl 拒绝：防止把下一章粘进来', () {
    test('指向另一章（文件名主体不同）', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: '/book/217539/83685741.html',
        ),
        isNull,
      );
    });

    test('最后一页的「下一页」指向下一章的第 1 页', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_3.html',
          candidateHref: '83685741.html',
        ),
        isNull,
      );
    });

    test('最后一页的「下一页」指向下一章的分页变体', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_3.html',
          candidateHref: '83685741_2.html',
        ),
        isNull,
      );
    });

    test('指向目录页', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: '/book/217539/',
        ),
        isNull,
      );
    });

    test('指向上级目录里的其它页面', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: '/book/217540/83685740_2.html',
        ),
        isNull,
      );
    });

    test('换 host', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref:
              'https://evil.example/book/217539/83685740_2.html',
        ),
        isNull,
      );
    });

    test('换 scheme', () {
      expect(
        deriveNextPageUrl(
          currentUrl: chapterUrl,
          candidateHref: 'http://m.bingfengzw.net/book/217539/83685740_2.html',
        ),
        isNull,
      );
    });

    test('换端口', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example:8443/c/1.html',
          candidateHref: 'https://x.example:9000/c/1_2.html',
        ),
        isNull,
      );
    });

    test('页码不增：_2 → _2', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_2.html',
          candidateHref: '83685740_2.html',
        ),
        isNull,
      );
    });

    test('页码倒退：_2 → _1', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_2.html',
          candidateHref: '83685740_1.html',
        ),
        isNull,
      );
    });

    test('页码跳号：_2 → _4', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_2.html',
          candidateHref: '83685740_4.html',
        ),
        isNull,
      );
    });

    test('页码超过上限 $kMaxDerivedContentPages', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/c/ch-$kMaxDerivedContentPages.html',
          candidateHref: 'ch-${kMaxDerivedContentPages + 1}.html',
        ),
        isNull,
      );
    });

    test('纯数字文件名不当作分页：/2.html → /3.html', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/book/1/2.html',
          candidateHref: '3.html',
        ),
        isNull,
      );
    });

    test('query 里除页码外的参数不同', () {
      expect(
        deriveNextPageUrl(
          currentUrl: 'https://x.example/read.php?id=99&page=1',
          candidateHref: '/read.php?id=100&page=2',
        ),
        isNull,
      );
    });

    test('javascript: / # / 空 href', () {
      expect(
        deriveNextPageUrl(
            currentUrl: chapterUrl, candidateHref: 'javascript:next()'),
        isNull,
      );
      expect(
        deriveNextPageUrl(currentUrl: chapterUrl, candidateHref: '#next'),
        isNull,
      );
      expect(
        deriveNextPageUrl(currentUrl: chapterUrl, candidateHref: '   '),
        isNull,
      );
    });

    test('当前 URL 不是合法绝对 URL 时不推导', () {
      expect(
        deriveNextPageUrl(
          currentUrl: '/book/217539/83685740.html',
          candidateHref: '83685740_2.html',
        ),
        isNull,
      );
    });
  });

  group('isNextPageAnchorText 锚文本闸门', () {
    test('命中下一页的各种写法', () {
      expect(isNextPageAnchorText('下一页'), isTrue);
      expect(isNextPageAnchorText('下页'), isTrue);
      expect(isNextPageAnchorText('下一頁'), isTrue);
      expect(isNextPageAnchorText('Next Page'), isTrue);
      expect(isNextPageAnchorText('  下一页 >  '), isTrue);
    });

    test('下一章一律否决', () {
      expect(isNextPageAnchorText('下一章'), isFalse);
      expect(isNextPageAnchorText('下章'), isFalse);
      expect(isNextPageAnchorText('下一節'), isFalse);
      expect(isNextPageAnchorText('Next Chapter'), isFalse);
    });

    test('同时出现时以否决为准', () {
      expect(isNextPageAnchorText('下一页(下一章)'), isFalse);
    });

    test('无关文本', () {
      expect(isNextPageAnchorText('上一页'), isFalse);
      expect(isNextPageAnchorText('目录'), isFalse);
      expect(isNextPageAnchorText(''), isFalse);
      expect(isNextPageAnchorText(null), isFalse);
    });
  });

  group('findNextPageUrlInHtml 两道闸门联合', () {
    test('页脚「下一页」被采纳', () {
      const html = '''
        <html><body>
          <div id="content">正文第一页……</div>
          <div class="page">
            <a href="/book/217539/index.html">目录</a>
            <a href="/book/217539/83685740_2.html">下一页</a>
            <a href="/book/217539/83685741.html">下一章</a>
          </div>
        </body></html>
      ''';
      expect(
        findNextPageUrlInHtml(html: html, currentUrl: chapterUrl),
        'https://m.bingfengzw.net/book/217539/83685740_2.html',
      );
    });

    test('只有「下一章」时不翻页', () {
      const html = '''
        <html><body>
          <div id="content">正文最后一页……</div>
          <a href="/book/217539/83685741.html">下一章</a>
        </body></html>
      ''';
      expect(
        findNextPageUrlInHtml(
          html: html,
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_3.html',
        ),
        isNull,
      );
    });

    test('最后一页的「下一页」实际指向下一章 → 被形状闸门拦住', () {
      const html = '''
        <html><body>
          <div id="content">正文最后一页……</div>
          <a href="/book/217539/83685741.html">下一页</a>
        </body></html>
      ''';
      expect(
        findNextPageUrlInHtml(
          html: html,
          currentUrl: 'https://m.bingfengzw.net/book/217539/83685740_3.html',
        ),
        isNull,
      );
    });

    test('「下一页」被标成 JS 时不翻页', () {
      const html = '''
        <html><body><a href="javascript:void(0)" onclick="go()">下一页</a></body></html>
      ''';
      expect(
        findNextPageUrlInHtml(html: html, currentUrl: chapterUrl),
        isNull,
      );
    });

    test('没有任何链接时返回 null', () {
      expect(
        findNextPageUrlInHtml(
          html: '<html><body><div id="content">正文</div></body></html>',
          currentUrl: chapterUrl,
        ),
        isNull,
      );
      expect(findNextPageUrlInHtml(html: '', currentUrl: chapterUrl), isNull);
    });
  });

  group('三页链路：逐页重新推导，最后一页自然收敛', () {
    // 模拟《夜无疆》第 1 章：3 个分页，前两页页脚有「下一页」，
    // 第 3 页的「下一页」指向下一章（站点常见写法）。
    String pageHtml(String nextHref, String nextText) => '''
      <html><body>
        <div id="content">正文</div>
        <a href="$nextHref">$nextText</a>
      </body></html>
    ''';

    test('第 1、2 页各推导出一个分页，第 3 页停止', () {
      const p1 = 'https://m.bingfengzw.net/book/217539/83685740.html';
      const p2 = 'https://m.bingfengzw.net/book/217539/83685740_2.html';
      const p3 = 'https://m.bingfengzw.net/book/217539/83685740_3.html';

      final visited = <String>[p1];
      final pages = <String, String>{
        p1: pageHtml('83685740_2.html', '下一页'),
        p2: pageHtml('83685740_3.html', '下一页'),
        // 第 3 页的「下一页」其实是下一章
        p3: pageHtml('83685741.html', '下一页'),
      };

      var current = p1;
      while (visited.length < kMaxDerivedContentPages) {
        final next =
            findNextPageUrlInHtml(html: pages[current]!, currentUrl: current);
        if (next == null || visited.contains(next)) break;
        visited.add(next);
        current = next;
      }

      expect(visited, <String>[p1, p2, p3]);
    });
  });

  // 走真实的 getContent：本地 HttpServer 起一个三分页的章节，
  // 验证兜底分支确实把三页拼起来，且不会多抓下一章。
  group('getContent 兜底翻页（本地 HttpServer）', () {
    late HttpServer server;
    late String base;
    final requested = <String>[];

    // 注意：这里不能调 TestWidgetsFlutterBinding.ensureInitialized()，
    // 它会装上把所有请求都回 400 的 HttpOverrides，本地 HttpServer 收不到请求。
    setUp(() async {
      requested.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://${server.address.address}:${server.port}';
      server.listen((request) async {
        final path = request.uri.path;
        requested.add(path);
        // 每页页脚的「下一页」：前两页指向真正的下一分页，
        // 第三页指向下一章（站点常见写法，必须被闸门拦住）
        const nextHref = <String, String>{
          '/book/1/100.html': '100_2.html',
          '/book/1/100_2.html': '100_3.html',
          '/book/1/100_3.html': '101.html',
          '/book/1/101.html': '102.html',
        };
        const bodyText = <String, String>{
          '/book/1/100.html': '第一页正文',
          '/book/1/100_2.html': '第二页正文',
          '/book/1/100_3.html': '第三页正文',
          '/book/1/101.html': '下一章正文',
        };
        request.response.headers.contentType =
            ContentType('text', 'html', charset: 'utf-8');
        request.response.write(
          '<html><body>'
          '<div id="content"><p>${bodyText[path] ?? '未知'}</p></div>'
          '<a href="${nextHref[path] ?? ''}">下一页</a>'
          '</body></html>',
        );
        await request.response.close();
      });
    });

    tearDown(() async => server.close(force: true));

    BookSource sourceWithoutNextRule() => BookSource(
          bookSourceUrl: base,
          bookSourceName: '本地测试源',
          ruleContent: const ContentRule(content: 'id.content@html'),
        );

    test('源规则没写 nextContentUrl 时，三页被拼成一章', () async {
      final content = await WebBook(sourceWithoutNextRule())
          .getContent('$base/book/1/100.html');

      expect(content, isNotNull);
      expect(content, contains('第一页正文'));
      expect(content, contains('第二页正文'));
      expect(content, contains('第三页正文'));
      // 第三页的「下一页」其实指向下一章，必须被 URL 形状闸门拦住
      expect(content, isNot(contains('下一章正文')));
      expect(
        requested,
        <String>['/book/1/100.html', '/book/1/100_2.html', '/book/1/100_3.html'],
      );
    });

    test('传了 nextChapterUrl 时熔断也不会被触发到第三页之外', () async {
      final content = await WebBook(sourceWithoutNextRule()).getContent(
        '$base/book/1/100.html',
        nextChapterUrl: '$base/book/1/101.html',
      );

      expect(content, contains('第三页正文'));
      expect(content, isNot(contains('下一章正文')));
      expect(requested, hasLength(3));
    });

    test('源规则写了 nextContentUrl 时走原路径，兜底不介入', () async {
      final source = BookSource(
        bookSourceUrl: base,
        bookSourceName: '本地测试源',
        ruleContent: const ContentRule(
          content: 'id.content@html',
          // 故意写一个取不到值的规则：原路径会「翻不动」，
          // 此时兜底不该偷偷补位，行为要和今天一致
          nextContentUrl: 'id.no-such-node@href',
        ),
      );

      final content = await WebBook(source).getContent('$base/book/1/100.html');

      expect(content, contains('第一页正文'));
      expect(content, isNot(contains('第二页正文')));
      expect(requested, <String>['/book/1/100.html']);
    });

    // 健康检查只判「正文规则抽不抽得到东西」。让它串 N 个请求会在 25s 单步预算里
    // 把慢的分页源判成不健康，那是判定漂移而不是变慢，所以给它留了关闸开关。
    test('followUndeclaredNextPage=false 时只发一个请求，正文按第一页算', () async {
      final content = await WebBook(sourceWithoutNextRule()).getContent(
        '$base/book/1/100.html',
        followUndeclaredNextPage: false,
      );

      expect(content, contains('第一页正文'));
      expect(content, isNot(contains('第二页正文')));
      expect(requested, <String>['/book/1/100.html']);
    });
  });
}
