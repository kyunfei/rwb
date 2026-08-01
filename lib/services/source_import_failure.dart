import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// 书源导入失败类别（面向用户诊断）。
enum SourceImportErrorKind {
  /// 网络不通、连接被拒等
  networkUnreachable,

  /// 连接/收发超时
  timeout,

  /// DNS 解析失败（国内访问 GitHub 等域名常见）
  dnsFailed,

  /// HTTP 非 2xx
  httpStatus,

  /// 返回内容不是 JSON（如 HTML 登录页/错误页）
  notJson,

  /// JSON 能解但缺少书源必要字段
  invalidStructure,

  /// 解出来了但有效书源为 0 条
  emptySources,

  /// 其他
  unknown,
}

/// 带用户可读中文提示的导入异常。
class SourceImportException implements Exception {
  final SourceImportErrorKind kind;
  final String userMessage;
  final Object? cause;
  final int? statusCode;

  const SourceImportException({
    required this.kind,
    required this.userMessage,
    this.cause,
    this.statusCode,
  });

  factory SourceImportException.httpStatus(int statusCode, {String? url}) {
    final where = (url != null && url.isNotEmpty) ? '（$url）' : '';
    return SourceImportException(
      kind: SourceImportErrorKind.httpStatus,
      statusCode: statusCode,
      userMessage:
          '服务器返回了错误状态码 $statusCode$where。请确认链接是否正确、是否需要登录，或换一个书源地址。',
    );
  }

  factory SourceImportException.notJson({String? snippet}) {
    final hint = _snippetHint(snippet);
    return SourceImportException(
      kind: SourceImportErrorKind.notJson,
      userMessage:
          '这个链接返回的不是书源 JSON 文件$hint。常见原因：打开了网页/登录页/错误页，而不是直接的 .json 下载地址。请换用返回书源 JSON 的链接，或改用「文本导入」粘贴内容。',
    );
  }

  factory SourceImportException.invalidStructure([String? detail]) {
    return SourceImportException(
      kind: SourceImportErrorKind.invalidStructure,
      userMessage: detail == null || detail.isEmpty
          ? '内容是 JSON，但不是合法书源（缺少 bookSourceUrl 或 bookSourceName 等必要字段）。请确认这是 Legado 格式的书源文件。'
          : '内容是 JSON，但不是合法书源：$detail',
    );
  }

  factory SourceImportException.emptySources() {
    return const SourceImportException(
      kind: SourceImportErrorKind.emptySources,
      userMessage: '已成功下载并解析，但没有找到任何有效书源（0 条）。请确认链接内容是书源数组或单个书源对象。',
    );
  }

  @override
  String toString() => userMessage;

  static String _snippetHint(String? snippet) {
    if (snippet == null || snippet.trim().isEmpty) return '';
    final trimmed = snippet.trimLeft().toLowerCase();
    if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
      return '（看起来像网页 HTML）';
    }
    return '';
  }
}

/// 将任意异常转为普通用户能看懂的中文提示。
String describeSourceImportFailure(Object error) {
  if (error is SourceImportException) return error.userMessage;

  if (error is FormatException) {
    final msg = error.message;
    if (msg.contains('bookSourceUrl') || msg.contains('bookSourceName')) {
      return SourceImportException.invalidStructure(msg).userMessage;
    }
    if (msg.contains('未找到有效书源') || msg.contains('0')) {
      return SourceImportException.emptySources().userMessage;
    }
    if (msg.contains('书源必须是') ||
        msg.contains('Unexpected') ||
        msg.contains('JSON')) {
      return SourceImportException.notJson().userMessage;
    }
    return SourceImportException.invalidStructure(msg).userMessage;
  }

  if (error is DioException) {
    return _fromDio(error).userMessage;
  }

  if (error is SocketException) {
    return _fromSocket(error).userMessage;
  }

  if (error is HandshakeException) {
    return const SourceImportException(
      kind: SourceImportErrorKind.networkUnreachable,
      userMessage:
          '安全连接失败（HTTPS 握手错误）。请检查网络、系统时间是否正确，或换一个书源地址重试。',
    ).userMessage;
  }

  if (error is TimeoutException) {
    return const SourceImportException(
      kind: SourceImportErrorKind.timeout,
      userMessage: '下载超时。请检查网络是否畅通后重试；若链接指向国外站点（如 GitHub），国内网络常会失败。',
    ).userMessage;
  }

  // 嵌套：Exception('JSON导入失败: ...')
  final text = error.toString();
  if (text.contains('Failed host lookup') ||
      text.contains('Name or service not known') ||
      text.contains('nodename nor servname')) {
    return _dnsMessage().userMessage;
  }
  if (text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable')) {
    return _networkMessage().userMessage;
  }
  if (text.contains('Timeout') || text.contains('timed out')) {
    return const SourceImportException(
      kind: SourceImportErrorKind.timeout,
      userMessage: '下载超时。请检查网络是否畅通后重试；若链接指向国外站点（如 GitHub），国内网络常会失败。',
    ).userMessage;
  }

  return '导入失败：$text';
}

/// 从 Dio / Socket 等底层错误归类（单测可直接调用）。
SourceImportException classifySourceImportError(Object error) {
  if (error is SourceImportException) return error;
  if (error is DioException) return _fromDio(error);
  if (error is SocketException) return _fromSocket(error);
  if (error is FormatException) {
    final described = describeSourceImportFailure(error);
    if (described.contains('不是书源 JSON') || described.contains('不是书源文件')) {
      return SourceImportException.notJson();
    }
    if (described.contains('0 条')) {
      return SourceImportException.emptySources();
    }
    return SourceImportException.invalidStructure(error.message);
  }
  return SourceImportException(
    kind: SourceImportErrorKind.unknown,
    userMessage: describeSourceImportFailure(error),
    cause: error,
  );
}

SourceImportException _fromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const SourceImportException(
        kind: SourceImportErrorKind.timeout,
        userMessage:
            '下载超时。请检查网络是否畅通后重试；若链接指向国外站点（如 GitHub），国内网络常会失败，可改用国内可访问的书源地址，或用「文本导入 / 从文件导入」。',
      );
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode ?? 0;
      return SourceImportException.httpStatus(
        code,
        url: e.requestOptions.uri.toString(),
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      final inner = e.error;
      if (inner is SocketException) return _fromSocket(inner);
      final msg = '${e.message ?? ''} ${inner ?? ''}';
      if (_looksLikeDns(msg)) return _dnsMessage();
      return _networkMessage(cause: e);
    case DioExceptionType.cancel:
      return SourceImportException(
        kind: SourceImportErrorKind.unknown,
        userMessage: '导入已取消。',
        cause: e,
      );
    case DioExceptionType.badCertificate:
      return SourceImportException(
        kind: SourceImportErrorKind.networkUnreachable,
        userMessage: '证书校验失败，无法安全下载该书源。请换一个地址或检查设备时间。',
        cause: e,
      );
  }
}

SourceImportException _fromSocket(SocketException e) {
  final msg = '${e.message} ${e.osError ?? ''}';
  if (_looksLikeDns(msg)) return _dnsMessage(cause: e);
  return _networkMessage(cause: e);
}

bool _looksLikeDns(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('failed host lookup') ||
      lower.contains('name or service not known') ||
      lower.contains('nodename nor servname') ||
      lower.contains('temporary failure in name resolution') ||
      msg.contains('主机名') ||
      msg.contains('域名');
}

SourceImportException _dnsMessage({Object? cause}) {
  return SourceImportException(
    kind: SourceImportErrorKind.dnsFailed,
    cause: cause,
    userMessage:
        '无法解析域名（DNS 失败）。国内网络访问 GitHub / raw.githubusercontent.com 等国外地址经常失败。请换用国内可打开的书源 JSON 链接，或把书源内容复制后用「文本导入」，也可以用「从文件导入」。',
  );
}

SourceImportException _networkMessage({Object? cause}) {
  return SourceImportException(
    kind: SourceImportErrorKind.networkUnreachable,
    cause: cause,
    userMessage:
        '网络不通，无法下载书源。请确认手机已联网；若链接是国外站点，国内网络常会失败。可改用国内书源地址，或用「文本导入 / 从文件导入」。',
  );
}

/// 粗判文本是否像 HTML（而非 JSON）。
bool looksLikeHtmlDocument(String text) {
  final t = text.trimLeft().toLowerCase();
  return t.startsWith('<!doctype html') ||
      t.startsWith('<html') ||
      (t.startsWith('<') && t.contains('<head') && t.contains('<body'));
}

/// 粗判文本是否像可解析的 JSON 开头。
bool looksLikeJsonPayload(String text) {
  final t = text.trimLeft();
  return t.startsWith('{') || t.startsWith('[');
}
