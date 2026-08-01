import 'dart:convert';

import '../models/book_source.dart';

/// 从完整 URL 中提取根 URL（scheme://host），用作 Referer
String extractBaseUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.hasScheme && uri.host.isNotEmpty) {
      return '${uri.scheme}://${uri.host}';
    }
  } catch (_) {
    // 落到下方原样返回
  }
  return url;
}

/// 构建封面图请求头。
///
/// 很多书源站点有防盗链，加载封面必须带 Referer 和 User-Agent，否则返回 403。
/// 书源的 header 字段既可能是 JSON，也可能是按行的 `Key: Value`，两种都要认。
/// 书源自带的同名头优先，这里只补它没给的。
///
/// 纯函数：不读存储、不碰 Widget，便于单测。
Map<String, String> buildCoverHeaders({
  required BookSource? source,
  required String? sourceUrl,
}) {
  final headers = <String, String>{};
  if (sourceUrl == null || sourceUrl.isEmpty) return headers;

  final headerStr = source?.header;
  if (headerStr != null && headerStr.isNotEmpty) {
    try {
      final decoded = json.decode(headerStr);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final val = value.toString();
          if (val.isNotEmpty) {
            headers[key.toString()] = val;
          }
        });
      }
    } catch (_) {
      // 非 JSON，按行解析 Key: Value
      for (final line in headerStr.split('\n')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join(':').trim();
          if (key.isNotEmpty && val.isNotEmpty) {
            headers[key] = val;
          }
        }
      }
    }
  }

  headers.putIfAbsent('Referer', () => extractBaseUrl(sourceUrl));
  headers.putIfAbsent(
    'User-Agent',
    () => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  );

  return headers;
}
