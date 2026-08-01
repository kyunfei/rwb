import 'dart:convert';
import 'dart:typed_data';
import 'package:charset/charset.dart';
import '../native/js_engine.dart';
import 'big5_codec.dart';

/// 编码工具函数库
///
/// 提供 HTTP 请求链路的全流程编码支持：
/// - [urlEncode]：按指定字符集对字符串进行 URL 编码（GBK/UTF-8 等）
/// - [decodeResponse]：按指定字符集解码 HTTP 响应字节流
/// - [detectCharsetFromHeaders]：从 Content-Type 头提取 charset
/// - [detectCharsetFromHtml]：从 HTML meta 标签检测 charset
///
/// 解码优先走 Dart 侧：`charset` 包注册表（GBK 等）+ 内置 Big5/CP950 表；
/// URL 编码中的非 UTF-8 仍走 C 原生层（quickjs charset_conv.c，目前主要覆盖 GB 族）。
class CharsetUtils {
  /// URL-encode 字符串，使用指定字符集
  ///
  /// 例如中文 "搜索" 用 GBK 编码会被转为 %CB%D1%CB%F7，
  /// 用 UTF-8 编码则转为 %E6%90%9C%E7%B4%A2。
  ///
  /// [str] 待编码字符串
  /// [charset] 字符集名称，如 "GBK", "UTF-8", "GB2312"。为空或 "UTF-8" 时使用 [Uri.encodeComponent]
  /// 返回 percent-encoded 字符串
  static String urlEncode(String str, String charset) {
    if (str.isEmpty) return str;
    final cs = charset.trim().toLowerCase();
    if (cs.isEmpty || cs == 'utf-8' || cs == 'utf8') {
      return Uri.encodeComponent(str);
    }
    // 通过 C 原生层进行 GBK/GB2312/GB18030 编码（charset_conv.c 当前无 Big5）
    // JsEngine.urlEncodeNative 调用 quickjs charset_url_encode
    try {
      final result = JsEngine.instance.urlEncodeNative(str, charset.trim());
      if (result.isNotEmpty) return result;
    } catch (_) {}
    // 原生不可用时回退 UTF-8
    return Uri.encodeComponent(str);
  }

  /// 从 HTTP 响应头中检测字符集
  ///
  /// 优先解析 [Content-Type: text/html; charset=GBK] 中的 charset 值。
  /// 支持 key 大小写不敏感。
  static String? detectCharsetFromHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return null;
    // 大小写不敏感查找 content-type
    final contentType = headers.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    if (contentType.isEmpty) return null;
    final charsetMatch = RegExp(
      r"""charset\s*=\s*([^;\s"']+)""",
      caseSensitive: false,
    ).firstMatch(contentType);
    if (charsetMatch == null) return null;
    return charsetMatch.group(1);
  }

  /// 从 HTML 文档中检测字符集
  ///
  /// 按优先级检测：
  /// 1. `<meta charset="xxx">`（HTML5 写法）
  /// 2. `<meta http-equiv="Content-Type" content="...charset=xxx">`
  ///
  /// [html] HTML 文档字符串（可能是已用 UTF-8 解码的，我们只在表面做正则匹配）
  /// 返回检测到的 charset 名称，未检测到时返回 null
  static String? detectCharsetFromHtml(String html) {
    if (html.isEmpty) return null;
    // 1. HTML5: <meta charset="xxx"> / <meta charset=xxx>
    final metaMatch = RegExp(
      r"""<meta[^>]+charset\s*=\s*["']?\s*([^"'\s>/;]+)""",
      caseSensitive: false,
    ).firstMatch(html);
    if (metaMatch != null) {
      final cs = metaMatch.group(1)!.trim();
      if (cs.isNotEmpty) return cs;
    }
    // 2. HTML4/XHTML: <meta http-equiv="Content-Type" content="text/html; charset=xxx">
    // 上面的正则未命中时才走这里（原实现在此之前直接 return null，令本分支不可达）
    final httpEquivMatch = RegExp(
      r"""<meta[^>]+http-equiv\s*=\s*["']?\s*Content-Type\s*["']?[^>]+"""
      r"""content\s*=\s*["'][^"']*charset\s*=\s*([^"'\s>;]+)""",
      caseSensitive: false,
    ).firstMatch(html);
    if (httpEquivMatch != null) {
      final cs = httpEquivMatch.group(1)!.trim();
      if (cs.isNotEmpty) return cs;
    }
    return null;
  }

  /// GB 家族编码名。charset 包注册表里的 `gbk` 实例是 `allowMalformed: false`，
  /// 遇到脏字节会抛异常；书源网页常有残缺字节，故这一族单独用容错实例解码。
  static const _gbFamily = <String>{
    'gbk',
    'gb2312',
    'gb-2312',
    'gb_2312',
    'gb18030',
    'cp936',
    'cp-936',
    'ms936',
    'windows-936',
  };

  /// Big5 / CP950 别名。charset 2.x 无 Big5 实现，走内置纯 Dart 映射表。
  static const _big5Family = <String>{
    'big5',
    'big-5',
    'big_5',
    'cn-big5',
    'csbig5',
    'x-x-big5',
    'cp950',
    'cp-950',
    'windows-950',
    'ms950',
  };

  /// 将字节数组按指定字符集解码为字符串
  ///
  /// 通过 charset 包的编码注册表支持 GBK/GB2312/GB18030/EUC-JP/EUC-KR/
  /// Shift_JIS/windows-125x/ISO-8859-x/UTF-16/UTF-32，叠加 dart:convert
  /// 内置的 utf-8/latin-1/ascii；Big5/CP950 由内置 [Big5Codec] 覆盖
  ///（纯 Dart，Windows 单测无需 quickjs_c_bridge.dll）。
  static String decodeResponse(Uint8List bytes, String? charset) {
    final cs = charset?.trim().toLowerCase() ?? '';
    if (cs.isEmpty || cs == 'utf-8' || cs == 'utf8') {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (cs == 'latin-1' || cs == 'latin1' || cs == 'iso-8859-1') {
      return latin1.decode(bytes);
    }
    if (cs == 'ascii') {
      // 容错：ascii.decode 遇到高位字节会抛，交给下面的兜底
      return ascii.decode(bytes, allowInvalid: true);
    }
    if (_gbFamily.contains(cs)) {
      try {
        return const GbkCodec(allowMalformed: true).decode(bytes);
      } catch (_) {
        // 落到下方兜底
      }
    }
    if (_big5Family.contains(cs)) {
      try {
        return const Big5Codec(allowMalformed: true).decode(bytes);
      } catch (_) {
        // 落到下方兜底
      }
    }
    final encoding = Charset.getByName(cs);
    if (encoding != null) {
      try {
        return encoding.decode(bytes);
      } catch (_) {
        // 落到下方兜底
      }
    }
    // 注册表仍未覆盖或解码失败：latin-1 保证不丢字节，
    // 调用方可用 detectCharsetFromHtml 二次检测后重新解码
    try {
      return latin1.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 从 URL 路径/扩展名推断编码（扩展用，暂不实现）
  /// 预留用于 "根据 URL 模板信息注册对应编码"
  static String? detectCharsetFromUrl(String url) {
    // TODO: 某些书源在 URL 中包含编码信息
    return null;
  }
}