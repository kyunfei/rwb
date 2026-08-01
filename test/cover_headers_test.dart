import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/utils/cover_headers.dart';

BookSource _source({String? header}) => BookSource(
      bookSourceUrl: 'https://example.com/novel/index.html',
      bookSourceName: '测试源',
      header: header,
    );

/// 封面防盗链是最容易静默失效的一环：头没带对只是图片不显示，不会报错，
/// 所以这里把 Referer/UA 的补齐规则钉住。
void main() {
  group('buildCoverHeaders', () {
    test('sourceUrl 为空时不编造任何头', () {
      expect(
        buildCoverHeaders(source: _source(), sourceUrl: null),
        isEmpty,
      );
      expect(
        buildCoverHeaders(source: _source(), sourceUrl: ''),
        isEmpty,
      );
    });

    test('书源没有 header 时，仍补上 Referer 与 User-Agent', () {
      final headers = buildCoverHeaders(
        source: _source(),
        sourceUrl: 'https://example.com/novel/index.html',
      );
      expect(headers['Referer'], 'https://example.com');
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
    });

    test('书源记录已丢失（source 为 null）时也要补头，否则封面必然 403', () {
      final headers = buildCoverHeaders(
        source: null,
        sourceUrl: 'https://example.com/novel/index.html',
      );
      expect(headers['Referer'], 'https://example.com');
      expect(headers['User-Agent'], isNotNull);
    });

    test('JSON 格式的 header 被解析', () {
      final headers = buildCoverHeaders(
        source: _source(header: '{"Cookie":"a=1","X-Foo":"bar"}'),
        sourceUrl: 'https://example.com/',
      );
      expect(headers['Cookie'], 'a=1');
      expect(headers['X-Foo'], 'bar');
    });

    test('按行 Key: Value 格式的 header 被解析，值里的冒号不被截断', () {
      final headers = buildCoverHeaders(
        source: _source(
          header: 'Cookie: a=1\nReferer: https://other.com/page',
        ),
        sourceUrl: 'https://example.com/',
      );
      expect(headers['Cookie'], 'a=1');
      expect(headers['Referer'], 'https://other.com/page');
    });

    test('书源自带的 Referer / UA 优先，不被默认值覆盖', () {
      final headers = buildCoverHeaders(
        source: _source(
          header: '{"Referer":"https://custom.com","User-Agent":"MyUA"}',
        ),
        sourceUrl: 'https://example.com/novel/index.html',
      );
      expect(headers['Referer'], 'https://custom.com');
      expect(headers['User-Agent'], 'MyUA');
    });
  });

  group('extractBaseUrl', () {
    test('取到 scheme://host，丢掉路径与查询', () {
      expect(
        extractBaseUrl('https://example.com/a/b?c=1'),
        'https://example.com',
      );
    });

    test('非法 URL 原样返回，不抛异常', () {
      expect(extractBaseUrl('not a url'), 'not a url');
    });
  });
}
