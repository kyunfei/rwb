import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/reader_typography.dart';

void main() {
  group('ReaderTypography.isPredominantlyLatin', () {
    test('detects English prose', () {
      const text =
          'It is a truth universally acknowledged, that a single man in '
          'possession of a good fortune, must be in want of a wife.';
      expect(ReaderTypography.isPredominantlyLatin(text), isTrue);
    });

    test('detects Chinese web novel lines', () {
      const text = '萧炎缓缓睁开双眼，淡淡的光芒自眸中闪过。'
          '今日便是分家大典，他必须尽快突破。';
      expect(ReaderTypography.isPredominantlyLatin(text), isFalse);
    });

    test('short mixed snippets stay non-latin', () {
      expect(ReaderTypography.isPredominantlyLatin('Hi 你好'), isFalse);
    });
  });

  group('ReaderTypography.splitToParagraphs', () {
    test('Chinese keeps one paragraph per non-empty line', () {
      const text = '第一段内容在这里。\n第二段另一行。\n\n第三段。';
      final paras = ReaderTypography.splitToParagraphs(text);
      expect(paras, ['第一段内容在这里。', '第二段另一行。', '第三段。']);
    });

    test('English soft-wraps join; blank line splits paragraphs', () {
      const text = '''
It is a truth universally acknowledged, that a single man in
possession of a good fortune, must be in want of a wife.

However little known the feelings or views of such a man may be
on his first entering a neighbourhood, this truth is so well
fixed.
''';
      final paras = ReaderTypography.splitToParagraphs(text);
      expect(paras, hasLength(2));
      expect(paras[0], contains('universally acknowledged'));
      expect(paras[0], contains('want of a wife'));
      expect(paras[0].contains('\n'), isFalse);
      expect(paras[1], startsWith('However little known'));
      // 不得在单词中间因硬换行留下断裂痕迹（拼合后应为连续词）
      expect(paras[0], contains('in possession'));
      expect(paras[1], contains('be on his first'));
    });

    test('English without blank lines becomes a single paragraph', () {
      const text = '''
Call me Ishmael. Some years ago—never mind how long precisely—
having little or no money in my purse, I thought I would sail
about a little and see the watery part of the world.
''';
      final paras = ReaderTypography.splitToParagraphs(text);
      expect(paras, hasLength(1));
      expect(paras.single, contains('Call me Ishmael'));
      expect(paras.single, contains('watery part of the world'));
    });
  });

  group('ReaderTypography indent / wrap css', () {
    test('latin indent is capped', () {
      expect(
        ReaderTypography.effectiveIndentEm(
          configuredEm: 2,
          latinDominant: true,
        ),
        1.5,
      );
      expect(
        ReaderTypography.effectiveIndentEm(
          configuredEm: 2,
          latinDominant: false,
        ),
        2,
      );
      expect(
        ReaderTypography.effectiveIndentEm(
          configuredEm: 0,
          latinDominant: true,
        ),
        0,
      );
    });

    test('wrap css prefers word boundaries', () {
      expect(ReaderTypography.paragraphWrapCss, contains('word-break: normal'));
      expect(
        ReaderTypography.paragraphWrapCss,
        contains('overflow-wrap: break-word'),
      );
      expect(
        ReaderTypography.paragraphWrapCss.contains('break-all'),
        isFalse,
      );
    });

    test('content format indent differs by script', () {
      expect(
        ReaderTypography.contentFormatIndent(latinDominant: true),
        '  ',
      );
      expect(
        ReaderTypography.contentFormatIndent(latinDominant: false),
        '\u3000\u3000',
      );
    });
  });
}
