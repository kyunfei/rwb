import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book.dart';
import 'package:mr/utils/book_metadata_merge.dart';

Book _searchBook({
  String name = '搜索书名',
  String author = '搜索作者',
  String coverUrl = 'https://img/c.jpg',
  String intro = '搜索简介',
  String? kind = '玄幻',
  String? lastChapter = '第一百章',
  String? tocUrl,
}) {
  return Book(
    bookUrl: 'https://books.example/1',
    name: name,
    author: author,
    coverUrl: coverUrl,
    intro: intro,
    mediaType: MediaType.novel,
    originType: BookOriginType.online,
    sourceUrl: 'https://source.example',
    kind: kind,
    lastChapter: lastChapter,
    tocUrl: tocUrl,
    addedTime: DateTime(2026),
  );
}

Book _detailBook({
  String name = '',
  String author = '',
  String coverUrl = '',
  String intro = '',
  String? kind,
  String? lastChapter,
  String? tocUrl,
}) {
  return Book(
    bookUrl: 'https://books.example/1',
    name: name,
    author: author,
    coverUrl: coverUrl,
    intro: intro,
    mediaType: MediaType.novel,
    originType: BookOriginType.online,
    sourceUrl: 'https://source.example',
    kind: kind,
    lastChapter: lastChapter,
    tocUrl: tocUrl,
    addedTime: DateTime(2026),
  );
}

void main() {
  group('isMissingBookField', () {
    test('null empty and whitespace are missing', () {
      expect(isMissingBookField(null), isTrue);
      expect(isMissingBookField(''), isTrue);
      expect(isMissingBookField('   '), isTrue);
      expect(isMissingBookField('\t\n'), isTrue);
    });

    test('non-blank is present', () {
      expect(isMissingBookField('x'), isFalse);
      expect(isMissingBookField('  x  '), isFalse);
    });
  });

  group('mergeBookMetadata', () {
    test('detail all empty uses search values', () {
      final merged = mergeBookMetadata(
        _detailBook(),
        _searchBook(),
        tocUrlFallback: 'https://books.example/1',
      );

      expect(merged.name, '搜索书名');
      expect(merged.author, '搜索作者');
      expect(merged.coverUrl, 'https://img/c.jpg');
      expect(merged.intro, '搜索简介');
      expect(merged.kind, '玄幻');
      expect(merged.lastChapter, '第一百章');
      expect(merged.tocUrl, 'https://books.example/1');
    });

    test('detail partial values prefer detail where present', () {
      final merged = mergeBookMetadata(
        _detailBook(
          name: '详情书名',
          intro: '更长简介',
          lastChapter: ' ',
        ),
        _searchBook(),
        tocUrlFallback: 'https://books.example/1',
      );

      expect(merged.name, '详情书名');
      expect(merged.author, '搜索作者');
      expect(merged.intro, '更长简介');
      expect(merged.lastChapter, '第一百章');
    });

    test('detail whitespace-only fields fall back to search', () {
      final merged = mergeBookMetadata(
        _detailBook(name: '  ', author: '\n'),
        _searchBook(),
      );

      expect(merged.name, '搜索书名');
      expect(merged.author, '搜索作者');
    });

    test('both sides empty yields empty strings without crash', () {
      final merged = mergeBookMetadata(
        _detailBook(),
        _searchBook(
          name: '',
          author: '',
          coverUrl: '',
          intro: '',
          kind: null,
          lastChapter: null,
        ),
        tocUrlFallback: 'https://books.example/1',
      );

      expect(merged.name, '');
      expect(merged.author, '');
      expect(merged.tocUrl, 'https://books.example/1');
    });

    test('tocUrl uses detail when present', () {
      final merged = mergeBookMetadata(
        _detailBook(tocUrl: 'https://books.example/toc'),
        _searchBook(tocUrl: 'https://search/toc'),
        tocUrlFallback: 'https://books.example/1',
      );

      expect(merged.tocUrl, 'https://books.example/toc');
    });

    test('tocUrl falls back to detail page url when missing', () {
      final merged = mergeBookMetadata(
        _detailBook(),
        _searchBook(),
        tocUrlFallback: 'https://books.example/1',
      );

      expect(merged.tocUrl, 'https://books.example/1');
    });
  });
}
