import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/shelf/shelf_toc_entry.dart';
import 'package:mr/services/shelf/shelf_chapter_diff.dart';

void main() {
  group('ShelfChapterDiff', () {
    test('first snapshot does not report new chapters', () {
      final current = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章', url: 'https://a/2'),
      ];
      final result = ShelfChapterDiff.compare([], current);
      expect(result.isFirstSnapshot, isTrue);
      expect(result.hasNewChapters, isFalse);
    });

    test('detects newly appended chapters by url', () {
      final previous = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
      ];
      final current = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章', url: 'https://a/2'),
        const ShelfTocEntry(title: '第三章', url: 'https://a/3'),
      ];
      final result = ShelfChapterDiff.compare(previous, current);
      expect(result.hasNewChapters, isTrue);
      expect(result.newChapterCount, 2);
      expect(result.newChapterTitles, ['第二章', '第三章']);
    });

    test('ignores volume-only rows without url', () {
      final previous = [
        const ShelfTocEntry(title: '第一卷', isVolume: true),
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
      ];
      final current = [
        const ShelfTocEntry(title: '第一卷', isVolume: true),
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章', url: 'https://a/2'),
      ];
      final result = ShelfChapterDiff.compare(previous, current);
      expect(result.newChapterCount, 1);
    });

    test('detects last chapter replacement without count change', () {
      final previous = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章 旧', url: 'https://a/2-old'),
      ];
      final current = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章 新', url: 'https://a/2-new'),
      ];
      final result = ShelfChapterDiff.compare(previous, current);
      expect(result.hasNewChapters, isTrue);
    });

    test('no update when directory unchanged', () {
      final list = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章', url: 'https://a/2'),
      ];
      final result = ShelfChapterDiff.compare(list, list);
      expect(result.hasNewChapters, isFalse);
      expect(result.newChapterCount, 0);
    });

    test('reports removed chapters count without treating as new', () {
      final previous = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第二章', url: 'https://a/2'),
        const ShelfTocEntry(title: '第三章', url: 'https://a/3'),
      ];
      final current = [
        const ShelfTocEntry(title: '第一章', url: 'https://a/1'),
        const ShelfTocEntry(title: '第三章', url: 'https://a/3'),
      ];
      final result = ShelfChapterDiff.compare(previous, current);
      expect(result.removedChapterCount, 1);
      expect(result.hasNewChapters, isFalse);
    });
  });
}
