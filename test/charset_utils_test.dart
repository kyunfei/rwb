import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_engine/charset_utils.dart';

/// decodeResponse 曾对 GBK/GB2312 直接走 latin1 兜底，导致所有非 UTF-8
/// 中文书源正文乱码。这组测试锁死解码行为，防止回退。
void main() {
  group('decodeResponse', () {
    test('GBK 字节能正确解码，而非 latin1 乱码', () {
      // "第一章" 的 GBK 编码：B5DA D2BB D5C2
      final bytes = Uint8List.fromList([0xB5, 0xDA, 0xD2, 0xBB, 0xD5, 0xC2]);

      expect(CharsetUtils.decodeResponse(bytes, 'GBK'), '第一章');
      // 明确断言不等于旧的错误行为
      expect(CharsetUtils.decodeResponse(bytes, 'GBK'),
          isNot(equals(latin1.decode(bytes))));
    });

    test('GB 家族各别名走同一条解码路径', () {
      const text = '重生之都市修仙，第三十七回';
      final bytes = Uint8List.fromList(const GbkCodec().encode(text));

      for (final name in ['GBK', 'gbk', 'GB2312', 'gb-2312', 'GB18030',
        'cp936', 'windows-936']) {
        expect(CharsetUtils.decodeResponse(bytes, name), text,
            reason: '编码名 $name 解码失败');
      }
    });

    test('GBK 流中夹杂残缺字节时容错而不抛异常', () {
      // 合法 GBK + 一个孤立高位字节（真实网页常见的截断）
      final bytes = Uint8List.fromList([0xB5, 0xDA, 0xD2, 0xBB, 0xFF]);

      late String out;
      expect(() => out = CharsetUtils.decodeResponse(bytes, 'GBK'),
          returnsNormally);
      expect(out, startsWith('第一'));
    });

    test('UTF-8 与空 charset 仍按 UTF-8 处理', () {
      final bytes = Uint8List.fromList(utf8.encode('第一章'));

      expect(CharsetUtils.decodeResponse(bytes, 'UTF-8'), '第一章');
      expect(CharsetUtils.decodeResponse(bytes, ''), '第一章');
      expect(CharsetUtils.decodeResponse(bytes, null), '第一章');
    });

    test('未覆盖的编码回退到 latin-1 且不丢字节', () {
      // Big5 是已知缺口：charset 2.x 无该编码实现
      final bytes = Uint8List.fromList([0xA4, 0x40, 0xA4, 0x47]);

      final out = CharsetUtils.decodeResponse(bytes, 'Big5');
      expect(out.codeUnits.length, bytes.length,
          reason: 'latin-1 兜底必须逐字节保留，供调用方二次检测');
    });

    test('未知编码名不抛异常', () {
      final bytes = Uint8List.fromList([0x68, 0x69]);

      expect(CharsetUtils.decodeResponse(bytes, 'not-a-real-charset'), 'hi');
    });
  });

  group('detectCharsetFromHtml', () {
    test('识别 HTML5 meta charset 的各种写法', () {
      const cases = <String, String>{
        '<meta charset="gbk">': 'gbk',
        "<meta charset='GBK'>": 'GBK',
        '<meta charset=gbk>': 'gbk',
        '<meta charset="gbk" />': 'gbk',
        '<meta  charset = "GB18030" >': 'GB18030',
      };
      cases.forEach((html, expected) {
        expect(CharsetUtils.detectCharsetFromHtml(html), expected,
            reason: '未能从 $html 提取编码');
      });
    });

    test('识别 HTML4 http-equiv 写法', () {
      expect(
        CharsetUtils.detectCharsetFromHtml(
          '<meta http-equiv="Content-Type" '
          'content="text/html; charset=GB2312">',
        ),
        'GB2312',
      );
    });

    test('charset 值后带分号时不把分号并入', () {
      expect(
        CharsetUtils.detectCharsetFromHtml('<meta charset="gbk;">'),
        'gbk',
      );
    });

    test('真实 GBK 页面头部（latin-1 还原后）能嗅探出编码', () {
      // 模拟 web_book 的做法：GBK 字节用 latin-1 逐字节还原后做正则
      final bytes = const GbkCodec().encode(
        '<html><head><meta http-equiv="Content-Type" '
        'content="text/html; charset=gb2312"><title>第一章</title></head>',
      );
      final head = latin1.decode(bytes);

      expect(CharsetUtils.detectCharsetFromHtml(head), 'gb2312');
    });

    test('无 meta 声明时返回 null', () {
      expect(
        CharsetUtils.detectCharsetFromHtml('<html><head></head></html>'),
        isNull,
      );
      expect(CharsetUtils.detectCharsetFromHtml(''), isNull);
    });
  });

  group('detectCharsetFromHeaders', () {
    test('大小写不敏感地取出 charset', () {
      expect(
        CharsetUtils.detectCharsetFromHeaders(
          {'Content-Type': 'text/html; charset=GBK'},
        ),
        'GBK',
      );
      expect(
        CharsetUtils.detectCharsetFromHeaders(
          {'content-type': 'text/html; charset=utf-8'},
        ),
        'utf-8',
      );
    });
  });
}
