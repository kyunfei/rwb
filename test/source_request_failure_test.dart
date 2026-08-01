import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_search_exception.dart';
import 'package:mr/services/source_request_failure.dart';

void main() {
  group('classifySourceRequestError / describeSourceRequestFailure', () {
    test('连接超时 → timeout 文案（不含 Dio 枚举名）', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://zh.wikisource.org/wiki/Portal'),
        type: DioExceptionType.connectionTimeout,
        message: 'The request connection took longer than 0:00:15.000000',
      );
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.timeout);
      final msg = classified.userMessage;
      expect(msg, contains('超时'));
      expect(msg, isNot(contains('DioException')));
      expect(msg, isNot(contains('connectionTimeout')));
      expect(describeSourceRequestFailure(err), msg);
    });

    test('DNS 解析失败 → dnsFailed', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://www.gutenberg.org/ebooks/1'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup: www.gutenberg.org'),
      );
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.dnsFailed);
      expect(classified.userMessage, contains('DNS'));
      expect(classified.userMessage, contains('换源'));
    });

    test('网络不可达 → networkUnreachable', () {
      const err = SocketException('Network is unreachable');
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.networkUnreachable);
      expect(classified.userMessage, contains('网络不通'));
    });

    test('HTTP 状态码 → 文案含状态码', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: 'https://example.com/x'),
          statusCode: 503,
        ),
      );
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.httpStatus);
      expect(classified.statusCode, 503);
      expect(classified.userMessage, contains('503'));
      expect(
        SourceRequestException.httpStatus(404).userMessage,
        contains('404'),
      );
    });

    test('规则未命中 → ruleEmpty，提示换源', () {
      final ex = SourceRequestException.ruleEmpty(what: '目录');
      expect(ex.kind, SourceRequestErrorKind.ruleEmpty);
      expect(ex.userMessage, contains('目录'));
      expect(ex.userMessage, contains('规则'));
      expect(ex.userMessage, contains('换源'));
      expect(classifySourceRequestError(ex).kind, SourceRequestErrorKind.ruleEmpty);
    });

    test('BookSearchException.timeout 映射为浏览超时文案', () {
      const err = BookSearchException(
        kind: BookSearchFailureKind.timeout,
        message: '搜索请求超时',
      );
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.timeout);
      expect(classified.userMessage, contains('超时'));
    });

    test('BookSearchException.ruleMismatch 映射为规则失效', () {
      const err = BookSearchException(
        kind: BookSearchFailureKind.ruleMismatch,
        message: '列表规则命中 3 条，但书名规则未解析出结果',
      );
      final classified = classifySourceRequestError(err);
      expect(classified.kind, SourceRequestErrorKind.ruleEmpty);
      expect(classified.userMessage, contains('换源'));
    });
  });

  group('classifyHttpLayerFailure', () {
    test('statusCode=0 且带 DioException 超时 → timeout', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
      final classified = classifyHttpLayerFailure(statusCode: 0, cause: dioErr);
      expect(classified.kind, SourceRequestErrorKind.timeout);
    });

    test('statusCode=0 无 cause → 通用网络不通文案', () {
      final classified = classifyHttpLayerFailure(statusCode: 0);
      expect(classified.kind, SourceRequestErrorKind.networkUnreachable);
      expect(classified.userMessage, contains('无法连接'));
    });

    test('HTTP 4xx/5xx', () {
      final classified = classifyHttpLayerFailure(statusCode: 403);
      expect(classified.kind, SourceRequestErrorKind.httpStatus);
      expect(classified.userMessage, contains('403'));
    });
  });
}
