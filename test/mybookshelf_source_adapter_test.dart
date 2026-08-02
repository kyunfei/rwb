import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/services/book_source_import_service.dart';
import 'package:mr/services/mybookshelf_source_adapter.dart';

void main() {
  late List<Map<String, dynamic>> fixtures;

  setUpAll(() {
    final file = File('test/fixtures/mybookshelf2_sources.json');
    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    fixtures = decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  });

  Map<String, dynamic> byUrl(String url) {
    return fixtures.firstWhere((e) => e['bookSourceUrl'] == url);
  }

  group('isMyBookshelf2FlatSource', () {
    test('真实 2.x 扁平条目被识别', () {
      expect(isMyBookshelf2FlatSource(byUrl('https://www.tianyabook.com#')), isTrue);
      expect(isMyBookshelf2FlatSource(byUrl('https://www.yodu.org##破冰')), isTrue);
    });

    test('Legado 3.x 嵌套条目不被误伤', () {
      final legado3 = <String, dynamic>{
        'bookSourceUrl': 'https://example.com/legado3',
        'bookSourceName': 'Legado3',
        'enabled': true,
        'searchUrl': 'https://example.com/search?q={{key}}',
        'ruleSearch': {
          'bookList': '.item',
          'name': 'a@text',
          'bookUrl': 'a@href',
        },
        'ruleToc': {
          'chapterList': '.chapter',
          'chapterName': 'text',
          'chapterUrl': 'href',
        },
        'ruleContent': {'content': '#content@html'},
      };
      expect(isMyBookshelf2FlatSource(legado3), isFalse);
      expect(convertMyBookshelf2Source(legado3)['searchUrl'],
          'https://example.com/search?q={{key}}');
    });

    test('同时带 2.x 与 3.x 字段的混合输入按 3.x 原样走', () {
      final mixed = <String, dynamic>{
        'bookSourceUrl': 'https://example.com/mixed',
        'bookSourceName': 'mixed',
        'ruleSearchUrl': 'https://example.com/?q=searchKey',
        'searchUrl': 'https://example.com/?q={{key}}',
        'ruleSearch': {'bookList': '.x'},
      };
      expect(isMyBookshelf2FlatSource(mixed), isFalse);
    });
  });

  group('convertMyBookshelf2Url', () {
    test('searchKey/searchPage 裸占位符变为 {{key}}/{{page}}', () {
      expect(
        convertMyBookshelf2Url(
          'http://www.800xiaoshuo.com/modules/article/search.php'
          '?searchkey=searchKey&page=searchPage',
        ),
        'http://www.800xiaoshuo.com/modules/article/search.php'
        '?searchkey={{key}}&page={{page}}',
      );
    });

    test('|char=gbk 抽出为 charset 选项', () {
      final out = convertMyBookshelf2Url(
        'https://www.tianyabook.com/modules/article/search.php'
        '?searchkey=searchKey|char=gbk',
      );
      expect(
        out,
        'https://www.tianyabook.com/modules/article/search.php'
        '?searchkey={{key}},{"charset":"gbk"}',
      );
    });

    test('|charset= 大小写不敏感，且可与其它 | 参数共存', () {
      final out = convertMyBookshelf2Url(
        'https://ex.com/s?q=searchKey|foo=1|Charset=GBK|bar=2',
      );
      expect(out.startsWith('https://ex.com/s?q={{key}}|foo=1|bar=2,'), isTrue);
      final opt = jsonDecode(out.substring(out.indexOf(',') + 1)) as Map;
      expect(opt['charset'], 'GBK');
    });

    test('@ 分隔 POST body，且 body 内占位符一并替换', () {
      final out = convertMyBookshelf2Url(
        'https://www.yodu.org/sa@searchkey=searchKey&searchtype=all',
      );
      expect(
        out,
        'https://www.yodu.org/sa,'
        '{"method":"POST","body":"searchkey={{key}}&searchtype=all"}',
      );
    });

    test('相对路径 @POST 可切', () {
      final out = convertMyBookshelf2Url(
        '/modules/article/search.php@searchkey=searchKey',
      );
      expect(
        out,
        '/modules/article/search.php,'
        '{"method":"POST","body":"searchkey={{key}}"}',
      );
    });

    test('含 <js> 或 @js: 的值不做 @ POST 切分', () {
      const withJsTag =
          'https://ex.com/s?<js>result+"@"+searchKey</js>';
      expect(convertMyBookshelf2Url(withJsTag), contains('@'));
      expect(convertMyBookshelf2Url(withJsTag), isNot(contains('"method":"POST"')));

      const withJsPrefix =
          'https://ex.com/@js:java.ajax(baseUrl+"@q="+searchKey)';
      expect(convertMyBookshelf2Url(withJsPrefix), isNot(contains('"method":"POST"')));
      expect(convertMyBookshelf2Url(withJsPrefix), contains('{{key}}'));
    });

    test('user:pass@host 形态的 userinfo 不被当成 POST', () {
      expect(
        convertMyBookshelf2Url('https://user:pass@example.com/path?q=searchKey'),
        'https://user:pass@example.com/path?q={{key}}',
      );
    });

    test('charset 与 POST 可同时存在', () {
      final out = convertMyBookshelf2Url(
        'http://ex.com/search.php@searchkey=searchKey|char=gbk',
      );
      final opt = jsonDecode(out.substring(out.indexOf(',') + 1)) as Map;
      expect(opt['charset'], 'gbk');
      expect(opt['method'], 'POST');
      expect(opt['body'], 'searchkey={{key}}');
    });
  });

  group('convertMyBookshelf2Header / loginUrl', () {
    test('裸 UA 包成 header JSON', () {
      final src = byUrl('http://tongren.faloo.com#🎃');
      final out = convertMyBookshelf2Source(src);
      final header = out['header'] as String;
      final decoded = jsonDecode(header) as Map;
      expect(decoded['User-Agent'], startsWith('Mozilla/5.0'));
    });

    test('以 { 开头的 header 原样保留；@js: 原样保留', () {
      final jsonUa = convertMyBookshelf2Header(
        '{"User-Agent":"Mozilla/5.0"}',
      );
      expect(jsonUa, '{"User-Agent":"Mozilla/5.0"}');

      final jsUa = convertMyBookshelf2Header(
        '@js:JSON.stringify({"referer":baseUrl})',
      );
      expect(jsUa, '@js:JSON.stringify({"referer":baseUrl})');
    });

    test('loginUrl 空壳被丢弃，真实 loginUrl 保留', () {
      final empty = convertMyBookshelf2Source(byUrl('http://lgqm.huijiwiki.com'));
      expect(empty.containsKey('loginUrl'), isFalse);

      final real = convertMyBookshelf2Source(byUrl('https://www.yodu.org##破冰'));
      expect(real['loginUrl'], 'https://www.yodu.org/');
    });
  });

  group('字段映射完整性（真实 fixture）', () {
    test('天涯书库：顶层 + ruleSearch/Info/Toc/Content', () {
      final out = convertMyBookshelf2Source(byUrl('https://www.tianyabook.com#'));
      expect(out['bookSourceUrl'], 'https://www.tianyabook.com#');
      expect(out['bookSourceName'], '天涯书库（优）');
      expect(out['bookSourceType'], 0);
      expect(out['enabled'], isTrue);
      expect(out['enabledExplore'], isFalse);
      expect(out['searchUrl'], contains('{{key}}'));
      expect(out['searchUrl'], contains('"charset":"gbk"'));

      final search = out['ruleSearch'] as Map;
      expect(search['bookList'], 'class.mySearch@ul');
      expect(search['name'], 'tag.a.0@text');
      expect(search['author'], 'tag.li.2@text');
      expect(search['bookUrl'], 'tag.a.0@href');
      expect(search['coverUrl'], 'img@src');
      expect(search['kind'], 'tag.li.5@text');
      expect(search['lastChapter'], 'tag.a.1@text');

      final info = out['ruleBookInfo'] as Map;
      expect(info['name'], 'class.bookTitle@text');
      expect(info['author'], 'class.booktag@tag.a.0@text');
      expect(info['intro'], 'id.bookIntro@text');
      expect(info['coverUrl'], contains('img@src'));
      expect(info['lastChapter'], contains('class.booktag'));

      final toc = out['ruleToc'] as Map;
      expect(toc['chapterList'], 'id.list-chapterAll@tag.dd');
      expect(toc['chapterName'], 'tag.a@text');
      expect(toc['chapterUrl'], 'tag.a@href');
      expect(toc['nextTocUrl'], isNull); // 源里没有 next

      final content = out['ruleContent'] as Map;
      expect(content['content'], startsWith('id.htmlContent@html'));
      expect(content['nextContentUrl'], 'text.下一章@href');
    });

    test('发现规则 ruleFind* 映射到 ruleExplore', () {
      final out = convertMyBookshelf2Source(
        byUrl('https://example.com/find-demo'),
      );
      expect(out['enabledExplore'], isTrue);
      expect(out['exploreUrl'], 'https://example.com/rank?page={{page}}');
      final explore = out['ruleExplore'] as Map;
      expect(explore['bookList'], 'class.item@!');
      expect(explore['name'], 'tag.a.0@text');
      expect(explore['author'], 'class.author@text');
      expect(explore['bookUrl'], 'tag.a.0@href');
    });

    test('enable/serialNumber/bookSourceType 空串映射', () {
      final out = convertMyBookshelf2Source({
        'bookSourceUrl': 'https://ex.com',
        'bookSourceName': 't',
        'bookSourceType': '',
        'enable': false,
        'serialNumber': 9,
        'ruleSearchUrl': 'https://ex.com?q=searchKey',
        'ruleBookContent': 'id.c@text',
      });
      expect(out['bookSourceType'], 0);
      expect(out['enabled'], isFalse);
      expect(out['customOrder'], 9);
    });
  });

  group('导入链路', () {
    test('importText 识别 2.x 并带上转换计数；结果可被 BookSource 消化', () async {
      final tianya = byUrl('https://www.tianyabook.com#');
      final yodu = byUrl('https://www.yodu.org##破冰');
      final payload = jsonEncode([tianya, yodu]);

      // 不落盘：用假 storage 会更干净，但这里只测 parse + 计数字段。
      // parseText 不写存储；转换计数在 importText 上。
      final sources = await BookSourceImportService().parseText(payload);
      expect(sources.length, 2);
      expect(sources.every((s) => s.searchUrl != null && s.searchUrl!.isNotEmpty),
          isTrue);
      expect(sources.first.ruleSearch?.bookList, isNotNull);
      expect(sources.first.ruleContent?.content, isNotNull);

      // 用内存式校验：adapt + fromJson 路径与计数
      final adapted = adaptMyBookshelfPayload(jsonDecode(payload));
      expect(adapted.convertedCount, 2);
      for (final item in adapted.data as List) {
        final source = BookSource.fromJson(
          (item as Map).map((k, v) => MapEntry('$k', v)),
        );
        expect(source.bookSourceName, isNotEmpty);
        expect(source.enabled, isTrue);
      }
    });

    test('3.x JSON 导入 convertedCount 为 0', () {
      final legado3 = [
        {
          'bookSourceUrl': 'https://example.com/l3',
          'bookSourceName': 'L3',
          'searchUrl': 'https://example.com?q={{key}}',
          'ruleSearch': {'bookList': '.a', 'name': 'text', 'bookUrl': 'href'},
          'ruleContent': {'content': '#c'},
        }
      ];
      final adapted = adaptMyBookshelfPayload(legado3);
      expect(adapted.convertedCount, 0);
      expect(
        (adapted.data as List).first['searchUrl'],
        'https://example.com?q={{key}}',
      );
    });
  });
}
