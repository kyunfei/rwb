/// 单书源搜索失败原因，供 UI 区分处理方式。
enum BookSearchFailureKind {
  /// 网络不通：DNS/超时/连接失败/无响应体
  network,

  /// 站点报错：HTTP 4xx/5xx 等
  siteError,

  /// 规则没匹配上：选择器/JS/字段解析失败
  ruleMismatch,

  /// 超时（调用方或读超时）
  timeout,

  /// 其它未分类异常
  unknown;

  String get kindLabel {
    switch (this) {
      case BookSearchFailureKind.network:
        return '网络不通';
      case BookSearchFailureKind.siteError:
        return '站点报错';
      case BookSearchFailureKind.ruleMismatch:
        return '规则未匹配';
      case BookSearchFailureKind.timeout:
        return '超时';
      case BookSearchFailureKind.unknown:
        return '未知错误';
    }
  }
}

/// 单书源搜索异常。批量搜索时应按源捕获，不应直接炸掉整次搜索。
class BookSearchException implements Exception {
  const BookSearchException({
    required this.kind,
    required this.message,
    this.sourceName,
    this.statusCode,
    this.cause,
  });

  final BookSearchFailureKind kind;
  final String message;
  final String? sourceName;
  final int? statusCode;
  final Object? cause;

  String get kindLabel => kind.kindLabel;

  @override
  String toString() {
    final buf = StringBuffer(kindLabel);
    if (sourceName != null && sourceName!.isNotEmpty) {
      buf.write('[$sourceName]');
    }
    if (statusCode != null) {
      buf.write('(HTTP $statusCode)');
    }
    buf.write(': $message');
    return buf.toString();
  }
}
