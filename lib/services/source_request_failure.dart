import 'dart:async';

import 'package:dio/dio.dart';

import '../models/book_search_exception.dart';
import 'source_import_failure.dart';

/// 书源请求（发现/目录/详情等）失败类别，面向普通用户诊断。
enum SourceRequestErrorKind {
  /// 连接/收发超时
  timeout,

  /// DNS 解析失败
  dnsFailed,

  /// 网络不通、连接被拒等
  networkUnreachable,

  /// HTTP 非 2xx
  httpStatus,

  /// 请求成功但规则未抽到任何结果（可能书源失效）
  ruleEmpty,

  /// 请求被取消
  cancelled,

  /// 其他
  unknown,
}

/// 带用户可读中文提示的书源请求异常。
class SourceRequestException implements Exception {
  final SourceRequestErrorKind kind;
  final String userMessage;
  final Object? cause;
  final int? statusCode;

  const SourceRequestException({
    required this.kind,
    required this.userMessage,
    this.cause,
    this.statusCode,
  });

  /// 请求成功但列表/目录为空：提示换源，而非伪装成「暂无内容」。
  factory SourceRequestException.ruleEmpty({String what = '内容'}) {
    return SourceRequestException(
      kind: SourceRequestErrorKind.ruleEmpty,
      userMessage:
          '已连接到站点，但未能解析出$what。可能是书源规则失效或页面结构已变，请尝试换源后重试。',
    );
  }

  factory SourceRequestException.httpStatus(int statusCode) {
    return SourceRequestException(
      kind: SourceRequestErrorKind.httpStatus,
      statusCode: statusCode,
      userMessage: '站点返回了错误状态码 $statusCode。请稍后重试，或换一个书源。',
    );
  }

  @override
  String toString() => userMessage;
}

/// 将任意异常转为发现/目录等场景下普通用户能看懂的中文提示（纯函数）。
String describeSourceRequestFailure(Object error) {
  return classifySourceRequestError(error).userMessage;
}

/// 从 Dio / Socket / 业务异常归类（单测可直接调用）。
SourceRequestException classifySourceRequestError(Object error) {
  if (error is SourceRequestException) return error;

  if (error is BookSearchException) {
    return _fromBookSearch(error);
  }

  // 复用书源导入侧已验证的 Dio/Socket 分类，再映射为浏览场景文案。
  final importClassified = classifySourceImportError(error);
  return _fromImportKind(importClassified, cause: error);
}

/// 由 HTTP 层返回的 statusCode / 底层错误构造异常（不依赖完整 DioException）。
SourceRequestException classifyHttpLayerFailure({
  required int statusCode,
  Object? cause,
  String? emptyBodyHint,
}) {
  if (statusCode == 0) {
    if (cause != null) {
      return classifySourceRequestError(cause);
    }
    return const SourceRequestException(
      kind: SourceRequestErrorKind.networkUnreachable,
      userMessage:
          '无法连接站点（连接超时或网络不通）。请检查网络后重试；国外站点在国内可能经常失败。',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return SourceRequestException.httpStatus(statusCode);
  }
  if (emptyBodyHint != null) {
    return SourceRequestException(
      kind: SourceRequestErrorKind.networkUnreachable,
      userMessage: emptyBodyHint,
      statusCode: statusCode,
    );
  }
  return const SourceRequestException(
    kind: SourceRequestErrorKind.unknown,
    userMessage: '加载失败，请稍后重试。',
  );
}

SourceRequestException _fromBookSearch(BookSearchException e) {
  switch (e.kind) {
    case BookSearchFailureKind.timeout:
      return SourceRequestException(
        kind: SourceRequestErrorKind.timeout,
        userMessage: _timeoutMessage,
        cause: e,
        statusCode: e.statusCode,
      );
    case BookSearchFailureKind.network:
      // 若 cause 是 DioException，进一步细分超时 / DNS
      if (e.cause != null) {
        final nested = classifySourceRequestError(e.cause!);
        if (nested.kind != SourceRequestErrorKind.unknown) return nested;
      }
      return SourceRequestException(
        kind: SourceRequestErrorKind.networkUnreachable,
        userMessage: _networkMessage,
        cause: e,
        statusCode: e.statusCode,
      );
    case BookSearchFailureKind.siteError:
      final code = e.statusCode ?? 0;
      return code > 0
          ? SourceRequestException.httpStatus(code)
          : SourceRequestException(
              kind: SourceRequestErrorKind.httpStatus,
              userMessage: e.message,
              cause: e,
              statusCode: e.statusCode,
            );
    case BookSearchFailureKind.ruleMismatch:
      return SourceRequestException(
        kind: SourceRequestErrorKind.ruleEmpty,
        userMessage:
            '已连接到站点，但书源规则未能解析出结果。可能是规则失效或页面结构已变，请尝试换源后重试。',
        cause: e,
      );
    case BookSearchFailureKind.unknown:
      if (e.cause != null) {
        return classifySourceRequestError(e.cause!);
      }
      return SourceRequestException(
        kind: SourceRequestErrorKind.unknown,
        userMessage: '加载失败：${e.message}',
        cause: e,
      );
  }
}

SourceRequestException _fromImportKind(
  SourceImportException classified, {
  Object? cause,
}) {
  switch (classified.kind) {
    case SourceImportErrorKind.timeout:
      return SourceRequestException(
        kind: SourceRequestErrorKind.timeout,
        userMessage: _timeoutMessage,
        cause: cause ?? classified.cause,
        statusCode: classified.statusCode,
      );
    case SourceImportErrorKind.dnsFailed:
      return SourceRequestException(
        kind: SourceRequestErrorKind.dnsFailed,
        userMessage: _dnsMessage,
        cause: cause ?? classified.cause,
      );
    case SourceImportErrorKind.networkUnreachable:
      return SourceRequestException(
        kind: SourceRequestErrorKind.networkUnreachable,
        userMessage: _networkMessage,
        cause: cause ?? classified.cause,
      );
    case SourceImportErrorKind.httpStatus:
      final code = classified.statusCode ?? 0;
      return code > 0
          ? SourceRequestException.httpStatus(code)
          : SourceRequestException(
              kind: SourceRequestErrorKind.httpStatus,
              userMessage: classified.userMessage,
              cause: cause,
              statusCode: classified.statusCode,
            );
    case SourceImportErrorKind.notJson:
    case SourceImportErrorKind.invalidStructure:
    case SourceImportErrorKind.emptySources:
      // 导入特有类别，浏览场景归为未知
      return SourceRequestException(
        kind: SourceRequestErrorKind.unknown,
        userMessage: '加载失败，请稍后重试。',
        cause: cause,
      );
    case SourceImportErrorKind.unknown:
      if (cause is TimeoutException ||
          classified.userMessage.contains('超时') ||
          classified.userMessage.contains('Timeout')) {
        return SourceRequestException(
          kind: SourceRequestErrorKind.timeout,
          userMessage: _timeoutMessage,
          cause: cause,
        );
      }
      if (classified.userMessage.contains('取消')) {
        return SourceRequestException(
          kind: SourceRequestErrorKind.cancelled,
          userMessage: '请求已取消。',
          cause: cause,
        );
      }
      // Dio cancel / badCertificate 等已在 import 分类里带有可读文案，
      // 浏览场景改写成不含「导入」措辞的版本。
      if (cause is DioException &&
          cause.type == DioExceptionType.badCertificate) {
        return SourceRequestException(
          kind: SourceRequestErrorKind.networkUnreachable,
          userMessage: '证书校验失败，无法安全连接该站点。请检查设备时间，或换一个书源。',
          cause: cause,
        );
      }
      return SourceRequestException(
        kind: SourceRequestErrorKind.unknown,
        userMessage: '加载失败，请稍后重试。',
        cause: cause,
      );
  }
}

const _timeoutMessage =
    '连接超时，站点响应过慢或网络不稳定。请检查网络后重试；国外站点在国内可能经常超时。';

const _dnsMessage =
    '无法解析域名（DNS 失败）。请检查网络；若是国外站点，国内网络常会解析失败，可尝试换源。';

const _networkMessage =
    '网络不通，无法连接站点。请确认手机已联网；国外站点在国内可能经常失败，可尝试换源。';
