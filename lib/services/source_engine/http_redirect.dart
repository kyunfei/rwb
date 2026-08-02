import 'dart:convert';

import 'analyze_url.dart';

/// 书源 HTTP 层对 3xx 的跟随策略（对齐 OkHttp / 浏览器事实行为）。
///
/// dart:io 的 [HttpClient] 只对 GET/HEAD 自动跟随重定向；POST 收到 301/302
/// 会把 3xx 原样交给上层。书源站点常用 301 做域名迁移，因此必须在上层自行跟随。
///
/// 语义：
/// - 301 / 302 / 303 → 改发 GET，丢掉请求体与实体头
/// - 307 / 308 → 保持原 method 与 body
/// - Location 相对当前请求 URL 解析；未转义中文/空格做容错
/// - 最多跟随 [kMaxRedirects] 次，并按已访问 URL 防循环
const int kMaxRedirects = 5;

/// 需要跟随的 3xx 状态码。
bool isRedirectStatus(int statusCode) {
  return statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;
}

/// 301/302/303 是否应把后续请求改成 GET（并丢 body）。
bool shouldSwitchToGet(int statusCode) {
  return statusCode == 301 || statusCode == 302 || statusCode == 303;
}

/// 解析 Location，相对 [currentUrl] 拼成绝对 URL；对未转义空格/中文做容错。
String resolveRedirectLocation(String currentUrl, String location) {
  final trimmed = location.trim();
  if (trimmed.isEmpty) return trimmed;

  // 先走书源已有的相对 URL 解析（支持 /foo、foo、//host/foo）
  final resolved = AnalyzeUrl.resolve(currentUrl, trimmed);
  if (resolved.isEmpty) return resolved;

  // Dart 的 Uri.tryParse 对空格较宽容，但 HttpClient 实际发请求时可能踩坑；
  // 对空格/控制字符/未转义非 ASCII 做最小容错编码。
  if (_needsUriEncoding(resolved)) {
    return _encodeUnsafeUriChars(resolved);
  }
  return resolved;
}

bool _needsUriEncoding(String url) {
  for (final rune in url.runes) {
    if (rune <= 0x20 || rune == 0x7F || rune > 0x7F) return true;
  }
  return false;
}

/// 跳域时从请求头里剔除不应跨站带出的字段。
///
/// 选择：
/// - **保留** User-Agent、Referer 及书源自带的其它业务头（很多站点靠 UA/Referer
///   防盗链；Referer 即便跨域也常仍被源站规则写死，跟 OkHttp 一样不主动改写）。
/// - **剔除** Cookie / cookie：会话凭据不应随 3xx 跳到另一域名。
///   项目里 `enabledCookieJar` 目前只暴露给 JS 环境，请求层尚未自动挂 CookieJar；
///   但书源 `header` 里可能手写 Cookie，跳域时仍按浏览器同源策略丢掉。
/// - **剔除** Authorization：与 Cookie 同理，避免凭据泄漏到第三方主机。
Map<String, String> stripCredentialsOnCrossHost(
  Map<String, String> headers,
  String fromUrl,
  String toUrl,
) {
  if (!_hostChanged(fromUrl, toUrl)) {
    return Map<String, String>.from(headers);
  }
  final next = <String, String>{};
  for (final entry in headers.entries) {
    final key = entry.key.toLowerCase();
    if (key == 'cookie' || key == 'authorization') continue;
    next[entry.key] = entry.value;
  }
  return next;
}

/// 301/302/303 改 GET 时去掉实体头，避免空 body 仍带着 Content-Type/Length。
Map<String, String> stripEntityHeaders(Map<String, String> headers) {
  final next = <String, String>{};
  for (final entry in headers.entries) {
    final key = entry.key.toLowerCase();
    if (key == 'content-type' ||
        key == 'content-length' ||
        key == 'content-encoding' ||
        key == 'transfer-encoding') {
      continue;
    }
    next[entry.key] = entry.value;
  }
  return next;
}

/// 超限/循环时的用户可读文案（走 [SourceRequestException] 体系）。
String redirectLimitUserMessage({
  required int maxRedirects,
  required bool isLoop,
}) {
  if (isLoop) {
    return '站点重定向出现循环，已停止跟随。请检查书源地址是否配置错误或已失效。';
  }
  return '站点重定向次数过多（已跟随 $maxRedirects 次），已停止跟随。'
      '请检查书源地址是否配置错误或已失效。';
}

bool _hostChanged(String fromUrl, String toUrl) {
  final from = Uri.tryParse(fromUrl);
  final to = Uri.tryParse(toUrl);
  if (from == null || to == null) return false;
  return from.host.toLowerCase() != to.host.toLowerCase();
}

/// 仅编码非法 URI 字符，保留已有 %xx 与结构分隔符。
String _encodeUnsafeUriChars(String url) {
  final buffer = StringBuffer();
  for (final rune in url.runes) {
    final isUnreserved = (rune >= 0x41 && rune <= 0x5A) || // A-Z
        (rune >= 0x61 && rune <= 0x7A) || // a-z
        (rune >= 0x30 && rune <= 0x39) || // 0-9
        rune == 0x2D || // -
        rune == 0x2E || // .
        rune == 0x5F || // _
        rune == 0x7E; // ~
    final isReserved = rune == 0x3A || // :
        rune == 0x2F || // /
        rune == 0x3F || // ?
        rune == 0x23 || // #
        rune == 0x5B || // [
        rune == 0x5D || // ]
        rune == 0x40 || // @
        rune == 0x21 || // !
        rune == 0x24 || // $
        rune == 0x26 || // &
        rune == 0x27 || // '
        rune == 0x28 || // (
        rune == 0x29 || // )
        rune == 0x2A || // *
        rune == 0x2B || // +
        rune == 0x2C || // ,
        rune == 0x3B || // ;
        rune == 0x3D || // =
        rune == 0x25; // %
    if (isUnreserved || isReserved) {
      buffer.writeCharCode(rune);
    } else {
      for (final b in utf8.encode(String.fromCharCode(rune))) {
        buffer.write('%');
        buffer.write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
  }
  return buffer.toString();
}
