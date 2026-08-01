import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_import_logic.dart';

/// 文件选择器已放开为「任意类型」（Android 按后缀过滤实为按 MIME 过滤，
/// 会把 .json 置灰导致选不中），所以把守门的责任移到了这个纯函数上。
void main() {
  group('validateSourceFilePick', () {
    test('json/txt/js 都放行', () {
      for (final ext in supportedSourceFileExtensions) {
        expect(
          validateSourceFilePick(
            fileName: 'sources.$ext',
            extension: ext,
            sizeBytes: 1024,
          ),
          isNull,
          reason: '.$ext 应该被接受',
        );
      }
    });

    test('后缀大写也放行', () {
      expect(
        validateSourceFilePick(
          fileName: 'SOURCES.JSON',
          extension: 'JSON',
          sizeBytes: 1024,
        ),
        isNull,
      );
    });

    test('拒绝无关类型，且提示里带上用户选的文件名', () {
      final reason = validateSourceFilePick(
        fileName: '电影.mp4',
        extension: 'mp4',
        sizeBytes: 1024,
      );
      expect(reason, isNotNull);
      expect(reason, contains('.mp4'));
      expect(reason, contains('电影.mp4'));
    });

    test('没有后缀时不崩，给出可读提示', () {
      final reason = validateSourceFilePick(
        fileName: 'sources',
        extension: null,
        sizeBytes: 1024,
      );
      expect(reason, isNotNull);
      expect(reason, contains('无后缀'));
    });

    test('超过大小上限的文件被拦下', () {
      final reason = validateSourceFilePick(
        fileName: 'huge.json',
        extension: 'json',
        sizeBytes: maxSourceFileBytes + 1,
      );
      expect(reason, isNotNull);
      expect(reason, contains('太大'));
    });

    test('正好等于上限的文件放行（边界不误杀）', () {
      expect(
        validateSourceFilePick(
          fileName: 'big.json',
          extension: 'json',
          sizeBytes: maxSourceFileBytes,
        ),
        isNull,
      );
    });

    test('大小未知（null）时不拦，交给后续解析报错', () {
      expect(
        validateSourceFilePick(
          fileName: 'sources.json',
          extension: 'json',
          sizeBytes: null,
        ),
        isNull,
      );
    });

    test('allowed 收窄到 js 时，json 被拒且提示只提 .js', () {
      final reason = validateSourceFilePick(
        fileName: 'sources.json',
        extension: 'json',
        sizeBytes: 1024,
        allowed: const ['js'],
      );
      expect(reason, isNotNull);
      expect(reason, contains('.js'));
      expect(reason, isNot(contains('.txt')));
    });
  });
}
