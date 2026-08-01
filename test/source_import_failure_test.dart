import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/book_source_import_service.dart';
import 'package:mr/services/source_import_failure.dart';

void main() {
  group('classifySourceImportError / describeSourceImportFailure', () {
    test('DNS 解析失败给出国内网络提示', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://raw.githubusercontent.com/a.json'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup: raw.githubusercontent.com'),
      );
      final classified = classifySourceImportError(err);
      expect(classified.kind, SourceImportErrorKind.dnsFailed);
      expect(classified.userMessage, contains('DNS'));
      expect(classified.userMessage, contains('GitHub'));
    });

    test('超时给出超时提示', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/a.json'),
        type: DioExceptionType.connectionTimeout,
      );
      final msg = describeSourceImportFailure(err);
      expect(msg, contains('超时'));
      expect(msg, contains('GitHub'));
    });

    test('HTTP 非 200 带出状态码', () {
      final ex = SourceImportException.httpStatus(404, url: 'https://x.com/a.json');
      expect(ex.kind, SourceImportErrorKind.httpStatus);
      expect(ex.userMessage, contains('404'));
      expect(describeSourceImportFailure(ex), contains('404'));
    });

    test('HTML 内容判定为不是书源 JSON', () {
      final ex = SourceImportException.notJson(
        snippet: '<!DOCTYPE html><html><body>login</body></html>',
      );
      expect(ex.kind, SourceImportErrorKind.notJson);
      expect(ex.userMessage, contains('不是书源'));
      expect(ex.userMessage, contains('HTML'));
    });

    test('结构错误 / 0 条有效源', () {
      expect(
        classifySourceImportError(
          SourceImportException.invalidStructure('缺少 bookSourceUrl'),
        ).kind,
        SourceImportErrorKind.invalidStructure,
      );
      expect(
        describeSourceImportFailure(SourceImportException.emptySources()),
        contains('0 条'),
      );
    });

    test('网络不通', () {
      const err = SocketException('Network is unreachable');
      final classified = classifySourceImportError(err);
      expect(classified.kind, SourceImportErrorKind.networkUnreachable);
      expect(classified.userMessage, contains('网络不通'));
    });
  });

  group('BookSourceImportService 错误分类接入', () {
    test('HTML 正文导入抛出 notJson', () async {
      final service = BookSourceImportService(
        fetchText: (url, _) async =>
            '<!DOCTYPE html><html><head></head><body>oops</body></html>',
      );
      await expectLater(
        service.importText('https://example.com/fake.json'),
        throwsA(
          isA<SourceImportException>().having(
            (e) => e.kind,
            'kind',
            SourceImportErrorKind.notJson,
          ),
        ),
      );
    });

    test('缺必要字段抛出 invalidStructure', () async {
      final service = BookSourceImportService();
      await expectLater(
        service.importText('{"bookSourceName":"只有名字没有URL"}'),
        throwsA(
          isA<SourceImportException>().having(
            (e) => e.kind,
            'kind',
            SourceImportErrorKind.invalidStructure,
          ),
        ),
      );
    });

    test('空数组抛出 emptySources', () async {
      final service = BookSourceImportService();
      await expectLater(
        service.importText('[]'),
        throwsA(
          isA<SourceImportException>().having(
            (e) => e.kind,
            'kind',
            SourceImportErrorKind.emptySources,
          ),
        ),
      );
    });

    test('fetch 侧 HTTP 状态经自定义 fetcher 透传分类文案', () async {
      final service = BookSourceImportService(
        fetchText: (url, _) async {
          throw SourceImportException.httpStatus(403, url: url);
        },
      );
      try {
        await service.importText('https://example.com/sources.json');
        fail('should throw');
      } catch (e) {
        expect(describeSourceImportFailure(e), contains('403'));
      }
    });
  });

  group('looksLikeHtmlDocument / looksLikeJsonPayload', () {
    test('识别 HTML 与 JSON 开头', () {
      expect(looksLikeHtmlDocument('<!DOCTYPE html><html>'), isTrue);
      expect(looksLikeJsonPayload('[{"a":1}]'), isTrue);
      expect(looksLikeJsonPayload('<html>'), isFalse);
    });
  });
}
