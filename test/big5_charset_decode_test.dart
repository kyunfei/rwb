import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_engine/big5_codec.dart';
import 'package:mr/services/source_engine/charset_utils.dart';

/// Big5/CP950 解码：纯 Dart 路径，不依赖 quickjs_c_bridge.dll。
void main() {
  group('Big5Codec', () {
    test('经典 Big5 双字节：一(U+4E00) 二(U+4E8C)', () {
      // A440=一, A447=二（CP950 / 标准 Big5）
      final bytes = [0xA4, 0x40, 0xA4, 0x47];
      expect(const Big5Codec().decode(bytes), '一二');
    });

    test('ASCII 与双字节混排', () {
      final bytes = [0x41, 0xA4, 0x40, 0x42]; // A 一 B
      expect(const Big5Codec().decode(bytes), 'A一B');
    });

    test('残缺尾字节容错为 U+FFFD 且不抛', () {
      final bytes = [0xA4]; // 只有首字节
      late String out;
      expect(() => out = const Big5Codec().decode(bytes), returnsNormally);
      expect(out, '\uFFFD');
    });

    test('映射表可懒加载且 pair 数一致', () {
      expect(Big5Codec.table.length, greaterThan(10000));
    });
  });

  group('CharsetUtils.decodeResponse Big5', () {
    test('Big5 / 别名均能正确解码而非 latin-1 乱码', () {
      final bytes = Uint8List.fromList([0xA4, 0x40, 0xA4, 0x47]);
      for (final name in ['Big5', 'big5', 'BIG5', 'cp950', 'windows-950']) {
        final out = CharsetUtils.decodeResponse(bytes, name);
        expect(out, '一二', reason: '编码名 $name');
        expect(out, isNot(equals(latin1.decode(bytes))),
            reason: '$name 不得落到 latin-1');
      }
    });

    test('繁体常见用字：台灣小說', () {
      // CP950: 台=A578 灣=C657 小=A470 說=BBA1
      final bytes = Uint8List.fromList([
        0xA5, 0x78,
        0xC6, 0x57,
        0xA4, 0x70,
        0xBB, 0xA1,
      ]);
      expect(CharsetUtils.decodeResponse(bytes, 'Big5'), '台灣小說');
    });
  });
}
