import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book.dart';
import 'package:mr/utils/continue_reading.dart';

Book _book({
  required String name,
  DateTime? durChapterTime,
  int durChapterIndex = 0,
  String durChapterTitle = '',
}) {
  return Book(
    bookUrl: 'https://example.com/$name',
    name: name,
    author: '作者',
    mediaType: MediaType.novel,
    originType: BookOriginType.online,
    addedTime: DateTime(2024, 1, 1),
    durChapterTime: durChapterTime,
    durChapterIndex: durChapterIndex,
    durChapterTitle: durChapterTitle,
  );
}

void main() {
  group('pickLatestReadingBook', () {
    test('书架为空 → null', () {
      expect(pickLatestReadingBook(const []), isNull);
    });

    test('全部书 durChapterTime 为 null → null', () {
      final books = [
        _book(name: '甲'),
        _book(name: '乙'),
      ];
      expect(pickLatestReadingBook(books), isNull);
    });

    test('部分为 null → 选有值的里最新的', () {
      final older = DateTime(2025, 1, 1);
      final newer = DateTime(2025, 6, 1);
      final books = [
        _book(name: '未读'),
        _book(name: '较旧', durChapterTime: older, durChapterTitle: '第1章'),
        _book(name: '也未读'),
        _book(name: '较新', durChapterTime: newer, durChapterTitle: '第10章'),
      ];
      final picked = pickLatestReadingBook(books);
      expect(picked?.name, '较新');
      expect(picked?.durChapterTitle, '第10章');
    });

    test('多本都有值 → 选最新的', () {
      final books = [
        _book(name: 'A', durChapterTime: DateTime(2025, 3, 1)),
        _book(name: 'B', durChapterTime: DateTime(2025, 8, 1)),
        _book(name: 'C', durChapterTime: DateTime(2025, 5, 1)),
      ];
      expect(pickLatestReadingBook(books)?.name, 'B');
    });
  });
}
