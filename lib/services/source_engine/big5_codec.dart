import 'dart:convert';
import 'dart:typed_data';

import 'big5_table.dart';

/// 纯 Dart Big5/CP950 解码器（不依赖原生库或额外 pub 包）。
///
/// 映射表由 Windows CP950 生成，覆盖经典 Big5 与常见扩展区，
/// 供 [CharsetUtils.decodeResponse] 在 charset 包未提供 Big5 时使用。
class Big5Codec {
  const Big5Codec({this.allowMalformed = true});

  final bool allowMalformed;

  static Map<int, int>? _table;

  /// 懒加载：base64 解包为 Big5 code → Unicode 映射。
  static Map<int, int> get table {
    final cached = _table;
    if (cached != null) return cached;

    final raw = base64Decode(kBig5PackedBase64);
    if (raw.length != kBig5PairCount * 4) {
      throw StateError(
        'Big5 table size mismatch: ${raw.length} vs ${kBig5PairCount * 4}',
      );
    }
    final map = <int, int>{};
    final bd = ByteData.sublistView(raw);
    for (var i = 0; i < kBig5PairCount; i++) {
      final o = i * 4;
      final code = bd.getUint16(o, Endian.little);
      final uni = bd.getUint16(o + 2, Endian.little);
      map[code] = uni;
    }
    return _table = map;
  }

  String decode(List<int> bytes) {
    final map = table;
    final out = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final b0 = bytes[i] & 0xFF;
      if (b0 <= 0x7F) {
        out.writeCharCode(b0);
        i++;
        continue;
      }
      // Big5/CP950 双字节：首字节 0x81-0xFE
      if (b0 >= 0x81 && b0 <= 0xFE && i + 1 < bytes.length) {
        final b1 = bytes[i + 1] & 0xFF;
        final code = (b0 << 8) | b1;
        final uni = map[code];
        if (uni != null) {
          out.writeCharCode(uni);
          i += 2;
          continue;
        }
      }
      if (!allowMalformed) {
        throw FormatException('Invalid Big5 sequence at offset $i');
      }
      // 容错：孤立高位字节 → U+FFFD，与 GBK 路径一致
      out.writeCharCode(0xFFFD);
      i++;
    }
    return out.toString();
  }
}
