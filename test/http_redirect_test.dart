import 'dart:convert';
import 'dart:io' hide HttpClient;
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_engine/http_redirect.dart';
import 'package:mr/services/source_engine/web_book.dart';
import 'package:mr/services/source_request_failure.dart';

/// 本地 HttpServer 验证 POST 重定向跟随，不依赖外网。
void main() {
  group('http_redirect helpers', () {
    test('resolveRedirectLocation 拼接相对路径', () {
      expect(
        resolveRedirectLocation('http://a.example/search.html?/', '/step2'),
        'http://a.example/step2',
      );
      expect(
        resolveRedirectLocation('http://a.example/dir/page', 'step2'),
        'http://a.example/dir/step2',
      );
      expect(
        resolveRedirectLocation('https://a.example/x', '//b.example/y'),
        'https://b.example/y',
      );
    });

    test('resolveRedirectLocation 容错未转义空格', () {
      final out = resolveRedirectLocation(
        'http://a.example/',
        'http://a.example/path with space',
      );
      expect(out.contains(' '), isFalse);
      expect(out.contains('%20'), isTrue);
    });

    test('301/302/303 改 GET；307/308 保持原方法', () {
      expect(shouldSwitchToGet(301), isTrue);
      expect(shouldSwitchToGet(302), isTrue);
      expect(shouldSwitchToGet(303), isTrue);
      expect(shouldSwitchToGet(307), isFalse);
      expect(shouldSwitchToGet(308), isFalse);
    });

    test('跳域剔除 Cookie / Authorization，保留 UA', () {
      final headers = {
        'User-Agent': 'UA-Test',
        'Cookie': 'sid=1',
        'Authorization': 'Bearer x',
        'Referer': 'http://old.example/',
      };
      final next = stripCredentialsOnCrossHost(
        headers,
        'http://old.example/a',
        'http://new.example/b',
      );
      expect(next['User-Agent'], 'UA-Test');
      expect(next['Referer'], 'http://old.example/');
      expect(next.containsKey('Cookie'), isFalse);
      expect(next.containsKey('Authorization'), isFalse);
    });

    test('同域不剔 Cookie', () {
      final next = stripCredentialsOnCrossHost(
        {'Cookie': 'sid=1'},
        'http://a.example/a',
        'http://a.example/b',
      );
      expect(next['Cookie'], 'sid=1');
    });

    test('改 GET 时剥离实体头', () {
      final next = stripEntityHeaders({
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': '12',
        'User-Agent': 'UA',
      });
      expect(next.containsKey('Content-Type'), isFalse);
      expect(next.containsKey('Content-Length'), isFalse);
      expect(next['User-Agent'], 'UA');
    });
  });

  group('HttpClient redirect follow', () {
    late HttpServer server;
    late String base;
    final seen = <_SeenRequest>[];

    setUp(() async {
      seen.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://${server.address.address}:${server.port}';
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        seen.add(_SeenRequest(
          method: request.method,
          path: request.uri.path,
          body: body,
          contentType: request.headers.contentType?.mimeType,
        ));

        final path = request.uri.path;
        if (path == '/post-301') {
          request.response.statusCode = 301;
          request.response.headers.set('Location', '$base/final-get');
          await request.response.close();
          return;
        }
        if (path == '/post-307') {
          request.response.statusCode = 307;
          request.response.headers.set('Location', '$base/final-post');
          await request.response.close();
          return;
        }
        if (path == '/rel-301') {
          request.response.statusCode = 301;
          request.response.headers.set('Location', '/step2');
          await request.response.close();
          return;
        }
        if (path == '/step2') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.html;
          request.response.write('rel-ok');
          await request.response.close();
          return;
        }
        if (path == '/final-get') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.html;
          request.response.write('get-final');
          await request.response.close();
          return;
        }
        if (path == '/final-post') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.html;
          request.response.write('post-final:$body');
          await request.response.close();
          return;
        }
        if (path == '/chain0') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain1');
          await request.response.close();
          return;
        }
        if (path == '/chain1') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain2');
          await request.response.close();
          return;
        }
        if (path == '/chain2') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain3');
          await request.response.close();
          return;
        }
        if (path == '/chain3') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain4');
          await request.response.close();
          return;
        }
        if (path == '/chain4') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain5');
          await request.response.close();
          return;
        }
        if (path == '/chain5') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/chain6');
          await request.response.close();
          return;
        }
        if (path == '/chain6') {
          request.response.statusCode = 200;
          request.response.write('too-far');
          await request.response.close();
          return;
        }
        if (path == '/gbk-301') {
          request.response.statusCode = 301;
          request.response.headers.set('Location', '$base/gbk-page');
          await request.response.close();
          return;
        }
        if (path == '/gbk-page') {
          const text = '第一章';
          final bytes = Uint8List.fromList(const GbkCodec().encode(text));
          request.response.statusCode = 200;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/html; charset=GBK',
          );
          request.response.add(bytes);
          await request.response.close();
          return;
        }
        if (path == '/get-ok') {
          request.response.statusCode = 200;
          request.response.write('plain-get');
          await request.response.close();
          return;
        }
        if (path == '/get-302') {
          request.response.statusCode = 302;
          request.response.headers.set('Location', '$base/get-ok');
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('POST → 301 → 目标收到 GET 且无 body，最终内容正确', () async {
      final client = HttpClient();
      final res = await client.execute(
        '$base/post-301',
        method: 'POST',
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'RedirectTest/1.0',
        },
        body: 'searchkey=凡人修仙传',
      );

      expect(res.isSuccessful, isTrue);
      expect(res.body, 'get-final');
      expect(seen.length, 2);
      expect(seen[0].method, 'POST');
      expect(seen[0].body, 'searchkey=凡人修仙传');
      expect(seen[1].method, 'GET');
      expect(seen[1].body, isEmpty);
      expect(seen[1].contentType, isNull);
    });

    test('POST → 307 → 目标仍是 POST 且 body 完整', () async {
      final client = HttpClient();
      final res = await client.execute(
        '$base/post-307',
        method: 'POST',
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'searchkey=abc',
      );

      expect(res.isSuccessful, isTrue);
      expect(res.body, 'post-final:searchkey=abc');
      expect(seen.length, 2);
      expect(seen[0].method, 'POST');
      expect(seen[1].method, 'POST');
      expect(seen[1].body, 'searchkey=abc');
    });

    test('相对 Location /step2 能正确拼接', () async {
      final client = HttpClient();
      final res = await client.execute(
        '$base/rel-301',
        method: 'POST',
        body: 'x=1',
      );

      expect(res.isSuccessful, isTrue);
      expect(res.body, 'rel-ok');
      expect(seen.map((e) => e.path).toList(), ['/rel-301', '/step2']);
    });

    test('超过最大重定向次数 → 可读错误，不无限循环', () async {
      final client = HttpClient();
      final res = await client.execute(
        '$base/chain0',
        method: 'POST',
        body: 'x=1',
      ).timeout(const Duration(seconds: 5));

      expect(res.isSuccessful, isFalse);
      expect(res.error, isA<SourceRequestException>());
      final err = res.error! as SourceRequestException;
      expect(err.userMessage, contains('重定向'));
      // 初始 + 最多 5 次跟随尝试对应的请求数：不超过 1 + kMaxRedirects
      expect(seen.length, lessThanOrEqualTo(1 + kMaxRedirects));
      expect(seen.any((e) => e.path == '/chain6'), isFalse);
    });

    test('重定向到 GBK 页面时最终文本正确解码', () async {
      final client = HttpClient();
      final res = await client.execute(
        '$base/gbk-301',
        method: 'POST',
        body: 'q=1',
      );

      expect(res.isSuccessful, isTrue);
      expect(res.body, '第一章');
    });

    test('GET 现有跟随行为不回退', () async {
      final client = HttpClient();
      final res = await client.execute('$base/get-302', method: 'GET');

      expect(res.isSuccessful, isTrue);
      expect(res.body, 'plain-get');
      expect(seen.map((e) => e.method).toList(), ['GET', 'GET']);
    });
  });
}

class _SeenRequest {
  final String method;
  final String path;
  final String body;
  final String? contentType;

  _SeenRequest({
    required this.method,
    required this.path,
    required this.body,
    required this.contentType,
  });
}
